# Evidencia del Día 5 · Ansible y CI

Índice para el reporte; la explicación está en `docs/04-automatizacion.md`.

| Archivo | Qué demuestra | Para el reporte |
|---|---|---|
| `ansible-lab.txt` | Rol `lab` en la Dell: 5 cambios la primera vez y **0 la segunda**; `netseg.service` activo y ordenado antes que Docker | Idempotencia y resolución del pendiente del Día 2 |
| `ansible-hub.txt` | Rol `hub` contra el droplet real: simulación (3 cambios), aplicación (4) y segunda aplicación (**0**); claves recortadas | Configuración como código del concentrador VPN |
| `despliegue-github-actions.md` | Primera ejecución completa de `desplegar.yml`: simulación, 8.6 h de espera, aprobación humana, aplicación y comprobación de salud | Control de cambios con aprobación manual (D7, D8) |
| `despliegue-espera-aprobacion.jpg` | La compuerta del Environment `produccion-lab` con la simulación en verde y "Aplicar" en espera de revisión | **Figura**: el control humano antes de tocar producción |

La CI de cada commit está en la pestaña *Actions* del repositorio (workflow `lint`); sus dos corridas rojas y por qué se
explican en `docs/04-automatizacion.md` §7.
