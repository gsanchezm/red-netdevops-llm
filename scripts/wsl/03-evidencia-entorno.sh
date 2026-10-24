#!/usr/bin/env bash
# Captura la evidencia del entorno del laboratorio (solo lectura, salvo cargar el módulo wireguard).
# Uso:  sudo bash scripts/wsl/03-evidencia-entorno.sh [directorio-salida]
# Salida: <directorio>/entorno.txt (por defecto evidencia/dia2)
set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SALIDA="${1:-$RAIZ/evidencia/dia2}"
mkdir -p "$SALIDA"
OUT="$SALIDA/entorno.txt"

seccion() { printf '\n== %s ==\n' "$1"; }

{
  echo "# entorno.txt - $(date '+%Y-%m-%d %H:%M:%S %z')"

  seccion "Sistema"
  . /etc/os-release && echo "$PRETTY_NAME"
  uname -r
  echo "systemd: $(systemctl is-system-running)"
  echo "RAM: $(free -h | awk '/Mem:/ {print $2}') · CPU lógicas: $(nproc) · disco libre: $(df -h / | awk 'NR==2 {print $4}')"

  seccion "Docker Engine (no Docker Desktop)"
  type -a docker | head -3
  docker --version
  docker compose version
  docker info 2>/dev/null | grep -E "Server Version|Storage Driver|Cgroup Driver|Firewall Backend|Default Runtime|Runtimes"
  echo "iptables: $(iptables -V)"
  echo "ip_forward: $(sysctl -n net.ipv4.ip_forward) · bridge-nf-call-iptables: $(sysctl -n net.bridge.bridge-nf-call-iptables 2>/dev/null || echo n/d)"

  seccion "WireGuard en el kernel (cierra la verificación previa al Día 4)"
  modprobe wireguard && lsmod | grep -E "^wireguard" || echo "módulo wireguard no disponible: el Día 4 usa wireguard-go"

  seccion "GPU en WSL (driver de Windows, sin driver Linux)"
  /usr/lib/wsl/lib/nvidia-smi --query-gpu=name,driver_version,memory.total,memory.used --format=csv

  seccion "GPU dentro de un contenedor (nvidia-container-toolkit)"
  nvidia-ctk --version | head -1
  docker run --rm --gpus all ubuntu:24.04 nvidia-smi --query-gpu=name,driver_version,memory.total,memory.used --format=csv
} > "$OUT" 2>&1

echo "Evidencia escrita en $OUT"
