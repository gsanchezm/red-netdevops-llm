# Evaluación de Hermes · modelo qwen3.5:4b · modo contexto · 2026-10-25 19:56:35 -0600

Tarea: con el contenido ya dentro del prompt (sin herramientas), decidir si la cadena `forward`
permite algo que la matriz de flujos deniega. 3 corridas por escenario; los escenarios 2-4 son copias
sintéticas con un desvío inyectado (no se cambió el firewall real). Acierto = veredicto correcto y, si hay
desvío, la línea `REGLA:` cita la regla problemática.

| Escenario | Esperado | Aciertos | Veredictos obtenidos | Tiempo medio |
|---|---|---|---|---|
| sin_desvio | SIN_DESVIO | **3/3** | SIN_DESVIO SIN_DESVIO SIN_DESVIO | 112 s |
| invitados_a_trabajo | DESVIO | **2/3** | DESVIO DESVIO SIN_DESVIO | 95 s |
| policy_accept | DESVIO | **1/3** | SIN_DESVIO DESVIO SIN_DESVIO | 112 s |
| admin_sin_puerto | DESVIO | **0/3** | SIN_DESVIO DESVIO SIN_DESVIO | 91 s |

**Total: 6/12 aciertos.**
