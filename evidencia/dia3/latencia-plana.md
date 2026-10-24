# Latencia de la API de la IA · topología plana

Generada 2026-10-24 01:36:05 -0600 con `scripts/latencia-api.sh` · modelo `qwen3.5:2b` (contexto 65536, 100 % GPU) · 10 peticiones por ruta, modelo ya cargado.
Petición: `/api/generate`, streaming, `think:false`, 48 tokens, `temperature:0`. Valores en **ms: mediana (peor caso)**; "1.er token" es el tiempo hasta el primer byte de la respuesta (incluye TCP y TLS).

| Ruta | TCP | TLS | 1.er token | Total | Tokens/s |
|---|---|---|---|---|---|
| Trabajo → Ollama directo (sin TLS, sin control) | 0.3 (1.1) | — | 32 (71) | 474 (547) | 94 |
| Referencia nube: Trabajo → api.anthropic.com (solo conexión, sin modelo) | 45.2 (63.3) | 47.8 (55.4) | 131 (156) | 131 (157) | — |

**Arranque en frío** (modelo fuera de la GPU, primera petición): total 10.201371 s, de los cuales la carga del modelo 10069 ms.
