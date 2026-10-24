#!/usr/bin/env bash
# Instala nvidia-container-toolkit y registra el runtime en Docker (GPU para contenedores).
# Uso:  sudo bash scripts/wsl/02-nvidia-toolkit.sh
# NO instala driver NVIDIA de Linux: en WSL2 la GPU se expone desde el driver de Windows
# (bibliotecas en /usr/lib/wsl/lib). Aquí solo se instala el toolkit de contenedores.
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "Ejecutar como root: sudo bash $0" >&2
  exit 1
fi

if ! /usr/lib/wsl/lib/nvidia-smi >/dev/null 2>&1; then
  echo "nvidia-smi no ve la GPU desde WSL: revisar el driver NVIDIA de Windows." >&2
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive
apt-get install -y -qq gnupg curl

curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey \
  | gpg --dearmor --yes -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
curl -fsSL https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list \
  | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' \
  > /etc/apt/sources.list.d/nvidia-container-toolkit.list

apt-get update -qq
apt-get install -y -qq nvidia-container-toolkit

nvidia-ctk runtime configure --runtime=docker
systemctl restart docker

echo "Toolkit instalado. Probar: docker run --rm --gpus all ubuntu nvidia-smi"
