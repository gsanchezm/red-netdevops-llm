#!/usr/bin/env bash
# Valida D9: el modelo corre con contexto de 64 K, 100 % en GPU, y usa de verdad ese contexto.
# Requiere el laboratorio arriba (plana o segmentada) y el modelo ya descargado:
#   - descarga (solo en la topología plana, que tiene salida):  docker exec ollama ollama pull qwen3.5:2b
# Uso (root):  scripts/modelo.sh [modelo] [archivo-salida.txt]
# Salida: evidencia/dia3/modelo-64k.txt
set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODELO="${1:-qwen3.5:2b}"
SALIDA="${2:-$RAIZ/evidencia/dia3/modelo-64k.txt}"
REPETICIONES="${REPETICIONES:-2400}"      # ≈ 48 K tokens con la frase de relleno
mkdir -p "$(dirname "$SALIDA")"
docker inspect ollama >/dev/null 2>&1 || { echo "Ollama no está levantado: scripts/lab.sh plana|segmentada" >&2; exit 2; }

local_curl() { docker run --rm --network container:ollama -v "$TMP:/datos:ro" --entrypoint curl lab-nodo:1 "$@"; }
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

# Prompt largo: una "aguja" al inicio, relleno, y la pregunta al final.
{
  printf '{"model":"%s","stream":false,"think":false,"options":{"temperature":0,"num_predict":24},"prompt":"' "$MODELO"
  printf 'El código secreto del laboratorio es AZUL-7. Memorízalo. '
  for ((i=0; i<REPETICIONES; i++)); do printf 'El tráfico de la red 10.10.20.0/24 no sale a internet. '; done
  printf 'Pregunta final: ¿cuál es el código secreto del laboratorio? Responde solo el código."}'
} > "$TMP/prompt.json"

{
  echo "# modelo-64k.txt - $(date '+%Y-%m-%d %H:%M:%S %z')"
  echo "Modelo: $MODELO · servidor: $(docker exec ollama ollama --version 2>&1 | tail -1)"
  echo
  echo "== ollama show =="
  docker exec ollama ollama show "$MODELO" 2>&1 | sed -n '1,14p'
  echo
  echo "== Configuración del servidor (compose) =="
  docker inspect -f '{{range .Config.Env}}{{println .}}{{end}}' ollama | grep -E "^OLLAMA_(CONTEXT_LENGTH|FLASH_ATTENTION|KV_CACHE_TYPE|MAX_LOADED_MODELS|KEEP_ALIVE|NO_CLOUD)"

  docker exec ollama ollama stop "$MODELO" >/dev/null 2>&1
  desde="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo
  echo "== Petición con ~48 K tokens de contexto (aguja al inicio) =="
  respuesta="$(local_curl -s -m 600 http://127.0.0.1:11434/api/generate -H 'Content-Type: application/json' -d @/datos/prompt.json)"
  echo "$respuesta" | sed -E 's/"context":\[[^]]*\],?//' | head -c 700; echo
  echo
  echo "prompt_eval_count (tokens de entrada realmente procesados): $(echo "$respuesta" | sed -n 's/.*"prompt_eval_count":\([0-9]*\).*/\1/p')"
  echo "prompt_eval_duration: $(echo "$respuesta" | sed -n 's/.*"prompt_eval_duration":\([0-9]*\).*/\1/p') ns · load_duration: $(echo "$respuesta" | sed -n 's/.*"load_duration":\([0-9]*\).*/\1/p') ns"
  if echo "$respuesta" | grep -q "AZUL-7"; then echo "Aguja recuperada: AZUL-7 ✅"; else echo "Aguja NO recuperada ❌"; fi

  echo
  echo "== ollama ps (con el modelo cargado) =="
  docker exec ollama ollama ps
  echo
  echo "== GPU =="
  /usr/lib/wsl/lib/nvidia-smi --query-gpu=name,memory.used,memory.free,memory.total --format=csv
  echo
  echo "== Registro de carga de Ollama =="
  docker logs --since "$desde" ollama 2>&1 | grep -iE "too large|n_ctx_seq|kv_cache: size|offloaded|compute buffer size|model buffer size" \
    | sed -E 's/^.*(llama_|load_tensors|time=)/\1/' | cut -c1-190 | head -10
} > "$SALIDA" 2>&1

cat "$SALIDA"
grep -q "Aguja recuperada" "$SALIDA" && grep -q "100% GPU" "$SALIDA" && grep -qE "(^| )65536 " "$SALIDA"
