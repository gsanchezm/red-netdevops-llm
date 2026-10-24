# Red segmentada y automatizada con NetDevOps para un LLM local

Proyecto final de **Redes Avanzadas**: diseño de una red local segmentada y automatizada
con prácticas NetDevOps para desplegar de forma segura un LLM local (Ollama + Hermes Agent)
que consumen 5 proyectos de software de un home office, con acceso remoto por WireGuard.

**La red es el centro del proyecto.** Docker, CI/CD y el LLM son la carga que la red
soporta; cada decisión se justifica por segmentación, direccionamiento, seguridad,
latencia o ancho de banda.

## Enfoque

- **Caso real** (solo lectura): la red del home office, documentada y medida sin modificarla.
- **Laboratorio emulado** (implementación): WSL2 + Ubuntu 24.04 + Docker Engine en la
  misma PC, con una topología **plana** ("antes") y una **segmentada** ("después") para
  comparar con la misma batería de pruebas.
- **Concentrador VPN real**: un droplet dedicado de DigitalOcean con WireGuard, al que la
  Dell se conecta hacia afuera y el celular por datos móviles, sin tocar la red de la casa.

## Estructura

```
docs/
  00-plan.md          Plan de 7 días y estado
  01-red-actual.md    Caso de estudio: inventario, topología, línea base, hallazgos
  02-diseno.md        Diseño objetivo: segmentos, IPs, matriz de flujos, decisiones, pruebas
  03-laboratorio.md   Laboratorio emulado: entorno, operación, resultados de la matriz
  img/                Capturas y diagramas
lab/
  compose.plana.yml, compose.segmentada.yml   Las dos topologías (Docker Compose)
  nftables/netseg.nft                          Política entre segmentos (tabla inet netseg)
  matriz/casos.txt                             Casos de la matriz de alcanzabilidad
  imagen/                                      Nodo de prueba (Alpine + herramientas de red)
  caddy/Caddyfile                              Puerta de la IA: TLS con CA interna
  hermes/config.yaml                           Configuración de Hermes (solo lectura)
evidencia/
  dia1/               Salidas de la línea base (IP pública y MACs ocultas)
  dia2/               Entorno, matrices por topología, contadores y log de descartes
  dia3/               Modelo a 64 K, candidatos, latencia de la API, Hermes y matrices
scripts/
  linea-base.ps1      Captura de la línea base en Windows (solo lectura)
  wsl/                Aprovisionamiento de Ubuntu (Docker, GPU) y evidencia del entorno
  lab.sh, matriz.sh   Ciclo de vida del laboratorio y matriz de alcanzabilidad
  contadores.sh, netseg-sola.sh   Qué capa de filtrado detiene cada flujo
  modelo.sh, latencia-api.sh, hermes-prueba.sh   Pruebas del Día 3 (modelo, API, Hermes)
```

Se agregan día con día: `ansible/`, `hermes/` y `.github/workflows/`.

## Reproducir

```bash
# en Ubuntu (WSL2), como root; ver docs/03-laboratorio.md
scripts/lab.sh segmentada && scripts/matriz.sh segmentada
```

Línea base de la red real (Windows, solo lectura):

```powershell
pwsh -File scripts/linea-base.ps1
```

## Reglas del proyecto

- Ningún secreto en el repositorio (es público): llaves de WireGuard, CA de Caddy y
  tokens se generan en el servidor.
- Hermes Agent **nunca** aplica cambios: propone un PR, el pipeline lo valida y una
  persona lo aprueba.
- Toda la configuración de red vive como código y se despliega por el pipeline.
