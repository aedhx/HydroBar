# 🤝 Guide de Contribution

Merci de votre intérêt pour contribuer à HydroBar ! Ce document fournit des directives pour contribuer au projet.

## 📋 Comment Contribuer

### Signaler un Bug

1. Vérifiez que le bug n'a pas déjà été signalé dans les [Issues](../../issues)
2. Si ce n'est pas le cas, créez une nouvelle issue avec le template "Bug Report"
3. Incluez toutes les informations pertinentes (macOS version, étapes de reproduction, etc.)

### Proposer une Fonctionnalité

1. Vérifiez que la fonctionnalité n'a pas déjà été proposée
2. Créez une nouvelle issue avec le template "Feature Request"
3. Décrivez clairement la fonctionnalité et son utilité

### Contribuer au Code

1. Fork le repository
2. Créez une branche pour votre fonctionnalité (`git checkout -b feature/ma-fonctionnalite`)
3. Suivez les conventions de code existantes
4. Ajoutez des tests si applicable
5. Commit avec des messages clairs (`git commit -m 'Ajout de la fonctionnalité X'`)
6. Push vers votre fork (`git push origin feature/ma-fonctionnalite`)
7. Ouvrez une Pull Request

## 🎨 Conventions de Code

- **Swift** : Suivez les [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/)
- **SwiftUI** : Utilisez les meilleures pratiques SwiftUI
- **Nommage** : Noms clairs et descriptifs en français pour les variables/fonctions utilisateur, anglais pour le code technique
- **Commentaires** : Code auto-documenté, commentaires pour la logique complexe uniquement

## 📝 Structure du Projet

```
HydroBar/
├── src/HydroBar/
│   ├── HydroBar/          # Code source principal
│   │   ├── Views/         # Vues SwiftUI
│   │   ├── Models/        # Modèles de données
│   │   └── Managers/      # Gestionnaires (HydrationManager, etc.)
│   └── build/             # Build artifacts
├── docs/                  # Documentation
└── .github/               # Templates GitHub
```

## ✅ Checklist avant Pull Request

- [ ] Le code compile sans erreurs
- [ ] Les fonctionnalités sont testées
- [ ] La documentation est à jour
- [ ] Les conventions de code sont respectées
- [ ] Les messages de commit sont clairs
- [ ] La Pull Request a une description détaillée

## 🐛 Tests

Avant de soumettre une PR, testez votre code sur :
- [ ] macOS 12.0+
- [ ] Apple Silicon (si possible)
- [ ] Intel (si possible)
- [ ] Mode clair et sombre

## 📄 Licence

En contribuant, vous acceptez que vos contributions soient sous la même licence que le projet (MIT).

Merci de contribuer à HydroBar ! 🎉
