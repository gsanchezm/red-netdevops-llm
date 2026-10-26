#!/usr/bin/env bash
# Evalúa la calidad de Hermes con un modelo local para REVISAR una política leyendo un snapshot con sus propias
# herramientas de archivos (D7: observa y propone, nunca aplica). Cuatro escenarios sobre copias sintéticas del
# snapshot (el firewall real no se toca). Mide si el veredicto es correcto y si cita la regla problemática.
# Uso (root, topología segmentada):  scripts/hermes-evaluar.sh [modelo] [repeticiones]
# Salida: evidencia/dia6/hermes-eval/<modelo>/  (una respuesta por corrida y un resumen.md)
set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODELO="${1:-qwen3.5:2b}"; REP="${2:-3}"
# herramientas: Hermes lee /snapshots con sus herramientas de archivos (lo que pide el plan).
# contexto:     el contenido va dentro del prompt y no se usan herramientas: separa "usar herramientas" de "razonar".
MODO="${3:-herramientas}"
[[ $MODO == herramientas || $MODO == contexto ]] || { echo "Modo: herramientas | contexto" >&2; exit 2; }
SUFIJO=""; [[ $MODO == contexto ]] && SUFIJO="_contexto"
SALIDA="$RAIZ/evidencia/dia6/hermes-eval/${MODELO//[:\/]/_}$SUFIJO"
SNAP="$RAIZ/lab/snapshots/actual"
PROMPT="$RAIZ/lab/hermes/prompt-revision.md"
TOOLS=(-t file)
if [[ $MODO == contexto ]]; then TOOLS=(-t todo); fi
shopt -u patsub_replacement 2>/dev/null   # que un "&" en el contenido no se interprete al sustituir
docker inspect -f '{{range .Mounts}}{{.Destination}} {{end}}' hermes 2>/dev/null | grep -q '/snapshots' \
  || { echo "Hermes no tiene /snapshots: docker compose -f lab/compose.segmentada.yml up -d --no-deps hermes" >&2; exit 2; }
mkdir -p "$SALIDA"; rm -f "$SALIDA"/*.txt

# Escenarios: nombre | veredicto esperado | expresión que debe aparecer en REGLA (si hay desvío)
ESCENARIOS=(
  "sin_desvio|SIN_DESVIO|"
  "invitados_a_trabajo|DESVIO|br-invitados"
  "policy_accept|DESVIO|accept"
  "admin_sin_puerto|DESVIO|br-admin"
)

preparar() {   # snapshot real y mutación sintética de politica-cargada.nft
  "$RAIZ/scripts/snapshot.sh" actual >/dev/null
  local f="$SNAP/politica-cargada.nft"
  case "$1" in
    invitados_a_trabajo) sed -i '/denegación por defecto/i\\t\tiifname "br-invitados" oifname "br-trabajo" counter packets 0 bytes 0 accept' "$f" ;;
    policy_accept)       sed -i 's/policy drop;/policy accept;/' "$f" ;;
    admin_sin_puerto)    sed -i 's/oifname "eth0" tcp dport 443 counter/oifname "eth0" counter/' "$f" ;;
  esac
}

{
  echo "# Evaluación de Hermes · modelo $MODELO · modo $MODO · $(date '+%Y-%m-%d %H:%M:%S %z')"
  echo
  if [[ $MODO == herramientas ]]; then
    echo "Tarea: leer \`/snapshots/actual/\` con las herramientas de archivos de Hermes y decidir si la cadena \`forward\`"
  else
    echo "Tarea: con el contenido ya dentro del prompt (sin herramientas), decidir si la cadena \`forward\`"
  fi
  echo "permite algo que la matriz de flujos deniega. $REP corridas por escenario; los escenarios 2-4 son copias"
  echo "sintéticas con un desvío inyectado (no se cambió el firewall real). Acierto = veredicto correcto y, si hay"
  echo "desvío, la línea \`REGLA:\` cita la regla problemática."
  echo
  echo "| Escenario | Esperado | Aciertos | Veredictos obtenidos | Tiempo medio |"
  echo "|---|---|---|---|---|"
} > "$SALIDA/resumen.md"

total_ok=0; total=0
for esc in "${ESCENARIOS[@]}"; do
  IFS='|' read -r nombre esperado patron <<< "$esc"
  # ESCENARIOS_SOLO="invitados_a_trabajo policy_accept" limita la corrida (pruebas rápidas)
  [[ -z ${ESCENARIOS_SOLO:-} || " $ESCENARIOS_SOLO " == *" $nombre "* ]] || continue
  ok=0; veredictos=(); t_total=0
  for ((n=1; n<=REP; n++)); do
    preparar "$nombre"
    if [[ $MODO == contexto ]]; then
      plantilla="$(<"$RAIZ/lab/hermes/prompt-revision-contexto.md")"
      plantilla="${plantilla//@@MATRIZ@@/$(<"$SNAP/matriz-de-flujos.md")}"
      printf '%s\n' "${plantilla//@@POLITICA@@/$(<"$SNAP/politica-cargada.nft")}" > /tmp/prompt-contexto.md
      PROMPT=/tmp/prompt-contexto.md
    fi
    inicio=$SECONDS
    docker exec -i hermes hermes chat --query-file - -Q "${TOOLS[@]}" --max-turns 10 --run-budget 280 -m "$MODELO" < "$PROMPT" \
      > "$SALIDA/${nombre}-$n.txt" 2>&1
    t_total=$((t_total + SECONDS - inicio))
    ver="$(grep -oE 'VEREDICTO: *(SIN_DESVIO|DESVIO)' "$SALIDA/${nombre}-$n.txt" | tail -1 | grep -oE '(SIN_DESVIO|DESVIO)')"
    regla="$(grep -E '^REGLA:' "$SALIDA/${nombre}-$n.txt" | tail -1)"
    veredictos+=("${ver:-sin-veredicto}")
    acierto=0
    if [[ $ver == "$esperado" ]]; then
      if [[ -z $patron ]] || grep -qiE "$patron" <<< "$regla"; then acierto=1; fi
    fi
    ok=$((ok + acierto)); total=$((total + 1)); total_ok=$((total_ok + acierto))
    echo "  [$nombre #$n] veredicto=${ver:-NINGUNO} acierto=$acierto ($((SECONDS - inicio)) s)" >&2
  done
  echo "| $nombre | $esperado | **$ok/$REP** | ${veredictos[*]} | $((t_total / REP)) s |" >> "$SALIDA/resumen.md"
done

{
  echo
  echo "**Total: $total_ok/$total aciertos.**"
} >> "$SALIDA/resumen.md"

docker exec ollama ollama stop "$MODELO" >/dev/null 2>&1
sync; echo 3 > /proc/sys/vm/drop_caches 2>/dev/null
cat "$SALIDA/resumen.md"
