# Evidencia del Día 7 · enlace físico de la casa

Índice para el reporte. Las mediciones son de solo lectura: no se cambió la velocidad, el dúplex ni la configuración de ningún equipo.
Las direcciones de la red de la casa (`192.168.68.x`) y la de la NAT de WSL2 (`172.x`) son privadas; la dirección MAC no se imprime y el
nombre del equipo en los JSON se sustituyó por `equipo-oculto`.

| Archivo | Qué demuestra | Para el reporte |
|---|---|---|
| `enlace-negociado.txt` | La tarjeta cableada de la Dell (Killer E2600 Gigabit) negocia **1 Gbps** en dúplex completo y entre sus valores válidos no existe 2.5 Gbps (el máximo es 1.0 Gbps Full Dúplex) | Antecedentes y Conclusiones: la capacidad de 2.5 GbE del conmutador no se aprovecha |
| `macbook-negociado.txt` | La MacBook, por un adaptador de Ethernet (`en8`), negocia `1000baseT <full-duplex>`; el Wi-Fi estaba apagado (la primera lectura, por Wi-Fi, no se usó) | Segundo extremo del enlace medido |
| `enlace-iperf3.md` | TCP Dell ↔ MacBook por cable: **940.4 ± 0.1 Mbit/s** (Dell → MacBook) y **940.5 ± 0.6** (MacBook → Dell), n=3 de 10 s por sentido; 50 pings: 1.201 ms de media, 0 % de pérdida | Tabla 4 (fila "Enlace físico") y "Costo de segmentar y de cifrar" |
| `subida-1.json` a `subida-3.json`, `bajada-1.json` a `bajada-3.json` | Salida cruda de `iperf3 -J` de cada repetición (en `bajada` el cliente usa `-R`) | Respaldo de la media y la desviación |

## Condiciones de la medición

- **Equipos:** la Dell G15 (Windows 11; el cliente de iperf3 corre dentro de WSL2) y una MacBook (macOS 26.5.2, servidor `iperf3 -s`).
  Ambos van por cable a puertos del conmutador UGREEN, lo que declara el autor del laboratorio: el conmutador no es administrable
  (no hay lectura de puerto ni LLDP) y no se fotografiaron sus indicadores LED.
- **Un flujo TCP**, 10 s, 3 repeticiones por sentido, con el criterio del Día 6 (`sum_received`, desviación muestral con n−1).
  El sentido inverso lo inicia siempre la Dell (`-R`), así que no se abrió ningún puerto en ella.
- **Latencia:** 50 pings con intervalo de 0.2 s, hechos antes del iperf3 para que el enlace estuviera sin carga:
  mín 0.679, media 1.201, máx 2.283 ms, mdev 0.318 ms, 0 % de pérdida. Salen de WSL2, así que incluyen el salto virtual de su NAT.
  No son comparables con los 0.10 ms hacia el router del Día 1, que se midieron desde Windows con resolución de 1 ms.
- **Wi-Fi apagado en la MacBook** durante la prueba (si no, macOS puede contestar por Wi-Fi); el de la Dell estaba desconectado.

## Lectura y límites

- Los 940 Mbit/s son el 94 % de 1 Gbit/s, lo que corresponde a un enlace de 1 GbE que rinde casi todo lo que admite TCP sobre Ethernet:
  **el techo lo fija la tarjeta de 1 GbE de la Dell** (no admite 2.5 Gbps, ver `enlace-negociado.txt`), no el conmutador. La MacBook negocia
  1 Gbps; no se verificó qué máximo admite su adaptador, así que no se afirma que sea de 1 GbE.
- **No se midió el rendimiento a 2.5 GbE**: la Dell no lo admite. La medición muestra el techo de 1 GbE, no lo que daría el conmutador con
  tarjetas de 2.5 GbE en ambos extremos, y que los puertos del router de malla (Deco M5) son de 1 GbE sale de su ficha (`docs/01-red-actual.md`).
- En la bajada (MacBook → Dell) iperf3 registró retransmisiones (179, 94 y 331 en las tres repeticiones) y ninguna en la subida, sin que
  cambiara el rendimiento. No se investigó la causa; el salto virtual de WSL2 es una posibilidad que no se descartó.
- No se usaron la ThinkPad ni el nodo Deco de la oficina.

## Cómo repetirlo

`scripts/medir-enlace.sh <ip-del-servidor>` (como root en WSL, con `iperf3 -s` activo en el otro equipo). Escribe `enlace-iperf3.md`
y los seis JSON con el nombre del equipo tapado. Al terminar, detener el servidor en el otro equipo (`Ctrl+C`), volver a encender su
Wi-Fi y quitar el permiso del cortafuegos que se haya concedido para la prueba.

Para medir la capacidad de 2.5 GbE (trabajo futuro) hacen falta adaptadores de 2.5 GbE en ambos extremos (la Dell tendría que usar uno externo); antes de medir hay que registrar
la velocidad negociada de cada uno (`Get-NetAdapter` en Windows, `ifconfig <interfaz> | grep media` en macOS, `ethtool <interfaz>` en
Linux instalado directamente, no en WSL) y fotografiar los LED del conmutador.
