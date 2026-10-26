#!/usr/bin/env bash
# Convierte una propuesta de Hermes en un pull request que SOLO contiene un documento (docs/propuestas/). Hermes
# observa y propone; una persona ejecuta este script y otra decide si se incorpora (D7). Hermes no tiene token de
# GitHub ni acceso al repositorio: nunca aplica un cambio.
# Uso (lo ejecuta una PERSONA, con su sesión de GitHub):
#   scripts/proponer-pr.sh <archivo-con-la-propuesta> [--simular]
# --simular: muestra qué haría (rama, documento y PR) y NO cambia nada.
set -euo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARCHIVO="${1:?Uso: $0 <archivo-con-la-propuesta> [--simular]}"
SIMULAR=0; [[ ${2:-} == --simular ]] && SIMULAR=1
[[ -s $ARCHIVO ]] || { echo "La propuesta está vacía o no existe: $ARCHIVO" >&2; exit 2; }
cd "$RAIZ"

# La propuesta es texto de un LLM: nunca se publica sin revisar que no traiga IP reales ni llaves.
"$RAIZ/scripts/escanear-secretos.sh" --archivo "$ARCHIVO"

FECHA="$(date +%Y%m%d-%H%M%S)"
RAMA="hermes/propuesta-$FECHA"
DOC="docs/propuestas/$FECHA-hermes.md"
TITULO="Propuesta de Hermes (sin aplicar) $FECHA"
CUERPO="$(cat <<EOF
Propuesta generada por Hermes Agent al revisar un snapshot de solo lectura. **No se ha aplicado nada**: este PR solo
agrega un documento. Quien mantiene el repositorio decide si la propuesta tiene razón; si la tiene, el cambio real
se hace en otro PR, pasa la CI y se despliega con aprobación (D7).

Documento: \`$DOC\`
EOF
)"

if (( SIMULAR )); then
  echo "SIMULACIÓN (no se cambia nada):"
  echo "  rama:      $RAMA"
  echo "  documento: $DOC ($(wc -l < "$ARCHIVO") líneas)"
  echo "  título:    $TITULO"
  echo "  se haría:  git switch -c; añadir el documento; commit; git push; gh pr create --base main"
  echo "--- inicio del documento ---"; head -12 "$ARCHIVO"; echo "--- (fin del extracto) ---"
  exit 0
fi

GH="${GH:-$(command -v gh || command -v gh.exe || true)}"
[[ -n $GH ]] || { echo "Falta gh (o gh.exe en WSL). Instálalo o exporta GH=<ruta>" >&2; exit 2; }
[[ -z "$(git status --porcelain)" ]] || { echo "El árbol de trabajo tiene cambios sin commit: limpia antes de proponer" >&2; exit 2; }
ORIGINAL="$(git rev-parse --abbrev-ref HEAD)"
git switch -c "$RAMA"
mkdir -p "$(dirname "$DOC")"
{
  echo "# Propuesta de Hermes · $FECHA"
  echo
  echo "> Generada por un agente de IA local a partir de un snapshot de solo lectura. **No está aplicada** y puede estar equivocada: se revisa como cualquier propuesta."
  echo
  cat "$ARCHIVO"
} > "$DOC"
git add "$DOC"
git commit -q -m "$TITULO"
git push -u origin "$RAMA"
"$GH" pr create --base main --head "$RAMA" --title "$TITULO" --body "$CUERPO"
git switch "$ORIGINAL"
