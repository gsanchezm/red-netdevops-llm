#!/usr/bin/env bash
# Escanea los archivos versionados por IP reales y llaves de WireGuard. El repositorio es público.
# Lo usan la CI (.github/workflows/lint.yml) y el trabajo diario antes de cada commit.
# Uso:  scripts/escanear-secretos.sh            revisa todo lo versionado
#       scripts/escanear-secretos.sh --staging  revisa solo lo que está en staging
#       scripts/escanear-secretos.sh --probar   autoprueba: debe DETECTAR una IP y una llave de mentira
# Código de salida: 0 limpio · 1 hay coincidencias · 2 no se pudo revisar (nunca "limpio" sin haber revisado).
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 2

# IP públicas reales de este proyecto (en el repositorio solo se escriben ocultas: 45.55.x.x) y llaves
# de WireGuard (base64 de 32 bytes = 43 caracteres + "="), públicas o privadas.
PATRON='45\.55\.[0-9]+\.[0-9]+|189\.203\.[0-9]+\.[0-9]+|200\.68\.[0-9]+\.[0-9]+|[A-Za-z0-9+/]{43}=|PrivateKey *= *[A-Za-z0-9+/]{20}'
# Como root el repositorio (de otro usuario) daría "dubious ownership" y git no listaría nada.
GIT=(git -c "safe.directory=$PWD")

if [[ ${1:-} == --probar ]]; then
  falsa_ip="45.55.$((RANDOM % 200 + 20)).$((RANDOM % 200 + 20))"
  falsa_llave="$(printf 'A%.0s' {1..43})="
  for muestra in "$falsa_ip" "$falsa_llave"; do
    grep -qE "$PATRON" <<< "$muestra" || { echo "AUTOPRUEBA FALLÓ: no detecta '$muestra'" >&2; exit 2; }
  done
  echo "autoprueba OK: detecta una IP real y una llave de mentira"
  exit 0
fi

if [[ ${1:-} == --archivo ]]; then
  # Un archivo cualquiera (p. ej. la propuesta de Hermes) antes de publicarlo.
  [[ -f ${2:-} ]] || { echo "Uso: $0 --archivo <ruta>" >&2; exit 2; }
  if grep -InE "$PATRON" "$2" | cut -c1-160 >&2; [[ ${PIPESTATUS[0]} -eq 0 ]]; then echo "COINCIDENCIAS en $2" >&2; exit 1; fi
  echo "limpio: $2 no tiene IP reales ni llaves"
  exit 0
fi

tmp="$(mktemp)"; trap 'rm -f "$tmp"' EXIT
if [[ ${1:-} == --staging ]]; then
  "${GIT[@]}" diff --cached -U0 > "$tmp" || { echo "no pude leer el staging de git" >&2; exit 2; }
  salida="$(grep -E '^\+' "$tmp" | grep -vE '^\+\+\+' | grep -E "$PATRON")"
else
  "${GIT[@]}" ls-files -z > "$tmp" || { echo "no pude listar los archivos de git" >&2; exit 2; }
  [[ -s $tmp ]] || { echo "git no devolvió archivos: no se revisó nada" >&2; exit 2; }
  salida="$(xargs -0 -a "$tmp" grep -InE "$PATRON" 2>/dev/null)"
fi

if [[ -n $salida ]]; then
  echo "COINCIDENCIAS (IP real o llave):" >&2
  echo "$salida" | cut -c1-160 >&2
  exit 1
fi
echo "limpio: sin IP reales ni llaves ($([[ ${1:-} == --staging ]] && echo 'staging' || echo "$(tr -cd '\0' < "$tmp" | wc -c) archivos versionados"))"
