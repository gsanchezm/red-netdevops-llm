#!/usr/bin/env bash
# Snapshot de SOLO LECTURA del estado del laboratorio para que Hermes lo analice (D7: el agente observa y propone,
# no cambia nada). Escribe en lab/snapshots/<destino> (por omisión, una carpeta con la fecha); esa carpeta se monta
# en Hermes como /snapshots:ro. No contiene llaves: `wg show` oculta la privada y se recortan las públicas.
# Uso (root, con la topología segmentada levantada):  scripts/snapshot.sh [destino]
set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DESTINO="$RAIZ/lab/snapshots/${1:-$(date +%Y%m%d-%H%M%S)}"
docker inspect caddy >/dev/null 2>&1 || { echo "La topología segmentada no está levantada: scripts/lab.sh segmentada" >&2; exit 2; }
mkdir -p "$DESTINO"

cp "$RAIZ/lab/hermes/matriz-de-flujos.md" "$DESTINO/matriz-de-flujos.md"
nft list chain inet netseg forward > "$DESTINO/politica-cargada.nft"
docker ps --format '{{.Names}}  {{.Status}}  {{.Networks}}' | sort > "$DESTINO/contenedores.txt"
{ wg show wg0; wg show wg1; } 2>/dev/null | sed -E 's/((peer|public key): .{6}).*/\1…/; s/endpoint: ([0-9]+)\.([0-9]+)\.[0-9]+\.[0-9]+/endpoint: \1.\2.x.x/' > "$DESTINO/wireguard.txt"
cat > "$DESTINO/LEEME.txt" <<EOF
Snapshot del $(date '+%Y-%m-%d %H:%M:%S %z') (solo lectura).
matriz-de-flujos.md  Lo que la política permite; todo lo demás está denegado.
politica-cargada.nft Cadena forward de nftables cargada ahora (tabla inet netseg).
contenedores.txt     Contenedores y sus redes.
wireguard.txt        Estado de wg0 y wg1 (claves recortadas).
EOF
echo "Snapshot escrito en $DESTINO"
ls -1 "$DESTINO" | sed 's/^/  /'
