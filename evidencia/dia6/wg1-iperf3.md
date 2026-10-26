# Rendimiento real por wg1 (Dell ↔ droplet, por internet)

Generado 2026-10-25 23:13:46 -0600 con `scripts/medir-wg1.sh`. TCP con iperf3, 10 s × 3, un flujo.
El camino es el real: la Dell sale por la subida del internet de la casa (doble NAT) hasta el droplet (NYC3) dentro de WireGuard.

| Sentido | Mbit/s (media) | Desviación |
|---|---|---|
| Subida: Dell → droplet | **124.5** | ± 13.2 (n=3) |
| Bajada: droplet → Dell | **241.3** | ± 8.0 (n=3) |

## Latencia ICMP Dell → droplet por wg1 (50 pings)

    50 packets transmitted, 50 received, 0% packet loss, time 9831ms
    rtt min/avg/max/mdev = 69.183/69.939/75.755/0.912 ms

El puerto 5201 del droplet solo se abrió para 10.10.51.2 durante la prueba (regla de runtime TEMP-iperf3) y el paquete se desinstaló al terminar.
