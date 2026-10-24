#!/usr/bin/env bash
# Ciclo de vida del laboratorio: una topología a la vez (comparten nombres de servicio).
# Uso (como root o con sudo, porque carga reglas nftables):
#   scripts/lab.sh plana           levanta la topología plana (sin reglas)
#   scripts/lab.sh segmentada      carga lab/nftables/netseg.nft y levanta la segmentada
#   scripts/lab.sh nft-quitar      descarga la tabla netseg (la segmentada queda solo con las reglas de Docker)
#   scripts/lab.sh nft-cargar      vuelve a cargar la tabla netseg
#   scripts/lab.sh apagar          baja ambas topologías y descarga netseg
#   scripts/lab.sh estado
set -euo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LAB="$RAIZ/lab"
SUDO=""; [[ $EUID -ne 0 ]] && SUDO="sudo"

bajar() { docker compose -f "$LAB/compose.$1.yml" down --remove-orphans -t 2 >/dev/null 2>&1 || true; }
nft_cargar() { $SUDO nft -f "$LAB/nftables/netseg.nft"; echo "nftables: tabla inet netseg cargada"; }
nft_quitar() { $SUDO nft delete table inet netseg 2>/dev/null && echo "nftables: tabla inet netseg descargada" || true; }

# Espera a que los servicios de prueba escuchen (los puertos salen de ESCUCHA).
esperar() {
  local c p
  for c in $(docker ps --format '{{.Names}}'); do
    for p in $(docker inspect -f '{{range .Config.Env}}{{println .}}{{end}}' "$c" | sed -n 's/^ESCUCHA=//p' | tr ',' ' '); do
      for _ in $(seq 1 30); do
        docker exec "$c" nc -z 127.0.0.1 "$p" 2>/dev/null && continue 2
        sleep 0.2
      done
      echo "ADVERTENCIA: $c no escucha en $p" >&2
    done
  done
}

case "${1:-}" in
  plana)
    bajar segmentada; nft_quitar
    docker compose -f "$LAB/compose.plana.yml" up -d --build
    esperar ;;
  segmentada)
    bajar plana
    nft_cargar                     # primero la política: la red nace ya filtrada
    docker compose -f "$LAB/compose.segmentada.yml" up -d --build
    esperar ;;
  nft-cargar) nft_cargar ;;
  nft-quitar) nft_quitar ;;
  apagar)     bajar plana; bajar segmentada; nft_quitar ;;
  estado)
    docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Networks}}'
    $SUDO nft list tables ;;
  *) sed -n '2,10p' "${BASH_SOURCE[0]}"; exit 2 ;;
esac
