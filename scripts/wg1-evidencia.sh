#!/usr/bin/env bash
# Evidencia de la VPN real (Día 4), lado de la Dell: estado de wg1, latencia por internet hasta el droplet,
# contadores de las capas de filtrado y lo que Caddy registró del celular (origen 10.10.51.3, sin NAT).
# El lado del droplet se toma por ssh desde Windows y se anexa al mismo archivo (ver docs/03-laboratorio.md §8.5).
# Uso:  scripts/wg1-evidencia.sh [salida.txt]     (con la topología segmentada y wg1 arriba)
# Las claves públicas se acortan y las IP públicas se ocultan (45.55.x.x); la privada nunca se imprime.
set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SALIDA="${1:-$RAIZ/evidencia/dia4/wg1-real.txt}"
docker inspect caddy >/dev/null 2>&1 || { echo "La topología segmentada no está levantada: scripts/lab.sh segmentada" >&2; exit 2; }
SUDO=""; [[ $EUID -ne 0 ]] && SUDO="sudo"
ocultar() { sed -E 's/((peer|public key): .{6}).*/\1…/; s/endpoint: ([0-9]+)\.([0-9]+)\.[0-9]+\.[0-9]+/endpoint: \1.\2.x.x/'; }
LOG="$(mktemp)"; trap 'rm -f "$LOG"' EXIT
docker logs caddy > "$LOG" 2>&1

{
  echo "# VPN real · wg1 · $(date '+%Y-%m-%d %H:%M:%S %z')"
  echo
  echo "## Dell (wg1, 10.10.51.2): conexión saliente hacia el droplet, keepalive de 25 s"
  $SUDO wg show wg1 | ocultar
  echo
  echo "## Latencia ICMP Dell -> droplet por wg1 (50 pings, por internet real)"
  ping -c 50 -i 0.2 -q 10.10.51.1 | tail -2
  echo
  echo "## Solicitudes con origen 10.10.51.x que llegaron a Caddy (registro JSON de Caddy; sin NAT)"
  python3 - "$LOG" <<'PY'
import json, sys
tls = {771: "TLS 1.2", 772: "TLS 1.3"}
n = 0
for linea in open(sys.argv[1], errors="replace"):
    try:
        d = json.loads(linea)
    except ValueError:
        continue
    r = d.get("request", {})
    if r.get("remote_ip", "").startswith("10.10.51."):
        n += 1
        # El User-Agent distingue al celular (Safari) de las pruebas hechas desde el droplet (curl).
        ua = (r.get("headers", {}).get("User-Agent") or ["?"])[0]
        print("  origen=%s  %s %s  estado=%s  duración=%.1f ms  %s  cliente=%s" % (
            r["remote_ip"], r.get("method"), r.get("uri"), d.get("status"),
            d.get("duration", 0) * 1000, tls.get(r.get("tls", {}).get("version"), "?"),
            "curl (prueba desde el droplet)" if ua.startswith("curl") else ("Safari en iPhone" if "iPhone" in ua else ua[:40])))
print("  total de solicitudes con origen 10.10.51.x: %d" % n)
PY
  echo
  echo "## Capas de filtrado de la Dell para wg1 (contadores)"
  echo "netseg (forward):"
  $SUDO nft list chain inet netseg forward | grep -E 'wg1|denegación' | sed -E 's/^\s+/  /'
  echo "Docker (DOCKER-USER):"
  $SUDO iptables -L DOCKER-USER -v -n | grep -E 'wg1' | sed -E 's/^\s*/  /'
} > "$SALIDA"

cat "$SALIDA"
echo
echo "Escrito en $SALIDA"
