#!/usr/bin/env bash
# WireGuard emulado (Día 4; docs/02-diseno.md §3 y D6): servidor wg0 en el host (10.10.50.1/24,
# UDP 51820) y cliente dentro del contenedor cliente-remoto (203.0.113.10, túnel 10.10.50.2).
# Uso (como root o con sudo):
#   scripts/wg0.sh servidor    genera las llaves si faltan y levanta wg0 en el host
#   scripts/wg0.sh cliente     levanta wg0 dentro de cliente-remoto
#   scripts/wg0.sh abajo       baja wg0 del host (el del cliente desaparece con su contenedor)
#   scripts/wg0.sh estado      wg show del host y del cliente (sin llaves privadas)
# Las llaves viven solo en lab/wireguard/wg0.conf y wg0-cliente.conf (0600): el repositorio es
# público y *.conf de WireGuard está en .gitignore. Se generan una vez y se reutilizan.
set -euo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIR="$RAIZ/lab/wireguard"
SERVIDOR="$DIR/wg0.conf"
CLIENTE="$DIR/wg0-cliente.conf"
SUDO=""; [[ $EUID -ne 0 ]] && SUDO="sudo"

generar() {
  if [[ -f $SERVIDOR && -f $CLIENTE ]]; then return 0; fi
  mkdir -p "$DIR"; umask 077
  local ks kc
  ks="$(wg genkey)"; kc="$(wg genkey)"
  cat > "$SERVIDOR" <<EOF
[Interface]
Address = 10.10.50.1/24
ListenPort = 51820
PrivateKey = $ks

[Peer]
# cliente-remoto
PublicKey = $(wg pubkey <<< "$kc")
AllowedIPs = 10.10.50.2/32
EOF
  # El cliente enruta todo 10.10.0.0/16 por el túnel a propósito: la política que lo limita a
  # Caddy :443 es la de netseg en el host, no una configuración que el cliente pueda cambiar.
  cat > "$CLIENTE" <<EOF
[Interface]
Address = 10.10.50.2/24
PrivateKey = $kc

[Peer]
PublicKey = $(wg pubkey <<< "$ks")
Endpoint = 203.0.113.1:51820
AllowedIPs = 10.10.0.0/16
PersistentKeepalive = 25
EOF
  echo "wg0: llaves generadas en lab/wireguard/ (no versionadas)"
}

# Excepción en la capa de respaldo de Docker: su cadena DOCKER descarta lo que entra a br-trabajo desde
# fuera del bridge, aunque netseg lo permita. DOCKER-USER se evalúa antes que las reglas de Docker; la
# regla es la misma que acepta netseg (wg0 -> Caddy :443). `-C` comprueba, así que es idempotente.
REGLA_DOCKER=(DOCKER-USER -i wg0 -o br-trabajo -d 10.10.10.5 -p tcp --dport 443 -j ACCEPT)
docker_user_poner() { $SUDO iptables -C "${REGLA_DOCKER[@]}" 2>/dev/null || $SUDO iptables -I "${REGLA_DOCKER[@]}"; }
docker_user_quitar() { $SUDO iptables -D "${REGLA_DOCKER[@]}" 2>/dev/null || true; }

case "${1:-}" in
  servidor)
    generar
    if ip link show wg0 >/dev/null 2>&1; then echo "wg0 ya está arriba en el host"
    else $SUDO wg-quick up "$SERVIDOR"; fi
    docker_user_poner && echo "DOCKER-USER: wg0 -> Caddy :443 permitido" ;;
  cliente)
    if docker exec cliente-remoto ip link show wg0 >/dev/null 2>&1; then echo "wg0 ya está arriba en cliente-remoto"
    else docker exec cliente-remoto wg-quick up wg0; fi ;;
  abajo)
    docker_user_quitar
    if ip link show wg0 >/dev/null 2>&1; then
      if [[ -f $SERVIDOR ]]; then $SUDO wg-quick down "$SERVIDOR"; else $SUDO ip link del wg0; fi
    fi ;;
  estado)
    echo "== host =="; $SUDO wg show wg0 2>/dev/null || echo "wg0 no existe en el host"
    echo "== cliente-remoto =="; docker exec cliente-remoto wg show wg0 2>/dev/null || echo "wg0 no existe en cliente-remoto" ;;
  *) sed -n '2,11p' "${BASH_SOURCE[0]}"; exit 2 ;;
esac
