# Guide Gatekeeper - Distribution HydroBar

## 🔐 Comprendre Gatekeeper

Gatekeeper est le système de sécurité macOS qui vérifie que les applications proviennent de développeurs identifiés. Sans signature Apple Developer, macOS affichera un avertissement lors de la première ouverture.

## ⚠️ Limitations Sans Compte Développeur

**Sans compte Apple Developer ($99/an), vous ne pouvez pas :**
- ✅ Signer l'application avec un certificat reconnu par Apple
- ✅ Notariser l'application (processus qui vérifie l'absence de malware)
- ✅ Éliminer complètement l'avertissement Gatekeeper

**Ce que vous pouvez faire :**
- ✅ Utiliser "Ad Hoc Signing" (signature locale) - réduit certains avertissements
- ✅ Fournir des instructions claires aux utilisateurs
- ✅ Distribuer via GitHub Releases (plus de confiance)

## 🛠️ Options Disponibles

### Option 1 : Ad Hoc Signing (Recommandé)

L'ad hoc signing utilise votre identité locale pour signer l'application. Cela ne résout pas complètement Gatekeeper, mais peut réduire certains avertissements.

**Avantages :**
- Réduit certains avertissements système
- L'application apparaît comme "signée" (même si localement)
- Gratuit

**Inconvénients :**
- Gatekeeper affichera toujours un avertissement
- Les utilisateurs devront toujours faire "Clic droit > Ouvrir" la première fois

**Comment l'utiliser :**
Le script `build-release.sh` peut être modifié pour inclure l'ad hoc signing automatiquement.

### Option 2 : Distribution Sans Signature

Distribuer l'application sans aucune signature.

**Avantages :**
- Simple
- Pas de configuration supplémentaire

**Inconvénients :**
- Avertissement Gatekeeper plus visible
- Moins de confiance pour les utilisateurs

### Option 3 : Compte Apple Developer (Solution Complète)

Avec un compte Apple Developer ($99/an), vous pouvez :
1. Signer l'application avec un certificat reconnu
2. Notariser l'application via `notarytool` ou `altool`
3. Éliminer complètement l'avertissement Gatekeeper

## 📝 Instructions pour Utilisateurs (À Inclure dans le README)

Les utilisateurs devront contourner Gatekeeper manuellement. Voici les instructions à fournir :

### Méthode 1 : Clic Droit > Ouvrir (Recommandé)

1. Double-cliquez sur le DMG pour le monter
2. Glissez `HydroBar.app` dans le dossier Applications
3. **Ne double-cliquez PAS directement sur l'application**
4. Allez dans le dossier Applications
5. **Faites un clic droit** sur `HydroBar.app`
6. Sélectionnez **"Ouvrir"** dans le menu contextuel
7. Cliquez sur **"Ouvrir"** dans la fenêtre de sécurité qui apparaît

### Méthode 2 : Via Terminal (Pour Utilisateurs Avancés)

```bash
# Supprimer le flag de quarantaine
xattr -d com.apple.quarantine /Applications/HydroBar.app

# Puis ouvrir normalement
open /Applications/HydroBar.app
```

### Méthode 3 : Autoriser dans Préférences Système

1. Allez dans **Préférences Système > Sécurité et confidentialité**
2. Si vous voyez un message concernant HydroBar, cliquez sur **"Ouvrir quand même"**
3. Entrez votre mot de passe administrateur si demandé

## 🔧 Amélioration : Ad Hoc Signing Automatique

Pour améliorer l'expérience utilisateur, vous pouvez ajouter l'ad hoc signing au script de build :

```bash
# Après le build, ajouter cette ligne dans build-release.sh
codesign --force --deep --sign - "$APP_PATH"
```

**Note :** Cela nécessite que vous ayez une identité de signature locale configurée (généralement automatique sur macOS).

## 📊 Comparaison des Options

| Option | Avertissement Gatekeeper | Confiance Utilisateur | Coût | Complexité |
|--------|-------------------------|----------------------|------|------------|
| Sans signature | ⚠️ Fort | ⭐⭐ | Gratuit | Faible |
| Ad Hoc Signing | ⚠️ Moyen | ⭐⭐⭐ | Gratuit | Faible |
| Apple Developer | ✅ Aucun | ⭐⭐⭐⭐⭐ | $99/an | Moyenne |

## 🎯 Recommandation

Pour une distribution gratuite :
1. **Utilisez Ad Hoc Signing** (améliore l'expérience sans coût)
2. **Fournissez des instructions claires** dans le README
3. **Distribuez via GitHub Releases** (ajoute de la confiance)
4. **Considérez un compte Apple Developer** si vous prévoyez une distribution à grande échelle

## 🔗 Ressources

- [Apple Developer Documentation - Code Signing](https://developer.apple.com/documentation/security/code_signing_services)
- [Apple Developer Documentation - Notarization](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution)
- [Gatekeeper and macOS Security](https://support.apple.com/en-us/HT202491)
