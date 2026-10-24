# 03 · Laboratorio emulado (Día 2)

Implementación de las dos topologías de `02-diseno.md` en la Dell G15 (WSL2 + Ubuntu 24.04 +
Docker Engine) y de la prueba que las compara. Los servicios son **nodos de prueba**
(`lab/imagen`): abren los puertos del diseño y responden con su nombre. El Día 3 los
reemplaza por Caddy, Ollama y Hermes sin cambiar IP ni puertos.

## 1. Entorno

| Elemento | Valor | Evidencia |
|---|---|---|
| Sistema | Ubuntu 24.04.5 · kernel 6.18.54 (WSL2) · systemd activo | `evidencia/dia2/entorno.txt` |
| Motor | Docker Engine 29.9.2 (no Docker Desktop) · Compose v5.6.1 · backend de firewall `iptables` (nf_tables) | `entorno.txt` |
| GPU | RTX 3060 Laptop 6 GB visible dentro del contenedor con `--gpus all`; solo driver de Windows (610.88) + `nvidia-container-toolkit` 1.20.1 | `entorno.txt` |
| WireGuard | Módulo `wireguard` presente en el kernel (el Día 4 no necesita `wireguard-go`) | `entorno.txt` |
| Reenvío | `net.ipv4.ip_forward = 1` persistente (`/etc/sysctl.d/99-laboratorio.conf`); `bridge-nf-call-iptables = 1` | `entorno.txt` |

Aprovisionamiento reproducible: `scripts/wsl/01-docker-engine.sh`, `02-nvidia-toolkit.sh` y
`03-evidencia-entorno.sh` (el Día 5 los convierte en roles de Ansible).

## 2. Contenido de `lab/`

| Archivo | Función |
|---|---|
| `imagen/` | `lab-nodo:1`: Alpine con `curl`, `nc`, `iperf3`, `tcpdump`, `dig` y un escucha por puerto (`ESCUCHA=443,...`) |
| `compose.plana.yml` | Topología "antes": un bridge `br-plana` 10.10.0.0/24, sin reglas |
| `compose.segmentada.yml` | Topología "después": `br-trabajo` (10), `br-ia` (20, `internal`), `br-invitados` (30), `br-admin` (99), `br-inet` (Internet emulado, `internal`) con IP fija por servicio |
| `nftables/netseg.nft` | Tabla `inet netseg`: `forward` con política *drop* y `input` de los segmentos hacia el host |
| `matriz/casos.txt` | 34 casos TCP (una celda de la matriz de §5 cada uno), con lo esperado en cada topología |

Los bridges tienen **nombre fijo** (`br-trabajo`, …) para que las reglas no dependan de
identificadores que cambian al recrear la red. En la topología plana IoT e invitado usan
10.10.0.40 y .41 porque .10 y .11 ya son de Ollama y `proyecto1`.

## 3. Operación

```bash
# como root (carga reglas nftables); desde Windows:  wsl -d Ubuntu-24.04 -u root --cd ~/red-netdevops-llm -- ...
scripts/lab.sh segmentada        # carga netseg y levanta la topología segmentada
scripts/matriz.sh segmentada     # matriz de alcanzabilidad -> evidencia/dia2/matriz-segmentada.md
scripts/contadores.sh            # contadores de las tres capas de filtrado
scripts/netseg-sola.sh           # prueba netseg sin las reglas DROP de Docker (restaura al terminar)
scripts/lab.sh plana             # topología plana
scripts/lab.sh apagar            # baja todo y descarga netseg
```

Usar siempre `docker compose` (plugin v2). En Ubuntu, `docker-compose` con guion resuelve al
binario de Windows heredado por el `PATH`.

## 4. Resultados

La matriz ejecuta los mismos casos en las dos topologías y compara lo observado con lo
esperado (`permitir` = el puerto abre; `bloquear` = no abre). Cada destino tiene un caso
`permitir` que prueba que el puerto sí escucha, de modo que un bloqueo nunca es un puerto cerrado.

| Ejecución | Casos | Fallas | Archivo |
|---|---|---|---|
| Plana ("antes") | 29 | 0 — todo abierto, incluido IoT → Ollama e invitados → PCs de trabajo (hallazgo 1) | `matriz-plana.md` |
| Segmentada solo con reglas de Docker (estado *rojo*) | 35 | **2**: `I02` (Ollama inicia conexión hacia Caddy) y `A07` (Admin sale por TCP 80) | `matriz-segmentada-sin-netseg.md` |
| Segmentada con `netseg` | 35 | 0 | `matriz-segmentada.md` |
| Segmentada solo con `netseg` (reglas DROP de Docker retiradas) | 35 | 0 | `matriz-segmentada-netseg-sola.md` |

Los 35 casos de la segmentada son los 34 de `casos.txt` más la comprobación de que Admin
resuelve nombres y abre `https://github.com` aun con salida limitada a TCP 443 (HTTP 200: el
DNS de Docker consulta desde el host al resolvedor de WSL, 10.255.255.254, que es una
dirección local del propio host, así que no pasa por `forward`). La plana tiene 29 porque no
existen el Internet emulado ni sus 6 casos.

### Tres capas de filtrado (`evidencia/dia2/contadores-segmentada.txt`)

El kernel evalúa, en este orden, tres conjuntos de reglas; un `drop` en cualquiera es definitivo:

| Orden | Capa | Qué descarta en este laboratorio |
|---|---|---|
| 1 | Docker · `ip raw PREROUTING` (prioridad −300) | Lo dirigido a la IP de un contenedor que no entró por el bridge de ese contenedor: cubre Trabajo, Invitados y Admin como **destino** |
| 2 | **`netseg`** · `forward` (prioridad −10) | La política del proyecto. Única que cubre los destinos del segmento de IA, la salida de Admin y "Ollama nunca inicia" |
| 3 | Docker · `filter` (prioridad 0) | Aislamiento entre bridges y redes `internal`: respaldo |

Hallazgo: tras la matriz, `netseg` contó 12 paquetes en su *drop* por defecto y las reglas
DROP de la capa 3 quedaron en cero, pero los flujos hacia Trabajo, Invitados y Admin los
detuvo antes la capa 1 (sus contadores suman 48). Por eso la afirmación defendible no es
"netseg detiene todo", sino que **la política de `netseg` es completa por sí sola**: con las
reglas DROP de Docker retiradas en caliente, la matriz sigue pasando 35/35. Eso es lo que
permite llevarla a un router sin Docker (`02-diseno.md` §9). `log-descartes.txt` muestra
los descartes registrados por el kernel, p. ej. `IN=br-ia OUT=br-ia SRC=10.10.20.10 DST=10.10.20.5`
(Ollama intentando iniciar una conexión).

## 5. Observaciones de operación

- **WSL apaga la distro sin sesiones abiertas.** Al cerrarse el último `wsl.exe`, la VM se
  detiene tras unos segundos y los contenedores (`restart: "no"`) no regresan. Para las
  pruebas se mantuvo una sesión en segundo plano (`wsl -d Ubuntu-24.04 -- sleep infinity`).
  Para el Día 4, cuando el servidor VPN deba estar disponible, hay que decidir cómo se
  mantiene viva la VM (`vmIdleTimeout=-1` en `.wslconfig`, o una tarea que mantenga la sesión).
- **Las reglas deben existir antes que los contenedores.** `lab.sh segmentada` carga `netseg`
  primero. Tras un reinicio real, el Día 5 lo resuelve con un servicio `nftables` de systemd.
- **Internet emulado.** `br-inet` y `br-ia` conservan la IP .1 del host (se necesita en
  `br-inet`: es la "IP pública" del servidor para WireGuard), pero los contenedores no
  tienen ruta por defecto: `cliente-remoto` no sale a internet.
- **Caddy con tres patas** (Trabajo, IA, Admin) no enruta entre ellas (el reenvío IP de un
  contenedor está apagado) y su ruta por defecto sale por Trabajo (`gw_priority`).

## 6. Pendiente para otros días

| Qué | Cuándo |
|---|---|
| Filas VPN emulada y VPN real de la matriz (`wg0`, `wg1`) y UDP 51820 al host | Día 4 |
| Servicios reales (Caddy con TLS, Ollama con GPU, Hermes) en lugar de los nodos de prueba | Día 3 |
| Latencia ICMP intra e inter-segmento y `iperf3`: el costo de enrutar y filtrar se mide aquí contra la plana | Día 6 |
| `netseg` como servicio de systemd y Ansible | Día 5 |
