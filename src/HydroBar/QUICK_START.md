# 🚀 Quick Start - Création du DMG

## Méthode Rapide (Recommandée)

```bash
# 1. Aller dans le dossier du projet
cd "/Users/antoinedx/Desktop/Project IA/V2/src/HydroBar"

# 2. Builder l'application
./build-release.sh

# 3. Créer le DMG
./create-dmg.sh
```

Le DMG sera créé dans `build/HydroBar-v1.0.dmg`

## Méthode Alternative (Via Xcode)

1. Ouvrez `HydroBar.xcodeproj` dans Xcode
2. Sélectionnez **Product > Archive**
3. Dans la fenêtre Organizer, cliquez sur **Distribute App**
4. Sélectionnez **Copy App** (pas App Store)
5. Choisissez un emplacement pour sauvegarder
6. Utilisez ensuite `create-dmg.sh` avec le chemin de l'app exportée

## Configuration du Script

Si vous voulez changer la version du DMG, éditez `create-dmg.sh` :

```bash
DMG_NAME="${PROJECT_NAME}-v1.0"  # Changez "v1.0" par votre version
```

## Vérification

Après création, testez le DMG :
1. Double-cliquez pour monter
2. Glissez l'app dans Applications
3. Testez l'application
