# 03 · Laboratorio emulado (Días 2 a 4)

Implementación de las dos topologías de `02-diseno.md` en la Dell G15 (WSL2 + Ubuntu 24.04 +
Docker Engine) y de la prueba que las compara. En el Día 2 todos los servicios eran **nodos de
prueba** (`lab/imagen`): abren los puertos del diseño y responden con su nombre. En el Día 3
**Ollama, Caddy y Hermes ya son reales** (sección 7) y ocupan la misma IP y puerto que sus
nodos (Hermes solo en la topología segmentada, porque la red actual no lo tiene); los
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
| `matriz/casos.txt` | 37 casos TCP (una celda de la matriz de §5 cada uno; 35 al cierre del Día 2), con lo esperado en cada topología |
| `caddy/Caddyfile` | Caddy como puerta de la IA: TLS con CA interna, registro JSON y *streaming* sin búfer (Día 3) |
| `ca/` | Aquí se copia en ejecución el certificado raíz (público) de la CA interna y un paquete con las CA públicas; nada de esta carpeta se versiona |
| `hermes/config.yaml` | Configuración de Hermes (modelo, endpoint, contexto), montada de solo lectura (Día 3) |
| `wireguard/` | Aquí `scripts/wg0.sh` genera las llaves y las configuraciones de `wg0` (servidor y cliente); nada de esta carpeta se versiona (Día 4) |

Los bridges tienen **nombre fijo** (`br-trabajo`, …) para que las reglas no dependan de
identificadores que cambian al recrear la red. En la topología plana IoT e invitado usan
10.10.0.40 y .41 porque .10 y .11 ya son de Ollama y `proyecto1`.

## 3. Operación

```bash
# como root (carga reglas nftables); desde Windows:  wsl -d Ubuntu-24.04 -u root --cd ~/red-netdevops-llm -- ...
scripts/lab.sh segmentada        # carga netseg, levanta wg0 (scripts/wg0.sh) y la topología segmentada
scripts/matriz.sh segmentada     # matriz de alcanzabilidad -> evidencia/dia2/matriz-segmentada.md
scripts/wg0.sh estado            # wg show del host y de cliente-remoto (servidor | cliente | abajo | estado)
scripts/wg0-evidencia.sh         # evidencia de la VPN emulada -> evidencia/dia4/wg0-emulada.txt
scripts/contadores.sh            # contadores de las tres capas de filtrado
scripts/netseg-sola.sh           # prueba netseg sin las reglas DROP de Docker (restaura al terminar)
scripts/lab.sh plana             # topología plana
scripts/lab.sh apagar            # baja todo y descarga netseg
scripts/modelo.sh                # valida D9: contexto de 64 K, 100 % GPU, aguja en 57 K tokens
scripts/latencia-api.sh          # latencia de la API por cada ruta de la topología levantada
scripts/hermes-prueba.sh         # Hermes: sin puertos de entrada, config de solo lectura, una pregunta por TLS
docker exec hermes hermes chat -q "..." -Q     # usar Hermes (no hay pasarela de chat)
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
| Segmentada con VPN emulada (Día 4: `V01`–`V02`, `E07` y la comprobación HTTPS por el túnel) | 44 | 0 | `evidencia/dia4/matriz-segmentada.md` (§8) |

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
| ~~Filas VPN emulada de la matriz (`wg0`) y UDP 51820 al host~~ | Hecho en el Día 4 (§8); falta la VPN real (`wg1`) |
| Latencia ICMP intra e inter-segmento y `iperf3`: el costo de enrutar y filtrar se mide aquí contra la plana | Día 6 |
| `netseg` como servicio de systemd y Ansible | Día 5 |
| ~~Verificar que el certificado de Caddy cubre `10.10.50.1` y `10.10.51.2` (`openssl s_client`)~~ | Verificado en el Día 4: **no lo cubre** tras el DNAT; las VPN usan `10.10.10.5` (D12, §8.2) |
| Calidad de Hermes con un modelo de 2 B para llamar herramientas; reintentar `qwen3.5:4b` | Día 6 |

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
10.10.99.5; las VPN del Día 4 llegan por 10.10.10.5 (D12, §8.2): Caddy emite un certificado por cada nombre de `SITIOS`.

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

### 7.4 Hermes Agent en Admin

Hermes v0.22.5 (imagen oficial fijada por digest) vive solo en la VLAN 99 (`10.10.99.20`). Se
opera por `docker exec hermes hermes chat -q "..." -Q`. La imagen arranca por defecto su
pasarela (`gateway-default`) y un panel, pero sin ninguna plataforma de chat configurada y
escuchando solo en loopback; no se activa el panel web ni se publica ningún puerto.
Lo que `scripts/hermes-prueba.sh` comprueba (`evidencia/dia3/hermes.txt`):

- **Llega a la IA solo por Caddy con TLS**: `https://ia.lab.internal/v1`, aceptando la CA interna
  con `SSL_CERT_FILE` (un paquete con las CA públicas más la interna, para que el Día 6 pueda
  llegar también a GitHub). El registro de Caddy muestra la petición:
  `remote_ip=10.10.99.20 server_name=ia.lab.internal uri=/v1/chat/completions status=200`.
  Hermes no puede alcanzar Ollama directo (casos `A03` de la matriz).
- **Sin puertos de entrada desde la red**: solo escucha en loopback (su API local en
  `127.0.0.1:8642`); desde otro equipo de la VLAN 99 ese puerto no abre.
- **Sin acceso al host**: no monta `docker.sock` ni carpetas del host; sus únicos montajes son
  la CA (solo lectura), su configuración (solo lectura) y un volumen para sesiones y memoria.
- **No puede cambiar su propia configuración**: `config.yaml` sale del repositorio y se monta
  de solo lectura (`Read-only file system` al intentar escribirlo). Es la aplicación práctica
  de D7: los cambios pasan por el repositorio y el pipeline, no por el agente.

Una pregunta simple tarda ≈ 16 s la primera vez (carga del modelo y el prompt de sistema de
Hermes, que incluye los esquemas de sus herramientas) con 100 % GPU y contexto 65536. La
calidad de un modelo de 2 B para llamar herramientas no se evalúa aquí: es trabajo del Día 6.

### 7.5 Memoria: el límite de commit de Windows

Durante el Día 3 la VM de WSL se cayó una vez (volcado de *kernel panic* en
`%TEMP%\wsl-crashes`) y Windows mostró "Sin memoria virtual". La causa no es la RAM libre sino el
**límite de commit** (RAM + archivo de paginación = 63.7 GB), del que el uso normal de la máquina
ya consume ≈ 53 GB. `vmmemWSL` llegó a 11.2 GB: los 7.8 GB de RAM de la VM, que se llenan de
caché de disco al descargar modelos, más unos 3.4 GB que, según la hipótesis más probable, Windows
reserva como respaldo de lo cargado en la GPU (no se midió por separado). Medido: **cargar el
modelo cuesta ≈ 3.7 GB de commit**, y el caché de prompts de
llama.cpp (hasta 8 GB por defecto) lo agravaba con contextos largos. Mitigaciones aplicadas:

- `LLAMA_ARG_CACHE_RAM=1024` acota ese caché (Ollama lo pasa al runner; el log confirma `size limit: 1024 MiB`).
- `OLLAMA_KEEP_ALIVE=5m`: el modelo no queda residente.
- Liberar la caché de la VM tras descargas pesadas (`echo 3 > /proc/sys/vm/drop_caches`).

Además, el 24-oct se creó `%USERPROFILE%\.wslconfig` (fuera del repositorio; afecta a todas las
distros de WSL) para acotar la VM de forma permanente:

```ini
[wsl2]
memory=5GB

[experimental]
autoMemoryReclaim=gradual
```

Con ese tope se repitió la prueba más exigente (laboratorio completo, modelo cargado y una
pregunta de Hermes): **0 eventos OOM** en la VM, memoria disponible mínima de 2.5 GB de 4.9 GB, y
el margen mínimo de commit de Windows fue de **3.2 GB** (sin el tope había llegado a 1.2 GB). Para
deshacerlo basta borrar el archivo y ejecutar `wsl --shutdown`. No se fijó `vmIdleTimeout`: sin
sesiones abiertas WSL sigue apagando la VM, lo cual conviene mientras el laboratorio no se usa.

## 8. VPN emulada y VPN real: `wg0` y `wg1` (Día 4)

`scripts/lab.sh segmentada` levanta ahora la VPN completa: carga `netseg`, crea `wg0` en el host
(`scripts/wg0.sh servidor`), levanta la topología y, al final, el cliente (`wg0.sh cliente`).

### 8.1 Cómo está armada

| Pieza | Valor |
|---|---|
| Servidor | `wg0` en el host, `10.10.50.1/24`, UDP 51820. El kernel de WSL (6.18) trae WireGuard integrado: `ip link add … type wireguard` funciona aunque `lsmod` no lo liste, y solo hizo falta `apt install wireguard-tools` |
| Cliente | Contenedor `cliente-remoto` (`203.0.113.10`, red `internal` sin ruta por defecto) con `NET_ADMIN`, `wg0` `10.10.50.2/24`, `Endpoint = 203.0.113.1:51820`, `PersistentKeepalive = 25` |
| Qué enruta el cliente | `AllowedIPs = 10.10.0.0/16`: **todo el laboratorio** por el túnel, a propósito. Lo que puede alcanzar lo decide `netseg` en el host, no una configuración que el cliente pueda cambiar; así los casos `E02`–`E05` prueban la política de verdad (antes del Día 4 no tenían ruta y ningún filtro los veía) |
| Llaves | Las genera `wg0.sh` una vez en `lab/wireguard/wg0.conf` y `wg0-cliente.conf` (0600, ignorados por git: el repositorio es público) |
| Política | `wg0` entra en `$LAB` de `netseg` (si no, su `input` aceptaría todo lo que llega desde `wg0`) y una sola regla de `forward`: `wg0 → br-trabajo`, destino `10.10.10.5`, TCP 443 |

### 8.2 Tres hallazgos de la construcción

**1. Con DNAT el certificado no coincide (D12).** El primer diseño publicaba Caddy en `10.10.50.1:443`
(Docker traduce a `10.10.10.5`). El túnel, el DNAT y el filtrado funcionaron, pero
`curl --cacert … https://10.10.50.1` falló con `no alternative certificate subject name matches target
ipv4 address '10.10.50.1'`. `openssl s_client` mostró por qué: sin SNI (un cliente no lo envía para una IP)
Caddy elige el certificado por la IP local de la conexión, que tras el DNAT es `10.10.10.5`, y presentó
`SAN: IP:10.10.10.5`. Con SNI `ia.lab.internal` el certificado sí era el correcto, pero el celular no
resuelve `.internal`. Solución: sin NAT, la VPN anuncia la ruta `10.10.10.5/32` y el cliente se conecta a
la IP real. Aplica igual a `wg1` (celular).

**2. Docker pide la excepción en tres capas, no en una.** Acceder a la IP de un contenedor desde
una interfaz que no es su bridge cruza las tres capas de §4, y cada una necesita su propia regla:

| Capa | Qué la descartaba | Excepción |
|---|---|---|
| Docker `raw/PREROUTING` | Todo lo que llega a la IP de un contenedor por otra interfaz | `com.docker.network.bridge.trusted_host_interfaces: wg0` en la red `trabajo` (Docker la aplica a **todos** los contenedores de Trabajo; las dos capas siguientes lo acotan a Caddy :443) |
| `netseg` `forward` | Política *drop* | La regla `wg0 → 10.10.10.5:443` |
| Docker `filter`, cadena `DOCKER` | `DROP !br-trabajo → br-trabajo` (descartó exactamente los 18 SYN que `netseg` había aceptado) | Una regla en `DOCKER-USER` (la cadena que Docker evalúa antes que las suyas), puesta y quitada por `wg0.sh` |

La tercera se encontró por el contador de la regla `DROP` de Docker (18 paquetes = los 18 SYN). Se
probó antes `gateway_mode_ipv4=routed` con el puerto 443 publicado, que abre las dos capas de Docker sin
reglas manuales, pero **quita el NAT de salida** de la red: los casos `T07` y `T08` (Trabajo → internet)
fallaron y se descartó. Con `routed` Docker además abría un proxy en `[::]:443` del host (IPv6), por fuera de `netseg`.

**3. La construcción de la imagen choca con `netseg`.** `lab-nodo` ahora trae `wireguard-tools` y
`openssl`; reconstruirla con `netseg` cargada falló (`apk` sin red) porque el *build* sale por `docker0`,
que la política bloquea. `lab.sh` construye antes de cargar la política (`construir`).

También se comprobó que el cliente, en una red `internal`, sí alcanza al host: hay apretón de manos
(`br-inet → input udp 51820`, regla del Día 2); la red `internal` solo bloquea el reenvío hacia afuera.

### 8.3 Resultados (`evidencia/dia4/`)

| Prueba | Resultado |
|---|---|
| Matriz segmentada (`matriz-segmentada.md`) | **44 casos, 0 fallas** (los 41 del Día 3, donde `E01` pasó a `V01`, más `E07`, `V02` y la comprobación HTTPS por el túnel). Hay 25 bloqueos: 21 los descarta el filtrado y 4 no tienen ruta |
| `V01` VPN → Caddy `10.10.10.5:443` | permitido; HTTPS 200 con la CA interna y el certificado correcto (`SAN IP:10.10.10.5`) |
| `E02`–`E05`, `V02` | por `wg0` no llegan a Ollama, Trabajo, Admin, IoT ni a la pata de IA de Caddy: *sin-respuesta*, descartados por `forward` (el contador de la regla de denegación sube) |
| `E07` Internet → host `:443` | *sin-respuesta*: del host solo responde UDP 51820 |
| Latencia por el túnel (50 pings) | 0.56 ms de media (máx. 1.26) frente a 0.09 ms sin túnel por el mismo bridge: ≈ 0.5 ms de cifrado y filtrado; 0 % de pérdida |
| HTTPS por el túnel (5 solicitudes) | TCP 0.5–0.7 ms, TLS ≈ 4.7 ms, total 7.5–9.1 ms |
| `wg0` | MTU 1420, handshake renovado cada 25 s por el *keepalive* |

Limitaciones: `iperf3` por el túnel se deja para las mediciones finales del Día 6, con la plana
(y `netseg-sola.sh` cuenta ahora más casos que en el texto del Día 2: se vuelve a medir entonces).
Para que el servidor esté disponible mientras se prueba hay que mantener viva la VM
(`wsl -d Ubuntu-24.04 -- sleep infinity`).

### 8.4 Qué cambia al sumar `wg1` (VPN real, droplet y celular)

`wg1` repite el patrón de `wg0` hacia Caddy; lo que cambia es el rumbo de las rutas:

| Dónde | Qué hay que agregar |
|---|---|
| Dell, `netseg` | `"wg1"` en `$LAB`; regla `forward` `wg1 → br-trabajo`, destino `10.10.10.5`, TCP 443 |
| Dell, Docker | `trusted_host_interfaces: wg0:wg1` (el separador es **dos puntos**: comprobado, con coma Docker crea una sola interfaz llamada `wg0,wg1`); la regla de `DOCKER-USER` para `wg1` en `wg0.sh` |
| Droplet, par de la Dell | `AllowedIPs = 10.10.51.2/32, 10.10.10.5/32` (si no, el droplet no sabe reenviar hacia Caddy ni acepta sus respuestas) |
| Celular | `AllowedIPs` con `10.10.51.0/24` y `10.10.10.5/32`; destino `https://10.10.10.5`; instalar el certificado raíz de la CA interna |
| Dell, par del droplet | `AllowedIPs = 10.10.51.0/24` (las respuestas de Caddy al `10.10.51.3` vuelven por `wg1`) |

### 8.5 VPN real: resultados (25-oct-2026, `evidencia/dia4/wg1-real.txt`)

Implementación: `scripts/wg1.sh` (Dell) y `droplet/hub.nft` + `wg-quick@wg1` (droplet, Ubuntu 24.04.5,
512 MB). Las llaves viven solo en `lab/wireguard/wg1.conf` (Dell) y `/etc/wireguard/` (droplet), con IP
y claves ocultas en la evidencia. La guía del celular es `guia-celular-wireguard.md`.

| Prueba | Resultado |
|---|---|
| Dell ↔ droplet por `wg1` | Handshake inmediato; 50 pings, 0 % de pérdida, **69.6–70.2 ms** de media (mín. 67.9, máx. 77.5): coincide con los 69.9 ms medidos al elegir la región |
| Conexión saliente | El droplet ve a la Dell llegar desde la IP pública de la casa: atraviesa el doble NAT con un *keepalive* de 25 s, sin reenviar puertos ni tocar el router |
| iPhone por **5G** → `https://10.10.10.5/api/tags` | HTTP 200 con la lista de modelos (`celular-api-tags.png`), sin avisos de certificado; TLS 1.3; Caddy lo atendió en 3.6 ms |
| Origen visto por Caddy | `10.10.51.3`, la IP del celular en el túnel: sin NAT (D12), por lo que el registro identifica al cliente real |
| Filtrado | Droplet: 36 paquetes aceptados celular → Caddy y 0 descartes; Dell: la regla `wg1` de `netseg` y la de `DOCKER-USER` cuentan los mismos flujos. El contador "denegación por defecto" de la Dell incluye los bloqueos de la matriz, no solo `wg1` |
| Matriz con `wg0` y `wg1` cargados | 44 casos, 0 fallas (`V01` ahora usa la IP literal `10.10.10.5`) |

Dos aclaraciones sobre la evidencia: (1) de las dos solicitudes `GET /api/tags` registradas, una es una
**prueba mía desde el droplet** (`curl -k` con `10.10.51.3` agregada un momento a `wg1`; el registro la
distingue por su *User-Agent*) y la otra es la del iPhone, con su `favicon.ico`; (2) el celular no tiene
una fila en la matriz de §4 porque no es un contenedor: su prueba es la captura y el registro de Caddy.

**Lo que falló en la primera prueba.** Con el túnel arriba y el handshake correcto, Safari dijo "no pudo
conectarse al servidor". Los contadores mostraron que los 21 SYN cruzaron el droplet, `netseg` y
`DOCKER-USER`, pero la Dell respondía `ICMP host 10.10.10.5 unreachable`: en la tabla ARP de la Dell,
`10.10.10.5` estaba en `FAILED`. **Caddy tenía `10.10.10.2`** en Trabajo (`IPAMConfig=null`: Docker no aplicó
la IP estática en esa red; en `ia` y `admin` sí). Ocurrió una vez, en la primera corrida tras arrancar la VM, y
no se repitió al recrear el laboratorio; **se desconoce la causa**. Como la matriz resuelve las IP con
`docker inspect`, habría pasado en verde probando la IP equivocada. Por eso `lab.sh` ahora comprueba
(`verificar_caddy`) que Caddy esté en `10.10.10.5` y se detiene si no, y `V01` prueba esa IP literal.

Otra lección: en el droplet, `wg syncconf` **no** crea las rutas de `AllowedIPs` (`10.10.10.5/32`); hay que
reiniciar `wg-quick@wg1`. Y en iOS el campo *Punto final* acepta `IP:puerto`, no `IP/puerto`.

**Pendiente del Día 4:** dejar el SSH del droplet solo por `wg1` y quitar la regla SSH del Cloud Firewall
(requiere un cliente WireGuard en la PC de administración). `iperf3` por los túneles va en el Día 6.
