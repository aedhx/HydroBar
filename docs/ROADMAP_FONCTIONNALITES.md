# Roadmap fonctionnelle — HydroBar

> Propositions de fonctionnalités, classées par rapport valeur / effort.
> Complète l'[audit technique](AUDIT_TECHNIQUE.md), qui traite lui de la dette
> existante. Les deux se croisent : plusieurs fonctionnalités ci-dessous **exigent**
> qu'un point d'audit soit traité d'abord — c'est indiqué à chaque fois.

## Vue d'ensemble

| # | Fonctionnalité | Valeur | Effort | Prérequis |
|---|---|---|---|---|
| **F1** | **Deep links `hydrobar://`** | ⭐⭐⭐⭐⭐ | 1 j | — |
| **F2** | **App Intents / Shortcuts** | ⭐⭐⭐⭐⭐ | 2 j | F1 (validation partagée) |
| **F3** | **Lancement au démarrage** | ⭐⭐⭐⭐⭐ | 2 h | — |
| **F4** | Export des données (CSV / JSON) | ⭐⭐⭐⭐ | 1 j | P1-2 |
| **F5** | Historique illimité + vraie base | ⭐⭐⭐⭐ | 2 j | P1-2 |
| **F6** | Rappels intelligents | ⭐⭐⭐⭐ | 2 j | P0-3 |
| **F7** | Accessibilité (VoiceOver, contrastes) | ⭐⭐⭐⭐ | 1,5 j | — |
| **F8** | Onboarding au premier lancement | ⭐⭐⭐ | 1,5 j | — |
| **F9** | Types de boissons | ⭐⭐⭐ | 2 j | P1-2 |
| **F10** | Widget + contrôles Control Center | ⭐⭐⭐ | 1 j | P0-4, P0-5, P0-6 |
| **F11** | Synchronisation iCloud | ⭐⭐⭐ | 3 j | F5 |
| **F12** | Mises à jour automatiques (Sparkle) | ⭐⭐⭐ | 1,5 j | P3-6 |
| **F13** | Distribution Homebrew | ⭐⭐ | 3 h | P3-6 |
| **F14** | Interactions barre de menu (molette, alt-clic) | ⭐⭐ | 1 j | P2-1 |
| **F15** | Plugin Stream Deck | ⭐⭐ | 1 j | F1 |
| **F16** | Fenêtre tableau de bord | ⭐⭐ | 2 j | — |

---

## F1 — Deep links `hydrobar://` ⭐⭐⭐⭐⭐

**C'est la priorité absolue**, pour une raison simple : ce n'est pas une nouvelle
fonctionnalité, c'est une fonctionnalité **déjà documentée, déjà codée côté client,
et déjà mise en avant dans les réglages de l'app** — qui n'a jamais fonctionné faute
de handler côté app (voir [P0-1](AUDIT_TECHNIQUE.md#p0-1--le-schéma-durl-hydrobar-nexiste-pas--lextension-raycast-ne-peut-pas-fonctionner)).

Une journée de travail rend fonctionnel : l'extension Raycast existante, et une
intégration immédiate avec Alfred, BetterTouchTool, Keyboard Maestro, Stream Deck,
Automator et n'importe quel script shell.

📄 **Spécification complète : [`specs/DEEP_LINKS.md`](specs/DEEP_LINKS.md)**

---

## F2 — App Intents / Shortcuts ⭐⭐⭐⭐⭐

**Le complément indispensable de F1.** Un schéma d'URL est unidirectionnel : il ne
peut rien **renvoyer** (c'est volontaire — voir
[DEEP_LINKS § 4.5](specs/DEEP_LINKS.md#45-ce-que-le-schéma-ne-fera-jamais)). Les App
Intents, eux, retournent des valeurs, sont typés, traduits, et exposés
automatiquement dans Raccourcis, Spotlight et Siri.

La brique existe déjà : `HydroBarWidget/AddWaterIntent.swift`. Elle est simplement
cantonnée au target widget et écrit dans l'App Group au lieu de parler à l'app.

**Intents à exposer :**

| Intent | Entrée | Sortie | Usage typique |
|---|---|---|---|
| `AddWaterIntent` | quantité + unité | nouveau total | Raccourci clavier, automatisation |
| `AddPresetIntent` | preset (énumération dynamique) | nouveau total | Menu Raccourcis |
| `GetHydrationStatusIntent` | — | total, objectif, %, série | Affichage, Raycast « Status » |
| `SetGoalIntent` | quantité | confirmation | Ajustement selon l'activité |
| `UndoLastIntent` | — | quantité annulée | Correction |

**Ce que ça débloque concrètement :**

- **Automatisations Raccourcis** : « à 9 h, si mon Mac est déverrouillé, ajouter un
  verre », « quand je lance Zoom, rappeler de boire ».
- **Health sur iOS** : macOS n'a **pas** HealthKit (framework indisponible hors
  Mac Catalyst, et l'app Santé n'existe pas sur Mac) — l'item « Health app
  integration » de la roadmap du README n'est donc pas réalisable en direct. En
  revanche, un raccourci peut chaîner `GetHydrationStatusIntent` → « Enregistrer un
  échantillon de santé » sur un iPhone synchronisé. C'est le seul chemin viable, et
  il ne coûte qu'un intent.
- **Focus Filters** (`SetFocusFilterIntent`) : suspendre automatiquement les rappels
  pendant un mode de concentration — une alternative **fiable** à
  `INFocusStatusCenter`, qui demande une autorisation dédiée et échoue aujourd'hui en
  silence (voir [P0-3](AUDIT_TECHNIQUE.md#p0-3--la-synchronisation-focus-mode-ne-peut-jamais-sactiver)).

**Point d'attention.** Les intents s'exécutent dans un processus distinct quand l'app
est fermée. Ils doivent passer par la même couche de validation et de persistance que
les deep links et l'UI — sinon trois chemins d'écriture divergents, et des bugs de
double comptage comme celui déjà latent dans
[`AddWaterIntent.swift`](AUDIT_TECHNIQUE.md#p4--cosmétique-et-code-mort).

---

## F3 — Lancement au démarrage ⭐⭐⭐⭐⭐

**Fonctionnalité de base manquante.** Aucune trace de `ServiceManagement` ou de
`SMAppService` dans le code. Une app de barre de menu qu'il faut relancer à la main
après chaque redémarrage ne remplit pas son rôle : elle est censée être là, discrète,
en permanence. Et un traqueur d'hydratation qui ne tourne pas ne rappelle rien.

```swift
import ServiceManagement

var launchAtLogin: Bool {
    get { SMAppService.mainApp.status == .enabled }
    set {
        do {
            newValue ? try SMAppService.mainApp.register()
                     : try SMAppService.mainApp.unregister()
        } catch {
            Logger.app.error("Launch at login: \(error)")
        }
    }
}
```

À proposer dans l'onboarding (F8) et dans les réglages. Gérer le cas
`.requiresApproval` (macOS 13+ : l'utilisateur doit valider dans Réglages Système →
Ouverture) en affichant un lien vers le bon panneau.

**2 heures pour la fonctionnalité la plus structurante de cette liste après F1.**

---

## F4 — Export des données ⭐⭐⭐⭐

Présent dans la roadmap du README, et c'est aussi une question de confiance : des
données qu'on ne peut pas sortir sont des données prises en otage.

- **CSV** (`date,amount_ml,target_ml,goal_reached`) pour Excel / Numbers.
- **JSON** pour les scripts et la ré-importation.
- **Import** avec fusion (choix à la collision : garder / remplacer / additionner) —
  c'est ce qui permet de migrer depuis une autre app et de restaurer une sauvegarde.

**Prérequis.** L'historique est aujourd'hui plafonné à 30 jours et *détruit* au-delà
(voir [P1-2](AUDIT_TECHNIQUE.md#p1-2--trois-sources-de-vérité-pour-les-mêmes-données)).
Exporter avant d'avoir corrigé ça, c'est exporter un mois maximum, à vie.

---

## F5 — Historique illimité et vraie persistance ⭐⭐⭐⭐

Passer de deux fichiers JSON réécrits intégralement à chaque ajout (voir
[P2-2](AUDIT_TECHNIQUE.md#p2-2---hold-to-add---20-hz--2-écritures-disque--reprogrammation-des-notifications--sync-widget))
à **SwiftData** (disponible dès macOS 14, cible actuelle 15.1) ou SQLite via GRDB.

**Ce que ça apporte :**
- écritures incrémentales et transactionnelles (fin du risque de JSON tronqué,
  cf. [P3-3](AUDIT_TECHNIQUE.md#p3-3--écritures-disque-non-atomiques-et-échecs-silencieux)) ;
- historique complet : comparaisons annuelles, « meilleur mois », tendances ;
- horodatage **par ajout** et non par jour → statistiques par heure (« vous buvez
  peu entre 14 h et 17 h »), qui alimentent directement F6 ;
- socle indispensable pour F11 (iCloud).

Prévoir une migration one-shot depuis les JSON existants, testée sur un profil réel,
avec sauvegarde des anciens fichiers.

---

## F6 — Rappels intelligents ⭐⭐⭐⭐

Le système actuel est un intervalle fixe qui se réarme à chaque ajout — il notifie à
3 h du matin comme à 15 h.

**Améliorations, par ordre de valeur :**

1. **Plage horaire active** (« rappels entre 8 h et 20 h ») — le manque le plus
   évident, et le plus simple.
2. **Silence sur Mac inactif ou verrouillé** : inutile de rappeler quelqu'un qui
   n'est pas là. `CGEventSource.secondsSinceLastEventType` ou
   `NSWorkspace.screensDidSleepNotification`.
3. **Silence pendant une visio** : détecter la caméra ou le micro actifs.
4. **Cadence adaptative** : comparer l'avancement réel au prorata de la journée. À
   16 h avec 30 % de l'objectif, le rappel devient plus insistant ; à 100 %, il
   s'arrête. Les données existent déjà (`currentMl`, `targetMl`).
5. **Résumé hebdomadaire** le dimanche soir : série, moyenne, taux de réussite —
   tout est déjà calculé dans `HydrationManager`.
6. **Célébration de l'objectif** : une notification unique quand la barre est
   franchie, avec la série en cours.

Le point 4 est celui qui différencie l'app d'un simple minuteur.

---

## F7 — Accessibilité ⭐⭐⭐⭐

Aucun `accessibilityLabel` dans le projet. Quelques points concrets :

- **VoiceOver** : l'icône de la barre de menu et l'anneau de progression n'annoncent
  rien d'exploitable. Un `accessibilityLabel` du type « Hydratation : 72 %,
  1,45 litre sur 2 » change tout.
- **Daltonisme** : la sémantique repose entièrement sur bleu → vert
  (`ProgressRingView.swift:27-41`), les deux couleurs les plus confondues en
  deutéranopie. Ajouter un indicateur non chromatique (coche, épaisseur, motif).
- **`accessibilityReduceMotion`** : l'animation de l'anneau et le pulse proposé en
  F1 doivent la respecter.
- **Navigation clavier** dans le popover : aujourd'hui tout se fait à la souris.
- **Tailles de police système** : les tailles sont codées en dur
  (`.font(.system(size: 13))` partout) plutôt que dérivées des styles dynamiques.

C'est peu coûteux, rarement fait, et ça élargit réellement le public.

---

## F8 — Onboarding au premier lancement ⭐⭐⭐

Au premier lancement, l'app apparaît dans la barre de menu avec un objectif de 2 000 ml
et des presets arbitraires, sans explication, et demande l'autorisation de
notification d'emblée (`HydroBarApp.swift:147`) — au pire moment, avant que
l'utilisateur ait compris à quoi elle sert.

Trois écrans suffisent :
1. Unité + objectif quotidien (avec une suggestion basée sur le poids, optionnelle).
2. Presets et raccourcis clavier.
3. Rappels — **c'est là** qu'on demande l'autorisation de notification, en expliquant
   pourquoi, + lancement au démarrage (F3).

Un refus d'autorisation doit être visible et rattrapable depuis les réglages, pas
silencieux comme aujourd'hui.

---

## F9 — Types de boissons ⭐⭐⭐

Tout ne s'équivaut pas : le café est diurétique, le thé compte partiellement, l'alcool
déshydrate. Un coefficient d'hydratation par type (eau 1,0 / thé 0,9 / café 0,8 /
soda 0,6 / alcool −0,5) rend le suivi crédible.

Impose de stocker le type par entrée → dépend de F5. Garder l'eau par défaut en un
clic : l'ajout d'une friction pour chaque verre tuerait l'usage principal.

---

## F10 — Widget et contrôles Control Center ⭐⭐⭐

Le widget est **déjà écrit** (`HydroBarWidget/`, 285 lignes, familles small et medium,
boutons interactifs via App Intents) mais retiré de la v1.2 (commit `c84b203`).
Avant de le réactiver, traiter
[P0-4](AUDIT_TECHNIQUE.md#p0-4--app-non-sandboxée--widget-sandboxé--le-conteneur-app-group-nest-probablement-pas-partagé),
[P0-5](AUDIT_TECHNIQUE.md#p0-5--comapplesecurityapplication-groups-vide-dans-hydrobarwidgetextensionentitlements)
et [P0-6](AUDIT_TECHNIQUE.md#p0-6--cible-de-déploiement-du-widget--macos-262) : il y a
de fortes chances que le partage App Group n'ait jamais fonctionné, ce qui
expliquerait le retrait.

À ajouter ensuite :
- **presets réels de l'utilisateur** au lieu de `[200, 500, 750]` codés en dur
  (`HydroBarWidget.swift:88`) — il faut les transporter dans `HydrationSnapshot` ;
- **politique de timeline** : `.never` (`HydroBarWidget.swift:29`) fige le widget si
  l'app est quittée ; passer à `.after(prochain minuit)` pour que le reset quotidien
  se voie ;
- **`ControlWidget`** (Centre de contrôle / bouton Action) : « ajouter un verre »
  accessible partout, sans ouvrir l'app.

---

## F11 — Synchronisation iCloud ⭐⭐⭐

Présent dans la roadmap du README. Pertinent pour un utilisateur ayant un Mac fixe et
un portable.

- **Léger** : `NSUbiquitousKeyValueStore` pour l'état du jour + les réglages (1 Mo max,
  gratuit, simple).
- **Complet** : CloudKit avec SwiftData (F5) pour tout l'historique.

**Difficulté réelle : la résolution de conflits.** Deux Macs qui ajoutent chacun un
verre hors ligne doivent aboutir à la somme, pas à « le dernier écrase ». Cela impose
de stocker des **événements** (« +250 ml à 14 h 32 ») plutôt qu'un total — un
changement de modèle qu'il vaut mieux acter dès F5 que rétrofitter ensuite.

---

## F12 — Mises à jour automatiques (Sparkle) ⭐⭐⭐

Le flux actuel s'arrête à mi-chemin : `GitHubUpdateChecker` détecte une nouvelle
version, puis **ouvre une page web** et laisse l'utilisateur télécharger, monter le
DMG, glisser l'app, et contourner Gatekeeper. Résultat prévisible : la plupart des
utilisateurs restent sur leur version.

[`src/HydroBar/UPDATES_STRATEGY.md`](../src/HydroBar/UPDATES_STRATEGY.md) recommande
déjà Sparkle. Ajouter : appcast XML publié via GitHub Releases, signature EdDSA,
vérification au lancement (une fois par jour, pas plus).

**Prérequis strict** :
[P3-6](AUDIT_TECHNIQUE.md#p3-6--distribution--signature-ad-hoc-pas-de-notarisation).
Sparkle installant des binaires signés, une app ad-hoc ne peut pas se mettre à jour
proprement.

---

## F13 — Distribution Homebrew ⭐⭐

```bash
brew install --cask hydrobar
```

Installation, mise à jour et désinstallation gérées, et une visibilité réelle auprès
du public développeur macOS — qui est exactement la cible d'une app à raccourcis
globaux et extension Raycast. Un cask ne demande qu'un fichier Ruby et une PR sur
`homebrew-cask`, mais **exige une app notarisée** (P3-6).

---

## F14 — Interactions dans la barre de menu ⭐⭐

L'icône ne répond aujourd'hui qu'au clic gauche (popover) et au clic droit (menu).

- **Molette** sur l'icône → ajuster la quantité sans ouvrir le popover.
- **Alt+clic** → ajouter le preset n° 1 directement.
- **Glisser-déposer** d'un nombre sur l'icône → ajouter cette quantité.
- **Styles d'icône supplémentaires** : goutte remplie proportionnellement, verre qui
  se vide, ou texte compact « 1,4/2 L ».

Attendre [P2-1](AUDIT_TECHNIQUE.md#p2-1--licône-de-la-barre-de-menu-est-reconstruite-deux-fois-par-seconde) :
ajouter des interactions à une vue reconstruite deux fois par seconde multiplierait le
problème.

---

## F15 — Plugin Stream Deck ⭐⭐

`Resources/stream-deck.png` est déjà dans le dépôt — l'intention existait. Un plugin
Stream Deck avec trois boutons de preset, un bouton undo et un affichage en direct du
pourcentage sur la touche.

Devient quasi gratuit une fois F1 livré : le plugin se contente d'ouvrir des URLs
`hydrobar://`, exactement comme l'extension Raycast.

---

## F16 — Fenêtre tableau de bord ⭐⭐

Le popover est contraint à 320 px de large et sa hauteur est calculée à la main via un
`PreferenceKey` et un rappel vers l'`AppDelegate`
(`MainView.swift:211-230`) — un mécanisme fragile. Une vraie fenêtre, ouvrable depuis
le menu contextuel, permettrait :

- des graphiques lisibles sur 3, 6 et 12 mois ;
- des filtres (plage de dates, jours de la semaine, types de boissons) — l'item
  « Advanced statistics filters » de la roadmap du README ;
- l'export (F4) et l'édition rétroactive (« j'ai oublié de noter hier »).

L'édition rétroactive est d'ailleurs un manque à part entière : aujourd'hui, une
journée passée est figée.

---

## Séquencement suggéré

**v1.3 — « Ça marche enfin »** (~1 semaine)
`F1` + `F3` + lot 1 de l'audit (P0-2, P0-5, P0-6, P3-3, P3-8, code mort).
→ L'intégration Raycast fonctionne, l'app démarre toute seule, le crash potentiel
disparaît. Aucune fonctionnalité visible n'est promise sans être livrée.

**v1.4 — « Automatisable »** (~1 semaine)
`F2` + lots 3 et 4 de l'audit (tests, CI, refactor `@Observable`).
→ Shortcuts, Spotlight, Siri, Focus Filters. Et surtout : une base refactorisée avec
un filet de tests, avant que le code ne grossisse davantage.

**v1.5 — « Mes données »** (~1,5 semaine)
`F5` + `F4` + `F6`.
→ Historique complet, export, rappels qui ont du sens.

**v1.6 — « Partout »** (~1,5 semaine)
`F10` + `F12` + `F13` + P3-6 (notarisation).
→ Widget réellement fonctionnel, mise à jour en un clic, `brew install`.

**Ensuite, selon l'envie** : `F7` (accessibilité — à remonter si le public s'élargit),
`F8`, `F9`, `F11`, `F14`, `F15`, `F16`.

---

## Ce que je ne recommande pas

Par symétrie, quelques idées séduisantes qui coûteraient plus qu'elles ne rapportent
à ce stade :

- **Gamification poussée** (badges, niveaux, classements). La série de jours suffit et
  fonctionne déjà bien. Le reste transformerait un utilitaire discret en application
  qui réclame de l'attention — l'inverse de ce que fait HydroBar.
- **Compte utilisateur / backend**. Les données d'hydratation n'ont aucune raison de
  quitter la machine ; c'est aussi un argument de confidentialité que le README met
  déjà en avant. iCloud (F11) couvre le besoin réel de synchronisation.
- **Objectif adaptatif selon la météo ou l'activité.** Séduisant sur le papier,
  mais cela suppose une API externe, une géolocalisation et des permissions — pour un
  gain d'exactitude marginal face à un objectif fixe bien choisi.
- **App iOS compagnon.** Effort considérable (nouveau target, nouvelle UI, App Store,
  synchronisation) alors que F2 permet déjà de logger depuis un iPhone via Raccourcis.
- **Traduction dans davantage de langues.** 9 langues sont déjà annoncées mais ~35 des
  81 clés ne sont pas traduites (voir
  [P3-5](AUDIT_TECHNIQUE.md#p3-5--localisation-incomplète-et-changement-de-langue-par-redémarrage)).
  Finir l'existant avant d'en ajouter.
