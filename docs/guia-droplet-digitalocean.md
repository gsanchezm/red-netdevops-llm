# Guía · llave SSH y droplet de DigitalOcean (concentrador WireGuard)

Pasos manuales para el Día 4 del plan (`00-plan.md`). El droplet es **solo un concentrador
VPN** (`02-diseno.md` D10): la Dell se conecta hacia afuera y el celular llega por datos
móviles. Aquí se crea la llave, se elige la región por latencia medida, se crea el droplet y se
protege con un Cloud Firewall. La configuración posterior (WireGuard, nftables, usuario
`deploy`) la hace Ansible en el Día 5.

Verificado en la documentación oficial de DigitalOcean el 24-oct-2026: la ruta para subir la
llave, el asistente para crear un droplet, los precios, las regiones, cómo destruirlo y el
cobro. **No verificado en la documentación** (se describe con los nombres habituales del
panel, que pueden variar un poco): los campos de las reglas del Cloud Firewall y la consola
web del droplet. Si el panel cambia, manda la documentación de DigitalOcean.

| Parte | Cuándo | Costo |
|---|---|---|
| A. Llave SSH exclusiva del laboratorio | Antes del Día 4 | gratis |
| B. Prueba de regiones (3 droplets de unos minutos) | Día 4 | centavos |
| C. Droplet definitivo + Cloud Firewall | Día 4 | **$4 al mes** (512 MiB) o $6 (1 GiB) |
| D. Destruirlo | Al terminar el proyecto o si se pausa | detiene el cobro |

**Costo real:** DigitalOcean cobra por segundo (mínimo 60 s o $0.01), con tope de 672 horas al
mes. Un droplet de $4 cuesta $0.00595 por hora: dos semanas encendido ≈ $2. **Un droplet
apagado se sigue cobrando**; solo destruirlo detiene el cobro.

## Reglas de seguridad (el repositorio es público)

- La llave **privada** (`id_ed25519_redes_lab`, sin `.pub`) no sale de tu PC: no la pegues en
  chats, correos ni el repositorio. Solo se comparte la pública (`.pub`).
- No publiques la IP del droplet en el repositorio ni en el documento: el script de regiones
  ya la oculta (`203.0.x.x`).
- No uses la llave personal `id_ed25519` (la de GitHub y otros servicios) para este droplet.

## A. Crear la llave SSH exclusiva del laboratorio

Hazlo una sola vez, en PowerShell, en tu PC.

1. Comprueba que existe el cliente OpenSSH y la carpeta de llaves:

   ```powershell
   ssh -V
   New-Item -ItemType Directory -Force "$env:USERPROFILE\.ssh" | Out-Null
   ```

2. Genera la llave. **Escribe una frase de contraseña** cuando la pida (protege la llave si
   alguien copia el archivo) y guárdala en tu gestor de contraseñas:

   ```powershell
   ssh-keygen -t ed25519 -a 100 -C "redes-lab-admin" -f "$env:USERPROFILE\.ssh\id_ed25519_redes_lab"
   ```

3. Verifica que se crearon los dos archivos y anota la huella:

   ```powershell
   Get-ChildItem "$env:USERPROFILE\.ssh\id_ed25519_redes_lab*" | Select-Object Name, Length
   ssh-keygen -E md5 -lf "$env:USERPROFILE\.ssh\id_ed25519_redes_lab.pub"
   ssh-keygen -E sha256 -lf "$env:USERPROFILE\.ssh\id_ed25519_redes_lab.pub"
   ```

   Deben aparecer `id_ed25519_redes_lab` (privada) e `id_ed25519_redes_lab.pub` (pública).
   Se imprimen las dos huellas porque el panel puede mostrarla en MD5 o en SHA256.

4. Copia la parte **pública** al portapapeles:

   ```powershell
   Get-Content "$env:USERPROFILE\.ssh\id_ed25519_redes_lab.pub" | Set-Clipboard
   ```

5. Regístrala en DigitalOcean. Las llaves se suben al **equipo (team)**, y se aplican a los
   droplets **al crearlos** (no a los que ya existen):

   1. Entra al panel de DigitalOcean y selecciona tu equipo.
   2. Menú izquierdo **Settings** → pestaña **Security** → sección **SSH Keys**.
   3. Botón **Add SSH Key**: se abre la ventana **New SSH key**.
   4. Pega la llave pública en **Public Key** (empieza con `ssh-ed25519`).
   5. En **Key Name** escribe `redes-lab-admin (Dell G15)`.
   6. Botón **Add SSH Key** para guardar.

6. Comprueba que la huella que muestra el panel coincide con una de las del paso 3.

*Opcional, para no teclear la frase en cada conexión:* carga la llave en el agente de SSH de
Windows (requiere iniciar el servicio una vez, como administrador):

```powershell
Get-Service ssh-agent | Set-Service -StartupType Manual; Start-Service ssh-agent
ssh-add "$env:USERPROFILE\.ssh\id_ed25519_redes_lab"
```

En el Día 5 se genera **otra** llave, sin frase y solo para el despliegue automático, dentro de
Ubuntu, con un usuario `deploy` en el droplet. Así se puede revocar sin tocar esta.

## B. Elegir la región por latencia medida (Día 4)

DigitalOcean ya no ofrece una página de prueba de velocidad por región, y no hay centros de
datos en México ni en Texas. Se crean tres droplets de prueba durante unos minutos y se
mide con `ping`.

**Regiones a probar** (slugs de la documentación oficial): `sfo3` (San Francisco), `nyc3`
(Nueva York) y `atl1` (Atlanta, la más al sur del este de EE. UU.). Ten en cuenta:

- `atl1`, `ric1` y `mkc1` solo ofrecen CPU Premium, así que su plan más barato probablemente
  cuesta más que $4 (míralo en las tarjetas de plan). Si no te convence, prueba `tor1` en su lugar.
- `mem1` solo tiene planes v5 (facturación por recurso, otro configurador): no la uses.
- Las regiones `sfo1` y `ams2` son heredadas y ya no permiten crear recursos.

**Para cada región**, crea un droplet siguiendo la parte C (mismos pasos) con estas
diferencias: región distinta, nombre `lat-sfo3` / `lat-nyc3` / `lat-atl1`, **sin** etiqueta y
**sin** Cloud Firewall. Anota la IP de cada uno.

Mide desde tu PC (cableada), con 50 pings por región:

```powershell
.\scripts\ping-regiones.ps1 -Destino 'sfo3=<IP-sfo3>','nyc3=<IP-nyc3>','atl1=<IP-atl1>' -Pings 50
```

El resultado queda en `evidencia/dia4/regiones.txt`, con las IP ocultas. Elige la región con
menor promedio y jitter y **0 % de pérdida**. Luego **destruye los tres droplets de prueba**
(parte D) y crea el definitivo en la región ganadora, o conserva el de esa región y destruye
los otros dos (hay que ponerle la etiqueta `redes-lab` y renombrarlo `redes-lab-hub`).

## C. Crear el droplet definitivo

1. En el panel, botón verde **Create** → **Droplet**.
2. **Choose Region**: la región ganadora de la parte B.
3. **Choose an image**: pestaña **OS** → **Ubuntu** → versión **24.04 (LTS) x64**.
4. **Choose configuration type**: **Bundled** (si el panel lo pregunta).
5. **Choose a Droplet Plan**: grupo **SHARED CPU** → **Basic** → CPU **Regular** →
   **$4/mo (512 MiB, 1 vCPU, 10 GiB, 500 GiB de transferencia)**. Alcanza para WireGuard y
   nftables; si Ansible o `apt` se quedan sin memoria (`dmesg | grep -i "out of memory"`),
   cambia al de $6 (1 GiB).
6. **Additional Storage** y **Backups**: déjalos vacíos (los respaldos cuestan; Ansible
   recrea el servidor).
7. **Choose Authentication Method**: **SSH key** y marca `redes-lab-admin (Dell G15)`. **No**
   uses contraseña.
8. **Networking**: deja **Public IPv4 address** marcado y **Public IPv6 address** *sin*
   marcar (el diseño es solo IPv4).
9. **Monitoring** y **Additional Options / Startup scripts**: no hacen falta.
10. **Finalize Details**: cantidad `1`, nombre `redes-lab-hub`, etiqueta (tag) `redes-lab`.
11. Botón **Create Droplet**. Cuando termine la barra de progreso, el panel muestra la IP
    pública. Anótala (no la subas al repositorio).

### Primera conexión

```powershell
ssh -i "$env:USERPROFILE\.ssh\id_ed25519_redes_lab" root@<IP-del-droplet>
```

Acepta la huella del servidor la primera vez. Para no escribir la IP, agrega esto a
`$env:USERPROFILE\.ssh\config`:

```
Host redes-lab-hub
    HostName <IP-del-droplet>
    User root
    IdentityFile ~/.ssh/id_ed25519_redes_lab
    IdentitiesOnly yes
```

y conéctate con `ssh redes-lab-hub`. Comprueba también `ping <IP>` y que tu ping coincida con
el medido en la parte B.

### Cloud Firewall (protección fuera del droplet)

Un firewall de DigitalOcean filtra el tráfico **antes** de que llegue al droplet, y repite la
política de `02-diseno.md` §5.

1. Botón **Create** → **Firewall**. Nombre: `redes-lab-hub-fw`.
2. **Inbound Rules** (por defecto solo permite SSH desde cualquier origen; **cámbialo**):
   - **SSH** (TCP 22): origen únicamente **tu IP pública de casa**. Para obtenerla:

     ```powershell
     (Invoke-RestMethod https://api.ipify.org)
     ```

     Si tu IP cambia (DHCP del proveedor), SSH dejará de funcionar: entra por la consola web
     del panel (droplet → pestaña **Access** → **Launch Droplet Console**) y actualiza la regla.
   - **Custom** → **UDP**, puerto **51820**: origen **All IPv4** (la Dell y el celular
     cambian de IP; WireGuard no responde a paquetes sin autenticar).
   - Ninguna otra regla de entrada.
3. **Outbound Rules**: deja las que sugiere (todo permitido).
4. **Apply to Droplets**: escribe la etiqueta `redes-lab` y selecciónala.
5. Botón **Create Firewall**.

En el Día 4, cuando `wg1` esté funcionando, **elimina la regla de SSH desde internet**:
desde entonces el droplet se administra solo por el túnel (`10.10.51.1`).

## D. Destruir un droplet

Se hace para los droplets de prueba (parte B) y, al terminar el proyecto, para el definitivo.
Es **irreversible**. El despliegue con Ansible del Día 5 permite recrearlo.

1. En el panel abre el droplet (clic en su nombre) → pestaña **Settings** → **Destroy**.
2. En la ventana **Droplet Danger Zone**, pestaña **Destroy**.
3. Escribe el nombre del droplet para confirmar y pulsa **Destroy**.
4. Revisa que no queden droplets ni firewalls huérfanos: lista **Droplets** en el panel.

*Opcional, por línea de comandos:* `doctl compute droplet delete <nombre>` (requiere instalar
`doctl` y un token de acceso personal; ese token es un secreto y nunca se sube al repositorio).

## Lista de verificación

- [ ] La llave `id_ed25519_redes_lab` existe, tiene frase y la huella del panel coincide.
- [ ] `evidencia/dia4/regiones.txt` muestra la región elegida con 0 % de pérdida.
- [ ] Los droplets de prueba están destruidos (en el panel solo aparece `redes-lab-hub`).
- [ ] `ssh redes-lab-hub` funciona con la llave y **no** acepta contraseña.
- [ ] El Cloud Firewall solo permite SSH desde tu IP y UDP 51820.
- [ ] La IP del droplet no aparece en ningún archivo del repositorio.
