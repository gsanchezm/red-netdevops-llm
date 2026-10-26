#!/usr/bin/env bash
# Latencia de la API de la IA (docs/02-diseno.md §8): TCP, TLS, primer token, total y tokens/s,
# con la misma petición (streaming, sin razonamiento, 48 tokens) por cada ruta de la topología levantada:
#   plana:      cliente de Trabajo -> Ollama directo, sin TLS (:11434)
#   segmentada: cliente de Trabajo -> Caddy (TLS, CA interna) -> Ollama; y Caddy -> Ollama directo
#               (el salto interno que Caddy añade); más la nube como referencia de solo conexión.
# Uso (root):  scripts/latencia-api.sh [N]      (N = peticiones por ruta, 10 por defecto)
# Salida: evidencia/dia3/latencia-<topología>.md
set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
N="${1:-10}"
MODELO="${MODELO:-qwen3.5:2b}"
redes="$(docker inspect -f '{{range $k,$v := .NetworkSettings.Networks}}{{$k}} {{end}}' ollama 2>/dev/null)" || { echo "Ollama no está levantado" >&2; exit 2; }
case "$redes" in
  *segmentada_*) TOPO=segmentada ;;
  *plana_*)      TOPO=plana ;;
  *)             echo "No se reconoce la topología ($redes)" >&2; exit 2 ;;
esac
SALIDA="${SALIDA:-$RAIZ/evidencia/dia3/latencia-$TOPO.md}"; mkdir -p "$(dirname "$SALIDA")"

# Bucle de medición dentro de un contenedor con curl que comparte la red del origen.
# Imprime por petición: tcp tls primer_byte total tokens ns_generacion (segundos en curl).
BUCLE='N="$1"; URL="$2"; shift 2
BODY='"'"'{"model":"'"$MODELO"'","prompt":"Explica en una frase qué es una VLAN.","stream":true,"think":false,"options":{"num_predict":48,"temperature":0,"seed":1}}'"'"'
i=0
while [ "$i" -lt "$N" ]; do
  i=$((i+1))
  t=$(curl -sS -m 120 "$@" -H "Content-Type: application/json" -d "$BODY" -o /tmp/r -w "%{time_connect} %{time_appconnect} %{time_starttransfer} %{time_total}" "$URL") || { echo ERR; continue; }
  e=$(tail -n 1 /tmp/r | sed -n "s/.*\"eval_count\":\([0-9]*\),\"eval_duration\":\([0-9]*\).*/\1 \2/p")
  echo "$t $e"
done'
BUCLE_SIMPLE='N="$1"; URL="$2"; shift 2
i=0
while [ "$i" -lt "$N" ]; do
  i=$((i+1))
  curl -sS -m 30 "$@" -o /dev/null -w "%{time_connect} %{time_appconnect} %{time_starttransfer} %{time_total}\n" "$URL" || echo ERR
done'

medir() { # origen "bucle" url [opciones de curl]
  local origen="$1" bucle="$2"; shift 2
  docker run --rm --network "container:$origen" -v "$RAIZ/lab/ca:/ca:ro" --entrypoint sh lab-nodo:1 -c "$bucle" _ "$N" "$@"
}

# Mediana y peor caso, en ms (TLS = apretón de manos TLS solo, sin el TCP).
resumen() { # etiqueta  (lee las líneas de medir por stdin)
  awk -v etiqueta="$1" '
    function ordenar(a, n,   i, j, t) { for (i=2; i<=n; i++) { t=a[i]; for (j=i-1; j>=1 && a[j]>t; j--) a[j+1]=a[j]; a[j+1]=t } }
    $1 == "ERR" { err++; next }
    { n++; tcp[n]=$1*1000; tls[n]=($2>0)?($2-$1)*1000:0; ttfb[n]=$3*1000; tot[n]=$4*1000; if ($6>0) { tps[n]=$5/$6*1e9; hay=1 } }
    END {
      if (n == 0) { printf "| %s | sin datos | | | | |\n", etiqueta; exit }
      ordenar(tcp,n); ordenar(tls,n); ordenar(ttfb,n); ordenar(tot,n); if (hay) ordenar(tps,n)
      m = int((n+1)/2)
      tl = (tls[n]>0) ? sprintf("%.1f (%.1f)", tls[m], tls[n]) : "—"
      tk = hay ? sprintf("%.0f", tps[m]) : "—"
      printf "| %s | %.1f (%.1f) | %s | %.0f (%.0f) | %.0f (%.0f) | %s |\n", etiqueta, tcp[m], tcp[n], tl, ttfb[m], ttfb[n], tot[m], tot[n], tk
      if (err) printf "<!-- %d peticiones con error -->\n", err
    }'
}

{
  echo "# Latencia de la API de la IA · topología $TOPO"
  echo
  echo "Generada $(date '+%Y-%m-%d %H:%M:%S %z') con \`scripts/latencia-api.sh\` · modelo \`$MODELO\` (contexto 65536, 100 % GPU) · $N peticiones por ruta, modelo ya cargado."
  echo "Petición: \`/api/generate\`, streaming, \`think:false\`, 48 tokens, \`temperature:0\`. Valores en **ms: mediana (peor caso)**; \"1.er token\" es el tiempo hasta el primer byte de la respuesta (incluye TCP y TLS)."
  echo
  echo "| Ruta | TCP | TLS | 1.er token | Total | Tokens/s |"
  echo "|---|---|---|---|---|---|"
} > "$SALIDA"

# Calentamiento: carga el modelo y calienta la conexión (no se mide).
ARGS_CALENTAR=(http://10.10.0.10:11434/api/generate)
[[ $TOPO == segmentada ]] && ARGS_CALENTAR=(--cacert /ca/root.crt https://ia.lab.internal/api/generate)
docker run --rm --network container:proyecto1 -v "$RAIZ/lab/ca:/ca:ro" --entrypoint curl lab-nodo:1 -s -m 200 -o /dev/null \
  "${ARGS_CALENTAR[@]}" \
  -d '{"model":"'"$MODELO"'","prompt":"OK","stream":false,"think":false,"options":{"num_predict":2}}'

if [[ $TOPO == plana ]]; then
  medir proyecto1 "$BUCLE" http://10.10.0.10:11434/api/generate | resumen "Trabajo → Ollama directo (sin TLS, sin control)" >> "$SALIDA"
else
  medir caddy     "$BUCLE" http://10.10.20.10:11434/api/generate | resumen "Caddy → Ollama (salto interno, VLAN 20, sin TLS)" >> "$SALIDA"
  medir proyecto1 "$BUCLE" https://ia.lab.internal/api/generate --cacert /ca/root.crt | resumen "Trabajo → Caddy (TLS) → Ollama, por nombre" >> "$SALIDA"
  medir proyecto1 "$BUCLE" https://10.10.10.5/api/generate --cacert /ca/root.crt | resumen "Trabajo → Caddy (TLS) → Ollama, por IP" >> "$SALIDA"
  medir hermes    "$BUCLE" https://ia.lab.internal/api/generate --cacert /ca/root.crt | resumen "Admin → Caddy (TLS) → Ollama, por nombre" >> "$SALIDA"
  # VPN emulada (Día 4): el cliente remoto llega a Caddy por su IP real a través de wg0 (cifrado WireGuard).
  if docker exec cliente-remoto ip link show wg0 >/dev/null 2>&1; then
    medir cliente-remoto "$BUCLE" https://10.10.10.5/api/generate --cacert /ca/root.crt | resumen "VPN emulada: cliente-remoto → wg0 → Caddy (TLS) → Ollama, por IP" >> "$SALIDA"
  fi
fi
medir proyecto1 "$BUCLE_SIMPLE" https://api.anthropic.com/ | resumen "Referencia nube: Trabajo → api.anthropic.com (solo conexión, sin modelo)" >> "$SALIDA"

# Arranque en frío: modelo descargado de la GPU; incluye la carga de ~2.7 GB desde disco.
docker exec ollama ollama stop "$MODELO" >/dev/null 2>&1; sleep 2
URL_FRIO="http://10.10.0.10:11434/api/generate"; ORIGEN_FRIO=proyecto1; OPC_FRIO=""
[[ $TOPO == segmentada ]] && { URL_FRIO="https://ia.lab.internal/api/generate"; OPC_FRIO="--cacert /ca/root.crt"; }
frio="$(docker run --rm --network container:$ORIGEN_FRIO -v "$RAIZ/lab/ca:/ca:ro" --entrypoint curl lab-nodo:1 -s -m 300 $OPC_FRIO \
  -w '\nTOTAL %{time_total}\n' -d '{"model":"'"$MODELO"'","prompt":"OK","stream":false,"think":false,"options":{"num_predict":2}}' "$URL_FRIO")"
total="$(echo "$frio" | sed -n 's/^TOTAL //p')"
carga="$(echo "$frio" | sed -n 's/.*"load_duration":\([0-9]*\).*/\1/p')"
{
  echo
  echo "**Arranque en frío** (modelo fuera de la GPU, primera petición): total ${total:-?} s, de los cuales la carga del modelo ${carga:+$((carga/1000000))} ms."
} >> "$SALIDA"

docker exec ollama ollama stop "$MODELO" >/dev/null 2>&1   # no dejar el modelo residente (ver docs/03-laboratorio.md §7.5)
sync; echo 3 > /proc/sys/vm/drop_caches
cat "$SALIDA"
