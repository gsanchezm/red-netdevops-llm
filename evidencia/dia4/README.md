# Evidencia del Día 4 · WireGuard (VPN emulada y VPN real)

Índice para el reporte: qué prueba cada archivo y dónde se explica (`docs/03-laboratorio.md` §8).
Las llaves públicas aparecen recortadas, las privadas nunca se imprimen y las IP públicas están
ocultas (`45.55.x.x`, `189.203.x.x`, `200.68.x.x`). Las IP del laboratorio (`10.10.x.x`, `203.0.113.x`) son privadas o de documentación.

| Archivo | Qué demuestra | Para el reporte |
|---|---|---|
| `regiones.txt` | 50 pings desde la casa a tres regiones de DigitalOcean: nyc3 69.9 ms (jitter 1.1), tor1 72.6, sfo3 78.2, 0 % de pérdida | Elección del concentrador por **datos medidos**, no por suposición |
| `matriz-segmentada.md` | 44 casos, 0 fallas, con `wg0` y `wg1` cargados; 25 bloqueos (21 por el filtrado del kernel, 4 sin ruta) | Resultado principal de la política de segmentación y de la VPN |
| `wg0-emulada.txt` | Servidor `wg0` y cliente emulado: handshake, 0.56 ms por el túnel frente a 0.09 ms sin túnel, certificado válido por IP, lo prohibido sin respuesta, contadores de las tres capas de filtrado | Costo de cifrar y filtrar; acceso remoto cifrado funcionando |
| `wg1-real.txt` | VPN real: Dell ↔ droplet a ~70 ms con 0 % de pérdida, conexión saliente de la Dell, solicitudes que llegaron a Caddy con origen `10.10.51.3` (sin NAT), contadores del droplet y de la Dell | Latencia WAN real y trazabilidad del cliente |
| `celular-wireguard-handshake.png` | iPhone por **5G** con el túnel `redes-lab` activo: handshake reciente, `10.10.51.3/32`, IPs permitidas `10.10.51.0/24, 10.10.10.5/32` (IP del droplet tapada) | Figura: cliente real conectado por datos móviles |
| `celular-ca-confianza.png` | La CA interna de Caddy instalada y con confianza total en iOS | Figura: TLS con CA interna (D5) |
| `celular-api-tags.png` | Respuesta de Ollama (`/api/tags`) en Safari, por 5G, a través de droplet y Dell | **Figura principal:** el resultado de punta a punta |
| `celular-fallo-inicial.png` | La primera prueba falló ("no pudo conectarse al servidor") aun con handshake correcto: Caddy había quedado en `10.10.10.2` | Diagnóstico y lección (§8.5): `lab.sh` ahora verifica la IP de Caddy |

Nota: de las dos solicitudes `GET /api/tags` de `wg1-real.txt`, una es una prueba hecha desde el droplet
(`curl`) y la otra es la del iPhone; el registro las distingue por su *User-Agent*.

Cómo regenerar lo que es reproducible: `scripts/lab.sh segmentada`, `scripts/matriz.sh segmentada
evidencia/dia4/matriz-segmentada.md`, `scripts/wg0-evidencia.sh` y `scripts/wg1-evidencia.sh` (esta última no
incluye la sección del droplet, que se toma por `ssh`). Las capturas del celular no se regeneran.
