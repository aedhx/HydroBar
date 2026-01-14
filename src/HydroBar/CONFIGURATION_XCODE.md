# Configuration Xcode pour Distribution Sans Signature

## ⚙️ Configuration Requise

### 1. Désactiver la Signature Automatique

1. Ouvrez `HydroBar.xcodeproj` dans Xcode
2. Sélectionnez le projet dans le navigateur (icône bleue en haut)
3. Sélectionnez le target **HydroBar**
4. Allez dans l'onglet **Signing & Capabilities**
5. **Décochez** "Automatically manage signing"
6. Dans **Code Signing Identity**, sélectionnez **Sign to Run Locally** ou laissez vide

### 2. Configuration du Build Release

1. Allez dans **Product > Scheme > Edit Scheme** (ou `Cmd + <`)
2. Sélectionnez **Archive** dans le menu de gauche
3. Vérifiez que **Build Configuration** est sur **Release**
4. Fermez la fenêtre

### 3. Vérifier les Build Settings

Dans **Build Settings**, recherchez et vérifiez :

- **Code Signing Identity**: `-` (pas de signature) ou `Sign to Run Locally`
- **Code Signing Style**: `Manual` ou `Automatic` (sans équipe)
- **Development Team**: Vide
- **Enable Hardened Runtime**: Peut rester activé, mais pas nécessaire sans signature

### 4. Entitlements (Optionnel)

Si vous voulez simplifier les entitlements pour la distribution :

Le fichier `HydroBar.entitlements` peut rester tel quel. Le sandbox fonctionnera même sans signature, mais avec des limitations.

## 🔍 Vérification

Avant de builder, vérifiez que :

- ✅ Aucune erreur de signature dans Xcode
- ✅ Le projet compile en mode Release
- ✅ L'application fonctionne après le build

## 📝 Notes

- Sans signature, macOS affichera un avertissement à la première ouverture
- Les utilisateurs devront faire un clic droit > Ouvrir la première fois
- Certaines fonctionnalités peuvent nécessiter des autorisations supplémentaires
