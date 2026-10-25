#!/usr/bin/env bash
# Ciclo de vida del laboratorio: una topología a la vez (comparten nombres de servicio).
# Uso (como root o con sudo, porque carga reglas nftables):
#   scripts/lab.sh plana           levanta la topología plana (sin reglas)
#   scripts/lab.sh segmentada      carga lab/nftables/netseg.nft, levanta wg0 (scripts/wg0.sh) y la segmentada
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

# Construye las imágenes con la política descargada: el build sale a internet por docker0 y netseg
# (con su política drop) lo bloquea. Es rápido si no cambió nada (caché).
construir() { nft_quitar; docker compose -f "$LAB/compose.$1.yml" build; }

# Volúmenes externos y persistentes: el modelo de Ollama y la CA interna de Caddy.
# Compose nunca los borra (no usar `down -v`: el modelo pesa ~2 GB y la CA firma los certificados).
volumenes() { docker volume create ollama-data >/dev/null; docker volume create caddy-data >/dev/null; }

# Copia solo el certificado raíz (público) de la CA interna de Caddy a lab/ca/. La llave privada
# no sale del volumen caddy-data. Los clientes montan lab/ca en /ca (solo lectura).
exportar_ca() {
  local destino="$LAB/ca/root.crt" origen="caddy:/data/caddy/pki/authorities/local/root.crt"
  mkdir -p "$LAB/ca"
  for _ in $(seq 1 60); do
    if docker cp "$origen" "$destino" 2>/dev/null; then
      chmod 644 "$destino"
      # Paquete para clientes que reemplazan el almacén de confianza (SSL_CERT_FILE): CA públicas + la interna.
      cat /etc/ssl/certs/ca-certificates.crt "$destino" > "$LAB/ca/bundle.crt"; chmod 644 "$LAB/ca/bundle.crt"
      echo "CA interna exportada a lab/ca/root.crt (y bundle.crt)"; return 0
    fi
    sleep 1
  done
  echo "ADVERTENCIA: Caddy no generó su CA a tiempo" >&2; return 1
}

# Espera a los servicios con `healthcheck` (Ollama, Caddy).
esperar_salud() {
  for _ in $(seq 1 120); do
    [[ -z "$(docker ps -q --filter health=starting)" ]] && break
    sleep 1
  done
  local mal; mal="$(docker ps --filter health=unhealthy --format '{{.Names}}')"
  [[ -z $mal ]] || echo "ADVERTENCIA: no saludables: $mal" >&2
}

# Espera a que los servicios de prueba escuchen (los puertos salen de ESCUCHA).
esperar() {
  esperar_salud
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
    bajar segmentada; "$RAIZ/scripts/wg0.sh" abajo; nft_quitar; volumenes
    docker compose -f "$LAB/compose.plana.yml" up -d --build
    esperar ;;
  segmentada)
    bajar plana; volumenes; mkdir -p "$LAB/ca"
    construir segmentada
    nft_cargar                     # primero la política: la red nace ya filtrada
    "$RAIZ/scripts/wg0.sh" servidor   # wg0 y su excepción en Docker (DOCKER-USER) antes que la topología
    docker compose -f "$LAB/compose.segmentada.yml" up -d --build
    esperar
    exportar_ca
    "$RAIZ/scripts/wg0.sh" cliente ;;
  nft-cargar) nft_cargar ;;
  nft-quitar) nft_quitar ;;
  apagar)     bajar plana; bajar segmentada; "$RAIZ/scripts/wg0.sh" abajo; nft_quitar ;;
  estado)
    docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Networks}}'
    $SUDO nft list tables
    "$RAIZ/scripts/wg0.sh" estado ;;
  *) sed -n '2,10p' "${BASH_SOURCE[0]}"; exit 2 ;;
esac
