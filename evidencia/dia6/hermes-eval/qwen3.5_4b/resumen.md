# Evaluación de Hermes · modelo qwen3.5:4b · modo herramientas · 2026-10-25 20:17:17 -0600

Tarea: leer `/snapshots/actual/` con las herramientas de archivos de Hermes y decidir si la cadena `forward`
permite algo que la matriz de flujos deniega. 3 corridas por escenario; los escenarios 2-4 son copias
sintéticas con un desvío inyectado (no se cambió el firewall real). Acierto = veredicto correcto y, si hay
desvío, la línea `REGLA:` cita la regla problemática.

| Escenario | Esperado | Aciertos | Veredictos obtenidos | Tiempo medio |
|---|---|---|---|---|
| sin_desvio | SIN_DESVIO | **3/3** | SIN_DESVIO SIN_DESVIO SIN_DESVIO | 151 s |
| invitados_a_trabajo | DESVIO | **1/3** | DESVIO SIN_DESVIO DESVIO | 95 s |
| policy_accept | DESVIO | **1/3** | DESVIO DESVIO SIN_DESVIO | 63 s |
| admin_sin_puerto | DESVIO | **0/3** | DESVIO sin-veredicto SIN_DESVIO | 66 s |

**Total: 5/12 aciertos.**
