# Backlog — HydroBar après la 2.0.1

État au 13 octobre 2026. Ce document dit ce qui vient ensuite, dans quel ordre et
pourquoi. Il remplace, pour la suite, le séquencement de
[ROADMAP_FONCTIONNALITES.md](ROADMAP_FONCTIONNALITES.md), qui reste la référence
détaillée de ce qui a été livré jusqu'à la 2.0 ; les identifiants `F…` y renvoient.

## Où on en est

- **2.0.1 publiée** sur GitHub, signée et notarisée, gratuite. Version Mac App
  Store (build 5) en attente de validation, à 1,99 €.
- **Livré depuis la 2.0** : journal des prises, rappels calés sur la journée,
  notifications actionnables, jours off, mode gourde, statistiques, Raccourcis et
  Siri, widget et bouton du Centre de contrôle (version du Store), export et
  sauvegarde, 9 langues, Réglages et Statistiques redessinés, landing page,
  extension Raycast 1.2.
- **Décisions actées** : macOS uniquement ; aucun compte, aucun serveur, aucune
  donnée collectée ; téléchargement direct gratuit et open source, Store payant
  une fois, sans abonnement.

Effort : **S** quelques heures, **M** quelques jours, **L** une à deux semaines,
**XL** au-delà. Valeur de ★ à ★★★★★.

---

## 1. Tout de suite — 2.0.2

Ce qui finit proprement la 2.0.1. Rien de neuf pour l'utilisateur, mais c'est ce
qui se voit.

| ID | Sujet | Pourquoi | Effort | Valeur |
|---|---|---|---|---|
| **B-01** | **Regarder la 2.0.1 à l'écran et corriger** : Réglages (verre, aperçus, teinte des interrupteurs), Statistiques, rendu sous macOS 26 et 27 | Ces écrans n'ont été jugés que sur des rendus hors écran. Le verre réel, les animations et le look du nouveau SDK n'ont pas été vus | S à M | ★★★★★ |
| **B-02** | **Captures de référence en CI** : un test qui rend chaque écran en clair et en sombre, et échoue si l'image change | Évite de refaire B-01 à la main à chaque version. C'était le dernier « reste » de la roadmap | M | ★★★★ |
| **B-03** | **Nom des touches dans les raccourcis** : une touche sans nom s'affiche « Key(67) » (`GlobalHotkeyManager.swift:37`), par exemple celles du pavé numérique | Défaut visible dans Réglages › Raccourcis | S | ★★★ |
| **B-04** | **À l'approbation d'Apple** : lien du Store sur le site (`APP_STORE_URL`) et dans le README, badge officiel « Download on the Mac App Store » | Le site annonce « Coming soon » | S | ★★★★★ |
| **B-05** | **Tester la build du Store sur TestFlight** : widget, bouton du Centre de contrôle, filtre de Concentration, reprise des données d'une installation DMG | Cette build n'a jamais été lancée ; la liste est au § 6 du [guide de publication](PUBLICATION_MAC_APP_STORE.md) | S | ★★★★★ |
| **B-06** | **Relecture native** des deux libellés ajoutés aux Réglages (« Shortcuts », « Menu bar icon ») et des mots-clés japonais et chinois de la fiche | Traduits sans relecteur natif | S | ★★ |
| **B-07** | **Extension Raycast** : joindre le zip 1.2 à une release, capture d'écran dans son README | Le zip des Releases date de février (1.0.0) | S | ★★ |
| **B-08** | **Retirer le renvoi `raycast-hydrobar/`** à la racine, une fois la 2.0.2 sortie | Il n'existe que pour le lien des versions ≤ 2.0.1 | S | ★ |
| **B-09** | **Liquid Glass sur les cartes des Réglages** (SDK 26) | Les presets l'ont, pas les cartes : le verre n'est pas le même d'un écran à l'autre sur macOS 26+ | S | ★★★ |
| **B-10** | **Tailles de texte dynamiques** (reste de F7) | Les jetons de `Theme.swift` existent ; les vues ne suivent pas encore le réglage du système | M | ★★★ |

---

## 2. Distribution — 2.1

Le téléchargement direct est signé, mais il reste en retrait de la version du
Store. C'est le chantier qui a le plus de valeur par ligne de code.

| ID | Sujet | Pourquoi | Effort | Valeur |
|---|---|---|---|---|
| **B-20** | **Widget et Centre de contrôle dans le téléchargement direct** : build Developer ID sandboxée, avec un profil qui autorise le groupe d'apps | macOS ne charge pas un widget hors sandbox : la version gratuite n'a ni widget ni bouton du Centre de contrôle. **Point dur** : passer en sandbox déplace les données ; il faut une migration testée depuis l'emplacement actuel | L | ★★★★ |
| **B-21** | **Mises à jour automatiques avec Sparkle** (F12) | Aujourd'hui la version directe ouvre une page web et laisse tout faire à la main. Le prérequis (app signée) est levé | M | ★★★★ |
| **B-22** | **Release en une étape** : signature et notarisation dans la CI, avec la clé d'API App Store Connect en secret | La notarisation se lance encore à la main depuis un Mac (`notarize-release.sh`) | M | ★★★ |
| **B-23** | **Build du Store depuis la CI** | Même raison ; et la CI est l'environnement où tout est validé | M | ★★ |
| **B-24** | **Homebrew** : `brew install --cask hydrobar` (F13) | Le public de l'app (raccourcis, Raycast) installe ainsi. Prérequis (notarisation) levé | S | ★★★ |

---

## 3. Produit — 2.x

| ID | Sujet | Pourquoi | Effort | Valeur |
|---|---|---|---|---|
| **B-30** | **Types de boissons** (F9) : café, thé, avec un coefficient ; l'eau reste à un clic | La question revient dans la FAQ du site. Le journal par prise le permet depuis la 2.0 | M | ★★★★ |
| **B-31** | **Fenêtre tableau de bord** (F16) : graphiques sur 3, 6 et 12 mois, filtres | Le popover fait 320 pt ; les statistiques y sont à l'étroit | L | ★★★ |
| **B-32** | **Raycast : état du jour et résultat réel** (« 250 ml · 1,6 L sur 2 L ») | Les liens `hydrobar://` ne répondent pas. Il faut un canal de lecture, fiable aussi avec la version sandboxée du Store | M | ★★★ |
| **B-33** | **Publier l'extension sur le Raycast Store** | Installation en un clic au lieu de `npm install` | S à M | ★★★ |
| **B-34** | **Barre de menus** (reste de F14) : molette pour ajuster, styles d'icône (goutte, texte compact) | Petits gestes pour les habitués | M | ★★ |
| **B-35** | **Plugin Stream Deck** (F15) | Les liens suffisent pour les boutons ; l'affichage du pourcentage sur la touche dépend de B-32 | M | ★★ |
| **B-36** | **Navigation au clavier dans le popover** (reste de F7) | Tout s'y fait encore à la souris | M | ★★★ |
| **B-37** | **Invitation à noter l'app**, version du Store uniquement, une fois, après une série de jours réussis | Les notes font la visibilité sur le Store. À faire sobrement, ou pas du tout | S | ★★★ |
| **B-38** | **Synchronisation iCloud entre deux Mac** (F11), privée, désactivée par défaut | Pour qui a un fixe et un portable. Le journal par prise rend la fusion possible. À n'ouvrir que si la demande existe | L | ★★★ |

---

## 4. Faire connaître

| ID | Sujet | Pourquoi | Effort | Valeur |
|---|---|---|---|---|
| **B-40** | **Lancement** : Product Hunt, annuaires (macosmenubar.com, AlternativeTo, listes « awesome macOS ») | À faire une fois le Store en ligne et B-01 passé | M | ★★★★ |
| **B-41** | **Article technique** : le bouton du Centre de contrôle sur macOS 26, ou la notarisation sans certificat local | Sujets peu documentés, lus par le public visé | S | ★★★ |
| **B-42** | **Fiche du Store** : vidéo d'aperçu, puis tests A/B des captures quand il y a du trafic | La fiche est en place ; l'optimiser demande des données | M | ★★★ |
| **B-43** | **Site en français**, puis dans les langues de l'app si le trafic le justifie | L'app parle 9 langues, le site une seule | M | ★★ |
| **B-44** | **Setapp** | Un revenu sans gérer la facturation. À étudier après le Store | M | ★★ |
| **B-45** | **GitHub Sponsors** | Coût nul, cohérent avec la version gratuite | S | ★ |

Mesure : aucune télémétrie dans l'app, et cela ne change pas. Les chiffres
viennent d'App Store Connect et des téléchargements GitHub.

---

## 5. Technique

| ID | Sujet | Pourquoi | Effort |
|---|---|---|---|
| **B-50** | **Injection de dépendances de `HydrationManager`** | Dernier point ouvert de l'[audit](AUDIT_TECHNIQUE.md) (seconde moitié de P3-1) : le singleton rend la logique d'état difficile à tester | M |
| **B-51** | **CI sur le SDK macOS 27** en plus du 26 | La build du Store 2.0.1 sort de Xcode 27, que la CI n'exerce pas | S |
| **B-52** | **Avertissements SwiftLint** : 19, dont 6 lignes trop longues et 2 fichiers trop gros | Les garder sous contrôle avant qu'ils ne s'accumulent | S |
| **B-53** | **Scripts** : `hdiutil attach`, `detach` et `convert` sont annoncés obsolètes sous macOS 27 | `package-dmg.sh` et le workflow Release les utilisent | S |
| **B-54** | **Tests d'interface** réels à la place des gabarits Xcode | Ils sont ignorés par la CI : ils ne testent rien | M |

---

## Ordre conseillé

1. **2.0.2** : B-01, B-03, B-04, B-05, puis B-02 pour ne plus refaire B-01 à la main.
2. **2.1** : B-21 et B-24 d'abord (petits, et ils changent l'installation et les
   mises à jour), puis B-20, le gros morceau, avec sa migration de données.
3. **Lancement** : B-40 et B-41, une fois le Store en ligne et la 2.1 sortie.
4. **2.2** : B-30, la fonction la plus demandée, puis B-32 et B-33 pour Raycast.
5. Le reste selon les retours.

## Ce qu'on ne fera pas

Inchangé, et pour les mêmes raisons que dans la roadmap :

- **Pas d'abonnement.** Un prix, une fois.
- **Pas de compte ni de serveur.** Si une synchronisation existe un jour, elle
  passe par l'iCloud privé de l'utilisateur.
- **Pas d'app iOS ni Apple Watch** pour l'instant : c'est un autre produit. Sans
  elles, pas d'Apple Santé, qui n'est pas accessible aux apps Mac.
- **Pas de gamification** au-delà de la série de jours.
- **Pas d'objectif calculé d'après la météo ou l'activité** : des permissions et
  une API externe pour un gain marginal.
- **Pas de rappels insistants** (blocage d'écran, vérifications).
- **Pas de nouvelles langues** sans demande : chaque langue alourdit chaque
  future chaîne.
