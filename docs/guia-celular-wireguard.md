# Guía · el celular como cliente WireGuard real (Día 4)

Pasos manuales para probar el acceso remoto con un **cliente real**: el celular, por datos
móviles, llega a Caddy (la puerta de la IA del laboratorio) a través del droplet de
DigitalOcean (`02-diseno.md` D10 y D12). El celular no entra a la red de la casa ni toca el
router: se conecta al droplet, el droplet lo une con la Dell, y la Dell (que también sale
hacia el droplet) le responde.

```
celular (datos móviles) ──UDP 51820──► droplet (hub, 10.10.51.1) ◄──UDP 51820── Dell (10.10.51.2)
   10.10.51.3                           reenvía solo 10.10.51.3 → 10.10.10.5:443        └─► Caddy 10.10.10.5
```

**Qué se va a probar:** abrir `https://10.10.10.5/api/tags` en el navegador del celular y ver
la respuesta de Ollama, con candado, a través del túnel. Es solo lectura (lista los modelos).

> **Probado de punta a punta con un iPhone (iOS, app en español) el 25-oct-2026**, por 5G. Los
> pasos de **Android** y los nombres exactos de menús y botones **no se verificaron con la
> documentación oficial** de la app: se describen con los términos habituales y cambian un poco
> según la versión, el idioma y el fabricante. Si algo no coincide, manda lo que ves en pantalla.

## Reglas de seguridad (el repositorio es público)

- La **clave privada** del celular nace dentro de la app y **no sale de ella**. No la copies, no la
  fotografíes y no la pegues en chats. Lo único que se comparte es la clave **pública**.
- **No exportes el túnel como código QR ni como archivo** y no publiques capturas con la sección
  *Interface* o un QR a la vista: contienen la clave privada.
- La IP del droplet **no** va al repositorio ni al documento. En esta guía aparece como
  `<IP-DEL-DROPLET>`; en las capturas de evidencia se tapa (`45.55.x.x`).
- El certificado que se instala en el celular es el **público** de la CA interna (`root.crt`).
  Si alguien te ofrece un archivo con la llave privada de la CA, **no lo instales ni lo reenvíes**.

## Valores que vas a usar

Claude te da los dos primeros por chat (no se guardan en el repositorio); los demás son fijos
del diseño.

| Dato | Valor |
|---|---|
| IP pública del droplet | `<IP-DEL-DROPLET>` |
| Clave pública del droplet | `<CLAVE-PÚBLICA-DEL-DROPLET>` (44 caracteres, termina en `=`) |
| Puerto | `51820` (UDP) |
| IP del celular en el túnel | `10.10.51.3` |
| Redes que irán por el túnel | `10.10.51.0/24` y `10.10.10.5/32` (solo Caddy) |
| Dirección a abrir | `https://10.10.10.5/api/tags` |

## Quién hace qué, y cuándo

| Parte | Quién | Cuándo |
|---|---|---|
| **A.** Instalar la app, crear el túnel, mandar la clave pública | tú | ya (no depende del laboratorio) |
| **B.** Agregar el celular al droplet y a la Dell | Claude | al recibir tu clave pública |
| **C.** Instalar el certificado de la CA en el celular | tú | cuando Claude te pase `root.crt` |
| **D.** Activar el túnel por datos móviles y probar | tú | cuando Claude avise "listo para probar" |
| **E.** Evidencia y limpieza | tú y Claude | al terminar |

## A. Instalar la app y crear el túnel (sin activarlo)

1. Instala la app **WireGuard** oficial. Entra por los enlaces de `wireguard.com/install` para
   llegar a la ficha correcta de Google Play o de la App Store (hay imitaciones con nombres
   parecidos). Es gratuita y no pide cuenta.
2. Ábrela y crea un túnel desde cero:
   - **Android:** botón **+** (abajo a la derecha) → **Crear desde cero**.
   - **iOS:** **Añadir un túnel** → **Crear desde cero**.
3. Llena la sección **Interface** (*Interfaz*):

   | Campo | Qué poner |
   |---|---|
   | Nombre | `redes-lab` |
   | Clave privada | la que genera la app. **No la toques.** Si el campo está vacío, usa el botón de generar |
   | Clave pública | la calcula la app; **cópiala** (paso 4) |
   | Direcciones | `10.10.51.3/32` |
   | Puerto de escucha | vacío |
   | DNS | **vacío** (el túnel no maneja nombres) |
   | MTU | vacío (automático) |

4. **Copia tu clave pública** (la que aparece en *Interface*, no la privada): en Android tócala o
   mantenla presionada; en iOS mantenla presionada → *Copiar*. Son 44 caracteres y terminan en `=`.
   Pégala en un mensaje a ti mismo (correo, Notas, "Mensajes guardados") y de ahí a este chat. Si
   la escribes a mano, revisa mayúsculas y minúsculas: la `I` mayúscula y la `l` minúscula se
   parecen.
5. Agrega el par (*Add peer* / *Añadir par*) que representa al droplet:

   | Campo | Qué poner |
   |---|---|
   | Clave pública | `<CLAVE-PÚBLICA-DEL-DROPLET>` |
   | Clave precompartida | vacía |
   | Endpoint | `<IP-DEL-DROPLET>:51820` |
   | IPs permitidas | `10.10.51.0/24, 10.10.10.5/32` |
   | Keepalive persistente | `25` (segundos) |

   > **Importante:** **no** uses `0.0.0.0/0` en *IPs permitidas*. Eso manda **todo** el internet del
   > celular por el droplet, y el droplet no sale a internet por ti: te quedarías sin conexión.
   > Con las dos redes de arriba solo viaja lo del laboratorio y el resto sigue normal.
6. Guarda el túnel (**Guardar** / **✓**) y **déjalo apagado**. Falta que Claude agregue tu clave
   al droplet; sin eso no hay apretón de manos.

## B. Lo que hace Claude (para que sepas qué esperar)

1. Con tu clave pública, agrega el par `10.10.51.3/32` en el droplet.
2. Genera la llave de `wg1` de la Dell, agrega ese par en el droplet (`10.10.51.2/32` y
   `10.10.10.5/32`) y levanta `wg1` en la Dell.
3. Comprueba en el droplet que la Dell hizo apretón de manos (la Dell siempre inicia hacia
   afuera) y te avisa. Para esto el laboratorio debe estar levantado y WSL vivo.

## C. Instalar el certificado de la CA interna en el celular

Caddy firma su certificado con una CA propia del laboratorio. Hasta que el celular confíe en ella
verás "conexión no privada". Claude te pasará el archivo público **`root.crt`**; envíalo al
celular por correo, tu nube, AirDrop/Nearby Share o cable. Es un certificado público, no un secreto.

**Android** (los nombres cambian según el fabricante):

1. Guarda `root.crt` en *Descargas*.
2. **Ajustes → Seguridad (y privacidad) → Más seguridad → Cifrado y credenciales → Instalar un
   certificado → Certificado de CA**.
3. Acepta el aviso (*Instalar de todos modos*) y elige `root.crt`. Android avisará que "la red
   puede ser supervisada": es normal, la CA es tuya.
4. Chrome usa esa CA sin más. Firefox para Android necesita además activar los certificados de
   terceros en su configuración; para esta prueba usa Chrome.

**iOS:**

1. Abre `root.crt` desde *Archivos*, Mail o Safari. Aparece **Perfil descargado**.
2. **Ajustes → Perfil descargado → Instalar** (pide tu código).
3. **Ajustes → General → Información → Ajustes de confianza de certificados** y activa el
   interruptor de la CA cuyo nombre empieza con **Caddy Local Authority**. Sin este paso iOS no
   confía en ella aunque esté instalada.

## D. Activar el túnel y probar (por datos móviles)

1. **Apaga el Wi-Fi** del celular y comprueba que tienes datos móviles. Con Wi-Fi de la casa
   también funcionaría, pero la prueba que importa es la remota.
2. Activa el túnel `redes-lab` (interruptor). El sistema pide permiso de VPN la primera vez:
   acéptalo.
3. En la pantalla del túnel, en unos segundos deben verse:
   - **Último apretón de manos** (*Latest handshake*): "hace unos segundos".
   - **Transferencia** (*Transfer*): bytes recibidos y enviados mayores que cero.

   Si dice "nunca" ve a *Si algo falla*.
4. Abre el navegador (Chrome o Safari) en **`https://10.10.10.5/api/tags`**. Debes ver:
   - el **candado** sin avisos;
   - un texto JSON que empieza con `{"models":[` y menciona `qwen3.5:2b`.
5. **No uses desde el celular `/api/generate` ni `/api/chat`** durante esta prueba: eso carga el
   modelo en la GPU y consume cerca de 3.7 GB de memoria de Windows (ver `03-laboratorio.md` §7.5).
   Con `/api/tags` basta para probar el camino completo.
6. Desactiva el túnel cuando termines (datos y batería: el *keepalive* envía un paquete diminuto
   cada 25 s).

## E. Evidencia y limpieza

**Capturas** (guárdalas como `evidencia/dia4/celular-*.png`):

1. La pantalla del túnel con el apretón de manos y la transferencia. **Tapa** el *Endpoint* (la IP
   del droplet) y asegúrate de que no se vea la clave privada ni el QR.
2. El navegador con el candado y el JSON de `https://10.10.10.5/api/tags`.

**Lo que hace Claude** como evidencia del lado del servidor: `wg show` del droplet y de la Dell
(claves recortadas), y el registro de Caddy, donde la solicitud aparece con origen `10.10.51.3`
(sin NAT, D12) y su duración.

**Limpieza al terminar el proyecto:**

- Borra el túnel `redes-lab` de la app.
- Quita la CA: **Android** → *Ajustes → Seguridad → Cifrado y credenciales → Credenciales de
  usuario* → elimina la que empieza con *Caddy Local Authority*. **iOS** → *Ajustes → General →
  VPN y gestión de dispositivos* → perfil de la CA → *Eliminar perfil*.

## Si algo falla

| Síntoma | Causa probable | Qué hacer |
|---|---|---|
| Al guardar: **"Par inválido: la clave pública del par debe ser de 32 bytes en base64"** | La clave del droplet quedó mal escrita: falta un carácter, sobra un espacio o un salto de línea (confundir `I` con `l` **no** produce este error) | Borra el campo y **pega** la clave (44 caracteres, termina en `=`); no la teclees |
| Al guardar, el *Punto final* se rechaza | Escribiste `IP/51820` con una barra; en iOS el `:` está en la página de símbolos (`123`) | Debe ser `<IP-DEL-DROPLET>:51820` |
| Apretón de manos "nunca" | El droplet aún no tiene tu clave pública, o escribiste mal el *Endpoint* o la clave del droplet | Revisa IP, `:51820` y la clave del droplet carácter por carácter; avisa a Claude para revisar el droplet |
| Hay apretón de manos pero Safari dice "no pudo conectarse al servidor" | Falla en la Dell, no en el celular: el SYN llega pero nadie contesta (en la prueba real, Caddy había quedado con otra IP) | Avisa a Claude; `scripts/lab.sh` ahora verifica que Caddy esté en `10.10.10.5` |
| "Nunca" aunque todo coincide | Tu operador o la red bloquean UDP 51820 | Prueba con el *hotspot* de otro teléfono o con otra red; avisa a Claude |
| Hay apretón de manos pero la página no carga | La Dell no está conectada al droplet (WSL apagado, laboratorio caído) | Avisa a Claude: revisa el apretón de manos de la Dell en el droplet |
| "Conexión no privada" o error de certificado | La CA no está instalada o no está confiada | Repite la parte C (en iOS, el interruptor de confianza) |
| Página a medias o muy lenta | Paquetes grandes que no caben en el túnel (MTU) | En *Interface*, pon *MTU* `1280` y reactiva el túnel |
| El celular se queda sin internet con el túnel activo | *IPs permitidas* contiene `0.0.0.0/0` | Déjalo solo en `10.10.51.0/24, 10.10.10.5/32` |
| `ping` a `10.10.51.2` no responde | Es por diseño: el droplet solo reenvía `10.10.51.3 → 10.10.10.5:443` | Prueba siempre con el navegador a `https://10.10.10.5/api/tags` |
| `https://ia.lab.internal` no abre | El celular no resuelve `.internal` (D12) | Usa la IP `10.10.10.5` |

## Lista de verificación

- [ ] La clave privada del celular sigue solo dentro de la app (no hay copia ni QR exportado).
- [ ] *IPs permitidas* es `10.10.51.0/24, 10.10.10.5/32` (sin `0.0.0.0/0`).
- [ ] El apretón de manos aparece con datos móviles y el Wi-Fi apagado.
- [ ] `https://10.10.10.5/api/tags` abre con candado y muestra `qwen3.5:2b`.
- [ ] Las capturas no muestran la IP del droplet, la clave privada ni un QR.
- [ ] Al terminar: túnel y certificado eliminados del celular.
