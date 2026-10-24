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

## Estructura

```
docs/
  00-plan.md          Plan de 7 días y estado
  01-red-actual.md    Caso de estudio: inventario, topología, línea base, hallazgos
  02-diseno.md        Diseño objetivo: segmentos, IPs, matriz de flujos, decisiones, pruebas
  img/                Capturas y diagramas
evidencia/
  dia1/               Salidas de la línea base (IP pública y MACs ocultas)
scripts/
  linea-base.ps1      Captura de la línea base en Windows (solo lectura)
```

Se agregan día con día: `lab/` (compose y nftables), `ansible/`, `hermes/` y
`.github/workflows/`.

## Reproducir la línea base

```powershell
pwsh -File scripts/linea-base.ps1
```

## Reglas del proyecto

- Ningún secreto en el repositorio (es público): llaves de WireGuard, CA de Caddy y
  tokens se generan en el servidor.
- Hermes Agent **nunca** aplica cambios: propone un PR, el pipeline lo valida y una
  persona lo aprueba.
- Toda la configuración de red vive como código y se despliega por el pipeline.
