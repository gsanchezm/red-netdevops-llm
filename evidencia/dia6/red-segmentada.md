# Mediciones de red · topología segmentada

Generado 2026-10-25 19:11:45 -0600 con `scripts/medir-red.sh segmentada`. Kernel 6.18.54.1-microsoft-standard-WSL2. Los contenedores comparten el kernel de la Dell:
las cifras sirven para **comparar** (qué cuesta filtrar y cifrar), no como capacidad de un cable.

## Latencia ICMP (50 pings, intervalo de 0.2 s)

| Trayecto | Origen → destino | mín (ms) | media (ms) | máx (ms) | jitter (ms) | pérdida |
|---|---|---|---|---|---|---|
| Mismo segmento (Trabajo), con netseg | `proyecto1` → `10.10.10.12` | 0.065 | **0.162** | 3.365 | 0.458 | 0 % |
| Hacia el host (gateway de Trabajo) | `proyecto1` → `10.10.10.1` | 0.055 | **0.089** | 0.205 | 0.033 | 0 % |
| Caddy → Ollama (VLAN 20, única ruta ICMP permitida) | `caddy` → `10.10.20.10` | 0.058 | **0.327** | 10.482 | 1.451 | 0 % |

## Throughput TCP con iperf3 (10 s × 3, Gbit/s recibidos)

| Trayecto | Origen → destino | Media | Desviación |
|---|---|---|---|
| Mismo segmento, con netseg | `proyecto1` → `10.10.10.12`:5201 | **29.29** | ± 0.20 (n=3) |
| Sin túnel (cliente-remoto → host por br-inet) | `cliente-remoto` → `203.0.113.1`:5201 | **31.01** | ± 0.22 (n=3) |
| Con túnel WireGuard wg0 (cifrado) | `cliente-remoto` → `10.10.50.1`:5201 | **0.68** | ± 0.01 (n=3) |

La regla temporal de `input` que deja pasar el puerto 5201 (`TEMP-iperf3`) y el iperf3 del host se quitan al terminar.

## Latencia ICMP por la VPN emulada (cliente-remoto)

| Trayecto | Origen → destino | mín (ms) | media (ms) | máx (ms) | jitter (ms) | pérdida |
|---|---|---|---|---|---|---|
| Sin túnel (br-inet) | `cliente-remoto` → `203.0.113.1` | 0.054 | **0.117** | 1.083 | 0.160 | 0 % |
| Con túnel wg0 | `cliente-remoto` → `10.10.50.1` | 0.369 | **0.564** | 1.244 | 0.190 | 0 % |

Regla temporal: 0 restantes tras limpiar (debe ser 0).
