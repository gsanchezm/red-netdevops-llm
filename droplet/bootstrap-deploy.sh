#!/usr/bin/env bash
# Arranque ÚNICO del acceso de despliegue en el droplet (root, por la VPN de administración). Idempotente.
# Crea el usuario `deploy` para Ansible y la CI (docs/04-automatizacion.md). Lo ejecuta la persona
# responsable del laboratorio: concede acceso privilegiado, así que no es un paso para automatizar a ciegas.
#
# Qué hace, y nada más:
#   1. crea el usuario `deploy` sin contraseña (no se puede entrar con contraseña);
#   2. autoriza UNA llave pública, que solo vale desde la Dell (from="10.10.51.2") y sin reenvíos;
#   3. le da sudo sin contraseña (Ansible necesita ejecutar módulos como root).
#
# Uso:  scp droplet/bootstrap-deploy.sh redes-lab-hub-vpn:/root/
#       ssh redes-lab-hub-vpn "bash /root/bootstrap-deploy.sh '<llave pública ssh-ed25519>'"
# Revocar:  userdel -r deploy && rm /etc/sudoers.d/90-deploy
set -euo pipefail
PUB="${1:?falta la llave pública (la de ~/.ssh/id_ed25519_redes_deploy.pub en la Dell)}"
[[ $PUB == ssh-ed25519\ * ]] || { echo "no es una llave ed25519" >&2; exit 2; }

id deploy >/dev/null 2>&1 || adduser --disabled-password --gecos 'Despliegue automático (Ansible y CI)' deploy >/dev/null
install -d -m 700 -o deploy -g deploy /home/deploy/.ssh
printf '%s\n' "from=\"10.10.51.2\",no-port-forwarding,no-agent-forwarding,no-X11-forwarding $PUB" > /home/deploy/.ssh/authorized_keys
chown deploy:deploy /home/deploy/.ssh/authorized_keys
chmod 600 /home/deploy/.ssh/authorized_keys

printf 'deploy ALL=(ALL) NOPASSWD:ALL\n' > /etc/sudoers.d/90-deploy
chmod 440 /etc/sudoers.d/90-deploy
visudo -cf /etc/sudoers.d/90-deploy

echo "usuario: $(id deploy)"
passwd -S deploy | sed 's/^/contraseña: /'
cut -c1-90 /home/deploy/.ssh/authorized_keys
