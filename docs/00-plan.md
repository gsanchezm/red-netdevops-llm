# 00 · Plan de trabajo (7 días, ≈ 20 h)

Aprobado el 23-oct-2026; el mismo día se agregó un droplet de DigitalOcean como
concentrador WireGuard real (Días 4 y 5). Cada día deja un entregable verificable en el repositorio.

| Día | Horas | Entregable | Estado |
|---|---|---|---|
| 1 | 2.5 | Repo Git · documento de la red real con inventario y línea base · diseño objetivo (segmentos, direccionamiento, matriz de flujos, diagramas) | ✅ |
| 2 | 2.5 | Ubuntu 24.04 en WSL2 con Docker Engine y GPU · compose de las topologías plana y segmentada · nftables · script de matriz de alcanzabilidad (ver `03-laboratorio.md`) | ✅ |
| 3 | 3 | Ollama con modelo pequeño (100 % GPU con contexto 64 K) · Hermes en Admin · Caddy con TLS interno · segmento IA sin salida · latencia de la API (ver `03-laboratorio.md` §7; el modelo cambió de `qwen2.5:3b` a `qwen3.5:2b`, D9) | ✅ |
| 4 | 3 | WireGuard: servidor en el host + cliente remoto emulado · droplet dedicado como concentrador (región elegida por ping) con el celular real · reglas VPN → Caddy :443 · evidencia | ✅ `wg0` emulado y `wg1` real (celular por 5G → Caddy) funcionando; SSH del droplet solo por `wg1` y Cloud Firewall solo con UDP 51820 (`03-laboratorio.md` §8; `iperf3` por los túneles pasa al Día 6) |
| 5 | 3.5 | Ansible en roles con dos hosts (lab y droplet) · GitHub Actions (lint + despliegue con aprobación manual) | 🟡 Rol `lab` aplicado e idempotente, CI `lint.yml` y `desplegar.yml` escritos (`04-automatizacion.md`); falta el acceso de despliegue al droplet, el runner y el Environment |
| 6 | 2.5 | Hermes lee snapshots y propone un PR (nunca aplica) · mediciones finales plana vs segmentada | ✅ Mediciones de red, latencia de la API por la VPN, `qwen3.5:4b` y Hermes (snapshot, evaluación y propuesta de PR) hechos (`05-mediciones-y-hermes.md`); falta solo `iperf3` por `wg1` hasta el droplet, que depende del acceso de despliegue |
| 7 | 3 | Documento de la materia (10–15 páginas, APA 7) | ⬜ |

**Si hay retraso, se recorta en este orden:** QoS opcional → iperf3 físico opcional →
`ansible-lint` estricto. Si el droplet no está listo en el Día 4, la VPN emulada queda
sola y la parte real pasa al Día 6.

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

## Preparación antes del Día 4 (tarea del usuario)

> **Guía paso a paso, con la creación del droplet, la prueba de regiones, el Cloud Firewall y
> cómo destruirlo: [`guia-droplet-digitalocean.md`](guia-droplet-digitalocean.md).**
> Lo de abajo es el resumen de lo que hay que hacer **antes** del Día 4.

1. Crear una llave SSH **exclusiva del laboratorio**, con frase de contraseña (no reutilizar
   `id_ed25519`, que ya se usa para otros servicios):

   ```powershell
   ssh-keygen -t ed25519 -a 100 -C "redes-lab-admin" -f "$env:USERPROFILE\.ssh\id_ed25519_redes_lab"
   ```

2. Registrar la parte **pública** en DigitalOcean (Settings → Security → SSH Keys → Add SSH Key;
   la llave se sube al equipo y se aplica a los droplets **al crearlos**):

   ```powershell
   Get-Content "$env:USERPROFILE\.ssh\id_ed25519_redes_lab.pub"
   ```

3. No crear el droplet todavía: se crea en el Día 4 junto con la prueba de regiones.

En el Día 5 se genera otra llave, sin frase y solo para el despliegue automático, dentro de
Ubuntu, con un usuario `deploy` en el droplet. Así se puede revocar sin tocar la llave personal.

## Dónde vive el repositorio

- Copia de Windows: `C:\Users\gilsa\Documents\Repos\red-netdevops-llm`, fuera de OneDrive
  (la sincronización bloqueaba archivos de `.git`). El documento de la materia sí se queda
  en OneDrive.
- Desde el Día 2 la copia de trabajo y ejecución es un clon dentro de Ubuntu
  (`~/red-netdevops-llm`), sincronizado con esta vía GitHub.

## Preparación realizada (24-oct-2026)

- Memoria de WSL acotada (`~/.wslconfig`: `memory=5GB`, `autoMemoryReclaim=gradual`) tras
  una caída por agotamiento del límite de commit de Windows; ver `03-laboratorio.md` §7.5.
  Validado con el laboratorio completo, el modelo y Hermes: sin OOM y con un margen mínimo de
  commit de 3.2 GB (antes llegó a 1.2 GB).

- Docker Desktop limpio: imágenes, contenedores y caché de compilación borrados; se
  conservaron 9 volúmenes de bases de datos de otros proyectos (194 MB). Disco virtual
  compactado de 89.4 GB a 4.3 GB (`fstrim` + `diskpart compact`). Libre en C: 125 GB.
