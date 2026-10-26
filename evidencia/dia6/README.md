# Evidencia del Día 6 · mediciones finales y Hermes

Índice para el reporte; la explicación está en `docs/05-mediciones-y-hermes.md`.

| Archivo | Qué demuestra | Para el reporte |
|---|---|---|
| `red-plana.md`, `red-segmentada.md` | ICMP (50 pings) y `iperf3` (10 s × 3) en cada topología; en la segmentada, WireGuard con y sin túnel | Costo de segmentar (−2.2 % TCP) y de cifrar (0.68 vs 31 Gbit/s, +0.45 ms) |
| `latencia-segmentada.md` | Latencia de la API (TCP, TLS, 1.er token, total, tokens/s) por cada ruta, incluida la VPN emulada | La VPN añade ≈ 2 % al total: domina la generación del modelo |
| `modelo-4b-64k.txt` | `qwen3.5:4b` a 64 K con caché f16: aguja recuperada, 34 % CPU / 66 % GPU | Por qué el modelo del laboratorio sigue siendo el de 2 B |
| `modelo-4b-64k-kv-q8.txt` | Lo mismo con caché `q8_0`: 77 % GPU, tampoco llega al 100 % | Límite de 6 GB de VRAM |
| `hermes-eval/<modelo>/resumen.md` | Aciertos de Hermes revisando una política: `qwen3.5_2b` y `qwen3.5_4b`, con herramientas y con contexto (`_contexto`), 4 escenarios × 3 corridas | Calidad del agente: 2 B poco fiable, 4 B mejor, desvío sutil sin identificar |
| `hermes-eval/<modelo>/<escenario>-<n>.txt` | La respuesta cruda de cada corrida | Ejemplos de los modos de fallo (ruta inexistente, turnos agotados, archivo inventado) |

Se regeneran con `scripts/medir-red.sh`, `scripts/latencia-api.sh` (con `SALIDA=…`), `scripts/modelo.sh <modelo>` y
`scripts/hermes-evaluar.sh <modelo> <corridas> herramientas|contexto`. Las pruebas del 4 B usaron un *override*
temporal de Compose (`OLLAMA_KV_CACHE_TYPE=q8_0`) que no está en el repositorio.
