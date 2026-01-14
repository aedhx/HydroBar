# 🎨 Ajout de l'Image de Fond au DMG

## 📍 Emplacement de l'Image

Placez votre image de fond dans l'un de ces emplacements (le script la trouvera automatiquement) :

1. **Dans le dossier du projet** : `DMG-background.png`
2. **Dans un sous-dossier** : `dmg-assets/DMG-background.png`
3. **Dans le dossier parent** : `../DMG-background.png`

## 📝 Format Recommandé

- **Format** : PNG (recommandé pour la transparence) ou JPG
- **Résolution** : 600x400 pixels ou plus (sera redimensionnée automatiquement)
- **Nom** : `DMG-background.png`

## 🔄 Utilisation

Une fois l'image placée, exécutez simplement :

```bash
./build-and-package.sh
```

Le script détectera automatiquement l'image et l'utilisera comme fond du DMG.

## ✨ Résultat

L'image de fond sera :
- Affichée en arrière-plan de la fenêtre du DMG
- Positionnée derrière les icônes de l'application et du dossier Applications
- Cachée dans le DMG (fichier `.background.png`)

## 🎯 Positionnement des Icônes

Les icônes sont positionnées à :
- **HydroBar.app** : Position {160, 205}
- **Applications** : Position {360, 205}

Si vous voulez ajuster ces positions, modifiez les valeurs dans `create-dmg.sh`.
