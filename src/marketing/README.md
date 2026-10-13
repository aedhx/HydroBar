# Visuels de HydroBar

Ce dossier génère :

- les **captures App Store**, 6 écrans × 9 langues, en 2880 × 1800, dans
  `src/fastlane/screenshots/<langue>/` ;
- les **images du README** et l'**aperçu social GitHub** dans `Resources/v2/`, à la racine du dépôt.

```bash
cd src/marketing
npm install
npx playwright install chromium   # une seule fois
npm run screenshots               # captures App Store (ou : node render.cjs --only fr-FR)
npm run readme                    # images du README
```

## Comment c'est fait

`template.html` redessine l'interface de HydroBar en HTML : popover, notification,
fenêtre de réglages, widget, menu de l'icône. Les géométries viennent des vues SwiftUI
(anneau de 180 pt, trait de 12 pt, popover de 320 pt), et **tous les textes de
l'interface viennent du catalogue de l'app** (`Localizable.xcstrings`). Une chaîne
renommée dans l'app l'est donc aussi dans les captures, et une chaîne absente fait
échouer le rendu.

| Fichier | Rôle |
|---|---|
| `captions.json` | titre et sous-titre de chaque écran, par langue |
| `data.cjs` | contenu de chaque écran : valeurs de démonstration, dates et unités de la locale |
| `strings.cjs` | lecture du catalogue, formatage des quantités comme `AppUnit.format` |
| `template.html` | mise en page et dessin de l'interface |
| `render.cjs` | rendu avec Chromium (Playwright), et contrôle des textes qui débordent |

Les unités suivent l'usage de chaque pays : onces aux États-Unis, centilitres en Europe,
millilitres au Japon et en Chine.

## Recréation fidèle, pas capture d'écran

Ces images recréent l'interface ; elles ne sont pas des captures de l'app qui tourne.
Avant de les envoyer, compare-les à l'app sur un Mac (règle 2.3 de l'App Store : la
fiche doit montrer l'app telle qu'elle est). Si un écran a changé, corrige le gabarit :
toutes les langues suivent. Sur un Mac, les polices système (SF Pro, Hiragino,
PingFang) remplacent automatiquement Inter et les polices de secours.

## Fond du DMG

`dmg-background.html` est la source du fond de la fenêtre du DMG (660 × 400 points).
Après une modification, refais `src/scripts/dmg/DMG-background.tiff`, qui contient le rendu
en 1x et en 2x :

```sh
chrome=~/Library/Caches/ms-playwright/chromium_headless_shell-*/chrome-headless-shell-*/chrome-headless-shell
for scale in 1 2; do
  $chrome --headless --hide-scrollbars --window-size=660,400 --force-device-scale-factor=$scale \
    --screenshot=/tmp/dmg-bg@${scale}x.png "file://$PWD/marketing/dmg-background.html"
done
tiffutil -cathidpicheck /tmp/dmg-bg@1x.png /tmp/dmg-bg@2x.png -out src/scripts/dmg/DMG-background.tiff
```

Les positions des icônes sont dans `src/scripts/dmg/dmg-settings.py` : le fond et elles vont
ensemble. Le workflow Release joint une capture de la fenêtre telle que le Finder
l'ouvre (`dmg-window.png`).
