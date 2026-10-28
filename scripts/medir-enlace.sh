#!/usr/bin/env bash
# Rendimiento y latencia del ENLACE FÍSICO entre la Dell y otro equipo cableado al mismo conmutador (evidencia/dia7).
# Solo lectura: no cambia nada en ningún equipo. En el otro equipo una persona debe dejar corriendo "iperf3 -s".
# El cliente corre en un contenedor con la red del host de WSL2: el tráfico sale por la NAT de WSL2 y por la tarjeta
# cableada de la Dell (el resultado incluye ese salto virtual).
# Uso (como root o como un usuario del grupo docker):  scripts/medir-enlace.sh <ip-del-servidor-iperf3> [directorio]
set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SERVIDOR="${1:?Uso: $0 <ip-del-servidor-iperf3> [directorio]}"
DIR="${2:-$RAIZ/evidencia/dia7}"
DURACION=10; REPETICIONES=3
mkdir -p "$DIR"

docker image inspect lab-nodo:1 >/dev/null 2>&1 || { echo "Falta la imagen lab-nodo:1 (scripts/lab.sh)" >&2; exit 2; }
command -v jq >/dev/null || { echo "Falta jq" >&2; exit 2; }
ping -c 1 -W 2 "$SERVIDOR" >/dev/null 2>&1 || { echo "No hay respuesta de $SERVIDOR" >&2; exit 2; }

# El JSON de iperf3 trae el nombre del equipo en system_info; el repositorio es público, así que se tapa al capturar.
cliente() {
  docker run --rm --network host --entrypoint iperf3 lab-nodo:1 -c "$SERVIDOR" -t "$DURACION" -J "$@" 2>/dev/null |
    sed -E 's/("system_info":[[:space:]]*"Linux )[^ ]+/\1equipo-oculto/'
}

serie() {   # <etiqueta> <prefijo del JSON> [opciones de iperf3...]
  local et="$1" pref="$2"; shift 2
  local i v vals=()
  for ((i=1; i<=REPETICIONES; i++)); do
    cliente "$@" > "$DIR/$pref-$i.json"
    v="$(jq -r '.end.sum_received.bits_per_second // empty' "$DIR/$pref-$i.json")"
    [[ -n $v ]] && vals+=("$v"); sleep 2
  done
  ((${#vals[@]})) || { echo "| $et | sin respuesta | |"; return; }
  printf '%s\n' "${vals[@]}" | awk -v et="$et" -v n="${#vals[@]}" \
    '{ m=$1/1e6; s+=m; q+=m*m } END { mu=s/n; d=(n>1)?sqrt((q-n*mu*mu)/(n-1)):0; printf "| %s | **%.1f** | ± %.1f (n=%d) |\n", et, mu, d, n }'
}

# Primero el ping, sin carga en el enlace.
ping_salida="$(ping -c 50 -i 0.2 -q "$SERVIDOR" | tail -3 | sed 's/^/    /')"
subida="$(serie "Subida: Dell → equipo cableado" subida)"
bajada="$(serie "Bajada: equipo cableado → Dell" bajada -R)"

{
  echo "# Rendimiento del enlace físico (Dell ↔ equipo cableado al mismo conmutador)"
  echo
  echo "Generado $(date '+%Y-%m-%d %H:%M:%S %z') con \`scripts/medir-enlace.sh\`. TCP con iperf3, ${DURACION} s × ${REPETICIONES}, un flujo,"
  echo "en cada sentido (el inverso con \`-R\`, iniciado siempre desde la Dell). JSON crudo en \`subida-N.json\` y \`bajada-N.json\`."
  echo "El cliente corre en WSL2 (contenedor con la red del host): el tráfico pasa por la NAT de WSL2 antes de salir por la tarjeta cableada."
  echo
  echo "| Sentido | Mbit/s (media) | Desviación |"
  echo "|---|---|---|"
  echo "$subida"
  echo "$bajada"
  echo
  echo "## Latencia ICMP Dell → equipo cableado (50 pings, intervalo de 0.2 s, sin carga)"
  echo
  echo "$ping_salida"
} > "$DIR/enlace-iperf3.md"

cat "$DIR/enlace-iperf3.md"
