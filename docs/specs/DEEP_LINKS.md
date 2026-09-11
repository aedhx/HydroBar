# Spécification — Deep links `hydrobar://`

> **Statut : implémentée** (branche `claude/cool-johnson-f4y575`).
> Code : `HydroBar/DeepLink.swift` (parsing), `HydroBar/DeepLinkRouter.swift`
> (exécution), `HydroBar/Info.plist` (enregistrement), `HydroBarTests/DeepLinkParserTests.swift`.
> **Résout :** [AUDIT_TECHNIQUE.md § P0-1](../AUDIT_TECHNIQUE.md#p0-1--le-schéma-durl-hydrobar-nexiste-pas--lextension-raycast-ne-peut-pas-fonctionner)
> **Débloque :** Raycast (déjà écrit), Shortcuts, Alfred, Stream Deck, BetterTouchTool,
> Keyboard Maestro, scripts shell, Automator, barres de menu tierces.

## 1. Contexte

L'extension Raycast du dépôt (`raycast-hydrobar/src/*.ts`) ouvre déjà des URLs
`hydrobar://`, et son README les documente. **L'app ne les gère pas** : aucun
`CFBundleURLTypes` déclaré, aucun handler implémenté. Cette spec décrit quoi
implémenter pour que le contrat déjà publié devienne vrai — sans casser l'extension
existante.

**Contrainte de compatibilité.** Ces deux formes sont déjà dans la nature et doivent
continuer à fonctionner à l'identique :

```
hydrobar://add?ml=250
hydrobar://add/preset/0        # index 0-based
```

## 2. Grammaire des URLs

Format général : `hydrobar://<action>[/<path>][?<params>]`

### 2.1 Actions d'écriture

| URL | Effet | Notes |
|---|---|---|
| `hydrobar://add?ml=250` | Ajoute 250 ml | **Compat Raycast** |
| `hydrobar://add?cl=25` | Ajoute 25 cl | |
| `hydrobar://add?l=0.25` | Ajoute 0,25 L | |
| `hydrobar://add?oz=8` | Ajoute 8 oz US | |
| `hydrobar://add/preset/0` | Ajoute le preset n° 1 (index **0**-based) | **Compat Raycast** |
| `hydrobar://add?preset=1` | Ajoute le preset n° 1 (index **1**-based) | Forme recommandée, alignée sur l'UI |
| `hydrobar://undo` | Annule le dernier ajout | Équivalent ⌘Z |
| `hydrobar://set-goal?ml=2500` | Définit l'objectif du jour | **Sensible** — voir § 4 |
| `hydrobar://reset` | Remet la journée à zéro | **Destructif** — voir § 4 |

Si plusieurs unités sont fournies (`?ml=250&cl=25`), l'URL est **rejetée** — jamais
d'interprétation « au mieux » sur une action qui modifie des données.

### 2.2 Actions de navigation

| URL | Effet |
|---|---|
| `hydrobar://open` | Ouvre le popover sur la vue Aujourd'hui |
| `hydrobar://open/stats` | Ouvre le popover sur les statistiques |
| `hydrobar://open/settings` | Ouvre le popover sur les réglages |

### 2.3 Paramètres transverses

| Paramètre | Valeurs | Défaut | Rôle |
|---|---|---|---|
| `silent` | `1` / `0` | `0` | `1` = pas de son ni de retour visuel (utile pour les scripts en lot) |
| `confirm` | `1` | — | Requis par les actions destructives, voir § 4 |
| `x-success` | URL | — | Callback en cas de succès, voir § 3 |
| `x-error` | URL | — | Callback en cas d'échec, voir § 3 |

## 3. Retour d'information : `x-callback-url`

Un schéma d'URL est *fire-and-forget* : Raycast ne peut pas savoir si l'ajout a
réussi, ni afficher le total du jour. D'où le toast approximatif
« HydroBar not running? » affiché aujourd'hui quelle que soit la cause réelle.

La convention [x-callback-url](http://x-callback-url.com/) corrige ça sans dépendance :

```
hydrobar://add?ml=250&x-success=raycast://extensions/aedhx/hydrobar/callback
```

Au succès, HydroBar ouvre l'URL `x-success` en y ajoutant :

| Paramètre ajouté | Exemple |
|---|---|
| `currentMl` | `1450` |
| `targetMl` | `2000` |
| `percent` | `72` |
| `added` | `250` |

En cas d'échec, `x-error` est ouvert avec `errorCode` et `errorMessage`
(voir la table § 5). Si `x-error` est absent, l'erreur part dans `os_log`, dans le
journal consultable en mode debug (§ 4.4), et dans une notification locale — cette
dernière au mieux, puisqu'elle dépend de l'autorisation de notification.

Un callback est fourni par l'appelant, donc potentiellement hostile : les schémas
`file`, `data`, `javascript`, `about` et `hydrobar` lui-même (boucle) sont refusés.

## 4. Sécurité

**Un schéma d'URL est une surface d'attaque publique.** N'importe quelle page web
visitée par l'utilisateur peut déclencher `hydrobar://reset` via une iframe, et
n'importe quelle app peut spammer `hydrobar://add`. Les règles suivantes ne sont pas
optionnelles.

### 4.1 Actions destructives confirmées

`reset` et `set-goal` **ne s'exécutent jamais directement** depuis une URL. Deux
verrous cumulés :

1. Le paramètre `confirm=1` doit être présent (protection contre le déclenchement
   accidentel).
2. Une alerte modale demande la validation de l'utilisateur — sauf si le réglage
   *« Autoriser les liens destructifs sans confirmation »* (désactivé par défaut,
   à ajouter dans l'onglet Intégrations) est activé.

`add` et `undo` ne sont pas destructifs : `add` est annulable par `undo`, et `undo`
est borné par la pile existante.

### 4.2 Validation et bornes

Réutiliser les bornes définies dans
[AUDIT_TECHNIQUE.md § P1-4](../AUDIT_TECHNIQUE.md#p1-4--aucune-validation-des-entrées-utilisateur) —
la validation des deep links et celle des réglages doivent partager **exactement** le
même code, sinon elles divergeront :

```swift
enum HydrationLimits {
    static let goal: ClosedRange<Double>   = 200...10_000   // ml
    static let single: ClosedRange<Double> = 1...5_000      // ml par ajout
}
```

Toute valeur hors bornes, non numérique, `NaN` ou `Infinity` → rejet avec
`invalidAmount`. Pas de clamp silencieux : une URL invalide doit échouer bruyamment,
pas produire une valeur approchée.

### 4.3 Limitation de débit

Maximum **10 actions par seconde**, fenêtre glissante — `open` comprise, sinon une
page peut faire clignoter l'app indéfiniment. Au-delà, les requêtes sont rejetées avec
`rateLimited`. Empêche une page malveillante de saturer la journée d'un coup, et
protège au passage le chemin de persistance
(cf. [§ P2-2](../AUDIT_TECHNIQUE.md#p2-2---hold-to-add---20-hz--2-écritures-disque--reprogrammation-des-notifications--sync-widget)).

### 4.4 Journal des actions

Les 50 dernières actions déclenchées par deep link sont conservées en mémoire et
consultables en mode debug (`SettingsView` → section DEBUG). Sans ça, un ajout
inexpliqué est indébuggable.

### 4.5 Ce que le schéma ne fera jamais

- Aucune action de **lecture** renvoyant des données vers une URL arbitraire
  (pas de `hydrobar://export?to=https://…`) : ce serait un canal d'exfiltration.
  La lecture passe par App Intents / Shortcuts, où macOS gère les permissions.
- Aucune action modifiant des réglages système, les raccourcis globaux ou les
  autorisations.
- Aucune exécution de code, chemin de fichier ou commande transmis par URL.

## 5. Codes d'erreur

| Code | Signification | HTTP-like |
|---|---|---|
| `unknownAction` | Action inconnue | 404 |
| `invalidAmount` | Quantité absente, non numérique ou hors bornes | 400 |
| `ambiguousUnit` | Plusieurs unités fournies simultanément | 400 |
| `presetOutOfRange` | Index de preset inexistant | 400 |
| `confirmationRequired` | Action destructive sans `confirm=1` | 403 |
| `userCancelled` | L'utilisateur a refusé la confirmation | 403 |
| `rateLimited` | Plus de 10 actions/seconde | 429 |
| `nothingToUndo` | Pile d'undo vide | 409 |

## 6. Implémentation

### 6.1 Enregistrement du schéma

Le target app utilise `GENERATE_INFOPLIST_FILE = YES` et il n'existe pas de réglage
`INFOPLIST_KEY_*` pour un tableau de `CFBundleURLTypes`. Il faut donc fournir un
`Info.plist` partiel — Xcode fusionne les clés générées avec celles du fichier.

1. Créer `src/HydroBar/HydroBar/Info.plist` :

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleURLTypes</key>
    <array>
        <dict>
            <key>CFBundleURLName</key>
            <string>com.adxcool.HydroBar.deeplink</string>
            <key>CFBundleTypeRole</key>
            <string>Editor</string>
            <key>CFBundleURLSchemes</key>
            <array>
                <string>hydrobar</string>
            </array>
        </dict>
    </array>
</dict>
</plist>
```

2. Dans le target **HydroBar** : `INFOPLIST_FILE = HydroBar/Info.plist`
   (en gardant `GENERATE_INFOPLIST_FILE = YES`).

3. Vérifier l'enregistrement après build :

```bash
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
  -dump | grep -A3 hydrobar
```

> **Note.** L'enregistrement n'est effectif que si l'app est dans un emplacement
> connu de LaunchServices. Pendant le développement, lancer l'app une fois depuis
> `/Applications` (ou `lsregister -f` sur le `.app` de DerivedData).

### 6.2 Réception

Pour une app `LSUIElement` sans fenêtre, `onOpenURL` de SwiftUI n'est pas fiable :
il dépend d'une scène active, or la seule scène ici est `Settings { EmptyView() }`
(`HydroBarApp.swift:28`). On passe par AppKit, avec **un seul** point d'entrée :

```swift
// HydroBarApp.swift — dans AppDelegate
func application(_ application: NSApplication, open urls: [URL]) {
    urls.forEach { DeepLinkRouter.shared.handle($0) }
}
```

> **Pourquoi pas de handler Apple Event `GURL` en plus ?** C'est le motif classique
> (`NSAppleEventManager.setEventHandler(…, kAEGetURL)`) hérité d'avant
> `application(_:open:)`. AppKit installe déjà son propre handler `GURL`, qui appelle
> précisément cette méthode. En poser un second expose à ce que l'URL soit délivrée
> **deux fois** selon l'ordre d'installation — soit, ici, de l'eau ajoutée en double.
> Une seule voie, pas de déduplication à écrire.

Le cas « app démarrée *par* l'URL » est couvert autrement : le routeur met les URLs en
file d'attente tant que la barre de menu n'existe pas, et `markReady()` la vide à la
fin de `applicationDidFinishLaunching`.

```swift
func markReady() {
    isReady = true
    let queued = pendingURLs
    pendingURLs.removeAll()
    queued.forEach(handle)
}
```

### 6.3 Routeur

Point clé : **séparer le parsing de l'exécution**. Le parsing est une fonction pure,
donc testable sans app, sans `UserDefaults` et sans UI — c'est ce qui rend cette
fonctionnalité couvrable à 100 % par des tests
(cf. [§ P3-1](../AUDIT_TECHNIQUE.md#p3-1--aucun-test)).

```swift
// DeepLinkRouter.swift

enum DeepLinkAction: Equatable {
    case add(ml: Double)
    case addPreset(index: Int)          // 0-based en interne
    case undo
    case setGoal(ml: Double)
    case reset
    case open(ViewType)
}

enum DeepLinkError: String, Error {
    case unknownAction, invalidAmount, ambiguousUnit, presetOutOfRange
    case confirmationRequired, userCancelled, rateLimited, nothingToUndo
}

struct DeepLinkParser {
    /// Fonction pure : URL → action. Aucun effet de bord, aucune dépendance.
    static func parse(_ url: URL) throws -> DeepLinkAction { /* … */ }
}

final class DeepLinkRouter {
    static let shared = DeepLinkRouter(manager: .shared)

    func handle(_ url: URL) {
        do {
            let action = try DeepLinkParser.parse(url)
            try rateLimiter.check()
            try execute(action, from: url)
            callBack(url.queryValue("x-success"), with: successPayload())
        } catch let error as DeepLinkError {
            report(error, from: url)
        } catch { /* … */ }
    }
}
```

### 6.4 Retour utilisateur

Pour une action réussie hors `silent=1` :

- un son court est joué (`NSSound(named: "Pop")`) ;
- si le popover est ouvert, il se met à jour immédiatement ;
- *(reporté)* une animation courte de l'icône : elle suppose d'abord de corriger
  [P2-1](../AUDIT_TECHNIQUE.md#p2-1--licône-de-la-barre-de-menu-est-reconstruite-deux-fois-par-seconde),
  l'icône étant aujourd'hui reconstruite deux fois par seconde.

Aucune notification système pour un succès : ce serait intrusif pour une action que
l'utilisateur vient de déclencher lui-même.

## 7. Tests

### 7.1 Tests unitaires (`DeepLinkParserTests`)

```swift
@Test func parsesRaycastLegacyForms() throws {
    #expect(try DeepLinkParser.parse(URL(string: "hydrobar://add?ml=250")!) == .add(ml: 250))
    #expect(try DeepLinkParser.parse(URL(string: "hydrobar://add/preset/0")!) == .addPreset(index: 0))
}

@Test func rejectsAmbiguousUnits() {
    #expect(throws: DeepLinkError.ambiguousUnit) {
        try DeepLinkParser.parse(URL(string: "hydrobar://add?ml=250&cl=25")!)
    }
}

@Test func rejectsOutOfRangeAndNonFinite() {
    for bad in ["hydrobar://add?ml=0", "hydrobar://add?ml=-5",
                "hydrobar://add?ml=99999", "hydrobar://add?ml=abc",
                "hydrobar://add?ml=inf", "hydrobar://add?ml=nan"] {
        #expect(throws: DeepLinkError.invalidAmount) {
            try DeepLinkParser.parse(URL(string: bad)!)
        }
    }
}

@Test func requiresConfirmationForDestructiveActions() {
    #expect(throws: DeepLinkError.confirmationRequired) {
        try DeepLinkParser.parse(URL(string: "hydrobar://reset")!)
    }
}
```

### 7.2 Vérification manuelle

```bash
open "hydrobar://add?ml=250"
open "hydrobar://add/preset/0"
open "hydrobar://undo"
open "hydrobar://open/stats"
open "hydrobar://reset"              # doit être refusé : confirmationRequired
open "hydrobar://reset?confirm=1"    # doit afficher une confirmation
open "hydrobar://add?ml=-1"          # doit être refusé
for i in $(seq 1 30); do open "hydrobar://add?ml=1"; done   # doit déclencher rateLimited
```

## 8. Mise à jour de l'extension Raycast

Une fois le schéma en place, `raycast-hydrobar` peut être amélioré :

1. **Distinguer les erreurs réelles.** Aujourd'hui, tous les échecs affichent
   « HydroBar not running? » (`src/add-water.ts:18-24`), même quand l'app tourne. Avec
   `x-error`, le toast peut dire ce qui s'est vraiment passé.
2. **Presets dynamiques.** Les commandes sont figées sur « 0.3 L / 0.5 L / 1 L »
   (`package.json`) alors que l'app expose 200/500/750 ml par défaut et que
   l'utilisateur peut les changer. Utiliser `hydrobar://add?preset=N` et libeller les
   commandes « Preset 1/2/3 », sans quantité codée en dur.
3. **Commande « Status ».** Nécessite un canal de lecture — c'est le rôle des App
   Intents (roadmap F2), pas du schéma d'URL (§ 4.5).
4. **Publication sur le Raycast Store**, qui exige un `LICENSE`
   (cf. [§ P3-8](../AUDIT_TECHNIQUE.md#p3-8--fichier-license-absent)).

## 9. Découpage proposé

| Étape | Contenu | Effort |
|---|---|---|
| 1 | `Info.plist` + `CFBundleURLTypes` + vérif `lsregister` | 30 min |
| 2 | `DeepLinkParser` (fonction pure) + tests unitaires | 2 h |
| 3 | `DeepLinkRouter` + branchement `AppDelegate` | 1 h 30 |
| 4 | Confirmation des actions destructives + rate limiter | 1 h |
| 5 | `x-callback-url` (succès / erreur) | 1 h |
| 6 | Retour sonore (le pulse de l'icône est reporté : il suppose P2-1 corrigé) | 1 h |
| 7 | Mise à jour de l'extension Raycast | 1 h |
| 8 | Documentation (README app + README Raycast) | 30 min |

**Total : ~1 journée.** Les étapes 1 à 3 seules (~4 h) suffisent déjà à rendre
l'extension Raycast fonctionnelle.

> **Fait.** Étapes 1 à 5, 7 et 8. Étape 6 : le son est en place
> (`NSSound(named: "Pop")`, sauf `silent=1`) ; l'animation de l'icône est reportée,
> elle demande d'abord de corriger
> [P2-1](../AUDIT_TECHNIQUE.md#p2-1--licône-de-la-barre-de-menu-est-reconstruite-deux-fois-par-seconde).
