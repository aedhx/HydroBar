# Audit technique — HydroBar

> Audit du code au commit `c84b203` (v1.2). Périmètre : app macOS (`src/HydroBar`),
> extension widget, extension Raycast, scripts de build et documentation.
> Volume analysé : ~4 750 lignes Swift + ~80 lignes TypeScript.

## Résumé exécutif

HydroBar fait ce qu'il promet et l'UI est soignée. Les problèmes se concentrent sur
**trois axes** :

1. **Des fonctionnalités documentées ne fonctionnent pas**, et échouent en silence —
   aucune erreur visible, ce qui les rend difficiles à détecter : les deep links
   `hydrobar://` sur lesquels repose toute l'extension Raycast (**corrigé**, voir
   P0-1) et la synchronisation Focus Mode (P0-3, toujours ouvert).
2. **Le modèle de données n'est pas réactif.** `@AppStorage` est utilisé à l'intérieur
   d'un `ObservableObject`, où il ne publie rien. Toute l'app compense avec des timers
   de rafraîchissement et des `objectWillChange.send()` manuels. C'est la cause racine
   de la moitié des points de performance ci-dessous.
3. **Peu de filet de sécurité** : une écriture disque toujours non vérifiée (P3-3),
   et une division non gardée qui pouvait faire crasher l'app depuis les réglages
   (**corrigée**, voir P0-2). La CI existe désormais (P3-2) et fait tourner les
   31 tests écrits depuis, mais le cœur métier — conversions, séries, reset
   quotidien — reste non couvert (P3-1).

Rien n'est irrécupérable — le code est lisible, bien découpé en fichiers, et les
correctifs P0 représentent environ une journée de travail.

> **Suivi.** P0-1 et P0-2 sont corrigés. P0-4 et P0-5 se sont révélés erronés ou
> sans impact à la vérification du `.pbxproj` : le détail est conservé ci-dessous
> plutôt qu'effacé, pour que la correction soit traçable.

### Tableau de bord

| Sévérité | Nb | Thème dominant |
|---|---|---|
| **P0 — Bloquant** | 6 (2 corrigés, 2 invalidés) | Fonctionnalités mortes, crash potentiel |
| **P1 — Architecture** | 7 | Réactivité, source de vérité, encapsulation |
| **P2 — Performance** | 5 | Timers, I/O disque, reconstruction de vues |
| **P3 — Qualité / outillage** | 8 | Tests, CI, i18n, distribution |
| **P4 — Cosmétique** | 6 | Code mort, duplication, conventions |

---

## P0 — Bloquant

### P0-1 — Le schéma d'URL `hydrobar://` n'existe pas : l'extension Raycast ne peut pas fonctionner

**Constat.** `raycast-hydrobar/src/*.ts` ouvre `hydrobar://add?ml=250` et
`hydrobar://add/preset/0`. `raycast-hydrobar/README.md` documente ces URLs.
Or l'app ne déclare **aucun** `CFBundleURLTypes` (vérifié dans
`HydroBar.xcodeproj/project.pbxproj` et dans les `Info.plist`) et n'implémente
**aucun** handler (`application(_:open:)`, `onOpenURL`, ou `NSAppleEventManager`).

**Impact.** macOS ne sait pas à qui router `hydrobar://`. `open()` côté Raycast lève
ou ne fait rien ; l'utilisateur voit au mieux le toast « HydroBar not running? », qui
l'envoie sur une fausse piste (l'app *est* lancée — elle n'est juste pas enregistrée
comme handler). Toute l'intégration Raycast mise en avant dans le README et dans les
réglages (`SettingsView.swift:576`) est non fonctionnelle.

**Correctif.** ✅ **Corrigé.** `HydroBar/Info.plist` déclare `CFBundleURLTypes`,
`AppDelegate` implémente `application(_:open:)` + un handler Apple Event `GURL`, et
`DeepLinkParser` / `DeepLinkRouter` séparent parsing (pur, testé) et exécution.
Voir [`specs/DEEP_LINKS.md`](specs/DEEP_LINKS.md).

---

### P0-2 — Division non gardée par `targetMl` : crash possible depuis les réglages

**Constat.** `HydroBarApp.swift:227`

```swift
let percentage = Int((manager.currentMl / manager.targetMl) * 100)
```

Aucune garde sur `targetMl > 0`, contrairement à `MenuBarIconView` (ligne 39) et
`ProgressRingView` (ligne 14) qui, eux, gardent. Or le champ « Objectif quotidien »
(`SettingsView.swift:181`) écrit `manager.targetMl` à **chaque frappe**, sans
validation : `Double("0")` vaut `0.0` et est accepté.

**Impact.** En mode d'icône « Percentage », le timer de `HydroBarApp.swift:206`
exécute cette ligne toutes les 0,5 s. Si `targetMl == 0` :
`0/0 = NaN`, `x/0 = +∞`, et `Int(NaN)` / `Int(.infinity)` **piègent** en Swift →
crash. Scénario réel : l'utilisateur veut saisir `0.5 L`, tape `0` en premier
caractère, le timer se déclenche entre deux frappes.

**Correctif.**

```swift
// HydroBarApp.swift:227
let target = manager.targetMl
let percentage = target > 0 ? Int((manager.currentMl / target) * 100) : 0
```

✅ **Corrigé** dans `HydroBarApp.swift` : la division est gardée et `isGoalReached`
aussi. `HydrationLimits.goal` (200 – 10 000 ml) existe désormais dans
`DeepLink.swift` et borne déjà les deep links.

⚠️ **Reste à faire** : `SettingsView` n'utilise pas encore ces bornes et écrit
toujours à chaque frappe (voir P1-4). La garde empêche le crash, mais un objectif
de 0 reste saisissable.

---

### P0-3 — La synchronisation Focus Mode ne peut jamais s'activer

**Constat.** `FocusModeMonitor.swift:61-95` lit `INFocusStatusCenter.default.focusStatus`
sans jamais appeler `requestAuthorization(completion:)`, et la clé
`NSFocusStatusUsageDescription` est absente des réglages Info.plist du projet.

**Impact.** Sans autorisation, `focusStatus.isFocused` vaut `nil`. Le `guard let` de
la ligne 71 sort silencieusement à chaque tick du timer de 30 s. Le réglage
« Sync with Focus Mode » (`SettingsView.swift:348`) est donc un interrupteur qui
n'a aucun effet, sans que l'utilisateur puisse le savoir.

**Correctif.**

1. Ajouter au target app : `INFOPLIST_KEY_NSFocusStatusUsageDescription = "HydroBar met en pause ses rappels quand un mode de concentration est actif."`
2. Demander l'autorisation au moment où l'utilisateur active le toggle (pas au
   lancement), puis refléter le refus dans l'UI :

```swift
INFocusStatusCenter.default.requestAuthorization { status in
    DispatchQueue.main.async {
        guard status == .authorized else {
            manager.focusModeAutoSync = false
            self.authorizationDenied = true   // à afficher dans les réglages
            return
        }
        self.checkFocusStatus()
    }
}
```

3. Afficher un lien vers Réglages Système → Confidentialité → Concentration en cas de refus.

**Effort.** ~1 h 30.

---

### P0-4 — ~~App non sandboxée + widget sandboxé~~ : constat erroné

> **Correction (post-audit).** Ce point était **faux** et n'est pas un P0.

**Ce que disait l'audit initial.** `HydroBar/HydroBar.entitlements` ne contient pas
`com.apple.security.app-sandbox`, contrairement au widget — d'où un conteneur App
Group non partagé entre les deux processus.

**Pourquoi c'est faux.** Le projet gère les entitlements par *build settings*, pas
par le fichier `.entitlements` : `ENABLE_APP_SANDBOX = YES` et
`REGISTER_APP_GROUPS = YES` sont présents sur **les deux** targets
(`project.pbxproj:649`, `:668` pour l'app ; `:427`, `:452` pour le widget). Xcode
fusionne ces clés dans les entitlements à la compilation. Les deux processus sont
donc sandboxés et partagent bien le même groupe.

**Ce qui reste vrai.** Lire les entitlements uniquement dans les fichiers `.plist`
donne une image fausse de ce que l'app demande réellement — il faut lire les deux
sources. Et la cause du retrait du widget en v1.2 reste à identifier : ce n'est pas
celle-ci.

**Leçon.** Un constat de configuration doit être vérifié dans le `.pbxproj` autant
que dans les fichiers d'entitlements.

### P0-5 — Fichier d'entitlements orphelin (rétrogradé en P4)

> **Correction (post-audit).** Réel, mais sans impact fonctionnel — ce n'est pas un P0.

**Constat.** `src/HydroBar/HydroBarWidgetExtension.entitlements`, référencé par
`CODE_SIGN_ENTITLEMENTS` du target widget (`project.pbxproj:420`, `:467`), déclare un
tableau `application-groups` **vide**. Le fichier correctement rempli,
`HydroBarWidget/HydroBarWidget.entitlements`, n'est référencé **nulle part** dans le
projet (vérifié : 0 occurrence).

**Impact réel.** Aucun à l'exécution : `REGISTER_APP_GROUPS = YES` fait injecter
l'entitlement du groupe par Xcode au moment de la compilation, quel que soit le
contenu du fichier. Le problème est de lisibilité : deux fichiers d'entitlements pour
un seul target, dont celui qui *semble* faire foi est mort.

**Correctif.** Supprimer `HydroBarWidget/HydroBarWidget.entitlements`, ou le
référencer à la place du fichier vide. Et remplacer le fallback silencieux
d'`AppGroupStore.swift:44` par une assertion en debug — s'il retombe un jour sur
`.standard`, mieux vaut le savoir tout de suite :

```swift
private static var defaults: UserDefaults {
    guard let d = UserDefaults(suiteName: suiteName) else {
        assertionFailure("App Group \(suiteName) inaccessible — vérifier les entitlements")
        return .standard
    }
    return d
}
```

**Effort.** ~15 min.

### P0-6 — Cible de déploiement du widget : macOS 26.2

**Constat.** `project.pbxproj:438` et `:485` → `MACOSX_DEPLOYMENT_TARGET = 26.2`
pour le widget, contre `15.1` pour l'app (`:554`, `:615`) — et le README annonce
macOS 13+.

**Impact.** Le widget ne s'installerait que sur macOS 26.2+, alors que l'app tourne
dès 15.1. Incohérence de packaging : l'extension embarquée dans le bundle est
ignorée par les systèmes plus anciens.

**Correctif.** ✅ **Corrigé** : les deux configurations du widget passent à `15.1`.
Son code n'utilise rien au-delà de `.containerBackground(_:for:)` (macOS 14+), donc
la cible 26.2 était un simple défaut d'Xcode au moment où la cible a été créée.

C'était aussi un **bloquant pour la CI** : aucun runner GitHub ne peut construire une
cible dont le déploiement minimum dépasse son SDK.

---

## P1 — Architecture

### P1-1 — `@AppStorage` dans un `ObservableObject` ne publie rien (cause racine)

**Constat.** `HydrationManager.swift:105-185` : 14 propriétés `@AppStorage` déclarées
dans une classe `ObservableObject`.

`@AppStorage` est un `DynamicProperty` conçu pour les **vues** : il déclenche
l'invalidation via l'environnement SwiftUI de la vue hôte. Dans un `ObservableObject`,
il lit et écrit correctement les `UserDefaults`, mais **n'émet aucun `objectWillChange`**.

**Impact — c'est le point le plus structurant de cet audit.** Les propriétés dérivées
(`targetMl`, `selectedUnit`, `presetsMl`, `notificationInterval`, `menuBarIconStyle`)
ne notifient pas les vues. Toute l'app compense :

- le timer 0,5 s de `HydroBarApp.swift:206` qui reconstruit l'icône (P2-1) ;
- les `objectWillChange.send()` manuels (`HydrationManager.swift:182`, `:313`, `:1090`) ;
- les `DispatchQueue.main.async` défensifs (14 occurrences) ;
- les `Binding(get:set:)` manuels partout dans `SettingsView` au lieu de `$manager.x`.

Retirer ce contournement supprime mécaniquement la moitié des points P2.

**Correctif.** Deux voies, du moins au plus propre :

- **Rapide** : garder `UserDefaults` mais exposer les propriétés en `@Published`
  avec persistance dans le `didSet`, ou envelopper chaque accès dans un
  `objectWillChange.send()` explicite.
- **Recommandé** (cible macOS 15 → disponible) : passer à la macro `@Observable` et
  à un `SettingsStore` dédié, avec un seul point de persistance. Supprime aussi le
  besoin de `@Published`, `@ObservedObject` et `@StateObject`.

**Effort.** 1 à 2 jours selon la voie retenue. **C'est le refactor à prioriser.**

---

### P1-2 — Trois sources de vérité pour les mêmes données

**Constat.** L'état d'hydratation est persisté à trois endroits :

| Source | Fichier | Contenu | Rétention |
|---|---|---|---|
| `UserDefaults["currentMl"]` | prefs | jour courant | — |
| `history.json` | App Support | `DailyEntry` (sans objectif) | 7 jours |
| `historyEntries.json` | App Support | `HistoryEntry` (avec objectif) | 30 jours |

`DailyEntry` est marqué « legacy, pour compatibilité » (`HydrationManager.swift:7`)
mais reste écrit à chaque mutation et alimente encore `getLast7DaysData()`.

**Impact.** Chaque ajout d'eau écrit **deux fichiers JSON complets** (P2-2), avec un
risque de divergence entre les deux historiques. Le plafond à 30 jours est par
ailleurs un mur pour les fonctionnalités « export » et « statistiques avancées » de
la roadmap : l'historique au-delà de 30 jours est **détruit**, pas archivé
(`HydrationManager.swift:611`).

**Correctif.**
1. Supprimer `DailyEntry` et `history.json` (migration one-shot au lancement).
2. Ne plus tronquer à l'écriture : garder l'historique complet, tronquer à
   l'**affichage**. Un an de données fait ~30 Ko.
3. À terme, passer sur SwiftData ou SQLite (voir roadmap F5) — indispensable si
   l'iCloud sync arrive.

**Effort.** ~4 h (hors migration base de données).

---

### P1-3 — La vue mute directement l'état interne du manager

**Constat.** `MainView.swift:330-333` :

```swift
manager.undoStack.append((amount: holdTotalAmount, timestamp: Date()))
if manager.undoStack.count > 50 { manager.undoStack.removeFirst() }
```

`undoStack` est déclaré `internal` (`HydrationManager.swift:204`) juste pour permettre
cet accès, et la limite `50` est dupliquée alors que `maxUndoStackSize`
(`HydrationManager.swift:205`) existe et est `private`.

**Impact.** Invariant de l'undo cassable depuis n'importe quelle vue, limite
désynchronisable, et logique métier dans la couche présentation.

**Correctif.** Exposer une API d'intention et repasser `undoStack` en `private` :

```swift
func beginHoldSession()
func endHoldSession()      // agrège le hold en une seule entrée d'undo
```

**Effort.** ~1 h.

---

### P1-4 — Aucune validation des entrées utilisateur

**Constat.** `SettingsView.swift:181` (objectif) et `:215` (presets) :

```swift
if let value = Double(newValue) { manager.targetMl = manager.mlValue(from: value) }
```

Pas de borne basse, pas de borne haute, pas de rejet du négatif, écriture à chaque
frappe, et échec silencieux si la saisie n'est pas numérique (la valeur précédente
reste, l'utilisateur croit avoir enregistré).

**Impact.** Cause directe de P0-2. Permet aussi un objectif négatif (ring inversé,
streak incohérent) ou absurde (`999999 L`).

**Correctif.** Un helper unique, réutilisé par l'objectif, les presets et les deep
links (le routeur d'URL a exactement le même besoin — voir
[`specs/DEEP_LINKS.md`](specs/DEEP_LINKS.md#42-validation-et-bornes)) :

```swift
enum HydrationLimits {
    static let goal: ClosedRange<Double>   = 200...10_000   // ml
    static let single: ClosedRange<Double> = 1...5_000      // ml par ajout
}
```

Committer sur `.onSubmit` / perte de focus, afficher l'erreur, et restaurer la valeur
valide si la saisie est rejetée.

**Effort.** ~2 h.

---

### P1-5 — `@StateObject` sur un singleton

**Constat.** `MainView.swift:88` : `@StateObject private var manager = HydrationManager.shared`.

**Impact.** `@StateObject` signifie « cette vue **possède** cet objet et en contrôle
le cycle de vie ». Sur un singleton, c'est faux et trompeur ; l'autoclosure
d'initialisation est évaluée à chaque construction de la vue même si le résultat est
ignoré. Toutes les autres vues utilisent correctement `@ObservedObject`.

**Correctif.** `@ObservedObject var manager = HydrationManager.shared`, ou mieux,
injection par `@EnvironmentObject` depuis un point unique.

**Effort.** 5 min.

---

### P1-6 — Conformité rétroactive sur `Array` de la bibliothèque standard

**Constat.** `HydrationManager.swift:82` :

```swift
extension Array: @retroactive RawRepresentable where Element == Double
```

**Impact.** Conformité d'un type stdlib à un protocole stdlib, uniquement pour faire
passer `[Double]` dans `@AppStorage`. Le `@retroactive` tait l'avertissement mais pas
le risque : conflit possible si Apple ou une dépendance ajoute la même conformité,
et sémantique surprenante pour tout `[Double]` du projet (`rawValue` renvoie du JSON).

**Correctif.** Un type dédié :

```swift
struct Presets: Codable, RawRepresentable { var values: [Double] /* … */ }
```

ou, après le refactor P1-1, plus besoin de `RawRepresentable` du tout — encoder en
`Data` dans le store.

**Effort.** ~1 h.

---

### P1-7 — Ré-entrance gérée par des drapeaux temporaires

**Constat.** `FocusModeMonitor.swift:80-88` désactive `focusModeAutoSync`, modifie
`doNotDisturb`, puis le réactive — pour éviter que les `didSet` en cascade ne bouclent.
Même motif dans `HydrationManager.swift:134` (`guard oldValue != focusModeAutoSync`).

**Impact.** Le graphe d'état dépend de l'ordre d'exécution de `didSet` imbriqués.
Fragile à faire évoluer, et impossible à tester tel quel. Un plantage entre la
désactivation et la réactivation laisse le réglage utilisateur dans un état faux
**et persisté**.

**Correctif.** Séparer « intention utilisateur » et « état effectif » : le Focus Mode
écrit dans un `focusDrivenDoNotDisturb` distinct, et le comportement final est une
propriété calculée `effectiveDoNotDisturb = userDoNotDisturb || focusDrivenDoNotDisturb`.
Plus de cascade, plus de drapeau temporaire.

**Effort.** ~2 h.

---

## P2 — Performance

### P2-1 — L'icône de la barre de menu est reconstruite deux fois par seconde

**Constat.** `HydroBarApp.swift:206` : timer 0,5 s → `updateStatusBarIcon()`, qui en
mode « pie ring » (`:238-266`) **détruit toutes les sous-vues** et **instancie un
nouveau `NSHostingController`** à chaque tick.

**Impact.** ~2 créations/seconde d'un hôte SwiftUI complet, 24 h/24, pour une valeur
qui change quelques dizaines de fois par jour. Coût CPU permanent sur une app censée
être invisible, churn mémoire, et animations SwiftUI réinitialisées en boucle. Sur
batterie, c'est le genre de détail qui fait apparaître l'app dans « Consommation
d'énergie importante ».

**Correctif.** Créer le `NSHostingController` **une seule fois** dans `setupStatusBar()`.
`MenuBarIconView` observe déjà `manager` : une fois P1-1 corrigé, il se met à jour
tout seul et le timer disparaît. Ne recréer la vue que sur changement de
`menuBarIconStyle`.

**Effort.** ~1 h (2 h avec P1-1).

---

### P2-2 — « Hold to Add » : 20 Hz × (2 écritures disque + reprogrammation des notifications + sync widget)

**Constat.** `MainView.swift:308` déclenche `manager.addWater(amount: 25.0)` toutes
les 50 ms. Chaque appel enchaîne :

| Étape | Fichier | Coût par tick |
|---|---|---|
| `currentMl.didSet` → `saveTodayEntry()` | `HydrationManager.swift:188`, `:550` | réécriture **complète** de `history.json` **et** `historyEntries.json` |
| `scheduleNotifications()` | `:404` | `removeAllPendingNotificationRequests()` + `add()` (IPC vers `usernoted`) |
| `syncToAppGroup()` | `:997` | reconstruction de 7 jours d'historique + `JSONEncoder` + écriture `UserDefaults` |
| retour d'haptique + `makeKey()` | `MainView.swift:314` | recherche linéaire dans `NSApp.windows`, 20×/s |

Soit **40 écritures de fichiers par seconde** et 20 allers-retours vers le démon de
notifications pendant tout l'appui.

**Impact.** Pics d'I/O, risque de corruption si l'app est tuée en plein `write(to:)`
(pas d'écriture atomique — voir P3-3), et usure SSD inutile. Le debounce de 0,5 s
existe déjà pour `WidgetCenter` (`:1010`) : la preuve que le problème a été identifié,
mais seulement traité pour le widget.

**Correctif.**
1. Découpler mutation et persistance : un `debouncedSave()` (0,5–1 s) partagé par les
   deux JSON et par `syncToAppGroup()`, + un flush sur `applicationWillTerminate` et
   sur fermeture du popover.
2. Ne reprogrammer les notifications qu'à la **fin** du hold, pas à chaque gorgée.
3. Sortir `makeKey()` de la boucle (une fois au début du hold suffit).

**Effort.** ~3 h.

---

### P2-3 — Débit du « Hold to Add » : 500 ml/seconde

**Constat.** 25 ml toutes les 50 ms. Un appui d'une seconde ajoute un demi-litre ;
deux secondes d'inattention ajoutent l'équivalent d'un objectif de la moitié d'une
journée.

**Impact.** Plus un problème d'UX que de perf, mais il alimente P2-2 : c'est ce débit
qui rend l'appui long coûteux. Aucune limite haute, aucun retour visuel du total en
cours d'ajout (`holdTotalAmount` est suivi mais jamais affiché).

**Correctif.** Réduire à ~10 ml/tick (200 ml/s), afficher le cumul en direct sur le
bouton, et introduire une accélération progressive plutôt qu'un débit constant.

**Effort.** ~1 h.

---

### P2-4 — Trois timers permanents dont deux redondants

**Constat.** `HydrationManager.swift:329` (60 s, reset quotidien), `:340` (60 s,
badge de rappel), `FocusModeMonitor.swift:108` (30 s, polling du Focus Mode),
`HydroBarApp.swift:206` (0,5 s, icône). Quatre réveils périodiques pour une app de
barre de menu.

**Impact.** Empêche l'App Nap et le coalescing des timers système.

**Correctif.**
- Fusionner les deux timers de 60 s en un seul tick.
- Remplacer le reset quotidien par un `Timer` unique programmé sur le prochain
  minuit (`Calendar.nextDate(after:matching:)`) + un observateur
  `NSWorkspace.didWakeNotification` pour le retour de veille.
- Ajouter `timer.tolerance` (par ex. 10 s sur les timers de 60 s) pour laisser
  macOS regrouper les réveils.
- Supprimer le timer 0,5 s (P2-1).

**Effort.** ~2 h.

---

### P2-5 — `ISO8601DateFormatter` instancié à chaque appel

**Constat.** `HydrationManager.swift:12`, `:28`, `:293`, `:340`, `:346`, `:418` —
un nouveau formateur à chaque création d'entrée et à chaque lecture/écriture de date.

**Impact.** `ISO8601DateFormatter` est notoirement coûteux à instancier. Appelé dans
le chemin chaud du `addWater` (donc 20×/s pendant un hold).

**Correctif.** Un `static let` partagé (les formateurs sont thread-safe en lecture
depuis iOS 7/macOS 10.9). Idéalement, stocker des `Date` natives dans un `Codable`
plutôt que des `String` ISO : `HistoryEntry.id` pourrait être un `UUID` ou la date
elle-même.

**Effort.** ~30 min.

---

## P3 — Qualité et outillage

### P3-1 — Aucun test

**Partiellement corrigé.** Deux suites réelles existent désormais et passent en CI :
`DeepLinkParserTests` (18 cas) et `HydrationPaceTests` (13 cas). Le gabarit vide
`example()` a été retiré. `HydroBarUITests` contient toujours les deux templates
Xcode non modifiés — ils sont ignorés par la CI, puisque lancer une app `LSUIElement`
sans fenêtre n'y teste rien.

**Ce qui manque encore**, et c'est l'essentiel : le cœur métier historique reste non
couvert.

**Ce qui devrait être testé en priorité** (logique pure, sans UI, rapide à couvrir) :

| Cible | Fichier | Pourquoi |
|---|---|---|
| `AppUnit` conversions (aller-retour cl/L/oz) | `HydrationManager.swift:40-79` | arithmétique pure, régression silencieuse |
| `currentStreak` | `HydrationManager.swift:751` | logique de bord (aujourd'hui à 0, trous dans l'historique) |
| `completionRate`, `weeklyTotal`, `dailyAverage` | `:719-826` | calculs affichés en KPI |
| `isVersionNewer` | `GitHubUpdateChecker.swift:73` | comparaison sémantique (`1.10` vs `1.9`) |
| Reset quotidien | `:292` | dépend de la date système — à injecter |
| ~~`DeepLinkParser`~~ ✅ | `DeepLink.swift` | parsing + validation, couvert par 18 cas |

Le principal obstacle : `HydrationManager` est un singleton qui lit `UserDefaults.standard`,
`FileManager` et `Date()` en dur. Rendre testable = injecter ces trois dépendances
(un `init(defaults:fileManager:now:)` en plus du `.shared`). Ce n'est pas de la
sur-ingénierie : c'est ce qui débloque tout le reste.

Les deux suites existantes contournent le problème plutôt qu'elles ne le résolvent :
`DeepLinkParser` et `HydrationPace` ont été écrits comme des fonctions pures,
*en dehors* du manager. C'est la bonne approche pour du code neuf, mais elle ne fait
rien pour le code historique.

**Effort.** ~1 jour pour l'injection + une première suite couvrant les calculs.

---

### P3-2 — Aucune intégration continue

Pas de `.github/workflows`. Chaque release dépend d'un `./build-dmg.sh` lancé à la main
sur une machine de dev.

**Correctif.** ✅ **Corrigé** : `.github/workflows/ci.yml`, deux jobs.

| Job | Contenu |
|---|---|
| `app` (macOS) | `xcodebuild build` sans signature — la question « est-ce que ça compile ? » isolée de tout le reste — puis `xcodebuild test` en signature ad-hoc, `HydroBarUITests` ignoré (il ne contient que les gabarits Xcode). Journaux complets en artefact. |
| `raycast` (Linux) | `npm ci` + `tsc --noEmit`, et une vérification que chaque commande déclarée dans `package.json` a bien son fichier dans `src/`. |

Deux choix à noter :

- **Compilation et tests sont deux étapes séparées**, avec des dossiers de build
  distincts. Faire tourner un bundle de tests dans une app sandboxée demande une
  signature : c'est une cause d'échec entièrement différente de « le code ne compile
  pas », et les confondre rendrait chaque échec ambigu.
- **`ray lint` n'est pas utilisé** : il demande un compte Raycast. `tsc` en mode
  strict attrape ce qui casse réellement.

**Reste à faire** : `swiftlint` (P3-4, pas encore configuré) et un job `release` sur
tag `v*` produisant le DMG et le ZIP.

---

### P3-3 — Écritures disque non atomiques et échecs silencieux

**Constat.** `HydrationManager.swift:626` et `:677` :

```swift
try data.write(to: historyFileURL)          // pas de .atomic
} catch { print("Erreur lors de la sauvegarde…") }
```

**Impact.** Une coupure pendant l'écriture (crash, perte de courant) laisse un JSON
tronqué → `loadHistory()` part en `catch` et **remet l'historique à vide**
(`:649`, `:667`) sans prévenir. L'utilisateur perd un mois de données sans message.
Le risque est amplifié par les 40 écritures/seconde de P2-2.

**Correctif.**
1. `try data.write(to: url, options: [.atomic])`.
2. En cas d'échec de lecture : renommer le fichier corrompu en `.corrupt-<date>` au
   lieu de l'écraser, et notifier l'utilisateur.
3. Remplacer les 12 `print()` du projet par `Logger` (os.log) avec des catégories —
   `print()` ne laisse aucune trace exploitable dans une build Release distribuée.

**Effort.** ~2 h.

---

### P3-4 — Ni linter ni formateur

Pas de `.swiftlint.yml`, pas de `.swift-format`. Les conséquences se voient : mélange
de `String(format:)` et d'interpolation, indentation variable, imports inutilisés,
blocs commentés laissés en place (`SettingsView.swift:628-641`).

**Correctif.** `swiftlint` avec un jeu de règles minimal (dont `force_unwrapping`,
`todo`, `unused_closure_parameter`) branché en build phase **et** en CI.

**Effort.** ~1 h.

---

### P3-5 — Localisation incomplète et changement de langue par redémarrage

**Constat.** `Localizable.xcstrings` : 81 clés, mais seulement **46 traduites** en
de/es/it/ja/nl/pt/zh-Hans (57 en fr, 59 en en) — soit ~35 clés non traduites par
langue. 22 clés n'ont **aucune** localisation, dont `"Check for Updates"`,
`"Checking…"`, `"INTEGRATIONS"`, `"Day"`, et une clé vide `""`. La clé
`"Hello, world!"` (`ContentView.swift`) traîne encore.

De plus, `"Hold to Add"` est écrit en dur dans du code AppKit (`MainView.swift:57`),
donc totalement hors du système de localisation — et le paramètre `label` de
`HoldButton` (`:14`) n'est jamais utilisé.

Enfin, changer de langue affiche une `NSAlert` **bloquante depuis un setter de
`Binding`** puis **tue l'app** (`SettingsView.swift:606-617`).

**Correctif.**
- Compléter les traductions manquantes, supprimer les clés mortes.
- Utiliser `label` dans `HoldButtonNSView.draw` et passer par `String(localized:)`.
- Pour la langue : appliquer à chaud en propageant `\.locale` dans l'environnement
  SwiftUI ; si le redémarrage reste nécessaire, le proposer (« Relancer maintenant /
  Plus tard ») au lieu de l'imposer.

**Effort.** ~3 h (hors traduction elle-même).

---

### P3-6 — Distribution : signature ad-hoc, pas de notarisation

**Constat.** `build-dmg.sh:40-47` supprime le provisioning profile et re-signe en
ad-hoc (`codesign --sign "-"`).

**Impact.** Gatekeeper affiche « HydroBar est endommagé et ne peut pas être ouvert » —
d'où la section « Gatekeeper Notice » du README et le commit `4d1e93d`. Chaque
utilisateur doit passer par `xattr -cr`. C'est le principal frein à l'adoption, et
ça donne à une app saine l'apparence d'un malware.

**Correctif.** Certificat **Developer ID Application** (compte développeur payant),
puis :

```bash
codesign --force --options runtime --timestamp --sign "Developer ID Application: …" "$APP_PATH"
xcrun notarytool submit "$DMG_NAME" --keychain-profile "AC_PASSWORD" --wait
xcrun stapler staple "$DMG_NAME"
```

Voir aussi la roadmap F12 (Sparkle) et F13 (Homebrew cask), qui supposent tous deux
une app notarisée.

**Effort.** ~3 h (hors délai d'obtention du certificat).

---

### P3-7 — Version dupliquée entre le script et le projet

`build-dmg.sh:7` code `VERSION="1.2"` en dur, alors que `MARKETING_VERSION = 1.2`
existe dans `project.pbxproj:653`. Deux endroits à mettre à jour à chaque release,
donc un DMG qui finira par être mal nommé.

**Correctif.** Lire la version depuis le projet :

```bash
VERSION=$(xcodebuild -project "$PROJECT" -scheme "$SCHEME" -showBuildSettings \
          | awk -F' = ' '/MARKETING_VERSION/{print $2; exit}')
```

Corollaire : `build-dmg.sh:27` masque le code de sortie de `xcodebuild`
(`| grep … || true`). Conserver `PIPESTATUS` ou retirer le `|| true`.

**Effort.** ~30 min.

---

### P3-8 — Fichier LICENSE absent

Le README annonce « MIT License - see the LICENSE file » et
`raycast-hydrobar/package.json` déclare `"license": "MIT"`, mais aucun fichier
`LICENSE` n'existe dans le dépôt. Juridiquement, le code est donc « tous droits
réservés » par défaut — ce qui interdit les contributions que la section
« Contributing » sollicite, et bloque une soumission au Raycast Store.

**Correctif.** ✅ **Corrigé** : `LICENSE` (MIT, 2026, Antoine Deshoux) ajouté à la
racine du dépôt.

---

## P4 — Cosmétique et code mort

| # | Emplacement | Constat |
|---|---|---|
| P4-1 | `MainView.swift:181-198` | `MainView.startHolding()` / `stopHolding()` dupliquent `MainContentView` (avec un débit différent : 5 ml au lieu de 25) et `startHolding` n'est **jamais appelé**. Code mort trompeur. |
| P4-2 | `MainView.swift:158-164` | `onChange(of: currentView)` avec un corps vide et un commentaire « la taille sera mise à jour automatiquement » — un `asyncAfter` qui n'exécute rien. |
| P4-3 | `FocusModeMonitor.swift:100-104` | `setupFocusStatusObserver()` : corps vide, appelée depuis `startMonitoring`. |
| P4-4 | `HydrationManager.swift:719` | `_ = calendar.date(byAdding: .day, value: -6, to: today)!` — calcul jeté, avec force-unwrap. |
| P4-5 | `FocusModeMonitor.swift:29`, `SettingsView.swift:336`, `StatsComponents.swift:205` | Gardes `#available(macOS 12.0/13.0)` alors que la cible est 15.1 → branches mortes, dont un message « macOS 13+ required » inatteignable. |
| P4-6 | `MainView.swift:81` | `static var defaultValue: CGSize` dans un `PreferenceKey` : variable statique mutable → **erreur** en Swift 6 strict concurrency. Passer en `static let`. |

**Autres points mineurs relevés :**

- `MainView.swift:15` — `HoldButton.label` déclaré, jamais lu (voir P3-5).
- `HydroBarWidget.swift:88` — presets du widget codés en dur `[200, 500, 750]` au
  lieu des presets de l'utilisateur ; `HydrationSnapshot` ne les transporte pas.
- `HydroBarWidget.swift:29` — `Timeline(policy: .never)` : si l'app est quittée, le
  widget reste figé indéfiniment (y compris après le reset de minuit). Prévoir
  `.after(prochainMinuit)`.
- `HydrationManager.swift:977` — `UserDefaults.didChangeNotification` observée sur
  une suite partagée : ce mécanisme est peu fiable **entre processus**. Pour un
  réveil fiable depuis le widget, utiliser `DistributedNotificationCenter` ou une
  notification Darwin (`CFNotificationCenterGetDarwinNotifyCenter`).
- `AddWaterIntent.swift:17-29` — l'intent écrit un snapshot optimiste **et** un delta
  en attente ; si le routage change un jour, le risque de double comptage est réel.
  Un seul mécanisme (le delta, source de vérité) serait plus sûr.
- Facteur de conversion oz incohérent : `2.957` cl dans l'app
  (`HydrationManager.swift:54`) contre `29.5735` ml dans le widget
  (`HydroBarWidget.swift:69`). À centraliser dans `AppGroupStore` (partagé par les
  deux targets).
- `ContentView.swift` (24 lignes, « Hello, world! ») : template Xcode jamais
  supprimé, jamais référencé.
- « Reset my day » (`MainView.swift:285`) efface la journée **sans confirmation** et
  vide la pile d'undo (`HydrationManager.swift:480`) — donc l'action est
  irréversible sur un simple clic.
- Commentaires en français (165 occurrences) dans un projet dont le README, les
  identifiants et les chaînes localisées sont en anglais. À trancher une bonne fois
  (le français est un choix légitime, mais il doit être uniforme).
- `build-dmg.sh:24` — Team ID `S8YKU5RDHK` en dur dans un script versionné. Ce n'est
  pas un secret, mais le passer en variable d'environnement facilite les forks.

---

## Plan d'action suggéré

| Lot | Contenu | Effort | Pourquoi en premier |
|---|---|---|---|
| **1. Colmatage** | ~~P0-2~~, P0-5, ~~P0-6~~, P3-3, ~~P3-8~~, P4-1→P4-6 | ~0,5 j | Crash, code mort, risque de perte de données. Aucun risque de régression. |
| **2. Deep links** ✅ | ~~P0-1~~ — livré, voir [`specs/DEEP_LINKS.md`](specs/DEEP_LINKS.md) | fait | Rend fonctionnel ce qui est déjà documenté et débloque Raycast, Shortcuts, Stream Deck, Alfred. |
| **3. Filet de sécurité** | P3-1 (injection + tests), ~~P3-2~~ (CI ✅), P3-4 (lint) | ~1,5 j | Prérequis pour refactorer sereinement le lot 4. |
| **4. Refactor du cœur** | P1-1 (`@Observable`), P1-2, P1-3, P1-4 | ~3 j | Supprime mécaniquement P2-1, P2-4 et la moitié des `DispatchQueue.main.async`. |
| **5. Perf et finitions** | P2-2, P2-3, P2-5, P1-7, P3-5 | ~2 j | Confort et consommation. |
| **6. Widget et distribution** | P0-3, P0-4, P3-6, P3-7 | ~2 j | Débloque la v1.3 (widget) et supprime l'écran « app endommagée ». |

---

## Ce qui est déjà bien fait

Pour équilibrer : ces choix sont bons et méritent d'être conservés tels quels.

- **Découpage par fichier clair et cohérent** — on trouve ce qu'on cherche sans
  chercher, ce qui est rare dans une app de cette taille.
- **`AppGroupStore`** est proprement conçu : `Foundation` uniquement, types valeur,
  aucune dépendance vers `HydrationManager`. C'est exactement la bonne frontière
  entre les deux targets.
- **`HoldButton` en `NSViewRepresentable`** avec le commentaire expliquant *pourquoi*
  (les gestes SwiftUI sont avalés par la chaîne d'événements du popover). C'est le
  bon réflexe : documenter le contournement, pas seulement le poser.
- **`GitHubUpdateChecker`** : `async/await`, gestion explicite des codes HTTP,
  comparaison sémantique de versions composant par composant. Le fichier le plus
  propre du projet.
- **Le debounce du rechargement de widget** (`HydrationManager.swift:1008-1015`),
  commentaire de justification inclus.
- **`historyEntries` stocke l'objectif du jour** (`HistoryEntry.targetMl`) : les
  statistiques passées restent justes même après changement d'objectif. C'est un
  détail que beaucoup d'apps ratent.
- **Localisation en `.xcstrings`** dès le départ, avec des `comment:` utiles.
