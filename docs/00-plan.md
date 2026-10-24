# 00 · Plan de trabajo (7 días, ≈ 18 h)

Aprobado el 23-oct-2026. Cada día deja un entregable verificable en el repositorio.

| Día | Horas | Entregable | Estado |
|---|---|---|---|
| 1 | 2.5 | Repo Git · documento de la red real con inventario y línea base · diseño objetivo (segmentos, direccionamiento, matriz de flujos, diagramas) | ✅ |
| 2 | 2.5 | Ubuntu 24.04 en WSL2 con Docker Engine y GPU · compose de las topologías plana y segmentada · nftables · script de matriz de alcanzabilidad | ⬜ |
| 3 | 3 | Ollama con modelo pequeño (100 % GPU con contexto 64 K) · Hermes en Admin · Caddy con TLS interno · segmento IA sin salida · latencia de la API | ⬜ |
| 4 | 2 | WireGuard: servidor en el host + cliente remoto emulado · reglas VPN → Caddy :443 · evidencia | ⬜ |
| 5 | 3 | Ansible en roles · GitHub Actions (lint + despliegue en runner local con aprobación manual) | ⬜ |
| 6 | 2.5 | Hermes lee snapshots y propone un PR (nunca aplica) · mediciones finales plana vs segmentada | ⬜ |
| 7 | 3 | Documento de la materia (10–15 páginas, APA 7) | ⬜ |

**Si hay retraso, se recorta en este orden:** QoS opcional → iperf3 físico opcional →
`ansible-lint` estricto.

**Fuera de alcance (trabajo futuro):** alta disponibilidad, múltiples servidores,
Kubernetes, Containerlab / 802.1Q emulado, monitoreo avanzado, SSO.

## Preparación antes del Día 2 (tarea del usuario)

1. Liberar espacio en C: (se requieren ≈ 12–15 GB; hoy hay 34 GB libres).
2. Instalar Ubuntu 24.04 en WSL (pide crear usuario y contraseña, por eso es manual):

   ```powershell
   wsl --install -d Ubuntu-24.04
   ```

3. Dejar Docker Desktop **cerrado**: el laboratorio usa Docker Engine dentro de Ubuntu.
4. **No** instalar un driver NVIDIA de Linux dentro de WSL: CUDA en WSL usa el driver de
   Windows (610.88). En Ubuntu solo se instala `nvidia-container-toolkit`.
5. Comprobar en Ubuntu que el kernel trae WireGuard (`sudo modprobe wireguard && lsmod | grep wireguard`);
   si no, el Día 4 usa `wireguard-go`.

## Dónde vive el repositorio

- Copia de Windows: esta carpeta (dentro de OneDrive). OneDrive puede bloquear o corromper
  archivos de `.git` al sincronizar: conviene pausar la sincronización mientras se trabaja
  o mover el repo fuera de OneDrive.
- Desde el Día 2 la copia de trabajo y ejecución es un clon dentro de Ubuntu
  (`~/red-netdevops-llm`), sincronizado con esta vía GitHub.
