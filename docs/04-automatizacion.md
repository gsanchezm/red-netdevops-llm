# 04 · Automatización: Ansible y CI (Día 5)

La política de red vive en Git y los cambios llegan a los equipos por un canal único, repetible y revisable.
Aquí se codifica con Ansible lo que en el Día 4 se hizo a mano, y se valida con una CI en GitHub Actions
(D7 y D8 de `02-diseno.md`).

> **Estado.** El rol `lab` (la Dell) está **aplicado y probado**: 5 cambios la primera vez, 0 la segunda
> (`evidencia/dia5/ansible-lab.txt`). El rol `hub` (el droplet) está **escrito y pasa los linters, pero no se ha
> ejecutado contra el droplet**: falta crear el usuario `deploy` (§6). El runner y el Environment de GitHub
> tampoco están registrados todavía (§5).

## 1. Estructura

```
ansible/
  ansible.cfg, site.yml          Un solo playbook con dos plays: hub y lab
  inventory/hosts.yml            lab-dell (conexión local) y redes-lab-hub (10.10.51.1, usuario deploy, por la VPN)
  inventory/group_vars/          Variables sin datos propios
  vars.example.yml               Modelo del archivo de pares (el real vive FUERA del repositorio)
  roles/hub/                     Droplet: WireGuard wg1, nftables, hostname, ip_forward
  roles/lab/                     Dell: política netseg como servicio de systemd antes que Docker
droplet/hub.nft                  Reglas del droplet (fuente de verdad; el rol hub la instala)
lab/nftables/netseg.nft          Reglas del laboratorio (fuente de verdad; el rol lab la instala)
.github/workflows/lint.yml       CI en una máquina de GitHub
.github/workflows/desplegar.yml  Despliegue manual con aprobación, en el runner de la Dell
scripts/desplegar.sh             lint · simular (--check --diff) · aplicar
scripts/escanear-secretos.sh     IP reales y llaves en lo versionado
```

Decisiones de diseño (mías, para revisar): solo `ansible-core` con módulos incluidos (sin colecciones externas,
que habría que instalar y mantener); **un único origen de verdad** para el firewall (los roles copian los
archivos `.nft` del repositorio y los validan con `nft -c` antes de instalarlos); y dos roles en lugar de uno por
servicio, porque el alcance es de una actividad de clase.

## 2. Uso

```bash
scripts/desplegar.sh lint            # yamllint + ansible-lint + sintaxis (lo mismo que la CI)
scripts/desplegar.sh simular lab     # --check --diff: muestra qué cambiaría; no cambia nada
scripts/desplegar.sh aplicar lab     # aplica (como root: el rol lab escribe en /etc y systemd)
scripts/desplegar.sh simular hub     # igual para el droplet (requiere el usuario deploy, §6)
```

## 3. Secretos en un repositorio público

- Las llaves **privadas** de WireGuard nunca salen del host donde nacen: el rol `hub` las genera con
  `umask 077` solo si no existen, las lee con `slurp` para armar `wg1.conf` y todas esas tareas llevan `no_log`
  (con `--diff` Ansible imprimiría el archivo; `no_log` lo impide).
- Las llaves **públicas** de los pares y los datos propios van en un archivo **fuera del repositorio**
  (`/etc/redes-lab/vars.yml` o `~/.config/redes-lab/vars.yml`; modelo en `ansible/vars.example.yml`). El rol `hub`
  se niega a correr si faltan o si una clave no es base64 de 32 bytes.
- `scripts/escanear-secretos.sh` busca las IP públicas reales y llaves en lo versionado, y la CI lo ejecuta.
  **Primero se autoprueba** (`--probar`: debe detectar una IP y una llave de mentira) porque en su primera
  versión dio "limpio" sin haber revisado nada: como root, `git` rechazó el repositorio de otro usuario
  ("dubious ownership"), no listó archivos y el escáner concluyó que no había nada. Ahora, si no puede listar
  archivos, falla con código 2 en vez de pasar en verde.

## 4. Los roles

**`lab`** (Dell, WSL2): paquetes, reenvío IP, y la política `netseg` instalada en `/etc/redes-lab/netseg.nft`
con una unidad de systemd (`netseg.service`, `Before=docker.service`). Resuelve el pendiente del Día 2: tras un
reinicio real, las reglas existen antes que los contenedores. Termina comprobando que la tabla cargada tiene
política `drop`. Con `lab_levantar: true` además ejecuta `scripts/lab.sh segmentada` (lo usa el despliegue de CI).

**`hub`** (droplet): paquetes, nombre del sistema (`redes-lab-hub`; hoy el droplet se llama `lat-nyc3`),
reenvío IP, llave y configuración de `wg1`, y `droplet/hub.nft` validado antes de instalarlo. Dos decisiones
sobre la propia conexión de Ansible, que viaja por `wg1` y por el firewall que está cambiando:

- **No se reinicia `wg1`** al cambiar los pares: se usa `wg syncconf`, porque reiniciar cortaría la sesión SSH de
  Ansible. Limitación conocida: si un cambio *añade rutas* (un `AllowedIPs` nuevo hacia otra red), hay que
  reiniciar `wg-quick@wg1` a mano.
- **nftables se carga de forma atómica** (el archivo borra y recrea la tabla en una sola transacción) y la
  regla que permite el SSH está en el mismo archivo, así que no hay una ventana sin acceso.

**Límite de `--check`.** La simulación no puede consultar un servicio cuya unidad aún no existe (la primera vez
que se instala `netseg.service`); esa tarea se omite en modo simulación y está comentada en el rol.

## 5. CI con GitHub Actions

`lint.yml` corre en una máquina de GitHub con cada *push* a `main` y cada *pull request*: yamllint, ansible-lint
(perfil `moderate`), sintaxis de los playbooks, shellcheck (severidad `warning`), `nft -c` de los dos archivos
de reglas, `docker compose config` de las dos topologías y el escáner de secretos. No necesita acceso al
laboratorio ni al droplet. La acción `actions/checkout` está **fijada por SHA de commit** (no por etiqueta
móvil) y el permiso del token es solo lectura.

`desplegar.yml` es **manual** (`workflow_dispatch`) y solo desde `main`. Corre en un *runner* autohospedado en la
Dell (D8): solo abre conexiones salientes hacia GitHub y llega al droplet por la VPN. Tiene dos trabajos: primero
**simula** (`--check --diff`) y, solo si alguien con permiso aprueba el Environment `produccion-lab`, **aplica** y
vuelve a correr la matriz de alcanzabilidad.

**Pendiente (requiere decisiones del dueño del repositorio):** crear el Environment `produccion-lab` con revisor
obligatorio, registrar el runner (descarga el programa del *runner* de GitHub y lo deja corriendo como servicio) y,
si se quiere, proteger la rama `main` (D7).

## 6. Acceso de despliegue al droplet (pendiente)

Ansible y la CI llegan al droplet desde la Dell por SSH a `10.10.51.1` con una **llave de despliegue exclusiva,
sin frase** (`~/.ssh/id_ed25519_redes_deploy`, ya generada en Ubuntu), para poder revocarla sin tocar la llave
personal. Falta lo que concede acceso privilegiado y por eso lo ejecuta una persona:

1. En el droplet: `droplet/bootstrap-deploy.sh` crea el usuario `deploy`, autoriza esa llave **solo desde la Dell**
   (`from="10.10.51.2"`, sin reenvíos) y le da `sudo` sin contraseña.
2. En `droplet/hub.nft`: el SSH por la VPN pasa de aceptar solo la PC de administración (`10.10.51.4`) a aceptar
   también la Dell (`10.10.51.2`). El cambio ya está escrito en el repositorio y se aplica con un reversor
   automático, como en el Día 4.
3. Verificar la huella del host del droplet desde WSL contra la que se obtiene por el túnel de administración,
   antes de agregarla a `known_hosts`.

## 7. Resultados y hallazgos

| Qué | Resultado |
|---|---|
| `yamllint`, `ansible-lint`, sintaxis, `shellcheck`, `nft -c` en un espacio de red limpio, `compose config`, escáner | Pasan en local con los mismos comandos que la CI |
| Rol `lab` aplicado | 5 cambios la primera vez; **0 la segunda** (idempotente) |
| `netseg.service` | Activo, habilitado y ordenado antes de `docker.service` |

Hallazgos de esta etapa: (1) el escáner de secretos daba un **falso verde** (§3); (2) un YAML inválido en un
`meta/main.yml` (`: ` dentro de un texto sin comillas) que rompía a Ansible y a `ansible-lint` a la vez; (3) cuatro
avisos reales de `shellcheck` en scripts de días anteriores (una variable sin usar, un arreglo asignado a una
cadena y una sustitución sin comillas), ya corregidos; (4) `yamllint` con su configuración por defecto rechazaba
el estilo `{ clave: valor }` que usan los compose; se configuró en `.yamllint`.
