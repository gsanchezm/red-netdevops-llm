#!/usr/bin/env bash
# Prueba de humo de Hermes Agent en la VLAN 99 (topología segmentada): sin puertos de entrada,
# configuración de solo lectura y una pregunta de una sola vez que viaja
# Hermes -> Caddy (TLS, CA interna) -> Ollama (GPU), con el registro de Caddy como prueba.
# Uso (root):  scripts/hermes-prueba.sh      Salida: evidencia/dia3/hermes.txt
set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SALIDA="$RAIZ/evidencia/dia3/hermes.txt"; mkdir -p "$(dirname "$SALIDA")"
docker inspect -f '{{.Config.Image}}' hermes 2>/dev/null | grep -q hermes-agent || { echo "Hermes real no está levantado: scripts/lab.sh segmentada" >&2; exit 2; }
sonda() { docker run --rm --network container:hermes --entrypoint "$1" lab-nodo:1 "${@:2}"; }

{
  echo "# hermes.txt - $(date '+%Y-%m-%d %H:%M:%S %z')"
  echo "$(docker exec hermes hermes --version 2>/dev/null | head -1) · imagen $(docker inspect -f '{{.Config.Image}}' hermes | cut -c1-70)"
  echo
  echo "== Sin puertos de entrada desde la red =="
  sonda netstat -tln | tail -n +3
  echo "escuchas fuera de loopback: $(sonda netstat -tln | tail -n +3 | awk '{print $4}' | grep -vc '^127\.')"
  # Desde otro equipo de la misma VLAN, el puerto de la API local de Hermes no debe abrirse.
  echo "colector (misma VLAN 99) → 10.10.99.20:8642: $(docker run --rm --network container:colector --entrypoint nc lab-nodo:1 -zv -w 2 10.10.99.20 8642 2>&1 | sed -E 's/.*(refused|timed out|succeeded).*/\1/')"
  echo
  echo "== Sin acceso al host: puntos de montaje del contenedor =="
  docker inspect -f '{{range .Mounts}}{{.Type}} {{.Destination}} (rw={{.RW}}){{println}}{{end}}' hermes
  echo "docker.sock montado: $(docker inspect -f '{{range .Mounts}}{{.Source}} {{end}}' hermes | grep -c docker.sock)"
  echo
  echo "== La configuración es de solo lectura =="
  docker exec hermes sh -c 'echo prueba >> /opt/data/config.yaml' 2>&1 | head -1
  echo
  echo "== Modelo y endpoint que Hermes lee =="
  docker exec hermes hermes config get model 2>&1 | head -8
  echo
  echo "== Pregunta de una sola vez: hermes chat -q \"Responde solo con la palabra: OK\" -Q =="
  desde="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  inicio=$SECONDS
  docker exec hermes timeout 280 hermes chat -q "Responde solo con la palabra: OK" -Q 2>&1 | grep -v '^$' | tail -4
  echo "(duración total: $((SECONDS-inicio)) s, incluye la carga del modelo y el prompt del sistema de Hermes)"
  echo
  echo "== Registro de Caddy: la petición llegó desde Admin (10.10.99.20) por TLS =="
  linea="$(docker logs --since "$desde" caddy 2>&1 | grep '"remote_ip":"10.10.99.20"' | grep 'chat/completions' | tail -1)"
  campo() { echo "$linea" | grep -o "\"$1\":\"\?[^\",}]*" | head -1 | sed -E "s/\"$1\":\"?//"; }
  [[ -n $linea ]] && echo "remote_ip=$(campo remote_ip) proto=$(campo proto) server_name=$(campo server_name) uri=$(campo uri) status=$(campo status)"
  echo
  echo "== ollama ps =="
  docker exec ollama ollama ps
} > "$SALIDA" 2>&1

docker exec ollama ollama stop qwen3.5:2b >/dev/null 2>&1    # no dejar el modelo residente
sync; echo 3 > /proc/sys/vm/drop_caches
cat "$SALIDA"
grep -q "status=200" "$SALIDA" && grep -qE "^OK" "$SALIDA"
