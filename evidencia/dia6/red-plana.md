# Mediciones de red · topología plana

Generado 2026-10-25 19:15:13 -0600 con `scripts/medir-red.sh plana`. Kernel 6.18.54.1-microsoft-standard-WSL2. Los contenedores comparten el kernel de la Dell:
las cifras sirven para **comparar** (qué cuesta filtrar y cifrar), no como capacidad de un cable.

## Latencia ICMP (50 pings, intervalo de 0.2 s)

| Trayecto | Origen → destino | mín (ms) | media (ms) | máx (ms) | jitter (ms) | pérdida |
|---|---|---|---|---|---|---|
| Mismo segmento (L2) | `proyecto1` → `10.10.0.12` | 0.063 | **0.119** | 1.075 | 0.141 | 0 % |
| Hacia el host (gateway) | `proyecto1` → `10.10.0.1` | 0.047 | **0.135** | 2.980 | 0.406 | 0 % |
| Hacia Ollama (mismo L2 en la plana) | `proyecto1` → `10.10.0.10` | 0.049 | **0.149** | 2.947 | 0.400 | 0 % |

## Throughput TCP con iperf3 (10 s × 3, Gbit/s recibidos)

| Trayecto | Origen → destino | Media | Desviación |
|---|---|---|---|
| Mismo segmento | `proyecto1` → `10.10.0.12`:5201 | **29.94** | ± 0.10 (n=3) |
