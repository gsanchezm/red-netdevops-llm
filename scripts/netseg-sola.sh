#!/usr/bin/env bash
# Prueba que la política de lab/nftables/netseg.nft es completa por sí sola: retira en caliente
# las reglas DROP que Docker instala (protección por IP en raw/PREROUTING y aislamiento entre
# bridges en DOCKER y DOCKER-INTERNAL), ejecuta la matriz segmentada y restaura el laboratorio.
# Sirve para argumentar la migración a hardware real (§9): allí no existe Docker y la matriz
# la aplica el router. Docker queda como segunda barrera, no como la política.
# Uso (root):  scripts/netseg-sola.sh [archivo-salida.md]
set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SALIDA="${1:-$RAIZ/evidencia/dia2/matriz-segmentada-netseg-sola.md}"
[[ $EUID -eq 0 ]] || { echo "Ejecutar como root" >&2; exit 2; }
nft list table inet netseg >/dev/null 2>&1 || { echo "Levantar antes: scripts/lab.sh segmentada" >&2; exit 2; }

retirar_drop() { # tabla cadena
  iptables -t "$1" -S "$2" | awk '/^-A .* -j DROP$/' | while read -r regla; do
    # shellcheck disable=SC2086
    iptables -t "$1" ${regla/-A/-D}
  done
}

echo "Reglas DROP de Docker antes: raw=$(iptables -t raw -S PREROUTING | grep -c -- '-j DROP')" \
     "DOCKER=$(iptables -S DOCKER | grep -c -- '-j DROP') DOCKER-INTERNAL=$(iptables -S DOCKER-INTERNAL | grep -c -- '-j DROP')"
retirar_drop raw PREROUTING
retirar_drop filter DOCKER
retirar_drop filter DOCKER-INTERNAL
echo "Reglas DROP de Docker después: raw=$(iptables -t raw -S PREROUTING | grep -c -- '-j DROP')" \
     "DOCKER=$(iptables -S DOCKER | grep -c -- '-j DROP') DOCKER-INTERNAL=$(iptables -S DOCKER-INTERNAL | grep -c -- '-j DROP')"

bash "$RAIZ/scripts/matriz.sh" segmentada "$SALIDA" | tail -4
resultado=${PIPESTATUS[0]}
sed -i '1s/.*/# Matriz de alcanzabilidad · topología segmentada SOLO con netseg (reglas DROP de Docker retiradas)/' "$SALIDA"

echo "Restaurando el laboratorio (Docker vuelve a crear sus reglas)..."
"$RAIZ/scripts/lab.sh" segmentada >/dev/null 2>&1
exit "$resultado"
