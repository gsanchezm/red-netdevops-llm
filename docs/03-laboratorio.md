# 03 · Laboratorio emulado (Días 2 y 3)

Implementación de las dos topologías de `02-diseno.md` en la Dell G15 (WSL2 + Ubuntu 24.04 +
Docker Engine) y de la prueba que las compara. En el Día 2 todos los servicios eran **nodos de
prueba** (`lab/imagen`): abren los puertos del diseño y responden con su nombre. En el Día 3
**Ollama y Caddy ya son reales** (sección 7) y ocupan la misma IP y puerto que sus nodos; los
proyectos, el colector y los clientes siguen siendo nodos de prueba.

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
| `matriz/casos.txt` | 35 casos TCP (una celda de la matriz de §5 cada uno), con lo esperado en cada topología |
| `caddy/Caddyfile` | Caddy como puerta de la IA: TLS con CA interna, registro JSON y *streaming* sin búfer (Día 3) |
| `ca/` | Aquí se copia en ejecución el certificado raíz (público) de la CA interna; nada de esta carpeta se versiona |

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
scripts/modelo.sh                # valida D9: contexto de 64 K, 100 % GPU, aguja en 57 K tokens
scripts/latencia-api.sh          # latencia de la API por cada ruta de la topología levantada
```

El modelo se descarga **una sola vez, en la topología plana** (la única con salida a internet):
`docker exec ollama ollama pull qwen3.5:2b`. Vive en el volumen `ollama-data`, que la
segmentada monta sin necesitar red. Los volúmenes `ollama-data` y `caddy-data` son externos:
nunca usar `docker compose down -v`.

Usar siempre `docker compose` (plugin v2). En Ubuntu, `docker-compose` con guion resuelve al
binario de Windows heredado por el `PATH`. La matriz necesita internet real: prueba la salida
contra `1.1.1.1` y `https://github.com`.

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

Hallazgo: de los **23 bloqueos** de la matriz segmentada (una sola ejecución, contadores en cero):

- **9 no llegan a ningún filtro**: `ollama` y `cliente-remoto` viven en redes `internal` sin ruta
  por defecto, así que el paquete no sale del contenedor (`Network unreachable`; casos I03–I05
  y E01–E06). Es el efecto buscado de D4. En un router real esos paquetes sí llegarían a
  `forward`, donde la política *drop* los cubriría; aquí no se puede probar.
- **8 los descarta la capa 1** (destino en Trabajo, Invitados o Admin): 16 paquetes = 8 flujos × 2 SYN.
- **6 los descarta `netseg`** (12 paquetes): Trabajo, Invitados y Admin → IA, Ollama → Caddy
  y Admin → TCP 80. Las reglas DROP de la capa 3 quedan en cero.

Por eso la afirmación defendible no es "netseg detiene todo", sino que **la política de `netseg`
es completa por sí sola para los 14 flujos que llegan al filtrado**: con las reglas DROP de Docker
retiradas en caliente (`scripts/netseg-sola.sh`, que además recrea el laboratorio y comprueba que
vuelven las 11 + 3 + 4 reglas), la matriz sigue pasando 35/35. Eso es lo que permite llevar la
política a un router sin Docker (`02-diseno.md` §9). `log-descartes.txt` muestra los descartes
registrados por el kernel, p. ej. `IN=br-ia OUT=br-ia SRC=10.10.20.10 DST=10.10.20.5` (Ollama
intentando iniciar una conexión).

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
  contenedor está apagado). Su ruta por defecto sale por Trabajo (`gw_priority`), pero una
  regla de `netseg` le bloquea la salida a internet (D5: usa su CA interna, no necesita
  nada de afuera; caso `C01` de la matriz).

## 6. Pendiente para otros días

| Qué | Cuándo |
|---|---|
| Filas VPN emulada y VPN real de la matriz (`wg0`, `wg1`) y UDP 51820 al host | Día 4 |
| Latencia ICMP intra e inter-segmento y `iperf3`: el costo de enrutar y filtrar se mide aquí contra la plana | Día 6 |
| `netseg` como servicio de systemd y Ansible | Día 5 |

## 7. Servicios reales: Ollama y Caddy (Día 3)

### 7.1 Ollama y el modelo (D9 revisado)

Ollama 0.40.10 corre con GPU y las mismas variables en las dos topologías
(`OLLAMA_CONTEXT_LENGTH=65536`, `OLLAMA_FLASH_ATTENTION=1`, un solo modelo cargado). En la
segmentada vive solo en la VLAN 20, sin ruta a internet, y monta el volumen donde se descargó
el modelo. La imagen está fijada por digest.

La elección original de D9, `qwen2.5:3b`, **no cumple**: Ollama recorta el contexto al de
entrenamiento del modelo (32 K) por cualquier vía, aunque se pidan 64 K
(`WARN requested context size too large for model`). Se midieron los candidatos a 64 K
(`evidencia/dia3/candidatos-modelo.txt`):

| Modelo | Entrenado con | Tamaño a 64 K | Procesador | Resultado |
|---|---|---|---|---|
| `qwen2.5:3b` | 32 K | — | — | ✗ recorta a 32 K |
| `granite4.1:3b`, caché f16 | 128 K | 7.8 GB | 45 % CPU / 55 % GPU | ✗ |
| `granite4.1:3b`, caché `q8_0` | 128 K | 5.3 GB | 22 % CPU / 78 % GPU | ✗ |
| `granite4.1:3b`, caché `q4_0` | 128 K | 3.8 GB | 100 % GPU | ✓ con caché de 4 bits (alternativa) |
| `qwen3.5:4b` | — | — | — | no se pudo descargar (`Error: EOF`) |
| **`qwen3.5:2b`**, caché f16 | **256 K** | **3.2 GB** | **100 % GPU** | **✓ elegido** |

`qwen3.5:2b` gana por su arquitectura: solo 6 de sus 24 capas usan atención, así que la caché
KV a 64 K son **768 MiB** (el cálculo original para qwen2.5 daba ≈ 2.4 GB). Con un prompt de
57 647 tokens que lleva una frase al inicio, el modelo la recupera (`AZUL-7`) y `ollama ps`
sigue mostrando `100% GPU` con contexto 65536 (`evidencia/dia3/modelo-64k.txt`).

### 7.2 Caddy y la CA interna

Caddy es la única puerta hacia Ollama: termina TLS con su **CA interna** (sin ACME ni salida a
internet) y reenvía a `10.10.20.10:11434` sin búfer, para que los tokens salgan al instante.
Responde por `ia.lab.internal` (alias de Docker en Trabajo y Admin) y por las IP 10.10.10.5 y
10.10.99.5; el certificado ya incluye 10.10.50.1 y 10.10.51.2 para las VPN del Día 4.

La llave privada de la CA vive solo en el volumen `caddy-data`. `lab.sh` copia a `lab/ca/` solo
el certificado raíz, que los clientes montan en `/ca` de solo lectura. La matriz comprueba que
con esa CA la API responde HTTP 200 por nombre y por IP, que **sin** ella la conexión falla, y
que Invitados ni siquiera resuelve el nombre.

### 7.3 Latencia de la API (`evidencia/dia3/latencia-*.md`)

Misma petición en cada ruta (streaming, 48 tokens, modelo ya cargado), mediana de 10 en ms:

| Ruta | TCP | TLS | 1.er token | Total | Tokens/s |
|---|---|---|---|---|---|
| Plana: Trabajo → Ollama directo, sin TLS | 0.3 | — | 32 | 474 | 94 |
| Segmentada: Caddy → Ollama (salto interno) | 0.4 | — | 37 | 480 | 95 |
| Segmentada: Trabajo → Caddy (TLS) → Ollama | 1.1 | 4.0 | 37 | 484 | 94 |
| Segmentada: Trabajo → Caddy por IP | 0.2 | 3.5 | 34 | 483 | 94 |
| Segmentada: Admin → Caddy (TLS) → Ollama | 1.3 | 3.8 | 38 | 494 | 94 |
| Referencia nube: Trabajo → `api.anthropic.com` (solo conexión) | 45.6 | 46.6 | 133 | 134 | — |

Segmentar y poner TLS **no cuesta latencia apreciable**: el primer token tarda 2–6 ms más que
sin Caddy y el apretón de manos TLS añade ≈ 4 ms, frente a los ≈ 45 ms de TCP y ≈ 133 ms hasta
el primer byte con la API en la nube. La GPU genera ≈ 94 tokens/s. El arranque en frío (modelo
fuera de la GPU) tardó 3 s con el archivo en caché de disco y hasta 10–40 s la primera vez tras
crear el contenedor.

### 7.4 Memoria: el límite de commit de Windows

Durante el Día 3 la VM de WSL se cayó una vez (volcado de *kernel panic* en
`%TEMP%\wsl-crashes`) y Windows mostró "Sin memoria virtual". La causa no es la RAM libre sino el
**límite de commit** (RAM + archivo de paginación = 63.7 GB), del que el uso normal de la máquina
ya consume ≈ 53 GB. `vmmemWSL` llegó a 11.2 GB: los 7.8 GB de RAM de la VM, que se llenan de
caché de disco al descargar modelos, más ≈ 3.4 GB que Windows reserva como respaldo de lo cargado
en la GPU. Medido: **cargar el modelo cuesta ≈ 3.7 GB de commit**, y el caché de prompts de
llama.cpp (hasta 8 GB por defecto) lo agravaba con contextos largos. Mitigaciones aplicadas:

- `LLAMA_ARG_CACHE_RAM=1024` acota ese caché (Ollama lo pasa al runner; el log confirma `size limit: 1024 MiB`).
- `OLLAMA_KEEP_ALIVE=5m`: el modelo no queda residente.
- Liberar la caché de la VM tras descargas pesadas (`echo 3 > /proc/sys/vm/drop_caches`).

Pendiente de decisión del usuario: un `.wslconfig` con `memory=5GB` y
`autoMemoryReclaim=gradual` acotaría la VM de forma permanente (no se tocó).
