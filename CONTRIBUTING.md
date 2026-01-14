# Contribuer à HydroBar

Merci de votre intérêt pour contribuer à HydroBar ! 🎉

## 🚀 Comment Contribuer

### Signaler un Bug

1. Vérifiez que le bug n'a pas déjà été signalé dans les [Issues](https://github.com/aedhx/HydroBar/issues)
2. Créez une nouvelle issue avec :
   - Description claire du problème
   - Étapes pour reproduire
   - Comportement attendu vs comportement actuel
   - Version de macOS
   - Captures d'écran si applicable

### Proposer une Feature

1. Vérifiez que la feature n'a pas déjà été proposée
2. Créez une issue avec le label "enhancement"
3. Décrivez clairement la feature et son utilité

### Soumettre du Code

1. **Fork** le repository
2. Créez une branche pour votre feature (`git checkout -b feature/AmazingFeature`)
3. **Commitez** vos changements (`git commit -m 'Add some AmazingFeature'`)
4. **Push** vers la branche (`git push origin feature/AmazingFeature`)
5. Ouvrez une **Pull Request**

## 📝 Guidelines de Code

### Swift

- Suivez les conventions Swift standard
- Utilisez des noms de variables et fonctions descriptifs
- Ajoutez des commentaires pour le code complexe
- Respectez l'indentation (4 espaces)

### Architecture

- Suivez le pattern MVVM
- Gardez les vues légères (logique dans le ViewModel)
- Utilisez `@Published` pour les propriétés observables
- Évitez les dépendances circulaires

### UI/UX

- Respectez les [Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/macos) d'Apple
- Testez sur différentes tailles d'écran
- Assurez-vous que l'interface est accessible
- Testez en mode clair et sombre

### Tests

- Ajoutez des tests pour les nouvelles fonctionnalités
- Assurez-vous que tous les tests passent avant de soumettre

## 🌍 Localisation

Si vous ajoutez du texte, utilisez `String(localized:...)` et ajoutez les traductions dans `Localizable.xcstrings`.

## ✅ Checklist avant de Soumettre

- [ ] Code compilé sans erreurs
- [ ] Tests passés (si applicable)
- [ ] Documentation mise à jour
- [ ] Commentaires ajoutés pour le code complexe
- [ ] Respect des conventions de code
- [ ] Interface testée en clair et sombre
- [ ] Aucun warning du compilateur

## 📧 Questions ?

N'hésitez pas à ouvrir une issue pour toute question !

Merci de contribuer à HydroBar ! 💧
