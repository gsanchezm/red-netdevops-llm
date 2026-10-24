#!/bin/sh
# Servicio de prueba: abre cada puerto TCP de ESCUCHA (lista separada por comas) y responde
# "<NOMBRE>:<puerto>" al conectar. Sin ESCUCHA, el nodo solo actúa como cliente.
NOMBRE="${NOMBRE:-$(hostname)}"

for puerto in $(echo "${ESCUCHA:-}" | tr ',' ' '); do
  socat "TCP-LISTEN:${puerto},fork,reuseaddr" "SYSTEM:echo ${NOMBRE}:${puerto}" &
done

exec sleep infinity
