# Nodo de laboratorio: imagen mínima con herramientas de red y un "servicio de prueba".
# Sustituye a Caddy, Ollama, Hermes y los proyectos mientras se valida la red (Día 2);
# desde el Día 3 los servicios reales reemplazan a esta imagen sin cambiar IP ni puertos.
FROM alpine:3.22

RUN apk add --no-cache \
      bind-tools curl iperf3 iproute2 iputils-ping netcat-openbsd socat tcpdump

COPY entrada.sh /usr/local/bin/entrada.sh
RUN chmod +x /usr/local/bin/entrada.sh

ENTRYPOINT ["/usr/local/bin/entrada.sh"]
