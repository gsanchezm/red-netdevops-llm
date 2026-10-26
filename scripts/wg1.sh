#!/usr/bin/env bash
# WireGuard real (Día 4; docs/02-diseno.md D10 y D12): la Dell abre `wg1` hacia el droplet (10.10.51.2,
# solo conexión saliente con keepalive de 25 s: atraviesa el doble NAT sin tocar la casa) y el celular
# (10.10.51.3) llega a Caddy (10.10.10.5:443) pasando por el droplet, sin NAT.
# Uso (como root o con sudo):
#   scripts/wg1.sh crear <IP-DEL-DROPLET> <CLAVE-PÚBLICA-DEL-DROPLET>
#                              genera la llave de la Dell y lab/wireguard/wg1.conf (una sola vez)
#   scripts/wg1.sh publica     imprime la clave pública de la Dell (la que se registra en el droplet)
#   scripts/wg1.sh arriba      levanta wg1 y la excepción en DOCKER-USER (no hace nada si no hay wg1.conf)
#   scripts/wg1.sh abajo       baja wg1
#   scripts/wg1.sh estado      wg show de wg1 (sin llaves privadas)
# La IP del droplet y la llave privada viven solo en lab/wireguard/wg1.conf (0600, ignorado por git).
set -euo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIR="$RAIZ/lab/wireguard"
CONF="$DIR/wg1.conf"
SUDO=""; [[ $EUID -ne 0 ]] && SUDO="sudo"

# Misma excepción que wg0 (scripts/wg0.sh), solo para el celular: DOCKER-USER se evalúa antes que las
# reglas de Docker, cuya cadena DOCKER descarta lo que entra a br-trabajo desde fuera del bridge.
REGLA_DOCKER=(DOCKER-USER -i wg1 -o br-trabajo -s 10.10.51.3 -d 10.10.10.5 -p tcp --dport 443 -j ACCEPT)
docker_user_poner() { $SUDO iptables -C "${REGLA_DOCKER[@]}" 2>/dev/null || $SUDO iptables -I "${REGLA_DOCKER[@]}"; }
docker_user_quitar() { $SUDO iptables -D "${REGLA_DOCKER[@]}" 2>/dev/null || true; }

# sed y no awk -F'=': la clave base64 termina en "=" y un separador "=" se lo comería.
publica() { sed -nE 's/^PrivateKey = (.*)$/\1/p' "$CONF" | wg pubkey; }

case "${1:-}" in
  crear)
    [[ $# -eq 3 ]] || { sed -n '2,12p' "${BASH_SOURCE[0]}"; exit 2; }
    [[ "$(printf '%s' "$3" | base64 -d 2>/dev/null | wc -c)" -eq 32 ]] || { echo "La clave pública del droplet no es base64 de 32 bytes" >&2; exit 2; }
    if [[ -f $CONF ]]; then echo "wg1.conf ya existe: no se sobrescribe (borrarlo para recrearlo)"
    else
      mkdir -p "$DIR"; umask 077
      cat > "$CONF" <<EOF
[Interface]
Address = 10.10.51.2/24
PrivateKey = $(wg genkey)

[Peer]
# droplet (concentrador)
PublicKey = $3
Endpoint = $2:51820
AllowedIPs = 10.10.51.0/24
PersistentKeepalive = 25
EOF
      echo "wg1: llave y configuración creadas en lab/wireguard/wg1.conf (no versionado)"
    fi
    echo "Clave pública de la Dell (registrarla en el droplet): $(publica)" ;;
  publica) publica ;;
  arriba)
    if [[ ! -f $CONF ]]; then echo "wg1 sin configurar (scripts/wg1.sh crear <IP> <clave>): se omite"; exit 0; fi
    if ip link show wg1 >/dev/null 2>&1; then echo "wg1 ya está arriba en el host"
    else $SUDO wg-quick up "$CONF"; fi
    docker_user_poner && echo "DOCKER-USER: wg1 (celular) -> Caddy :443 permitido" ;;
  abajo)
    docker_user_quitar
    if ip link show wg1 >/dev/null 2>&1; then
      if [[ -f $CONF ]]; then $SUDO wg-quick down "$CONF"; else $SUDO ip link del wg1; fi
    fi ;;
  estado)
    $SUDO wg show wg1 2>/dev/null || echo "wg1 no existe en el host" ;;
  *) sed -n '2,12p' "${BASH_SOURCE[0]}"; exit 2 ;;
esac
