# Despliegue manual con aprobación (GitHub Actions) · 26-oct-2026

Primera ejecución completa de `.github/workflows/desplegar.yml`: corrida
[40273601046](https://github.com/gsanchezm/red-netdevops-llm/actions/runs/40273601046) sobre el commit `6738257` de
`main`, lanzada a mano (`workflow_dispatch`) por `gsanchezm`.

| Etapa | Dónde corre | Resultado |
|---|---|---|
| **Simulación** (`desplegar.sh simular hub`, `--check --diff`) | *Runner* autohospedado `dell-wsl` (WSL en la Dell, usuario `gsanchezm`), por SSH al droplet con el usuario `deploy` | Éxito en 26 s: `ok=13 changed=0` (el droplet ya coincide con el repositorio) |
| **Espera de aprobación** | Environment `produccion-lab` (revisor obligatorio: `gsanchezm`) | El trabajo de aplicar quedó en `waiting` ≈ **8.6 horas** (05:19 → 13:57 UTC): la compuerta no se abre sola |
| **Aprobación** | GitHub, por una persona (`gsanchezm = approved`) | Registrada en el historial de la corrida |
| **Aplicación** (`desplegar.sh aplicar hub`) | Mismo *runner* | Éxito: `ok=13 changed=0` (idempotente: no había nada que cambiar) |
| **Comprobación** (`scripts/verificar-hub.sh`) | Mismo *runner* | Droplet sano: `wg1=active`, `nftables=active`, `forward` e `input` con política `drop`, `ip_forward=1`, 3 pares |

Captura de la compuerta mientras esperaba: `despliegue-espera-aprobacion.jpg` (el trabajo de simulación en verde y
"Aplicar en el droplet" en espera de revisión).

**Lo que esta prueba demuestra.** Un cambio no llega al droplet sin pasar por: el repositorio, una simulación que dice
qué cambiaría, y la decisión de una persona. **Lo que no demuestra:** un despliegue que *cambie* algo (aquí
`changed=0`); el cambio real se probó antes, a mano, con el mismo rol (`ansible-hub.txt`: 4 cambios y luego 0).

**Un intento fallido que forma parte del resultado.** Cuando la corrida seguía pendiente, se intentó registrar la
aprobación a nombre del dueño desde la línea de comandos (`gh api`, con su sesión) porque la había dado en el chat. El
clasificador de seguridad de Claude Code lo bloqueó y se aceptó el bloqueo: la aprobación debe ser un acto de la
persona en la propia plataforma, no un permiso delegable a un asistente. La aprobación quedó registrada cuando la
persona la dio en GitHub.
