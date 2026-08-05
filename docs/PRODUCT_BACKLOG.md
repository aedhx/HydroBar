# HydroBar — Backlog produit & analyse de marché

**Auteur :** Head of Product
**Date :** août 2026
**Version du produit analysée :** v1.2 (widgets développés mais retirés de la release — commit `c84b203`)
**Statut :** proposition de roadmap, à arbitrer

---

## 0. TL;DR — la thèse

HydroBar n'est pas une app de rappel d'hydratation. C'est **le premier micro-tracker clavier-first du menu bar macOS** — et c'est une catégorie que personne n'occupe.

Les concurrents hydratation vendent de la culpabilité (notifications, écrans qui prennent le Mac en otage). HydroBar vend autre chose, sans encore le savoir : **une entrée de données en 80 ms, sans quitter le clavier, sans compte, sans cloud.** Raccourcis globaux + Raycast + Stream Deck, ça n'existe nulle part ailleurs sur ce segment. C'est ça, l'actif.

La thèse en une phrase :

> **Le geste de log doit coûter zéro, et la donnée doit vous appartenir. Le reste (les stats, les rappels, les widgets) découle de ces deux promesses.**

Trois choses bloquent aujourd'hui la montée en puissance, et aucune n'est un problème de features :

1. **La distribution.** L'app n'est pas notarisée. Le README demande à l'utilisateur de taper `xattr -cr` dans un Terminal. On perd la majorité des installeurs entre le téléchargement et le premier lancement — c'est le plus gros trou du tunnel, et le moins cher à boucher (99 $/an).
2. **Le modèle de données.** HydroBar stocke *combien d'eau aujourd'hui*. Il ne sait ni **quand** ni **quoi**. Sans horodatage par prise, on ne peut construire ni les insights, ni l'export, ni la sync, ni Apple Health. Tout l'étage supérieur du backlog repose sur cette fondation.
3. **L'historique est détruit à 30 jours** (`HydrationManager.swift:586-589`). On ne peut pas vendre « vos données vous appartiennent » en les supprimant tous les mois.

Corrigez ces trois points et le reste du backlog devient exécutable. Ne les corrigez pas, et chaque feature ajoutée s'empile sur du sable.

---

## 1. Analyse de marché

### 1.1 Le marché réel : deux marchés, pas un

Il faut distinguer deux dynamiques qu'on confond souvent.

**Marché A — « apps d'hydratation ».** Encombré, commoditisé, prix cassés. C'est un marché de features, gagné par celui qui a le meilleur ASO et la plus jolie animation de verre d'eau. On n'y gagne pas quand on est un dev solo open source.

**Marché B — « menu bar utilities pour power users Mac ».** C'est là que se trouvent Ice, Bartender, iStat Menus, Dato, Amphetamine, Stats. Ce marché a des caractéristiques radicalement différentes : les utilisateurs paient volontiers 10-30 $ en one-time, ils sont distribués par Homebrew, Product Hunt, Hacker News et Reddit r/macapps, ils valorisent l'open source, la légèreté et l'absence de compte. Setapp (250+ apps, revenue-share à l'usage) est un canal réel pour ce segment.

**HydroBar est aujourd'hui vendu comme une app du marché A alors qu'il est construit comme une app du marché B.** C'est le repositionnement central que je propose.

### 1.2 Paysage concurrentiel — hydratation sur macOS

| Produit | Modèle | Positionnement | Faiblesse exploitable |
|---|---|---|---|
| **WaterMinder** | ~4,99 $ one-time (Mac), écosystème iOS/Watch payant | Le leader multi-plateforme. Sync Apple Health, types de boissons, nutriments | Mac = citoyen de seconde zone, pas de logique clavier, pas d'ouverture développeur |
| **TakeSip** | Freemium, essai 2 semaines | Le plus proche concurrent direct menu bar, marketing soigné (site, guides, calculateur) | Reviews App Store qui remontent des **prompts d'upgrade insistants** — angle mort évident pour un concurrent gratuit et honnête |
| **Water Drop: Menu Bar Tracker** | 2,99 $ one-time, sans abonnement | Le minimaliste pur | Trop peu de valeur pour être défendable ; peu ou pas de traction |
| **Just Drink** | Mac + Windows, signaux visuels/sonores | « Ne loguez rien, buvez juste » | Ne track pas → pas de stats, pas de streak, pas de rétention |
| **Hydration Hostage** | Indie, agressif | Prend l'écran en otage jusqu'à confirmation caméra | Hostile ; ne survit pas à une semaine d'usage réel |
| **Viraam** | 14,99 $ early adopter, essai 14 j | Bien-être global : étirements, eau, marche, méditation, sommeil | Généraliste → pas excellent sur l'hydratation ; valide surtout un **prix à deux chiffres accepté sur ce segment** |
| **Mizu** (open source) | Gratuit, GitHub | Rappel minimaliste | Pas maintenu au niveau produit, aucune ambition d'écosystème |

**Ce que ce tableau dit :**

- Le prix d'ancrage sur macOS va de **2,99 $ à 14,99 $ en one-time**. Personne n'a réussi l'abonnement sur ce segment — TakeSip s'y frotte et se fait sanctionner en reviews.
- **Personne n'est ouvert.** Aucun concurrent n'expose de raccourcis globaux, d'extension Raycast, de plugin Stream Deck, d'App Intents ou de CLI. HydroBar a déjà deux de ces cinq briques.
- **Personne n'est crédible sur la privacy** au-delà du discours. HydroBar est MIT, 100 % local, auditable. C'est un argument de vente, pas une note de bas de page.
- **Personne n'exploite les nouvelles surfaces macOS.** Depuis macOS 26 Tahoe, les apps tierces peuvent publier des **contrôles Control Center**, épinglables directement dans le menu bar, pilotables par Shortcuts et par automatisation. La couverture presse note que **très peu de développeurs les ont adoptés, et que ceux qui essaient galèrent.** C'est une fenêtre d'opportunité qui se referme : premier arrivé, premier référencé.

### 1.3 Contexte plateforme (à jour août 2026)

- **macOS 27 « Golden Gate »** affine Liquid Glass : slider de transparence utilisateur, bords assombris, meilleurs contrastes, coins arrondis cohérents. Concrètement : une icône de menu bar dessinée en `Path` custom avec des couleurs en dur (`HydroBarApp.swift`, `ProgressRingView.swift`) **va mal vieillir**. Il y a un travail d'adaptation à planifier, pas à subir.
- **HealthKit n'existe pas sur macOS.** C'est le point le plus important de cette section. La roadmap actuelle du README promet « Health app integration », et un commit récent a ajouté les clés d'usage HealthKit au projet (`da9678e`) — c'est une impasse. La seule voie réelle passe par une **app compagnon iOS + CloudKit**, ou par un **export lisible par Shortcuts**. Il faut soit financer la voie longue, soit retirer la promesse.
- **La distribution est un projet en soi.** L'état de l'art indie 2026 (Developer ID + notarisation + Sparkle + appcast + cask Homebrew) représente couramment **20 à 30 % du temps total** d'un projet Mac. Ce n'est pas une tâche de fin de sprint.
- **Setapp** propose désormais, depuis février 2026, de l'achat individuel (mensuel, annuel ou one-time) en plus du bundle — le canal s'est ouvert aux petits éditeurs. Revenu partagé à l'usage, avec un **délai de 2 à 2,5 mois** avant encaissement des nouveaux utilisateurs.

### 1.4 Positionnement recommandé

> **HydroBar — the fastest way to log anything on your Mac. Starting with water.**
>
> Open source. 100 % local. Deux touches. Rien à installer, personne à qui rendre de comptes.

Trois piliers de différenciation, dans cet ordre :

1. **Vitesse d'entrée** (raccourcis globaux, Raycast, Stream Deck, Control Center, Shortcuts) — défendable, déjà amorcé, personne ne suit.
2. **Souveraineté des données** (local-first, export, MIT) — défendable, gratuit à tenir, devient un argument fort à mesure que les concurrents ajoutent des comptes.
3. **Insight honnête** (pas de gamification infantilisante, des stats qui apprennent quelque chose) — différenciant sur un segment saturé d'émojis.

L'ambition long terme, à garder en tête sans la promettre : la mécanique de log ultra-rapide n'a rien de spécifique à l'eau. Café, pas, pauses, doses de médicament, cigarettes — **HydroBar peut devenir un moteur de micro-tracking**. On ne le construit pas maintenant, mais **toutes les décisions d'architecture du backlog ci-dessous laissent la porte ouverte** (d'où l'insistance sur le modèle de données horodaté et typé).

---

## 2. État des lieux technique — ce qui cadre le rêve

Audit du code au 05/08/2026. Ces constats déterminent l'ordre du backlog.

| # | Constat | Emplacement | Conséquence produit |
|---|---|---|---|
| T1 | **Aucune granularité temporelle** : seul le total du jour est stocké | `HydrationManager.swift` (`currentMl`, `HistoryEntry`) | Bloque insights horaires, export sérieux, Health, types de boissons |
| T2 | **Historique purgé à 30 jours** (et 7 jours pour le legacy) | `HydrationManager.swift:586-589`, `:636-642` | Détruit la donnée utilisateur ; incompatible avec « vos données vous appartiennent » |
| T3 | **Deux stores parallèles** : `DailyEntry` (legacy) + `HistoryEntry` | `HydrationManager.swift:501-660` | Double écriture, risque de divergence, dette pure |
| T4 | **Réécriture JSON intégrale à chaque mutation**, déclenchée par le `didSet` de `currentMl` | `HydrationManager.swift:166-175` | En Hold-to-Add (20 Hz), écritures disque en rafale — batterie et SSD |
| T5 | **L'enum `AppUnit` ne contient que `cl`, `L`, `oz`** alors que le README promet ml et fl oz | `HydrationManager.swift:41-79` vs `README.md:32` | Promesse non tenue ; le **ml est l'unité par défaut de la majorité du monde**, son absence est un frein à l'adoption internationale |
| T6 | **`oz` = 29,57 ml** (once US) sans distinction UK | `HydrationManager.swift:54` | Valeurs fausses pour les utilisateurs britanniques |
| T7 | **Deux `Timer` à 60 s tournant en permanence** | `HydrationManager.swift:305-327` | Empêche l'App Nap, coût énergétique inutile pour une app résidente |
| T8 | **Pas de mise à jour automatique** : `GitHubUpdateChecker` notifie, l'utilisateur doit re-télécharger un DMG et refaire `xattr -cr` | `GitHubUpdateChecker.swift` | Le parc reste bloqué en vieilles versions → chaque amélioration n'atteint personne |
| T9 | **App non signée Developer ID, non notarisée** | `build-dmg.sh`, `README.md:100-113` | Le tueur de conversion n°1 |
| T10 | **App Group `group.com.adxcool.HydroBar`** requis par le widget | `AppGroupStore.swift:41` | Nécessite un compte développeur payant → dépendance dure vers E0 |
| T11 | **Widget fonctionnel mais retiré de la release** | commit `c84b203` | Valeur déjà payée, non encaissée |
| T12 | **Extension Raycast non publiée au store** : installation manuelle en 4 étapes dont un `npm run dev` à laisser tourner | `README.md:159-166` | Adoption proche de zéro alors que c'est un différenciateur majeur |
| T13 | **Couverture de tests quasi nulle** | `HydroBarTests/` | Toute refonte du modèle de données est risquée sans filet |
| T14 | **Accessibilité non traitée** (VoiceOver sur l'anneau, contrastes, Reduce Motion) | vues SwiftUI | Bloque le référencement « qualité » et exclut des utilisateurs |

---

## 3. Le backlog

**Échelle d'effort** (dev solo, temps partiel) : **S** ≤ 1 j · **M** 2-4 j · **L** 1-2 sem · **XL** > 2 sem
**Impact** : ⭐ à ⭐⭐⭐⭐⭐ (⭐⭐⭐⭐⭐ = débloque le produit ou la croissance)

---

### E0 — Le socle de distribution *(« personne ne peut aimer une app qu'il n'arrive pas à ouvrir »)*

C'est l'epic à faire en premier. Rien d'autre ne compte tant qu'il n'est pas fait.

| ID | Feature | Problème résolu | Effort | Impact | Notes |
|---|---|---|---|---|---|
| **E0-1** | **Apple Developer Program + signature Developer ID + notarisation** | L'utilisateur voit « app endommagée » et abandonne | M | ⭐⭐⭐⭐⭐ | 99 $/an. Débloque aussi E0-2, T10 (App Group → widgets), et l'accès Mac App Store / Setapp |
| **E0-2** | **Sparkle 2 + appcast signé EdDSA** | Le parc est gelé sur d'anciennes versions (T8) | M | ⭐⭐⭐⭐⭐ | Remplace `GitHubUpdateChecker` par une vraie MAJ en un clic. Appcast hébergeable sur GitHub Pages |
| **E0-3** | **Pipeline de release automatisé** (GitHub Actions : build → sign → notarize → staple → DMG → appcast → release) | Chaque release coûte une soirée et des erreurs | M | ⭐⭐⭐⭐ | Rend le rythme de livraison soutenable — prérequis d'une roadmap ambitieuse |
| **E0-4** | **Cask Homebrew officiel** (`brew install --cask hydrobar`) | Canal d'acquisition n°1 des power users Mac | S | ⭐⭐⭐⭐ | Dépend de E0-1 (les casks non signés sont mal vus) |
| **E0-5** | **Landing page** (hydrobar.app) : hero, GIF de 6 s du raccourci clavier, download, privacy | Le README GitHub ne convertit pas un non-développeur | M | ⭐⭐⭐⭐ | Le GIF du log au clavier **est** le pitch. À faire avant tout lancement Product Hunt |
| **E0-6** | **Réécriture du README orientée produit** + suppression de la promesse « Health app integration » (§1.3) | Promesse intenable en tête de roadmap publique | S | ⭐⭐ | Honnêteté = capital sur ce segment |

**Sortie de l'epic :** un utilisateur non technique installe HydroBar en deux clics et reçoit les mises à jour automatiquement.

---

### E1 — Le socle de données *(« on ne peut pas construire d'insight sur un compteur »)*

Refonte invisible pour l'utilisateur, mais qui conditionne les epics E3, E4, E5 et toute extension du produit.

| ID | Feature | Problème résolu | Effort | Impact | Notes |
|---|---|---|---|---|---|
| **E1-1** | **Modèle `IntakeEvent` horodaté** : `{id, timestamp, amountMl, source, kind}` — event log append-only, agrégats dérivés | T1, T3 — le produit ne sait ni quand ni quoi | L | ⭐⭐⭐⭐⭐ | **La pierre angulaire.** `source` = ring/hotkey/raycast/widget/shortcut → alimente aussi les stats d'usage. `kind` prépare les types de boissons sans les livrer |
| **E1-2** | **Historique illimité + migration transparente** depuis `history.json` / `historyEntries.json` | T2 — destruction de données | M | ⭐⭐⭐⭐⭐ | Passage à un stockage par fichier mensuel ou SQLite. Migration obligatoirement non destructive, testée |
| **E1-3** | **Persistance débouncée & écriture incrémentale** | T4 — écritures en rafale à 20 Hz | S | ⭐⭐⭐ | Sortir `saveTodayEntry()` du `didSet`, batcher à 1 Hz |
| **E1-4** | **Unités complètes : ml, cl, L, US fl oz, UK fl oz** + refonte du formatage | T5, T6 — promesse README non tenue, valeurs fausses au UK | S | ⭐⭐⭐⭐ | **Le ml manquant est un frein d'adoption internationale direct**, pas un détail cosmétique |
| **E1-5** | **Suite de tests sur le modèle** (agrégation, streak, reset de minuit, changement de fuseau, migration) | T13 — refonte à l'aveugle | M | ⭐⭐⭐ | Le reset de minuit et les fuseaux horaires sont les bugs classiques de cette catégorie d'app |
| **E1-6** | **Passage en App Nap-friendly** : timers remplacés par une planification événementielle | T7 — coût énergétique permanent | S | ⭐⭐ | Argument marketing réel sur macOS (« 0 % CPU au repos ») |

**Sortie de l'epic :** HydroBar sait **quand** chaque gorgée a été prise, **d'où** elle a été loguée, et ne perd plus jamais une donnée.

---

### E2 — Ubiquité *(« être là où la main de l'utilisateur se trouve déjà »)*

C'est l'epic qui crée la différenciation défendable. Aucun concurrent n'est présent sur ces surfaces.

| ID | Feature | Problème résolu | Effort | Impact | Notes |
|---|---|---|---|---|---|
| **E2-1** | **Sortir les widgets** (Small + Medium, bouton d'ajout interactif) | T11 — valeur développée non livrée | S | ⭐⭐⭐⭐ | Le code existe (`HydroBarWidget.swift`, `AddWaterIntent.swift`, `AppGroupStore.swift`). Déblocage = E0-1. **Le meilleur ratio effort/impact du backlog** |
| **E2-2** | **Contrôles Control Center + menu bar (App Intents)** | Fenêtre d'opportunité macOS 26/27 : peu de devs l'ont fait (§1.2) | M | ⭐⭐⭐⭐⭐ | « Add 25 cl » épinglable dans le Control Center, pilotable en automatisation. **Ticket de presse et d'ASO à lui seul** |
| **E2-3** | **Actions Shortcuts complètes** : Add Water, Get Today's Intake, Get Progress, Set Goal, Undo | Ouvre HydroBar à toute la mécanique d'automatisation macOS | M | ⭐⭐⭐⭐ | Ex. « au démarrage du Mac, log 25 cl » ou intégration Focus/Calendrier faite par l'utilisateur — on ne code pas, on ouvre |
| **E2-4** | **Publier l'extension Raycast au Raycast Store** | T12 — 4 étapes d'install manuelle aujourd'hui | S | ⭐⭐⭐⭐ | Le code est écrit. Le store Raycast est un canal d'acquisition qualifié et gratuit |
| **E2-5** | **URL scheme + CLI** (`hydrobar://add?ml=250`, `hydrobar add 250`) | Rend HydroBar scriptable, intégrable partout | S | ⭐⭐⭐ | Coût dérisoire, adoré par le public cible, alimente les posts HN/Reddit |
| **E2-6** | **Plugin Stream Deck officiel** | Aujourd'hui l'intégration passe par des raccourcis clavier bricolés | M | ⭐⭐⭐ | Dépend de E2-5. Présence dans le Elgato Marketplace = nouveau canal |
| **E2-7** | **Menu bar : mode « discret »** (icône seule, sans anneau) + adaptation Liquid Glass macOS 27 | §1.3 — le dessin custom vieillira mal | M | ⭐⭐⭐ | Les utilisateurs de menu bar apps sont obsédés par l'espace dans leur barre |

**Sortie de l'epic :** HydroBar est loguable depuis 7 surfaces différentes. C'est la phrase de positionnement qui devient vraie.

---

### E3 — Insight & souveraineté des données *(« la donnée doit vous rendre quelque chose »)*

Dépend entièrement de E1.

| ID | Feature | Problème résolu | Effort | Impact | Notes |
|---|---|---|---|---|---|
| **E3-1** | **Export CSV / JSON** (période sélectionnable, événements bruts) | Roadmap README déjà promise ; pilier « vos données vous appartiennent » | S | ⭐⭐⭐⭐ | Trivial une fois E1-1 fait. À mettre en avant sur la landing |
| **E3-2** | **Vue « rythme de la journée »** : distribution horaire des prises, détection des trous (ex. 14 h-18 h) | La vraie question n'est pas *combien* mais *quand vous décrochez* | M | ⭐⭐⭐⭐ | **Le premier insight que les concurrents ne peuvent pas produire** — ils n'ont pas la donnée |
| **E3-3** | **Historique longue durée** : vues mois / année, heatmap 365 j, records personnels | E1-2 débloque enfin la profondeur | M | ⭐⭐⭐ | Rétention : donne une raison de rester après 30 jours |
| **E3-4** | **Récap hebdomadaire** (notification du dimanche + vue dédiée) : tendance, meilleur jour, comparaison S-1 | Crée un rendez-vous récurrent = rétention | M | ⭐⭐⭐⭐ | Le pattern de rétention le plus éprouvé du quantified self, sans gamification |
| **E3-5** | **Streaks & jalons sobres** (7/30/100 jours), célébration discrète, jamais culpabilisante | Motivation sans infantilisation | S | ⭐⭐ | `currentStreak` existe déjà. **Garde-fou : pas de badges, pas d'emojis criards** — c'est un choix de marque |
| **E3-6** | **Objectif adaptatif** : calcul assisté (poids, activité, climat) au lieu des 2000 ml en dur | Le défaut à 2000 ml est faux pour la plupart des gens | S | ⭐⭐⭐ | À placer dans l'onboarding (E4-1) |
| **E3-7** | **Export au format lisible par Apple Santé** via Shortcuts / fichier | Contournement honnête de l'absence de HealthKit sur macOS (§1.3) | M | ⭐⭐⭐ | **Remplace la promesse intenable de la roadmap actuelle.** À communiquer clairement comme un pont, pas une sync |

---

### E4 — Le rituel intelligent *(« un rappel ignoré est pire que pas de rappel »)*

| ID | Feature | Problème résolu | Effort | Impact | Notes |
|---|---|---|---|---|---|
| **E4-1** | **Onboarding en 3 écrans** : objectif, unité, un premier raccourci clavier configuré | Aujourd'hui l'utilisateur arrive dans une app vide sans savoir que le clavier est la killer feature | M | ⭐⭐⭐⭐⭐ | **Le taux de configuration d'un raccourci au J1 est le meilleur prédicteur de rétention à J7.** À instrumenter dès sa sortie |
| **E4-2** | **Presets personnalisables** (montant, libellé, icône) | Roadmap README ; les 200/500/750 ml en dur ne correspondent à aucune vraie bouteille | S | ⭐⭐⭐ | `presetsMl` est déjà un tableau — c'est surtout de l'UI |
| **E4-3** | **Rappels contextuels** : plage horaire active, silence hors des heures de travail, pause quand le Mac est verrouillé/idle | Un rappel à 23 h détruit la confiance et fait désinstaller | M | ⭐⭐⭐⭐ | `FocusModeMonitor` existe déjà — il faut y ajouter idle et plage horaire |
| **E4-4** | **Rappels adaptatifs** : intervalle ajusté selon le retard sur l'objectif et le rythme historique | Un intervalle fixe est faux par construction | M | ⭐⭐⭐⭐ | Dépend de E1-1. **Heuristique explicable, pas de « IA »** — la boîte noire tue la confiance sur ce segment |
| **E4-5** | **Silence pendant les réunions** (EventKit, calendrier) | Notification pendant un call = désinstallation | M | ⭐⭐⭐ | Demande une permission ; à rendre strictement optionnelle et expliquée |
| **E4-6** | **Snooze & actions riches** dans la notification (snooze 15/30 min, log direct de chaque preset) | Aujourd'hui une seule action « Drink a glass » | S | ⭐⭐ | Amélioration de l'existant (`setupNotificationCategories`) |
| **E4-7** | **Accessibilité** : VoiceOver sur l'anneau et les stats, Reduce Motion, contrastes AA | T14 — exclusion d'utilisateurs, blocage de mise en avant éditoriale | M | ⭐⭐⭐ | Prérequis de fait pour un featuring App Store / Setapp |

---

### E5 — Sync & multi-appareil *(le rêve, cadré)*

**Attention : c'est l'epic qui peut faire dérailler le produit.** Il est structurellement plus coûteux que tous les autres réunis, et il attaque frontalement WaterMinder sur son terrain. Je le recommande **seulement si E0→E4 sont livrés et que la traction le justifie.**

| ID | Feature | Problème résolu | Effort | Impact | Notes |
|---|---|---|---|---|---|
| **E5-1** | **Sync CloudKit Mac ↔ Mac** (privée, chiffrée, optionnelle, désactivée par défaut) | Les power users ont souvent un portable + un fixe | L | ⭐⭐⭐ | Reste compatible avec la promesse privacy (**iCloud privé de l'utilisateur, pas nos serveurs**). Dépend de E1-1 (résolution de conflits sur event log = simple ; sur compteur = impossible) |
| **E5-2** | **App compagnon iOS minimale** | Seule voie d'accès réelle à HealthKit (§1.3) + log en mobilité | XL | ⭐⭐⭐ | Change la nature du projet : nouvelle app, nouveau cycle de review, nouveau support. **À traiter comme une décision d'entreprise, pas comme un ticket** |
| **E5-3** | **Sync HealthKit via le compagnon iOS** | Tient enfin la promesse historique | L | ⭐⭐⭐ | Strictement dépendant de E5-2 |
| **E5-4** | **Complication Apple Watch** | Le geste le plus naturel : loguer au poignet | L | ⭐⭐ | Dépendant de E5-2. Territoire WaterMinder — n'y aller qu'avec un avantage clair |

---

### E6 — Monétisation *(« financer la suite sans trahir la promesse »)*

Recommandation : **le cœur reste gratuit et open source. Le confort se paie une fois.** Pas d'abonnement — le marché l'a déjà sanctionné (§1.2).

| ID | Feature | Problème résolu | Effort | Impact | Notes |
|---|---|---|---|---|---|
| **E6-1** | **HydroBar Pro — licence one-time (~9,99 $)** : historique longue durée, insights avancés, export, sync, presets illimités | Financer les 99 $/an et le temps de dev | L | ⭐⭐⭐⭐ | Positionnement de prix entre Water Drop (2,99 $) et Viraam (14,99 $). Paddle ou Lemon Squeezy pour la TVA. **Le tracking et les rappels restent gratuits, à vie, sans nag screen** — c'est la réponse directe aux reviews de TakeSip |
| **E6-2** | **Candidature Setapp** | Revenu récurrent sans gérer paiement ni support de facturation | M | ⭐⭐⭐ | Canal ouvert aux petits éditeurs depuis février 2026. **Prévoir 2 à 2,5 mois de délai d'encaissement** dans le plan de trésorerie |
| **E6-3** | **Publication Mac App Store** (version gratuite ou Pro) | ASO et découverte organique — le canal où les concurrents sont référencés | M | ⭐⭐⭐ | Impose le sandbox : à valider tôt contre les raccourcis globaux (`GlobalHotkeyManager`) et l'accès Accessibilité |
| **E6-4** | **GitHub Sponsors / « buy me a bottle »** | Monétisation immédiate, coût nul | S | ⭐ | À mettre en place tout de suite, en attendant E6-1 |

---

### E7 — Croissance *(exécuter le lancement, pas seulement le produit)*

| ID | Action | Effort | Impact | Notes |
|---|---|---|---|---|
| **E7-1** | **Lancement Product Hunt** — angle « the fastest way to log water on a Mac, without touching your mouse » | M | ⭐⭐⭐⭐ | À déclencher **après** E0 + E2-1/E2-2/E2-4, jamais avant |
| **E7-2** | **Post technique** : « Comment j'ai branché HydroBar sur les contrôles Control Center de macOS 26 » | S | ⭐⭐⭐ | Peu de devs l'ont fait → article rare → HN/Reddit/newsletters Swift |
| **E7-3** | **Référencement dans les annuaires** (macosmenubar.com, alternativeto, awesome-macos-apps) | S | ⭐⭐ | Long tail SEO gratuite |
| **E7-4** | **Instrumentation d'usage locale et opt-in** (aucun envoi par défaut, agrégats anonymes) | M | ⭐⭐⭐ | **Contrainte de marque : le default est OFF, et le code est auditable.** Sans mesure, tout le reste de ce document est de l'opinion |

---

## 4. Séquencement proposé

### v1.3 — « Ça s'installe, ça se met à jour, c'est partout » *(~4-6 semaines)*
`E0-1 → E0-2 → E0-3 → E0-4 → E2-1 → E2-4 → E1-4 → E0-5 → E0-6`

C'est la release qui rend le produit **distribuable**. Elle encaisse le travail widget déjà payé (`c84b203`) et publie l'extension Raycast. Aucune feature spectaculaire — et c'est celle qui change le plus de choses.

### v1.4 — « Le socle de données & le rituel » *(~6-8 semaines)*
`E1-1 → E1-2 → E1-3 → E1-5 → E1-6 → E4-1 → E4-2 → E4-3 → E3-1`

Refonte du modèle, onboarding, rappels qui respectent la vie de l'utilisateur, export. Peu visible, indispensable.

### v1.5 — « Ubiquité & insight » *(~6-8 semaines)* — **la release qu'on lance publiquement**
`E2-2 → E2-3 → E2-5 → E3-2 → E3-3 → E3-4 → E4-7 → E7-1 → E7-2`

Control Center, Shortcuts, CLI, rythme de la journée, récap hebdo, accessibilité. **C'est la version dont on parle sur Product Hunt.**

### v2.0 — « Pro & continuité » *(à arbitrer sur données)*
`E6-1 → E6-2 → E5-1 → E3-7 → E2-6 → E6-3`

Monétisation, sync entre Macs, pont Apple Santé. **E5-2/E5-3/E5-4 (iOS + Watch) restent hors roadmap** tant qu'un signal de traction ne les justifie pas.

---

## 5. Mesure du succès

**North Star : nombre d'utilisateurs qui loguent au moins une fois par jour, 5 jours sur 7.** Pas les téléchargements, pas les stars GitHub — ces deux métriques mesurent la curiosité, pas la valeur.

| Métrique | Pourquoi elle compte | Où elle se joue |
|---|---|---|
| **Taux d'activation J1** (a lancé ET logué ET défini un objectif) | Mesure la friction d'installation et d'onboarding | E0-1, E4-1 |
| **% d'utilisateurs ayant configuré ≥1 raccourci à J7** | Le meilleur proxy de rétention long terme sur ce produit | E4-1 |
| **Logs par jour actif** | Un utilisateur qui logue 5×/jour est un utilisateur qui reste | E2-* (l'ubiquité fait mécaniquement monter ce chiffre) |
| **Répartition des logs par `source`** | Dit **objectivement** quelles surfaces méritent l'investissement suivant | E1-1 (le champ `source`), E7-4 |
| **Rétention J30** | La seule métrique qui compte pour arbitrer E5/E6 | tout |

---

## 6. L'anti-backlog — ce qu'on ne fera pas, et pourquoi

Un backlog crédible se juge autant à ce qu'il refuse.

- **Pas d'abonnement.** Le segment l'a déjà sanctionné en reviews. One-time ou rien.
- **Pas de compte utilisateur, pas de serveur.** La sync passe par l'iCloud privé de l'utilisateur ou n'existe pas. C'est le pilier n°2 du positionnement — le compromettre coûterait plus que tout ce qu'il rapporterait.
- **Pas de coach IA / chatbot hydratation.** Aucune valeur ajoutée, coût récurrent, contradiction frontale avec le local-first.
- **Pas de gamification lourde** (avatars, badges, niveaux, plantes qui meurent). Le public cible — power users Mac — la rejette. Streaks sobres : oui. Confettis : non.
- **Pas de social / leaderboard / challenges d'équipe.** L'angle B2B wellness est réel mais exige comptes, serveurs et RGPD — un autre produit, une autre entreprise. À ne rouvrir que sur demande entrante répétée.
- **Pas de rappels agressifs** (blocage d'écran, vérification caméra). Un concurrent le fait ; c'est son plafond de verre, pas son avantage.
- **Pas de Windows / Linux.** La force du produit est son intégration macOS profonde. Un port la dilue.
- **Pas de suivi nutritionnel généralisé** (calories, macros). C'est un autre marché, avec d'autres concurrents et d'autres exigences réglementaires.

---

## 7. Les trois arbitrages que j'attends de vous

1. **Financer E0-1 (99 $/an) — oui ou non ?** Toute la roadmap en dépend : notarisation, widgets (App Group), Setapp, App Store. C'est la décision la moins chère et la plus structurante du document.
2. **Assumer le repositionnement « micro-tracker clavier-first » ?** Il implique d'investir E2 (ubiquité) avant E3 (stats) — l'inverse de l'intuition, et l'inverse de ce que fait la concurrence.
3. **iOS : dedans ou dehors ?** C'est la seule voie vers Apple Santé et Apple Watch, et c'est un changement d'échelle du projet (E5-2, XL). Ma recommandation : **dehors pour l'instant**, et retirer la promesse Health du README d'ici là (E0-6).

---

## Sources

Analyse de marché appuyée sur :

- [MenuBarApps — Best macOS Menu Bar Apps Directory 2026](https://www.macosmenubar.com/)
- [TakeSip — site officiel](https://takesip.com/) et [fiche Mac App Store](https://apps.apple.com/us/app/takesip-best-water-reminder/id6479617048?mt=12)
- [Water Drop: Menu Bar Tracker — Mac App Store](https://apps.apple.com/app/id6759446769)
- [WaterMinder — Mac App Store](https://apps.apple.com/us/app/waterminder/id1415257369?mt=12) et [waterminder.com](https://waterminder.com/)
- [Just Drink](https://just-drink.app/) · [Mizu (open source)](https://github.com/esoxjem/Mizu)
- [Digital Trends — Hydration Hostage](https://www.digitaltrends.com/computing/this-new-mac-app-takes-your-screen-hostage-until-you-drink-water/)
- [LookAway — Best Break Reminder Apps for Mac in 2026 (Viraam)](https://lookaway.com/blog/2026/04/24/best-break-reminder-apps-for-mac-in-2026/)
- [Setapp — Monetizing your app](https://docs.setapp.com/docs/monetizing-an-application-with-setapp) · [Setapp company updates](https://setapp.com/news/company-updates) · [MacPaw — Setapp for developers](https://macpaw.com/setapp)
- [MacStories — macOS 26 Tahoe Review (Control Center & App Intents)](https://www.macstories.net/stories/macos-26-tahoe-the-macstories-review/3/) · [Apple — What's new in macOS Tahoe 26](https://support.apple.com/en-us/122868)
- [AppleInsider — Liquid Glass dans macOS 27](https://appleinsider.com/articles/26/06/09/dont-get-excited-for-big-liquid-glass-changes-in-macos-27-because-they-arent-there) · [iDropNews — macOS « Golden Gate »](https://www.idropnews.com/news/apple-fixes-liquid-glass-ios-27-macos-golden-gate/265049/)
- [Apple Developer Forums — HealthKit sur macOS](https://developer.apple.com/forums/thread/94937) · [Apple — About the HealthKit framework](https://developer.apple.com/documentation/healthkit/about-the-healthkit-framework)
- [Shipping a Notarized, Sparkle-Updated macOS App in 2026: The Indie Playbook](https://erseltrhn.medium.com/shipping-a-notarized-sparkle-updated-macos-app-in-2026-the-indie-playbook-5df44d4cdda9) · [Apple — Notarizing macOS software](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)
