#!/usr/bin/env bash
# Despliegue con Ansible (docs/04-automatizacion.md). Dos hosts: lab (la Dell) y hub (el droplet).
# Uso (como root: el rol lab escribe en /etc y systemd):
#   scripts/desplegar.sh lint            yamllint + ansible-lint + sintaxis (lo mismo que la CI)
#   scripts/desplegar.sh simular [host]  --check --diff: muestra qué cambiaría y NO cambia nada
#   scripts/desplegar.sh aplicar [host]  aplica los cambios
# host: all (por omisión) | lab | hub
# Los datos propios (llaves públicas de los pares) salen de un archivo FUERA del repositorio:
#   $REDES_LAB_VARS, o /etc/redes-lab/vars.yml, o ~/.config/redes-lab/vars.yml del dueño del laboratorio.
set -euo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DUENO="${REDES_LAB_USUARIO:-gsanchezm}"
CASA="$(getent passwd "$DUENO" | cut -d: -f6)"
# Como root, ~ es /root: la llave de despliegue y known_hosts son del dueño del laboratorio.
export REDES_LAB_DEPLOY_KEY="${REDES_LAB_DEPLOY_KEY:-$CASA/.ssh/id_ed25519_redes_deploy}"
export REDES_LAB_KNOWN_HOSTS="${REDES_LAB_KNOWN_HOSTS:-$CASA/.ssh/known_hosts}"

variables() {
  local c
  for c in "${REDES_LAB_VARS:-}" /etc/redes-lab/vars.yml "$CASA/.config/redes-lab/vars.yml"; do
    [[ -n $c && -f $c ]] && { echo "$c"; return 0; }
  done
  return 1
}

modo="${1:-}"; limite="${2:-all}"
case "$modo" in
  lint)
    cd "$RAIZ"
    yamllint .
    ansible-lint ansible/
    ( cd ansible && ansible-playbook site.yml --syntax-check -e @vars.example.yml ) ;;
  simular|aplicar)
    # El rol lab no usa los pares de wg1: solo el droplet necesita el archivo de variables.
    vars_args=()
    if VARS="$(variables)"; then vars_args=(-e "@$VARS")
    elif [[ $limite != lab ]]; then
      echo "No encuentro el archivo de variables (modelo: ansible/vars.example.yml)" >&2; exit 2
    fi
    extra=(); [[ $modo == simular ]] && extra=(--check --diff)
    cd "$RAIZ/ansible"
    ansible-playbook site.yml --limit "$limite" "${vars_args[@]}" "${extra[@]}" ;;
  *) sed -n '2,12p' "${BASH_SOURCE[0]}"; exit 2 ;;
esac
