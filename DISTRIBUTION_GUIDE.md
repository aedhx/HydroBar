# Guide de Distribution Gratuite - HydroBar

Ce guide vous explique comment créer un DMG pour distribuer HydroBar sans compte développeur Apple.

## 📋 Prérequis

- Xcode installé
- Application compilée et fonctionnelle
- Terminal macOS

## 🔧 Étape 1 : Configuration du Projet

### 1.1 Désactiver la signature de code (optionnel mais recommandé)

Dans Xcode :
1. Ouvrez le projet `HydroBar.xcodeproj`
2. Sélectionnez le target `HydroBar`
3. Allez dans l'onglet **Signing & Capabilities**
4. Décochez **Automatically manage signing** (si coché)
5. Dans **Code Signing Identity**, sélectionnez **Sign to Run Locally**

### 1.2 Configuration du Build

1. Dans Xcode, allez dans **Product > Scheme > Edit Scheme**
2. Sélectionnez **Archive** dans le menu de gauche
3. Vérifiez que **Build Configuration** est sur **Release**

## 🏗️ Étape 2 : Build de l'Application

### Option A : Via Xcode (Recommandé pour la première fois)

1. Dans Xcode, sélectionnez **Product > Archive**
2. Attendez la fin de la compilation
3. L'archive sera créée dans `~/Library/Developer/Xcode/Archives/`

### Option B : Via Script (Automatisé)

Utilisez le script `build-release.sh` fourni :

```bash
cd "/Users/antoinedx/Desktop/Project IA/V2/src/HydroBar"
./build-release.sh
```

L'application sera compilée dans `build/HydroBar.app`

## 📦 Étape 3 : Création du DMG

### Option A : Via Script Automatisé (Recommandé)

```bash
cd "/Users/antoinedx/Desktop/Project IA/V2/src/HydroBar"
./create-dmg.sh
```

### Option B : Manuellement

1. Créez un dossier temporaire pour le DMG
2. Copiez `HydroBar.app` dans ce dossier
3. Créez un lien symbolique vers `/Applications`
4. Utilisez Disk Utility ou le script fourni pour créer le DMG

## 📁 Structure du DMG

Le DMG final contiendra :
- `HydroBar.app` - L'application
- Un lien vers `/Applications` pour faciliter l'installation

## 🎨 Assets Nécessaires

### Icônes
✅ Déjà présentes dans `HydroBar/Assets.xcassets/AppIcon.appiconset/`

### Image de fond du DMG (Optionnel)
Vous pouvez créer une image `.png` pour le fond du DMG (ex: `DMG-background.png`)

### Licence (Recommandé)
Créez un fichier `LICENSE.txt` ou `README.txt` à inclure dans le DMG

## ⚠️ Notes Importantes

### Sandbox
L'application utilise le sandbox macOS. Les utilisateurs devront peut-être :
1. Autoriser l'application dans **Sécurité et confidentialité** > **Accessibilité**
2. Autoriser les notifications dans **Préférences Système**

### Première Ouverture
macOS peut afficher un avertissement lors de la première ouverture car l'app n'est pas signée. Les utilisateurs devront :
1. Clic droit sur l'application > **Ouvrir**
2. Confirmer dans la fenêtre de sécurité

### Distribution
- Partagez le DMG via votre site web, GitHub Releases, ou autre
- Indiquez clairement que l'application n'est pas signée
- Fournissez des instructions d'installation

## 🔍 Vérification

Avant de distribuer, testez :
1. ✅ L'application s'ouvre correctement
2. ✅ Les notifications fonctionnent
3. ✅ Les raccourcis clavier globaux fonctionnent
4. ✅ Les données sont sauvegardées correctement
5. ✅ Toutes les fonctionnalités sont opérationnelles

## 📝 Checklist de Distribution

- [ ] Application compilée en mode Release
- [ ] DMG créé et testé
- [ ] README ou instructions d'installation créées
- [ ] Licence ajoutée (si applicable)
- [ ] Version numérotée correctement
- [ ] Testé sur une machine propre (sans Xcode)

## 🚀 Prochaines Étapes

1. Testez le DMG sur une autre machine Mac
2. Créez une page de téléchargement
3. Préparez les notes de version
4. Distribuez !
