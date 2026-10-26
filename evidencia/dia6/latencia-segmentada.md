# Latencia de la API de la IA · topología segmentada

Generada 2026-10-25 20:37:08 -0600 con `scripts/latencia-api.sh` · modelo `qwen3.5:2b` (contexto 65536, 100 % GPU) · 10 peticiones por ruta, modelo ya cargado.
Petición: `/api/generate`, streaming, `think:false`, 48 tokens, `temperature:0`. Valores en **ms: mediana (peor caso)**; "1.er token" es el tiempo hasta el primer byte de la respuesta (incluye TCP y TLS).

| Ruta | TCP | TLS | 1.er token | Total | Tokens/s |
|---|---|---|---|---|---|
| Caddy → Ollama (salto interno, VLAN 20, sin TLS) | 0.3 (0.8) | — | 33 (120) | 464 (744) | 97 |
| Trabajo → Caddy (TLS) → Ollama, por nombre | 0.9 (18.0) | 4.0 (4.5) | 37 (82) | 469 (517) | 97 |
| Trabajo → Caddy (TLS) → Ollama, por IP | 0.2 (0.3) | 3.7 (4.2) | 34 (48) | 473 (487) | 96 |
| Admin → Caddy (TLS) → Ollama, por nombre | 0.9 (12.8) | 3.6 (6.3) | 35 (52) | 479 (497) | 95 |
| VPN emulada: cliente-remoto → wg0 → Caddy (TLS) → Ollama, por IP | 0.5 (1.5) | 4.0 (17.8) | 36 (49) | 485 (497) | 94 |
| Referencia nube: Trabajo → api.anthropic.com (solo conexión, sin modelo) | 45.2 (62.8) | 47.5 (52.7) | 133 (152) | 133 (152) | — |

**Arranque en frío** (modelo fuera de la GPU, primera petición): total 10.050684 s, de los cuales la carga del modelo 9817 ms.
