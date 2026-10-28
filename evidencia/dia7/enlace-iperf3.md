# Rendimiento del enlace físico (Dell ↔ equipo cableado al mismo conmutador)

Generado 2026-10-26 11:47:03 -0600 con `scripts/medir-enlace.sh`. TCP con iperf3, 10 s × 3, un flujo,
en cada sentido (el inverso con `-R`, iniciado siempre desde la Dell). JSON crudo en `subida-N.json` y `bajada-N.json`.
El cliente corre en WSL2 (contenedor con la red del host): el tráfico pasa por la NAT de WSL2 antes de salir por la tarjeta cableada.

| Sentido | Mbit/s (media) | Desviación |
|---|---|---|
| Subida: Dell → equipo cableado | **940.4** | ± 0.1 (n=3) |
| Bajada: equipo cableado → Dell | **940.5** | ± 0.6 (n=3) |

## Latencia ICMP Dell → equipo cableado (50 pings, intervalo de 0.2 s, sin carga)

    --- 192.168.68.166 ping statistics ---
    50 packets transmitted, 50 received, 0% packet loss, time 9867ms
    rtt min/avg/max/mdev = 0.679/1.201/2.283/0.318 ms
