# Latencia de la API de la IA · topología segmentada

Generada 2026-10-24 01:34:43 -0600 con `scripts/latencia-api.sh` · modelo `qwen3.5:2b` (contexto 65536, 100 % GPU) · 10 peticiones por ruta, modelo ya cargado.
Petición: `/api/generate`, streaming, `think:false`, 48 tokens, `temperature:0`. Valores en **ms: mediana (peor caso)**; "1.er token" es el tiempo hasta el primer byte de la respuesta (incluye TCP y TLS).

| Ruta | TCP | TLS | 1.er token | Total | Tokens/s |
|---|---|---|---|---|---|
| Caddy → Ollama (salto interno, VLAN 20, sin TLS) | 0.4 (145.4) | — | 37 (187) | 480 (630) | 95 |
| Trabajo → Caddy (TLS) → Ollama, por nombre | 1.1 (2.1) | 4.0 (12.0) | 37 (72) | 484 (661) | 94 |
| Trabajo → Caddy (TLS) → Ollama, por IP | 0.2 (0.8) | 3.5 (4.4) | 34 (41) | 483 (497) | 94 |
| Admin → Caddy (TLS) → Ollama, por nombre | 1.3 (18.8) | 3.8 (5.0) | 38 (52) | 494 (511) | 94 |
| Referencia nube: Trabajo → api.anthropic.com (solo conexión, sin modelo) | 45.6 (96.1) | 46.6 (51.0) | 133 (181) | 134 (181) | — |

**Arranque en frío** (modelo fuera de la GPU, primera petición): total 2.978900 s, de los cuales la carga del modelo 2878 ms.
