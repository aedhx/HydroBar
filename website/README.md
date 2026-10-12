# hydrobar.adx.cool

La landing page de HydroBar : une seule page statique, sans build ni dépendance.

```
website/
├── index.html        la page (HTML, CSS et JS dans le même fichier)
├── CNAME             domaine pour GitHub Pages
└── assets/           icônes, favicon, image Open Graph (1200 × 630)
```

## Héberger

N'importe quel hébergement statique convient : GitHub Pages, Netlify, Cloudflare Pages, ou
un simple serveur. Le dossier `website/` se publie tel quel.

- **GitHub Pages** : Settings › Pages › Deploy from a branch, dossier `/website` n'existe
  pas comme option, donc soit une action qui publie `website/`, soit une branche
  `gh-pages` qui contient son contenu. Le fichier `CNAME` règle le domaine.
- **DNS** : un enregistrement `CNAME` de `hydrobar` vers l'hôte choisi
  (par exemple `aedhx.github.io`).

## À mettre à jour

- **Lien Mac App Store** : en bas du fichier, `const APP_STORE_URL = ''`. Tant qu'il
  est vide, le bouton affiche « Mac App Store · soon » et le DMG est le téléchargement
  principal. Une fois l'app publiée, colle le lien de la fiche et, idéalement, remplace
  le bouton par le badge officiel « Download on the Mac App Store »
  (developer.apple.com › App Store › Marketing Resources).
- **Version** : « Version 2.0 » dans la section Download.

## Choix de design

- Clair par défaut, sombre selon le réglage du système, contrastes AA.
- Un seul accent, le bleu de la mascotte ; le vert ne sert qu'à « objectif atteint ».
- Bricolage Grotesque pour les titres, Instrument Sans pour le texte (Google Fonts).
- Les démos sont de vraies interactions, pas des captures : le popover (presets, appui
  long), la journée type, l'interrupteur jour de travail / jour off, la gourde.
- Les animations respectent « Réduire les animations ».
