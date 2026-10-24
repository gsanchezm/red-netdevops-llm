#!/usr/bin/env bash
# Matriz de alcanzabilidad (docs/02-diseno.md §5): ejecuta lab/matriz/casos.txt contra la
# topología levantada y compara lo observado con lo esperado.
# Uso:  scripts/matriz.sh plana|segmentada [archivo-salida.md]
# Código de salida: 0 si todos los casos coinciden; 1 si alguno falla.
set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOPO="${1:-}"
SALIDA="${2:-$RAIZ/evidencia/dia2/matriz-$TOPO.md}"
CASOS="$RAIZ/lab/matriz/casos.txt"
PARALELO=12

[[ $TOPO == plana || $TOPO == segmentada ]] || { echo "Uso: $0 plana|segmentada [salida.md]" >&2; exit 2; }
docker inspect caddy >/dev/null 2>&1 || { echo "La topología '$TOPO' no está levantada: scripts/lab.sh $TOPO" >&2; exit 2; }

recortar() { local v="$1"; v="${v#"${v%%[![:space:]]*}"}"; printf '%s' "${v%"${v##*[![:space:]]}"}"; }

# servicio[@segmento] -> IP del contenedor en esa red (en la plana solo hay una red).
ip_destino() {
  [[ $1 == [0-9]* ]] && { echo "$1"; return; }
  local svc="${1%@*}" red=""
  [[ $1 == *@* ]] && red="${1#*@}"
  docker inspect -f '{{range $n,$v := .NetworkSettings.Networks}}{{$n}} {{$v.IPAddress}}{{"\n"}}{{end}}' "$svc" 2>/dev/null \
    | awk -v red="$red" -v topo="$TOPO" 'NF==2 && (red=="" || topo=="plana" || $1==topo"_"red) { print $2; exit }'
}

# Las sondas comparten el espacio de red del contenedor de origen (misma IP, rutas y reglas) y
# traen sus propias herramientas desde lab-nodo: así el origen puede ser una imagen real
# (Caddy, Ollama, Hermes) que no incluye nc ni curl.
sonda() { local origen="$1" herramienta="$2"; shift 2; docker run --rm --network "container:$origen" -v "$RAIZ/lab/ca:/ca:ro" --entrypoint "$herramienta" lab-nodo:1 "$@"; }

# abierto | rechazado (RST) | sin-ruta | sin-respuesta (descartado)
sondear() {
  local s
  s="$(sonda "$1" nc -zv -w 2 "$2" "$3" 2>&1)"
  case "$s" in
    *succeeded*)            echo abierto ;;
    *refused*)              echo rechazado ;;
    *unreachable*|*"No route"*) echo sin-ruta ;;
    *)                      echo sin-respuesta ;;
  esac
}

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
declare -a IDS CELDAS ORIG DEST IPS PUERTOS ESPERADOS
n=0
while IFS='|' read -r id celda origen destino puerto e_seg e_pla nota; do
  id="$(recortar "$id")"
  [[ -z $id || $id == \#* ]] && continue
  esperado="$(recortar "$e_seg")"; [[ $TOPO == plana ]] && esperado="$(recortar "$e_pla")"
  [[ $esperado == "-" ]] && continue
  IDS[n]="$id"; CELDAS[n]="$(recortar "$celda")"; ORIG[n]="$(recortar "$origen")"
  DEST[n]="$(recortar "$destino")"; PUERTOS[n]="$(recortar "$puerto")"; ESPERADOS[n]="$esperado"
  IPS[n]="$(ip_destino "${DEST[n]}")"
  [[ -n ${IPS[n]} ]] || { echo "No se pudo resolver el destino ${DEST[n]} (caso $id)" >&2; exit 2; }
  n=$((n+1))
done < "$CASOS"

# Las pruebas bloqueadas esperan el tiempo de espera completo: se ejecutan en paralelo.
for ((i=0; i<n; i++)); do
  ( sondear "${ORIG[i]}" "${IPS[i]}" "${PUERTOS[i]}" > "$TMP/$i" ) &
  (( (i+1) % PARALELO == 0 )) && wait
done
wait

fallas=0; bloq_filtro=0; bloq_ruta=0
{
  echo "# Matriz de alcanzabilidad · topología $TOPO"
  echo
  echo "Generada $(date '+%Y-%m-%d %H:%M:%S %z') con \`scripts/matriz.sh $TOPO\` (política: docs/02-diseno.md §5)."
  echo
  echo "| Caso | Celda de §5 | Origen → destino:puerto | Esperado | Observado | Resultado |"
  echo "|---|---|---|---|---|---|"
  for ((i=0; i<n; i++)); do
    obs="$(<"$TMP/$i")"
    if [[ $obs == abierto ]]; then real=permitir; else real=bloquear; fi
    # "sin-ruta": el paquete no sale del origen (segmento internal); ninguna regla lo ve.
    if [[ $obs == sin-ruta ]]; then bloq_ruta=$((bloq_ruta+1)); elif [[ $obs != abierto ]]; then bloq_filtro=$((bloq_filtro+1)); fi
    if [[ $real == "${ESPERADOS[i]}" ]]; then res="✅ OK"; else res="❌ FALLA"; fallas=$((fallas+1)); fi
    echo "| ${IDS[i]} | ${CELDAS[i]} | ${ORIG[i]} → ${DEST[i]} (${IPS[i]}):${PUERTOS[i]} | ${ESPERADOS[i]} | $obs | $res |"
  done
  echo
  # Comprobaciones adicionales (código HTTP, o "fallo" si curl no pudo conectar o verificar TLS).
  extra() { # descripción esperado origen url [opciones de curl...]
    local desc="$1" esperado="$2" origen="$3" url="$4"; shift 4
    local obtenido; obtenido="$(sonda "$origen" curl -sS -m 10 -o /dev/null -w '%{http_code}' "$@" "$url" 2>/dev/null)" || obtenido=fallo
    [[ $obtenido == 000 ]] && obtenido=fallo
    if [[ $obtenido == "$esperado" ]]; then res="✅ OK"; else res="❌ FALLA"; fallas=$((fallas+1)); fi
    n=$((n+1))
    echo "- $desc (esperado \`$esperado\`): obtenido \`$obtenido\` · $res"
  }
  # Admin solo sale por TCP 443: los nombres deben resolverse sin abrir otros puertos hacia afuera.
  extra "Admin resuelve y abre https://github.com" 200 hermes https://github.com
  if [[ $TOPO == segmentada ]]; then
    # La API de la IA solo se alcanza por Caddy con TLS; el certificado es de la CA interna.
    extra "Trabajo → https://ia.lab.internal/api/tags con la CA interna" 200 proyecto1 https://ia.lab.internal/api/tags --cacert /ca/root.crt
    extra "Trabajo → https://10.10.10.5/api/tags (por IP) con la CA interna" 200 proyecto1 https://10.10.10.5/api/tags --cacert /ca/root.crt
    extra "Admin → https://ia.lab.internal/api/tags con la CA interna" 200 hermes https://ia.lab.internal/api/tags --cacert /ca/root.crt
    extra "Trabajo → https://ia.lab.internal sin la CA interna (el certificado no es público)" fallo proyecto1 https://ia.lab.internal/api/tags
    extra "Invitados → https://ia.lab.internal (no resuelve: sin pata de Caddy)" fallo invitado https://ia.lab.internal/api/tags --cacert /ca/root.crt
  else
    extra "Trabajo → http://ollama:11434/api/tags directo, sin TLS ni control" 200 proyecto1 http://10.10.0.10:11434/api/tags
  fi
  echo
  echo "**Bloqueos observados:** $((bloq_filtro+bloq_ruta)) · descartados por el filtrado del kernel: $bloq_filtro · sin ruta desde el origen (segmentos \`internal\`): $bloq_ruta"
  echo
  echo "**Casos:** $n · **Fallas:** $fallas"
} > "$SALIDA"

cat "$SALIDA"
echo
echo "Escrito en $SALIDA"
[[ $fallas -eq 0 ]]
