#!/usr/bin/env bash
# Instala Docker Engine (repositorio oficial de Docker) y nftables en Ubuntu 24.04 (WSL2).
# Uso:  sudo bash scripts/wsl/01-docker-engine.sh [usuario]
# No instala driver NVIDIA (CUDA en WSL usa el driver de Windows) ni toca Docker Desktop.
set -euo pipefail

USUARIO="${1:-${SUDO_USER:-gsanchezm}}"

if [[ $EUID -ne 0 ]]; then
  echo "Ejecutar como root: sudo bash $0" >&2
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq ca-certificates curl nftables

install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

. /etc/os-release
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu ${VERSION_CODENAME} stable" \
  > /etc/apt/sources.list.d/docker.list

apt-get update -qq
apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# El kernel hace de router entre segmentos: reenvío IPv4 permanente.
cat > /etc/sysctl.d/99-laboratorio.conf <<'EOF'
net.ipv4.ip_forward = 1
EOF
sysctl --system >/dev/null

usermod -aG docker "$USUARIO"
systemctl enable --now docker containerd

echo "Docker Engine instalado. Cerrar y reabrir la sesión de $USUARIO (wsl --terminate) para aplicar el grupo docker."
