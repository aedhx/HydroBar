# ✅ Checklist de Distribution - HydroBar

## Avant de Builder

- [ ] Version mise à jour dans Xcode (Marketing Version)
- [ ] Code nettoyé et testé
- [ ] Mode Debug désactivé dans les settings (ou laissé pour les testeurs)
- [ ] Toutes les fonctionnalités testées
- [ ] Icônes présentes et correctes
- [ ] Localisations vérifiées

## Configuration Xcode

- [ ] Signature désactivée ou configurée pour "Sign to Run Locally"
- [ ] Build Configuration en Release
- [ ] Aucune erreur de compilation
- [ ] Tous les assets présents

## Build

- [ ] Script `build-release.sh` exécuté avec succès
- [ ] Application compilée dans `build/HydroBar.app`
- [ ] Taille de l'application raisonnable (< 50 MB)
- [ ] Application testée après le build

## DMG

- [ ] Script `create-dmg.sh` exécuté avec succès
- [ ] DMG créé dans `build/HydroBar-v1.0.dmg`
- [ ] DMG testé (montage, installation)
- [ ] README inclus dans le DMG
- [ ] Lien vers Applications fonctionnel

## Tests sur Machine Propre

- [ ] DMG testé sur une autre machine Mac (sans Xcode)
- [ ] Application s'ouvre correctement
- [ ] Avertissement de sécurité géré (clic droit > Ouvrir)
- [ ] Toutes les fonctionnalités fonctionnent
- [ ] Notifications testées
- [ ] Raccourcis clavier testés
- [ ] Données sauvegardées correctement

## Documentation

- [ ] README-DMG.txt complet et à jour
- [ ] Instructions d'installation claires
- [ ] Notes de version préparées
- [ ] Capture d'écran de l'application (optionnel)

## Distribution

- [ ] DMG nommé correctement (ex: `HydroBar-v1.0.dmg`)
- [ ] Taille du DMG vérifiée
- [ ] Hash du fichier calculé (optionnel, pour vérification)
- [ ] Page de téléchargement préparée
- [ ] Notes de version rédigées

## Post-Distribution

- [ ] Lien de téléchargement testé
- [ ] Instructions disponibles pour les utilisateurs
- [ ] Support prêt pour les questions courantes

---

## 📝 Notes Additionnelles

### Calcul du Hash (Optionnel)

Pour créer un hash SHA256 du DMG (utile pour vérification) :

```bash
shasum -a 256 build/HydroBar-v1.0.dmg
```

### Taille Recommandée

- Application: < 50 MB
- DMG: < 60 MB (compressé)

### Versioning

Mettez à jour la version dans :
1. Xcode: Marketing Version
2. `create-dmg.sh`: Variable `DMG_NAME`
3. `README-DMG.txt`: Numéro de version
