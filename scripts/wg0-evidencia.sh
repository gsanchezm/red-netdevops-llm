#!/usr/bin/env bash
# Evidencia de la VPN emulada (Día 4): estado de wg0, apretón de manos, latencia por el túnel
# frente a la que hay sin túnel, HTTPS con la CA interna y el certificado que presenta Caddy.
# Uso:  scripts/wg0-evidencia.sh [salida.txt]     (con la topología segmentada levantada)
# Las llaves públicas se acortan; las privadas nunca se imprimen (`wg show` las oculta).
set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SALIDA="${1:-$RAIZ/evidencia/dia4/wg0-emulada.txt}"
docker inspect cliente-remoto >/dev/null 2>&1 || { echo "La topología segmentada no está levantada: scripts/lab.sh segmentada" >&2; exit 2; }
SUDO=""; [[ $EUID -ne 0 ]] && SUDO="sudo"

ocultar() { sed -E 's/((peer|public key): .{6}).*/\1…/'; }
cli() { docker exec cliente-remoto "$@"; }

{
  echo "# VPN emulada · wg0 · $(date '+%Y-%m-%d %H:%M:%S %z')"
  echo
  echo "## Host (servidor wg0, 10.10.50.1/24, UDP 51820)"
  $SUDO wg show wg0 | ocultar
  $SUDO ip -d link show wg0 | sed -n '1p;3p' | sed -E 's/^ +//'
  echo
  echo "## cliente-remoto (203.0.113.10, túnel 10.10.50.2; enruta 10.10.0.0/16 por wg0)"
  cli wg show wg0 | ocultar
  cli ip route | sed -E 's/^/  /'
  echo
  echo "## Latencia ICMP: 50 pings"
  echo "Por el túnel (cliente -> 10.10.50.1):"
  cli ping -c 50 -i 0.2 -q 10.10.50.1 | tail -2
  echo "Sin túnel (cliente -> 203.0.113.1, mismo host por br-inet):"
  cli ping -c 50 -i 0.2 -q 203.0.113.1 | tail -2
  echo
  echo "## HTTPS a Caddy por la IP real, por el túnel, con la CA interna (5 solicitudes a /api/tags)"
  for _ in 1 2 3 4 5; do
    cli curl -sS -m 10 --cacert /ca/root.crt -o /dev/null \
      -w 'HTTP %{http_code}  TCP %{time_connect}s  TLS %{time_appconnect}s  total %{time_total}s\n' https://10.10.10.5/api/tags
  done
  echo
  echo "## Certificado que presenta Caddy en 10.10.10.5:443 (el cliente no envía SNI para una IP)"
  cli sh -c 'echo | openssl s_client -connect 10.10.10.5:443 2>/dev/null | openssl x509 -noout -subject -issuer -ext subjectAltName' | sed -E 's/^/  /'
  echo
  echo "## Lo que la VPN no alcanza (nc -zv -w 2 desde cliente-remoto, por el túnel)"
  while IFS='|' read -r nombre ip port; do
    printf '  %-16s %s:%s -> %s\n' "$nombre" "$ip" "$port" "$(cli nc -zv -w 2 "$ip" "$port" 2>&1 | tail -1 | sed -E 's/^nc: //')"
  done <<'DESTINOS'
Ollama|10.10.20.10|11434
proyecto1|10.10.10.11|8080
colector|10.10.99.30|9100
iot-sensor|10.10.30.10|1883
Caddy (pata IA)|10.10.20.5|443
DESTINOS
  echo
  echo "## Contadores de netseg (forward)"
  $SUDO nft list chain inet netseg forward | grep -E 'wg0|denegación' | sed -E 's/^\s+/  /'
  echo "## Excepción en Docker (DOCKER-USER y raw)"
  $SUDO iptables -S DOCKER-USER | grep wg0 | sed -E 's/^/  /'
  $SUDO iptables-save -t raw | grep -E 'wg0' | sed -E 's/^/  /'
} > "$SALIDA"

cat "$SALIDA"
echo
echo "Escrito en $SALIDA"
