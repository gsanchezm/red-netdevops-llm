#!/usr/bin/env bash
# Muestra QUÉ capa detiene cada flujo prohibido: pone en cero los contadores de nftables y de
# Docker, ejecuta la matriz de la topología segmentada y vuelca los contadores de las tres capas,
# en el orden en que el kernel las evalúa:
#   1. Docker · raw/PREROUTING (prioridad -300): descarta lo dirigido a la IP de un contenedor
#      si no entró por su propio bridge. Cubre Trabajo, Invitados y Admin como destino.
#   2. netseg · forward (prioridad -10): la política del proyecto. Es la única que cubre los
#      destinos del segmento de IA, la salida de Admin y "Ollama nunca inicia".
#   3. Docker · filter (prioridad 0): aislamiento entre bridges y redes internas (respaldo).
# Uso (root):  scripts/contadores.sh [archivo-salida.txt]
set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SALIDA="${1:-$RAIZ/evidencia/dia2/contadores-segmentada.txt}"
SUDO=""; [[ $EUID -ne 0 ]] && SUDO="sudo"

$SUDO nft list table inet netseg >/dev/null 2>&1 || { echo "La tabla netseg no está cargada: scripts/lab.sh segmentada" >&2; exit 2; }

"$RAIZ/scripts/lab.sh" nft-cargar >/dev/null     # recarga la tabla: contadores en cero
$SUDO iptables -Z; $SUDO iptables -t raw -Z; $SUDO ip6tables -Z   # filter y raw (iptables -Z solo toca filter)
bash "$RAIZ/scripts/matriz.sh" segmentada /dev/null >/dev/null
resultado=$?
[[ $resultado -le 1 ]] || { echo "La matriz no pudo ejecutarse (código $resultado)" >&2; exit 2; }

{
  echo "# contadores-segmentada.txt - $(date '+%Y-%m-%d %H:%M:%S %z')"
  echo "Matriz segmentada ejecutada tras poner los contadores en cero (código de salida: $resultado)."
  echo
  echo "== 1. Docker · raw/PREROUTING (prioridad -300, evalúa primero) =="
  $SUDO iptables -t raw -vnL PREROUTING | awk 'NR>2 && $3=="DROP" {print}'
  echo
  echo "== 2. nftables · tabla inet netseg (prioridad -10) =="
  $SUDO nft list table inet netseg
  echo
  echo "== 3. Docker · filter (prioridad 0): reglas DROP con sus contadores =="
  echo "(un paquete que las capas 1 o 2 ya descartaron no llega aquí)"
  $SUDO iptables -t filter -vnL | awk '/^Chain/ {cadena=$2} /DROP|REJECT/ && !/^Chain/ {print cadena ": " $0}'
} > "$SALIDA"

cat "$SALIDA"
