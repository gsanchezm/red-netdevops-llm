# Matriz de alcanzabilidad · topología plana

Generada 2026-10-24 00:47:45 -0600 con `scripts/matriz.sh plana` (política: docs/02-diseno.md §5).

| Caso | Celda de §5 | Origen → destino:puerto | Esperado | Observado | Resultado |
|---|---|---|---|---|---|
| T01 | Trabajo→Trabajo | proyecto1 → proyecto2 (10.10.0.12):8080 | permitir | abierto | ✅ OK |
| T02 | Trabajo→Caddy | proyecto1 → caddy@trabajo (10.10.0.5):443 | permitir | abierto | ✅ OK |
| T03 | Trabajo→Caddy (IA) | proyecto1 → caddy@ia (10.10.0.5):443 | permitir | abierto | ✅ OK |
| T04 | Trabajo→Ollama | proyecto1 → ollama (10.10.0.10):11434 | permitir | abierto | ✅ OK |
| T05 | Trabajo→Admin | proyecto1 → colector (10.10.0.30):9100 | permitir | abierto | ✅ OK |
| T06 | Trabajo→IoT | proyecto1 → iot-sensor (10.10.0.40):1883 | permitir | abierto | ✅ OK |
| T07 | Trabajo→Internet | proyecto1 → 1.1.1.1 (1.1.1.1):443 | permitir | abierto | ✅ OK |
| T08 | Trabajo→Internet | proyecto1 → 1.1.1.1 (1.1.1.1):80 | permitir | abierto | ✅ OK |
| I01 | Caddy→Ollama | caddy → ollama (10.10.0.10):11434 | permitir | abierto | ✅ OK |
| I02 | IA→Caddy | ollama → caddy@ia (10.10.0.5):443 | permitir | abierto | ✅ OK |
| I03 | IA→Trabajo | ollama → proyecto1 (10.10.0.11):8080 | permitir | abierto | ✅ OK |
| I04 | IA→Admin | ollama → colector (10.10.0.30):9100 | permitir | abierto | ✅ OK |
| I05 | IA→Internet | ollama → 1.1.1.1 (1.1.1.1):443 | permitir | abierto | ✅ OK |
| A01 | Admin→Caddy | hermes → caddy@admin (10.10.0.5):443 | permitir | abierto | ✅ OK |
| A02 | Admin→Admin | hermes → colector (10.10.0.30):9100 | permitir | abierto | ✅ OK |
| A03 | Admin→Ollama | hermes → ollama (10.10.0.10):11434 | permitir | abierto | ✅ OK |
| A04 | Admin→Trabajo | hermes → proyecto1 (10.10.0.11):8080 | permitir | abierto | ✅ OK |
| A05 | Admin→IoT | hermes → iot-sensor (10.10.0.40):1883 | permitir | abierto | ✅ OK |
| A06 | Admin→Internet | hermes → 1.1.1.1 (1.1.1.1):443 | permitir | abierto | ✅ OK |
| A07 | Admin→Internet | hermes → 1.1.1.1 (1.1.1.1):80 | permitir | abierto | ✅ OK |
| G01 | Invitados→Invitados | invitado → iot-sensor (10.10.0.40):1883 | permitir | abierto | ✅ OK |
| G02 | Invitados→Invitados | iot-sensor → invitado (10.10.0.41):8080 | permitir | abierto | ✅ OK |
| G03 | Invitados→Trabajo | invitado → proyecto1 (10.10.0.11):8080 | permitir | abierto | ✅ OK |
| G04 | IoT→Trabajo | iot-sensor → proyecto1 (10.10.0.11):8080 | permitir | abierto | ✅ OK |
| G05 | Invitados→Caddy | invitado → caddy@trabajo (10.10.0.5):443 | permitir | abierto | ✅ OK |
| G06 | Invitados→Ollama | invitado → ollama (10.10.0.10):11434 | permitir | abierto | ✅ OK |
| G07 | Invitados→Admin | invitado → colector (10.10.0.30):9100 | permitir | abierto | ✅ OK |
| G08 | Invitados→Internet | invitado → 1.1.1.1 (1.1.1.1):443 | permitir | abierto | ✅ OK |

Comprobación adicional · Admin resuelve y abre `https://github.com` (esperado HTTP 200): obtenido `200` · ✅ OK

**Bloqueos observados:** 0 · descartados por el filtrado del kernel: 0 · sin ruta desde el origen (segmentos `internal`): 0

**Casos:** 29 · **Fallas:** 0
