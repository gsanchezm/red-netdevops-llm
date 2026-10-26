#!/usr/bin/env bash
# Comprueba, tras un despliegue, que el droplet sigue sano: servicios activos, firewall con política drop, ip_forward y
# que los pares de wg1 con los que hay tráfico siguen presentes. Solo lectura. Usa el acceso de despliegue (usuario deploy).
# Uso:  scripts/verificar-hub.sh        Código de salida: 0 sano · 1 algo falla
set -uo pipefail
DUENO="${REDES_LAB_USUARIO:-gsanchezm}"; CASA="$(getent passwd "$DUENO" | cut -d: -f6)"
LLAVE="${REDES_LAB_DEPLOY_KEY:-$CASA/.ssh/id_ed25519_redes_deploy}"
KNOWN="${REDES_LAB_KNOWN_HOSTS:-$CASA/.ssh/known_hosts}"

salida="$(ssh -i "$LLAVE" -o IdentitiesOnly=yes -o BatchMode=yes -o ConnectTimeout=8 -o StrictHostKeyChecking=yes \
  -o UserKnownHostsFile="$KNOWN" deploy@10.10.51.1 '
  echo "wg1=$(systemctl is-active wg-quick@wg1)"
  echo "nftables=$(systemctl is-active nftables)"
  echo "forward_policy_drop=$(sudo nft list chain inet hub forward | grep -c "policy drop")"
  echo "input_policy_drop=$(sudo nft list chain inet hub input | grep -c "policy drop")"
  echo "ip_forward=$(sysctl -n net.ipv4.ip_forward)"
  echo "pares=$(sudo wg show wg1 peers | wc -l)"' 2>&1)" || { echo "No pude consultar el droplet: $salida" >&2; exit 1; }
echo "$salida" | sed 's/^/  /'

fallo=0
[[ $salida == *wg1=active* ]]               || { echo "FALLA: wg1 no está activo" >&2; fallo=1; }
[[ $salida == *nftables=active* ]]          || { echo "FALLA: nftables no está activo" >&2; fallo=1; }
[[ $salida == *forward_policy_drop=1* ]]    || { echo "FALLA: forward no tiene política drop" >&2; fallo=1; }
[[ $salida == *input_policy_drop=1* ]]      || { echo "FALLA: input no tiene política drop" >&2; fallo=1; }
[[ $salida == *ip_forward=1* ]]             || { echo "FALLA: ip_forward apagado" >&2; fallo=1; }
n="$(sed -n 's/^pares=//p' <<< "$salida")"; [[ ${n:-0} -ge 3 ]] || { echo "FALLA: faltan pares en wg1 ($n < 3)" >&2; fallo=1; }
(( fallo == 0 )) && echo "droplet sano"
exit "$fallo"
