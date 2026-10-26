#!/usr/bin/env bash
# Rendimiento y latencia REALES por wg1 (Dell <-> droplet, por internet), con iperf3 y ping (docs/05, §1).
# Usa el acceso de despliegue (usuario deploy por la VPN). Mientras dura la prueba instala iperf3 en el droplet y
# abre el 5201 solo para la Dell con una regla de runtime marcada TEMP-iperf3; al terminar mata el servidor, borra la
# regla y desinstala el paquete: el droplet queda como lo deja Ansible.
# Uso (como gsanchezm, que está en el grupo docker):  scripts/medir-wg1.sh [salida.md]
set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SALIDA="${1:-$RAIZ/evidencia/dia6/wg1-iperf3.md}"
DUENO="${REDES_LAB_USUARIO:-gsanchezm}"; CASA="$(getent passwd "$DUENO" | cut -d: -f6)"
LLAVE="${REDES_LAB_DEPLOY_KEY:-$CASA/.ssh/id_ed25519_redes_deploy}"
KNOWN="${REDES_LAB_KNOWN_HOSTS:-$CASA/.ssh/known_hosts}"
DURACION=10; REPETICIONES=3
mkdir -p "$(dirname "$SALIDA")"

remoto() { ssh -i "$LLAVE" -o IdentitiesOnly=yes -o BatchMode=yes -o ConnectTimeout=8 -o StrictHostKeyChecking=yes \
             -o UserKnownHostsFile="$KNOWN" deploy@10.10.51.1 "$@"; }
remoto true || { echo "No llego al droplet por wg1 (¿wg1 arriba y el usuario deploy creado?)" >&2; exit 2; }
docker image inspect lab-nodo:1 >/dev/null 2>&1 || { echo "Falta la imagen lab-nodo:1 (scripts/lab.sh)" >&2; exit 2; }

limpiar() {
  remoto 'sudo pkill -x iperf3 2>/dev/null
          for h in $(sudo nft -a list chain inet hub input | sed -n "s/.*TEMP-iperf3.* # handle \([0-9]*\)/\1/p"); do sudo nft delete rule inet hub input handle "$h"; done
          sudo DEBIAN_FRONTEND=noninteractive apt-get remove -y -qq iperf3 >/dev/null 2>&1; true'
}
trap limpiar EXIT

remoto 'sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --no-install-recommends iperf3 >/dev/null 2>&1 &&
        sudo nft insert rule inet hub input iifname wg1 ip saddr 10.10.51.2 tcp dport 5201 counter accept comment TEMP-iperf3 &&
        (iperf3 -s -D) && sleep 1' || { echo "No pude preparar el servidor iperf3 en el droplet" >&2; exit 2; }

cliente() { docker run --rm --network host --entrypoint iperf3 lab-nodo:1 -c 10.10.51.1 -t "$DURACION" -J "$@" 2>/dev/null; }

serie() {   # <etiqueta> <jq> [opciones de iperf3...]
  local et="$1" filtro="$2"; shift 2
  local i v vals=()
  for ((i=1; i<=REPETICIONES; i++)); do
    v="$(cliente "$@" | jq -r "$filtro // empty")"
    [[ -n $v ]] && vals+=("$v"); sleep 2
  done
  ((${#vals[@]})) || { echo "| $et | sin respuesta | |"; return; }
  printf '%s\n' "${vals[@]}" | awk -v et="$et" -v n="${#vals[@]}" \
    '{ m=$1/1e6; s+=m; q+=m*m } END { mu=s/n; d=(n>1)?sqrt((q-n*mu*mu)/(n-1)):0; printf "| %s | **%.1f** | ± %.1f (n=%d) |\n", et, mu, d, n }'
}

{
  echo "# Rendimiento real por wg1 (Dell ↔ droplet, por internet)"
  echo
  echo "Generado $(date '+%Y-%m-%d %H:%M:%S %z') con \`scripts/medir-wg1.sh\`. TCP con iperf3, ${DURACION} s × ${REPETICIONES}, un flujo."
  echo "El camino es el real: la Dell sale por la subida del internet de la casa (doble NAT) hasta el droplet (NYC3) dentro de WireGuard."
  echo
  echo "| Sentido | Mbit/s (media) | Desviación |"
  echo "|---|---|---|"
  serie "Subida: Dell → droplet" '.end.sum_received.bits_per_second'
  serie "Bajada: droplet → Dell" '.end.sum_received.bits_per_second' -R
  echo
  echo "## Latencia ICMP Dell → droplet por wg1 (50 pings)"
  echo
  ping -c 50 -i 0.2 -q 10.10.51.1 | tail -2 | sed 's/^/    /'
  echo
  echo "El puerto 5201 del droplet solo se abrió para 10.10.51.2 durante la prueba (regla de runtime TEMP-iperf3) y el paquete se desinstaló al terminar."
} > "$SALIDA"

limpiar; trap - EXIT
echo "restos en el droplet: reglas TEMP=$(remoto 'sudo nft list chain inet hub input | grep -c TEMP-iperf3') · iperf3 instalado=$(remoto "dpkg-query -W -f='\${Status}' iperf3 2>/dev/null | grep -q 'install ok installed' && echo sí || echo no")"
cat "$SALIDA"
