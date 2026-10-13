#!/bin/bash
# deploy-website.sh — publie la landing (website/) sur le VPS, à hydrobar.adx.cool.
#
# Usage, depuis ton Mac, à la racine du dépôt :
#   ./deploy-website.sh --setup   # une seule fois : dossier, site nginx, certificat HTTPS
#   ./deploy-website.sh           # ensuite, à chaque mise à jour de la page
#
# Le serveur et le compte SSH se règlent par variables (valeurs par défaut ci-dessous) :
#   DEPLOY_HOST=antoine@185.97.144.4 ./deploy-website.sh
#
# Prérequis sur le VPS : nginx et certbot (sudo apt install nginx certbot python3-certbot-nginx),
# un compte qui peut utiliser sudo, et ta clé SSH autorisée.

set -euo pipefail

DOMAIN="hydrobar.adx.cool"
DEPLOY_HOST="${DEPLOY_HOST:-185.97.144.4}"
WEBROOT="/var/www/$DOMAIN"

cd "$(dirname "$0")"

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

    location / {
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
  scp -q "$conf" "$DEPLOY_HOST:/tmp/$DOMAIN.conf"
  rm -f "$conf"

  # -t : sudo et certbot peuvent poser leurs questions (mot de passe, e-mail la première fois).
  ssh -t "$DEPLOY_HOST" "
    set -e
    sudo mkdir -p '$WEBROOT'
    sudo chown \"\$(id -un)\": '$WEBROOT'
    sudo mv '/tmp/$DOMAIN.conf' '/etc/nginx/sites-available/$DOMAIN'
    sudo ln -sf '/etc/nginx/sites-available/$DOMAIN' '/etc/nginx/sites-enabled/$DOMAIN'
    sudo nginx -t
    sudo systemctl reload nginx
  "
  publish
  echo "→ Certificat HTTPS (certbot ajoute aussi la redirection HTTP → HTTPS)"
  ssh -t "$DEPLOY_HOST" "sudo certbot --nginx -d '$DOMAIN'"
}

publish() {
  echo "→ Envoi de website/ vers $DEPLOY_HOST:$WEBROOT"
  rsync -avz --delete --exclude README.md --exclude .DS_Store website/ "$DEPLOY_HOST:$WEBROOT/"
  echo "✓ https://$DOMAIN/"
}

case "${1:-}" in
  --setup) setup ;;
  "") publish ;;
  *) echo "Usage : $0 [--setup]" >&2; exit 64 ;;
esac
