# 05 · Mediciones finales y Hermes (Día 6)

Cuatro cosas: el costo de segmentar y de cifrar (§1), la API de la IA por la VPN (§2), el modelo `qwen3.5:4b`
(§3) y Hermes como revisor de políticas que observa y propone, sin aplicar (§4). Evidencia en `evidencia/dia6/`.

## 1. Mediciones de red (`scripts/medir-red.sh`)

Misma batería en las dos topologías: 50 pings (0.2 s) y `iperf3` TCP de 10 s × 3 repeticiones. Los contenedores
comparten el kernel de la Dell, así que las cifras sirven para **comparar** el costo de filtrar y de cifrar, no
como la capacidad de un cable de 1 Gb/s.

| Medición | Plana ("antes") | Segmentada ("después") | Lectura |
|---|---|---|---|
| ICMP, mismo segmento (media) | 0.119 ms | 0.162 ms | La diferencia (0.04 ms) es del orden del jitter (0.14 vs 0.46 ms) |
| ICMP, hacia el host (gateway) | 0.135 ms | 0.089 ms | Sin diferencia apreciable |
| TCP, mismo segmento | 29.94 ± 0.10 Gbit/s | 29.29 ± 0.20 Gbit/s | **−2.2 %** por la política `netseg` y `br_netfilter` |
| TCP sin túnel (`cliente-remoto` → host, `br-inet`) | n/a | 31.01 ± 0.22 Gbit/s | Referencia del mismo origen y destino |
| TCP con `wg0` (cifrado) | n/a | **0.68 ± 0.01 Gbit/s** | **−97.8 %** frente a la referencia |
| ICMP sin túnel / con `wg0` | n/a | 0.117 ms / 0.564 ms | **+0.45 ms** por cifrar y encapsular |
| ICMP Dell → droplet por `wg1` (internet real) | n/a | 69.9 ms (69.2–75.8) | Dominado por la distancia a Nueva York |
| TCP Dell → droplet por `wg1` (internet real), subida | n/a | **124.5 ± 13.2 Mbit/s** | Lo limita la subida del internet de la casa, no el cifrado |
| TCP droplet → Dell por `wg1`, bajada | n/a | **241.3 ± 8.0 Mbit/s** | Idem para la bajada |

**Lectura.** Segmentar con `nftables` casi no cuesta: en el mismo segmento el rendimiento baja 2 % y la latencia
queda dentro del ruido. Lo que sí cuesta es **cifrar**: `wg0` rinde 0.68 Gbit/s frente a 31 sin túnel. Dos matices
para no exagerar esa cifra:

- En la medición **el cliente y el servidor corren en la misma CPU**, así que se suma el cifrado y el descifrado
  de ambos extremos al mismo núcleo; con extremos en máquinas distintas el rendimiento por flujo sería mayor.
- Aun así 0.68 Gbit/s **supera lo que da el acceso de esta casa**, y la medición real lo confirma: por `wg1`,
  hasta el droplet, se miden **124.5 Mbit/s de subida y 241.3 Mbit/s de bajada** (`scripts/medir-wg1.sh`,
  `evidencia/dia6/wg1-iperf3.md`), entre 2.8 y 5.5 veces menos que los 0.68 Gbit/s que el cifrado sostuvo en la
  medición anterior: el límite es la subida del internet de la casa y los ~70 ms de ida y vuelta, no WireGuard. La asimetría (la subida es la mitad de la bajada) es
  la típica de un acceso doméstico.

Las dos pruebas abren un puerto solo mientras dura la medición: `medir-red.sh` usa una regla `TEMP-iperf3` en el host
y `medir-wg1.sh` otra de runtime en el droplet (solo para `10.10.51.2`), instala `iperf3` allí y al terminar borra la
regla y desinstala el paquete (se verifica que no queda ninguna ni el paquete: `dpkg-query` con el estado real, porque
`dpkg -s` da un falso positivo con paquetes removidos).

## 2. Latencia de la API por la VPN (`scripts/latencia-api.sh`, `evidencia/dia6/latencia-segmentada.md`)

Mismo modelo (`qwen3.5:2b`), misma petición (48 tokens en streaming), 10 por ruta, modelo ya cargado. Mediana (peor caso):

| Ruta | 1.er token | Total | Tokens/s |
|---|---|---|---|
| Trabajo → Caddy (TLS) → Ollama, por IP | 34 ms (48) | 473 ms | 96 |
| Admin → Caddy (TLS) → Ollama | 35 ms (52) | 479 ms | 95 |
| **VPN emulada: `cliente-remoto` → `wg0` → Caddy → Ollama** | **36 ms (49)** | **485 ms** | 94 |
| Referencia nube (`api.anthropic.com`, solo conexión) | 133 ms | 133 ms | n/a |

El túnel cifrado añade ≈ 10 ms (≈ 2 %) al total: **domina la generación del modelo, no la red**. La VPN emulada
corre en la propia Dell. En el acceso real (iPhone por `wg1`) se suman los ~70 ms de ida y vuelta hasta el
droplet en cada intercambio (TCP, TLS y la petición); eso **no se midió desde el celular**, solo se sabe por
el registro de Caddy que el servidor atiende la petición en milisegundos (`evidencia/dia4/wg1-real.txt`).
Arranque en frío (modelo fuera de la GPU): 10 s, de los cuales 9.8 s son la carga del modelo.

## 3. Reintento de `qwen3.5:4b` (`evidencia/dia6/modelo-4b-64k*.txt`)

En el Día 3 la descarga falló tres veces con `Error: EOF`; esta vez se descargó al primer intento (3.3 GB, 90 MB/s).
Con el contexto de 64 K del diseño y la misma prueba de la aguja (57 647 tokens de entrada):

| Caché KV | Aguja recuperada | Reparto CPU/GPU | VRAM usada | Prefill de 57 K tokens |
|---|---|---|---|---|
| f16 (configuración actual) | Sí (`AZUL-7`) | 34 % / **66 %** | 5.1 GB | 92 s |
| `q8_0` | Sí | 23 % / **77 %** | 5.0 GB | 80 s |

**Funciona, pero no cabe entera en 6 GB de VRAM** a 64 K: la caché KV (2 GB en f16, 1 GB en `q8_0`) y las capas que
no entran van a la CPU, y el criterio de D9 (100 % GPU) no se cumple. El modelo del laboratorio sigue siendo el de
2 B. Queda como candidato si se dispone de más VRAM o se acepta un modelo más lento.

## 4. Hermes: observa y propone, nunca aplica (D7)

### 4.1 Flujo

1. `scripts/snapshot.sh` escribe un *snapshot* de solo lectura (`lab/snapshots/`, no versionado): la cadena
   `forward` de `nftables` cargada, la matriz de flujos permitidos (`lab/hermes/matriz-de-flujos.md`), los
   contenedores y `wg show` sin llaves.
2. Esa carpeta se monta en Hermes como `/snapshots:ro`. Hermes la lee con sus herramientas y **devuelve una
   propuesta por texto**. Verificado: escribir ahí da `Read-only file system`; Hermes no tiene `docker.sock`, ni el
   repositorio, ni un token de GitHub. (Su conjunto de herramientas `file` incluye escribir, y el modelo llegó a
   intentar crear un archivo con reglas inventadas: el montaje de solo lectura y el aislamiento del contenedor
   son lo que lo hace inofensivo, no la buena conducta del modelo.)
3. `scripts/proponer-pr.sh <propuesta>` (lo ejecuta **una persona**) escanea el texto en busca de IP reales y
   llaves y abre un PR que solo agrega un documento a `docs/propuestas/`. Probado en seco: una propuesta con una IP
   real se rechaza antes de tocar `git`; la simulación no crea ramas. La CI lo revisa y una persona decide.

No se adoptó darle a Hermes un token de GitHub para que abra el PR él mismo: pondría un secreto dentro de un
contenedor con un agente de LLM.

### 4.2 Evaluación de la calidad (`scripts/hermes-evaluar.sh`, `evidencia/dia6/hermes-eval/`)

La tarea: decidir si la cadena `forward` permite algo que la matriz de flujos deniega. Cuatro escenarios sobre
copias sintéticas del snapshot (el firewall real no se tocó): **sin desvío**; **`Invitados → Trabajo` abierto**;
**`policy accept`** en lugar de `drop`; y un desvío **sutil**: la regla de Admin hacia internet sin `tcp dport 443`
(el comentario sigue diciendo "solo TCP 443"). Tres corridas por escenario y dos modos: *herramientas* (Hermes lee
los archivos con las suyas) y *contexto* (el contenido va en el prompt, sin herramientas), para separar "usar
herramientas" de "razonar". **Acierto estricto** = veredicto correcto y, si hay desvío, citar la regla.

| Modelo y modo | Aciertos estrictos | Solo veredicto correcto | Sin desvío (sin falsas alarmas) | Desvío sutil (Admin) |
|---|---|---|---|---|
| `qwen3.5:2b`, herramientas | 2 / 12 | 3 / 12 | 1 / 3 | 0 / 3 |
| `qwen3.5:2b`, contexto | 1 / 12 | 4 / 12 | 0 / 3 | 0 / 3 |
| `qwen3.5:4b`, herramientas | 5 / 12 | 8 / 12 | **3 / 3** | 0 / 3 |
| `qwen3.5:4b`, contexto | **6 / 12** | 7 / 12 | **3 / 3** | 0 / 3 |

Lectura (n = 12 por fila: indica la tendencia, no es una medida precisa):

- El modelo de **2 B no es fiable** para esta tarea: 1–2 de 12, muchas respuestas sin el veredicto en el formato
  pedido y falsas alarmas. Falla en los dos modos, así que no es solo un problema de llamar herramientas. Modos de
  fallo observados: buscar en una ruta que no existe (`/opt/snapshots/…`) y concluir que no hay archivos, agotar los
  turnos, e inventar el contenido de un archivo.
- El **4 B es claramente mejor** (5–6 de 12) y, sobre todo, **no dio ninguna falsa alarma** (3 de 3 sin desvío); a
  cambio es 2–4 veces más lento por el reparto con la CPU (§3): ≈ 60–150 s por consulta.
- **Ninguna configuración identificó el desvío sutil**: 0 de 12 corridas citaron la regla correcta (en 3 de las 12
  dijo `DESVIO`, pero señalando una regla equivocada). Un agente de este tamaño puede ayudar a una persona a
  revisar, pero **no puede ser el control**: eso confirma D7. La barrera real es la CI (`nft -c`, linters, la
  matriz de alcanzabilidad), la protección de la rama y la aprobación humana.

Qué se puede afirmar y qué no: es una prueba con un prompt, un formato de respuesta y cuatro escenarios; otro
prompt podría mejorar las cifras, pero la tendencia (2 B poco fiable, 4 B mejor, desvío sutil sin detectar) es lo
que importa para decidir el papel de Hermes.
