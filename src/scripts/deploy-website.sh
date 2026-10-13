#!/bin/bash
# src/scripts/deploy-website.sh — publie la landing (src/website/) sur le VPS, à hydrobar.adx.cool.
#
# Usage, depuis ton Mac, à la racine du dépôt :
#   ./src/scripts/deploy-website.sh --setup   # une seule fois : dossier, site nginx, certificat HTTPS
#   ./src/scripts/deploy-website.sh           # ensuite, à chaque mise à jour de la page
#
# Le serveur et le compte SSH se règlent par variable (valeur par défaut ci-dessous) :
#   DEPLOY_HOST=antoine@185.97.144.4 ./src/scripts/deploy-website.sh
#
# Prérequis sur le VPS : nginx et certbot (sudo apt install nginx certbot python3-certbot-nginx),
# un compte qui peut utiliser sudo, et ta clé SSH autorisée.
#
# --setup ne touche à aucun autre site du serveur : il écrit un seul fichier,
# /etc/nginx/sites-available/hydrobar.adx.cool, et ne recharge nginx qu'après
# un `nginx -t` réussi. Il peut être relancé : la config est réécrite, puis
# certbot y réinstalle le certificat existant.

set -euo pipefail

DOMAIN="hydrobar.adx.cool"
DEPLOY_HOST="${DEPLOY_HOST:-root@185.97.144.4}"
WEBROOT="/var/www/$DOMAIN"

# Un terminal distant pour que sudo et certbot puissent poser leurs questions ;
# rien quand le script tourne sans terminal (CI, agent), où ssh -t échouerait.
# Sans terminal, certbot ne peut rien demander : il lui faut alors un compte
# Let's Encrypt déjà enregistré sur le serveur (c'est le cas dès qu'un autre
# site y a un certificat).
SSH_TTY=()
CERTBOT_FLAGS="--redirect"
if [ -t 0 ]; then
  SSH_TTY=(-t)
else
  CERTBOT_FLAGS="$CERTBOT_FLAGS --non-interactive"
fi

cd "$(dirname "$0")/../.."

setup() {
  echo "→ Site nginx pour $DOMAIN sur $DEPLOY_HOST"
  local conf
  conf="$(mktemp)"
  cat > "$conf" <<EOF
server {
    listen 80;
    listen [::]:80;
    server_name $DOMAIN;
    root $WEBROOT;
    index index.html;

    access_log /var/log/nginx/hydrobar.access.log;
    error_log  /var/log/nginx/hydrobar.error.log;

    charset utf-8;

    # La page : toujours revalidée, pour qu'une mise à jour se voie tout de suite.
    location / {
        add_header Cache-Control "public, max-age=0, must-revalidate" always;
        try_files \$uri \$uri/ =404;
    }
    # Images, polices, fond d'écran : cache long.
    location /assets/ {
        expires 30d;
        add_header Cache-Control "public";
    }

    gzip on;
    gzip_types text/css application/javascript image/svg+xml;
}
EOF
  # Les étapes côté serveur partent dans un fichier plutôt que sur l'entrée
  # standard de ssh : celle-ci reste libre pour le mot de passe sudo.
  #
  # Si la nouvelle config ne passe pas `nginx -t`, l'ancienne est remise (ou le
  # site retiré s'il n'existait pas) : nginx ne reste jamais avec une config
  # invalide, qui ferait échouer le prochain rechargement des autres sites.
  local steps
  steps="$(mktemp)"
  cat > "$steps" <<'REMOTE'
set -e
available="/etc/nginx/sites-available/$DOMAIN"
enabled="/etc/nginx/sites-enabled/$DOMAIN"
previous="/tmp/$DOMAIN.previous"

sudo mkdir -p "$WEBROOT"
sudo chown "$(id -un)": "$WEBROOT"

sudo rm -f "$previous"
if [ -f "$available" ]; then sudo cp -p "$available" "$previous"; fi
sudo mv "/tmp/$DOMAIN.conf" "$available"
sudo ln -sf "$available" "$enabled"

if ! sudo nginx -t; then
  if [ -f "$previous" ]; then
    sudo mv "$previous" "$available"
  else
    sudo rm -f "$enabled" "$available"
  fi
  echo "✗ Config nginx refusée : état précédent rétabli." >&2
  exit 1
fi
sudo rm -f "$previous"
sudo systemctl reload nginx
REMOTE
  scp -q "$conf" "$DEPLOY_HOST:/tmp/$DOMAIN.conf"
  scp -q "$steps" "$DEPLOY_HOST:/tmp/$DOMAIN.setup.sh"
  rm -f "$conf" "$steps"
  ssh ${SSH_TTY[@]+"${SSH_TTY[@]}"} "$DEPLOY_HOST" \
    "DOMAIN='$DOMAIN' WEBROOT='$WEBROOT' bash '/tmp/$DOMAIN.setup.sh'; status=\$?; rm -f '/tmp/$DOMAIN.setup.sh'; exit \$status"

  publish
  echo "→ Certificat HTTPS (certbot ajoute aussi la redirection HTTP → HTTPS)"
  ssh ${SSH_TTY[@]+"${SSH_TTY[@]}"} "$DEPLOY_HOST" "sudo certbot --nginx $CERTBOT_FLAGS -d '$DOMAIN'"
}

publish() {
  echo "→ Envoi de src/website/ vers $DEPLOY_HOST:$WEBROOT"
  # -rlpt plutôt que -a : sans propriétaire ni groupe, pour que les fichiers
  # appartiennent au compte du serveur et non à l'identifiant numérique du Mac.
  rsync -rlptvz --delete --exclude README.md --exclude .DS_Store src/website/ "$DEPLOY_HOST:$WEBROOT/"
  echo "✓ https://$DOMAIN/"
}

case "${1:-}" in
  --setup) setup ;;
  "") publish ;;
  *) echo "Usage : $0 [--setup]" >&2; exit 64 ;;
esac
