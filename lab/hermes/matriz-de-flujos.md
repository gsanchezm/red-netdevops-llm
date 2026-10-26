# Flujos que la política PERMITE (resumen de docs/02-diseno.md §5)

La política es de denegación por defecto: **todo lo que no aparece aquí está denegado**.

| Origen | Destino permitido |
|---|---|
| Trabajo (br-trabajo) | su propio segmento; Caddy 10.10.10.5 puerto 443; internet (cualquier puerto) |
| Caddy (10.10.20.5) | Ollama 10.10.20.10 puerto 11434, dentro del segmento de IA (br-ia) |
| Administración (br-admin) | su propio segmento; Caddy puerto 443; internet **solo TCP 443** |
| Invitados/IoT (br-invitados) | su propio segmento; internet (cualquier puerto) |
| VPN emulada (wg0) | solo Caddy 10.10.10.5 puerto 443 |
| VPN real (wg1), solo el celular 10.10.51.3 | solo Caddy 10.10.10.5 puerto 443 |

Denegado de forma explícita (deben seguir bloqueados):

- Invitados/IoT hacia Trabajo, Administración o Ollama.
- Cualquier equipo hacia Ollama directo (puerto 11434): solo Caddy puede llegar.
- El segmento de IA (br-ia) hacia cualquier otro destino y hacia internet.
- Administración hacia Trabajo, Invitados o Ollama; y Administración hacia internet por puertos distintos de TCP 443.
- Caddy hacia internet.
