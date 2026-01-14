# 💧 HydroBar

<div align="center">

![HydroBar Logo](https://img.shields.io/badge/HydroBar-💧-blue?style=for-the-badge)
![macOS](https://img.shields.io/badge/macOS-12.0+-black?style=for-the-badge&logo=apple)
![Swift](https://img.shields.io/badge/Swift-5.0-orange?style=for-the-badge&logo=swift)
![License](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)

**L'application native macOS pour suivre votre hydratation quotidienne avec style**

[Features](#-features) • [Installation](#-installation) • [Utilisation](#-utilisation) • [Captures d'écran](#-captures-décran) • [Contribuer](#-contribuer)

</div>

---

## ✨ À propos

HydroBar est une application élégante et native pour macOS qui vous aide à rester hydraté tout au long de la journée. Discrètement installée dans votre barre de menu, elle vous rappelle de boire de l'eau et suit vos progrès avec des statistiques détaillées.

Conçue avec SwiftUI et suivant les meilleures pratiques d'Apple, HydroBar offre une expérience utilisateur fluide et intuitive, parfaitement intégrée à macOS.

## 🎯 Features

### 💧 Suivi Quotidien
- **Jauge circulaire animée** avec affichage en temps réel de votre progression
- **Objectif personnalisable** adapté à vos besoins
- **Presets rapides** pour ajouter de l'eau en un clic
- **Mode "Hold-to-Add"** pour un remplissage continu et intuitif

### 📊 Statistiques Avancées
- **Graphique hebdomadaire** avec visualisation des 7 derniers jours
- **Heatmap mensuelle** pour voir votre régularité sur 30 jours
- **KPIs détaillés** : moyenne quotidienne, total hebdomadaire, série actuelle
- **Calcul automatique** de votre streak d'hydratation

### 🔔 Rappels Intelligents
- **Notifications personnalisables** avec intervalles configurables
- **Synchronisation Focus Mode** : respecte automatiquement votre mode "Ne pas déranger"
- **Badge visuel** dans la barre de menu quand les rappels sont actifs
- **Actions rapides** depuis les notifications

### ⌨️ Raccourcis Clavier Globaux
- **Raccourcis personnalisables** pour chaque preset
- **Fonctionnent partout** dans macOS, même quand l'app est en arrière-plan
- **Feedback sonore** pour confirmer l'ajout d'eau

### 🎨 Interface Moderne
- **Design "Liquid Glass"** avec animations fluides
- **Thème sombre/clair** adaptatif selon vos préférences système
- **Icône dynamique** dans la barre de menu (pourcentage ou jauge circulaire)
- **Interface native macOS** respectant les Human Interface Guidelines

### 🌍 Multilingue
- **9 langues supportées** : Français, Anglais, Espagnol, Allemand, Italien, Portugais, Néerlandais, Japonais, Chinois
- **Détection automatique** de la langue système
- **Changement de langue** à la volée

### 🔄 Fonctionnalités Avancées
- **Undo/Redo** (Cmd+Z) pour corriger les erreurs
- **Réinitialisation quotidienne** automatique à minuit
- **Historique persistant** sauvegardé localement
- **Mode Debug** pour les développeurs

## 📸 Captures d'écran

### Vue Principale
La vue principale affiche votre progression quotidienne avec une jauge circulaire animée, des presets rapides et un bouton "Hold-to-Add" pour un remplissage continu.

### Statistiques
Visualisez vos données sur 7 jours avec un graphique en barres et sur 30 jours avec une heatmap colorée montrant votre régularité.

### Réglages
Personnalisez votre expérience : objectif quotidien, unités (cl, L, oz), style d'icône, notifications, raccourcis clavier, et bien plus.

## 🚀 Installation

### Méthode 1 : Téléchargement Direct

1. Téléchargez le fichier `HydroBar-v1.0.dmg` depuis les [Releases](https://github.com/aedhx/HydroBar/releases)
2. Double-cliquez sur le DMG pour le monter
3. Glissez `HydroBar.app` dans le dossier Applications
4. Ouvrez Applications et lancez HydroBar
5. **Première ouverture** : Faites un clic droit sur l'application > **Ouvrir** (nécessaire car l'app n'est pas signée)

### Méthode 2 : Build depuis les Sources

```bash
# Cloner le repository
git clone https://github.com/aedhx/HydroBar.git
cd HydroBar/src/HydroBar

# Ouvrir dans Xcode
open HydroBar.xcodeproj

# Ou builder via script
./build-and-package.sh
```

## 💻 Prérequis

- **macOS 12.0** (Monterey) ou supérieur
- **Xcode 14.0+** (pour compiler depuis les sources)
- **Swift 5.0+**

## 🎮 Utilisation

### Première Configuration

1. **Autorisations** : Lors du premier lancement, accordez les permissions nécessaires :
   - **Notifications** : Préférences Système > Notifications
   - **Accessibilité** : Préférences Système > Sécurité et confidentialité > Accessibilité (pour les raccourcis clavier globaux)

2. **Configuration de l'objectif** : Ouvrez les Réglages et définissez votre objectif quotidien

3. **Personnalisation** : Ajustez les presets, les unités, et le style d'icône selon vos préférences

### Utilisation Quotidienne

- **Clic gauche** sur l'icône dans la barre de menu : Ouvre le panneau principal
- **Clic droit** sur l'icône : Menu contextuel rapide
- **Presets** : Cliquez sur un preset pour ajouter rapidement de l'eau
- **Hold-to-Add** : Maintenez le bouton pour un remplissage continu
- **Raccourcis clavier** : Utilisez vos raccourcis globaux configurés depuis n'importe où

## 🛠️ Technologies

- **SwiftUI** - Interface utilisateur moderne et déclarative
- **Combine** - Gestion réactive des états
- **UserNotifications** - Système de notifications local
- **AppKit** - Intégration native macOS
- **Swift Charts** - Visualisation des données
- **Carbon API** - Raccourcis clavier globaux
- **Intents Framework** - Synchronisation Focus Mode

## 📁 Structure du Projet

```
HydroBar/
├── src/HydroBar/
│   ├── HydroBar/
│   │   ├── HydroBarApp.swift          # Point d'entrée de l'application
│   │   ├── HydrationManager.swift     # Gestionnaire de données (MVVM)
│   │   ├── MainView.swift             # Vue principale
│   │   ├── ProgressRingView.swift     # Jauge circulaire
│   │   ├── SettingsView.swift         # Vue des réglages
│   │   ├── StatisticsView.swift       # Vue des statistiques
│   │   ├── StatsComponents.swift      # Composants de statistiques
│   │   ├── GlobalHotkeyManager.swift  # Gestion des raccourcis
│   │   ├── ShortcutRecorderView.swift # Enregistrement de raccourcis
│   │   ├── FocusModeMonitor.swift     # Surveillance Focus Mode
│   │   └── Localizable.xcstrings      # Fichier de localisation
│   ├── build-release.sh               # Script de build
│   ├── create-dmg.sh                  # Script de création DMG
│   └── build-and-package.sh           # Script tout-en-un
└── README.md                          # Ce fichier
```

## 🎨 Architecture

HydroBar suit le pattern **MVVM** (Model-View-ViewModel) :

- **Model** : `HydrationManager` - Gestion des données et de la logique métier
- **View** : Vues SwiftUI (`MainView`, `SettingsView`, `StatisticsView`, etc.)
- **ViewModel** : `HydrationManager` agit comme ViewModel via `@ObservableObject`

## 🌟 Fonctionnalités Clés Détailées

### Suivi Intelligent
- Réinitialisation automatique à minuit (heure locale)
- Historique persistant sauvegardé en JSON local
- Calcul automatique des statistiques (moyenne, total, streak)

### Notifications Adaptatives
- Mode "Ne pas déranger" : Affiche un badge au lieu de notifications système
- Synchronisation automatique avec le Focus Mode macOS
- Intervalles personnalisables (30 min, 1h, 2h, ou personnalisé)

### Raccourcis Clavier
- Enregistrement visuel des raccourcis dans les réglages
- Validation pour éviter les conflits avec les raccourcis système
- Feedback sonore lors de l'activation

## 🤝 Contribuer

Les contributions sont les bienvenues ! N'hésitez pas à :

1. **Fork** le projet
2. Créer une **branche** pour votre feature (`git checkout -b feature/AmazingFeature`)
3. **Commit** vos changements (`git commit -m 'Add some AmazingFeature'`)
4. **Push** vers la branche (`git push origin feature/AmazingFeature`)
5. Ouvrir une **Pull Request**

### Guidelines

- Suivez les conventions de code Swift
- Respectez les Human Interface Guidelines d'Apple
- Ajoutez des commentaires pour le code complexe
- Testez vos changements avant de soumettre

## 📝 Roadmap

- [ ] Synchronisation iCloud pour l'historique
- [ ] Widgets pour le Centre de notification
- [ ] Export des données (CSV, JSON)
- [ ] Intégration Apple Health
- [ ] Thèmes personnalisables
- [ ] Mode sombre/clair forcé

## 🐛 Signaler un Bug

Si vous rencontrez un bug, veuillez ouvrir une [issue](https://github.com/aedhx/HydroBar/issues) avec :
- Description détaillée du problème
- Étapes pour reproduire
- Version de macOS
- Captures d'écran si applicable

## 📄 Licence

Ce projet est sous licence MIT. Voir le fichier `LICENSE` pour plus de détails.

## 👤 Auteur

**Antoine DX**

- GitHub: [@aedhx](https://github.com/aedhx)
- Email: [Votre email]

## 🙏 Remerciements

- Apple pour SwiftUI et les frameworks macOS
- La communauté open source Swift
- Tous les contributeurs et testeurs

---

<div align="center">

**Fait avec ❤️ et 💧 pour macOS**

⭐ Si ce projet vous plaît, n'hésitez pas à lui donner une étoile !

[⬆ Retour en haut](#-hydrobar)

</div>
