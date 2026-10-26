#!/usr/bin/env bash
# Mediciones de red del Día 6 (docs/02-diseno.md §8): latencia ICMP y throughput TCP, para comparar la
# topología plana ("antes") con la segmentada ("después") y medir lo que cuesta cifrar con WireGuard.
# Uso (como root, con esa topología levantada):  scripts/medir-red.sh plana|segmentada [salida.md]
# Los contenedores comparten el kernel de la Dell: las cifras son relativas (qué cuesta filtrar y cifrar),
# no la capacidad de un cable de 1 Gb/s. Los iperf3 de prueba se apagan al terminar (incluida la regla temporal).
set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOPO="${1:-}"
SALIDA="${2:-$RAIZ/evidencia/dia6/red-$TOPO.md}"
PINGS=50; DURACION=10; REPETICIONES=3
[[ $TOPO == plana || $TOPO == segmentada ]] || { sed -n '2,6p' "${BASH_SOURCE[0]}"; exit 2; }
docker inspect proyecto1 >/dev/null 2>&1 || { echo "La topología '$TOPO' no está levantada: scripts/lab.sh $TOPO" >&2; exit 2; }
mkdir -p "$(dirname "$SALIDA")"

# IP de un contenedor en la red de la topología (en la segmentada, la red se indica: servicio@red).
ip_de() {
  local svc="${1%@*}" red=""; [[ $1 == *@* ]] && red="${1#*@}"
  docker inspect -f '{{range $n,$v := .NetworkSettings.Networks}}{{$n}} {{$v.IPAddress}}{{"\n"}}{{end}}' "$svc" 2>/dev/null \
    | awk -v red="$red" -v topo="$TOPO" 'NF==2 && (red=="" || topo=="plana" || $1==topo"_"red) { print $2; exit }'
}

# rtt <etiqueta> <origen> <destino-ip>  ->  fila de tabla con mín/media/máx/jitter y pérdida
rtt() {
  local salida perdida r
  # Las herramientas vienen de lab-nodo dentro del espacio de red del origen (misma IP, rutas y reglas):
  # así el origen puede ser una imagen real (Caddy, Ollama) que no trae el mismo ping.
  salida="$(docker run --rm --network "container:$2" --entrypoint ping lab-nodo:1 -c "$PINGS" -i 0.2 -q "$3" 2>&1)"
  perdida="$(sed -n 's/.* \([0-9.]*\)% packet loss.*/\1/p' <<< "$salida")"
  r="$(sed -n 's/.*= \([0-9.]*\)\/\([0-9.]*\)\/\([0-9.]*\)\/\([0-9.]*\) ms.*/\1 \2 \3 \4/p' <<< "$salida")"
  if [[ -z $r ]]; then echo "| $1 | \`$2\` → \`$3\` | sin respuesta | | | | ${perdida:-100} % |"; return; fi
  read -r mn me mx jt <<< "$r"
  echo "| $1 | \`$2\` → \`$3\` | $mn | **$me** | $mx | $jt | ${perdida:-?} % |"
}

# tcp <etiqueta> <contenedor-servidor|-> <contenedor-cliente> <ip-servidor>
# Si el servidor es "-" ya hay un iperf3 -s corriendo (el del host). Devuelve fila con media y desviación (Gbit/s).
tcp() {
  local i bps vals=()
  for ((i=1; i<=REPETICIONES; i++)); do
    [[ $2 != - ]] && { docker exec -d "$2" iperf3 -s -1 >/dev/null 2>&1; sleep 1; }
    bps="$(docker exec "$3" iperf3 -c "$4" -t "$DURACION" -J 2>/dev/null | jq -r '.end.sum_received.bits_per_second // empty')"
    [[ -n $bps ]] && vals+=("$bps")
    [[ $2 != - ]] && sleep 1
  done
  if ((${#vals[@]} == 0)); then echo "| $1 | \`$3\` → \`$4\`:5201 | sin respuesta | |"; return; fi
  printf '%s\n' "${vals[@]}" | awk -v et="$1" -v c="$3" -v ip="$4" -v n="${#vals[@]}" \
    '{ g=$1/1e9; s+=g; q+=g*g } END { m=s/n; d=(n>1)?sqrt((q-n*m*m)/(n-1)):0; printf "| %s | `%s` → `%s`:5201 | **%.2f** | ± %.2f (n=%d) |\n", et, c, ip, m, d, n }'
}

REGLA_TEMP="TEMP-iperf3"
limpiar() {
  docker rm -f iperf-host >/dev/null 2>&1
  local h; for h in $(nft -a list chain inet netseg input 2>/dev/null | sed -n "s/.*$REGLA_TEMP.* # handle \([0-9]*\)/\1/p"); do
    nft delete rule inet netseg input handle "$h" 2>/dev/null
  done
}
trap limpiar EXIT

P1="$(ip_de proyecto1@trabajo)"; P2="$(ip_de proyecto2@trabajo)"
[[ $TOPO == plana ]] && { P1="$(ip_de proyecto1)"; P2="$(ip_de proyecto2)"; }
GW="${P1%.*}.1"

{
  echo "# Mediciones de red · topología $TOPO"
  echo
  echo "Generado $(date '+%Y-%m-%d %H:%M:%S %z') con \`scripts/medir-red.sh $TOPO\`. Kernel $(uname -r). Los contenedores comparten el kernel de la Dell:"
  echo "las cifras sirven para **comparar** (qué cuesta filtrar y cifrar), no como capacidad de un cable."
  echo
  echo "## Latencia ICMP ($PINGS pings, intervalo de 0.2 s)"
  echo
  echo "| Trayecto | Origen → destino | mín (ms) | media (ms) | máx (ms) | jitter (ms) | pérdida |"
  echo "|---|---|---|---|---|---|---|"
  if [[ $TOPO == plana ]]; then
    rtt "Mismo segmento (L2)" proyecto1 "$P2"
    rtt "Hacia el host (gateway)" proyecto1 "$GW"
    rtt "Hacia Ollama (mismo L2 en la plana)" proyecto1 "$(ip_de ollama)"
  else
    rtt "Mismo segmento (Trabajo), con netseg" proyecto1 "$P2"
    rtt "Hacia el host (gateway de Trabajo)" proyecto1 "$GW"
    rtt "Caddy → Ollama (VLAN 20, única ruta ICMP permitida)" caddy "$(ip_de ollama@ia)"
  fi
  echo
  echo "## Throughput TCP con iperf3 (${DURACION} s × ${REPETICIONES}, Gbit/s recibidos)"
  echo
  echo "| Trayecto | Origen → destino | Media | Desviación |"
  echo "|---|---|---|---|"
  tcp "Mismo segmento$([[ $TOPO == segmentada ]] && echo ', con netseg')" proyecto2 proyecto1 "$P2"
} > "$SALIDA"

if [[ $TOPO == segmentada ]]; then
  # Costo de WireGuard: el MISMO cliente (cliente-remoto) y el MISMO servidor (el host), por br-inet y por wg0.
  docker run -d --rm --network host --name iperf-host --entrypoint iperf3 lab-nodo:1 -s >/dev/null 2>&1
  nft insert rule inet netseg input iifname '{ "br-inet", "wg0" }' tcp dport 5201 counter accept comment "$REGLA_TEMP"
  sleep 1
  {
    tcp "Sin túnel (cliente-remoto → host por br-inet)" - cliente-remoto 203.0.113.1
    tcp "Con túnel WireGuard wg0 (cifrado)" - cliente-remoto 10.10.50.1
    echo
    echo "La regla temporal de \`input\` que deja pasar el puerto 5201 (\`$REGLA_TEMP\`) y el iperf3 del host se quitan al terminar."
    echo
    echo "## Latencia ICMP por la VPN emulada (cliente-remoto)"
    echo
    echo "| Trayecto | Origen → destino | mín (ms) | media (ms) | máx (ms) | jitter (ms) | pérdida |"
    echo "|---|---|---|---|---|---|---|"
    rtt "Sin túnel (br-inet)" cliente-remoto 203.0.113.1
    rtt "Con túnel wg0" cliente-remoto 10.10.50.1
  } >> "$SALIDA"
  limpiar
  echo >> "$SALIDA"
  echo "Regla temporal: $(nft list chain inet netseg input | grep -c "$REGLA_TEMP") restantes tras limpiar (debe ser 0)." >> "$SALIDA"
fi

cat "$SALIDA"
echo
echo "Escrito en $SALIDA"
