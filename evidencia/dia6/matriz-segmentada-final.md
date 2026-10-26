# Matriz de alcanzabilidad · topología segmentada

Generada 2026-10-25 20:40:51 -0600 con `scripts/matriz.sh segmentada` (política: docs/02-diseno.md §5).

| Caso | Celda de §5 | Origen → destino:puerto | Esperado | Observado | Resultado |
|---|---|---|---|---|---|
| T01 | Trabajo→Trabajo | proyecto1 → proyecto2 (10.10.10.12):8080 | permitir | abierto | ✅ OK |
| T02 | Trabajo→Caddy | proyecto1 → caddy@trabajo (10.10.10.5):443 | permitir | abierto | ✅ OK |
| T03 | Trabajo→Caddy (IA) | proyecto1 → caddy@ia (10.10.20.5):443 | bloquear | sin-respuesta | ✅ OK |
| T04 | Trabajo→Ollama | proyecto1 → ollama (10.10.20.10):11434 | bloquear | sin-respuesta | ✅ OK |
| T05 | Trabajo→Admin | proyecto1 → colector (10.10.99.30):9100 | bloquear | sin-respuesta | ✅ OK |
| T06 | Trabajo→IoT | proyecto1 → iot-sensor (10.10.30.10):1883 | bloquear | sin-respuesta | ✅ OK |
| T07 | Trabajo→Internet | proyecto1 → 1.1.1.1 (1.1.1.1):443 | permitir | abierto | ✅ OK |
| T08 | Trabajo→Internet | proyecto1 → 1.1.1.1 (1.1.1.1):80 | permitir | abierto | ✅ OK |
| I01 | Caddy→Ollama | caddy → ollama (10.10.20.10):11434 | permitir | abierto | ✅ OK |
| I02 | IA→Caddy | ollama → caddy@ia (10.10.20.5):443 | bloquear | sin-respuesta | ✅ OK |
| I03 | IA→Trabajo | ollama → proyecto1 (10.10.10.11):8080 | bloquear | sin-ruta | ✅ OK |
| I04 | IA→Admin | ollama → colector (10.10.99.30):9100 | bloquear | sin-ruta | ✅ OK |
| I05 | IA→Internet | ollama → 1.1.1.1 (1.1.1.1):443 | bloquear | sin-ruta | ✅ OK |
| C01 | Caddy→Internet | caddy → 1.1.1.1 (1.1.1.1):443 | bloquear | sin-respuesta | ✅ OK |
| A01 | Admin→Caddy | hermes → caddy@admin (10.10.99.5):443 | permitir | abierto | ✅ OK |
| A02 | Admin→Admin | hermes → colector (10.10.99.30):9100 | permitir | abierto | ✅ OK |
| A03 | Admin→Ollama | hermes → ollama (10.10.20.10):11434 | bloquear | sin-respuesta | ✅ OK |
| A04 | Admin→Trabajo | hermes → proyecto1 (10.10.10.11):8080 | bloquear | sin-respuesta | ✅ OK |
| A05 | Admin→IoT | hermes → iot-sensor (10.10.30.10):1883 | bloquear | sin-respuesta | ✅ OK |
| A06 | Admin→Internet | hermes → 1.1.1.1 (1.1.1.1):443 | permitir | abierto | ✅ OK |
| A07 | Admin→Internet | hermes → 1.1.1.1 (1.1.1.1):80 | bloquear | sin-respuesta | ✅ OK |
| G01 | Invitados→Invitados | invitado → iot-sensor (10.10.30.10):1883 | permitir | abierto | ✅ OK |
| G02 | Invitados→Invitados | iot-sensor → invitado (10.10.30.11):8080 | permitir | abierto | ✅ OK |
| G03 | Invitados→Trabajo | invitado → proyecto1 (10.10.10.11):8080 | bloquear | sin-respuesta | ✅ OK |
| G04 | IoT→Trabajo | iot-sensor → proyecto1 (10.10.10.11):8080 | bloquear | sin-respuesta | ✅ OK |
| G05 | Invitados→Caddy | invitado → caddy@trabajo (10.10.10.5):443 | bloquear | sin-respuesta | ✅ OK |
| G06 | Invitados→Ollama | invitado → ollama (10.10.20.10):11434 | bloquear | sin-respuesta | ✅ OK |
| G07 | Invitados→Admin | invitado → colector (10.10.99.30):9100 | bloquear | sin-respuesta | ✅ OK |
| G08 | Invitados→Internet | invitado → 1.1.1.1 (1.1.1.1):443 | permitir | abierto | ✅ OK |
| E02 | Internet→Ollama | cliente-remoto → ollama (10.10.20.10):11434 | bloquear | sin-respuesta | ✅ OK |
| E03 | Internet→Trabajo | cliente-remoto → proyecto1 (10.10.10.11):8080 | bloquear | sin-respuesta | ✅ OK |
| E04 | Internet→Admin | cliente-remoto → colector (10.10.99.30):9100 | bloquear | sin-respuesta | ✅ OK |
| E05 | Internet→Invitados | cliente-remoto → iot-sensor (10.10.30.10):1883 | bloquear | sin-respuesta | ✅ OK |
| E06 | Internet→Internet | cliente-remoto → 1.1.1.1 (1.1.1.1):443 | bloquear | sin-ruta | ✅ OK |
| E07 | Internet→Host | cliente-remoto → 203.0.113.1 (203.0.113.1):443 | bloquear | sin-respuesta | ✅ OK |
| V01 | VPN→Caddy | cliente-remoto → 10.10.10.5 (10.10.10.5):443 | permitir | abierto | ✅ OK |
| V02 | VPN→Caddy (IA) | cliente-remoto → caddy@ia (10.10.20.5):443 | bloquear | sin-respuesta | ✅ OK |

- Admin resuelve y abre https://github.com (esperado `200`): obtenido `200` · ✅ OK
- Trabajo → https://ia.lab.internal/api/tags con la CA interna (esperado `200`): obtenido `200` · ✅ OK
- Trabajo → https://10.10.10.5/api/tags (por IP) con la CA interna (esperado `200`): obtenido `200` · ✅ OK
- Admin → https://ia.lab.internal/api/tags con la CA interna (esperado `200`): obtenido `200` · ✅ OK
- VPN emulada → https://10.10.10.5/api/tags (por IP, por el túnel) con la CA interna (esperado `200`): obtenido `200` · ✅ OK
- Trabajo → https://ia.lab.internal sin la CA interna (el certificado no es público) (esperado `fallo`): obtenido `fallo` · ✅ OK
- Invitados → https://ia.lab.internal (no resuelve: sin pata de Caddy) (esperado `fallo`): obtenido `fallo` · ✅ OK

**Bloqueos observados:** 25 · descartados por el filtrado del kernel: 21 · sin ruta desde el origen (segmentos `internal`): 4

**Casos:** 44 · **Fallas:** 0
