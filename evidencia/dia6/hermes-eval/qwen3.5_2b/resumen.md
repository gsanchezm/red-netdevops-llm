# Evaluación de Hermes · modelo qwen3.5:2b · 2026-10-25 19:39:26 -0600

Tarea: leer `/snapshots/actual/` con las herramientas de archivos de Hermes y decidir si la cadena `forward`
permite algo que la matriz de flujos deniega. 3 corridas por escenario; los escenarios 2-4 son copias
sintéticas con un desvío inyectado (no se cambió el firewall real). Acierto = veredicto correcto y, si hay
desvío, la línea `REGLA:` cita la regla problemática.

| Escenario | Esperado | Aciertos | Veredictos obtenidos | Tiempo medio |
|---|---|---|---|---|
| sin_desvio | SIN_DESVIO | **1/3** | DESVIO SIN_DESVIO sin-veredicto | 38 s |
| invitados_a_trabajo | DESVIO | **1/3** | sin-veredicto DESVIO SIN_DESVIO | 27 s |
| policy_accept | DESVIO | **0/3** | sin-veredicto DESVIO sin-veredicto | 27 s |
| admin_sin_puerto | DESVIO | **0/3** | sin-veredicto sin-veredicto sin-veredicto | 38 s |

**Total: 2/12 aciertos.**
