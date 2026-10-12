# hydrobar.adx.cool

La landing page de HydroBar : une seule page statique, sans build ni dépendance.

```
website/
├── index.html        la page (HTML, CSS et JS dans le même fichier)
└── assets/           icônes, polices, fond d'écran, image Open Graph (1200 × 630)
```

## Héberger sur hydrobar.adx.cool

Le sous-domaine pointe sur le serveur nginx d'adx.cool (enregistrement A vers
185.97.144.4). Trois étapes sur le serveur, une seule fois.

**1. Copier la page.** Depuis la racine du dépôt :

```sh
rsync -av --delete --exclude README.md website/ <utilisateur>@185.97.144.4:/var/www/hydrobar.adx.cool/
```

**2. Déclarer le site dans nginx**, dans `/etc/nginx/sites-available/hydrobar.adx.cool` :

```nginx
server {
    listen 80;
    listen [::]:80;
    server_name hydrobar.adx.cool;
    root /var/www/hydrobar.adx.cool;
    index index.html;

    location / {
        try_files $uri $uri/ =404;
    }
    # Images, polices : versionnées par leur nom, cache long.
    location /assets/ {
        expires 30d;
        add_header Cache-Control "public";
    }

    gzip on;
    gzip_types text/css application/javascript image/svg+xml;
}
```

puis :

```sh
sudo ln -s /etc/nginx/sites-available/hydrobar.adx.cool /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx
```

**3. Le certificat HTTPS.** Tant qu'il manque, le navigateur reçoit celui d'adx.cool
et affiche une erreur. Certbot l'ajoute et règle la redirection HTTP → HTTPS :

```sh
sudo certbot --nginx -d hydrobar.adx.cool
```

Pour les mises à jour suivantes, seule l'étape 1 est à refaire.

## À mettre à jour

- **Lien Mac App Store** : en bas du fichier, `const APP_STORE_URL = ''`. Tant qu'il
  est vide, le bouton affiche « Mac App Store · soon » et le DMG est le téléchargement
  principal. Une fois l'app publiée, colle le lien de la fiche et, idéalement, remplace
  le bouton par le badge officiel « Download on the Mac App Store »
  (developer.apple.com › App Store › Marketing Resources).
- **Version** : « Version 2.0 » dans la section Download.

## Choix de design

Le système de design (couleurs et verre de l'app, typographie, règles) est décrit dans
[`DESIGN.md`](../DESIGN.md), à la racine du dépôt.
