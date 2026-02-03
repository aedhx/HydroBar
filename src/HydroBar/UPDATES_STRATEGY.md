# HydroBar — Stratégie de mises à jour

Ce document décrit l’approche actuelle (notification manuelle) et les options pour des mises à jour automatisées à distance.

---

## 1. Étape actuelle : notification manuelle (implémentée)

### Comportement

- **Réglages → UPDATES** : affiche la version installée et un bouton **« Vérifier les mises à jour »**.
- Au clic, l’app interroge l’API GitHub **Releases** (`/repos/aedhx/HydroBar/releases/latest`).
- Comparaison de versions (sémantique : `major.minor.patch`).
- **À jour** : message « Vous êtes à jour ».
- **Mise à jour disponible** : message « La version X.Y.Z est disponible » + bouton **« Ouvrir la page de téléchargement »** qui ouvre la release GitHub (DMG à télécharger manuellement).

### Fichiers concernés

- `HydroBar/GitHubUpdateChecker.swift` : fetch API, comparaison de versions, état (à jour / mise à jour / erreur).
- `HydroBar/SettingsView.swift` : section UPDATES (version courante, bouton, messages).

### Configuration

- Repo : `aedhx/HydroBar` (constantes dans `GitHubUpdateChecker.swift`).
- Version courante : `CFBundleShortVersionString` (depuis le projet Xcode / Info.plist généré).

---

## 2. Étape suivante : mises à jour à distance automatisées

Objectif : permettre une mise à jour sans retéléchargement manuel du DMG (téléchargement et remplacement de l’app par l’app elle-même ou par un installateur intégré).

### Contraintes macOS

1. **Signature et notarisation**  
   Une app distribuée en dehors du Mac App Store doit être signée et idéalement notarisée. Une mise à jour doit :
   - soit remplacer le binaire par une version elle-même signée (et notarisée),
   - soit lancer un installateur (pkg/dmg) signé et notarisé.

2. **Sans compte Apple Developer**  
   - Pas de notarisation officielle.
   - Signature ad hoc possible (`codesign -s -`), mais Gatekeeper peut toujours afficher des avertissements.
   - Mise à jour « silencieuse » (remplacement de l’app sans interaction) possible techniquement, mais l’utilisateur devra éventuellement confirmer au premier lancement (clic droit → Ouvrir, ou autorisation dans Sécurité).

3. **Avec compte Apple Developer**  
   - Notarisation possible → meilleure expérience Gatekeeper.
   - Même logique de mise à jour : télécharger un artefact signé + notarisé, puis l’installer.

### Options techniques

#### A. Téléchargement du DMG + ouverture (semi-automatique)

- L’app détecte une nouvelle version (déjà en place via GitHub Releases).
- Au lieu d’ouvrir uniquement la page Releases, on peut :
  - récupérer l’URL de l’asset DMG depuis l’API (ex. `browser_download_url` du premier asset ou celui dont le nom contient `.dmg`),
  - ouvrir cette URL dans le navigateur (ou déclencher un téléchargement via `NSWorkspace.shared.open(dmgURL)`).
- L’utilisateur installe manuellement en ouvrant le DMG et en faisant glisser l’app.

**Avantages** : simple, pas de remplacement de binaire par l’app, pas de risque de corrompre l’app en cours.  
**Inconvénients** : pas d’installation « en un clic » dans l’app.

#### B. Téléchargement + montage du DMG + copie de l’app (automatique, dans l’app)

- Télécharger le DMG depuis l’URL de l’asset.
- Monter le DMG (ex. `hdiutil attach` ou APIs AppKit).
- Copier `HydroBar.app` depuis le volume monté vers `/Applications` (ou vers le même dossier que l’app actuelle).
- Démonter le DMG, supprimer le fichier DMG.
- Proposer de redémarrer l’app (ou de quitter pour que l’utilisateur relance la nouvelle version).

**Points d’attention** :

- **Permissions** : écriture dans `/Applications` ou dans le dossier contenant l’app (ex. si l’app est dans Applications, il faut remplacer soi-même ou demander des privilèges admin).
- **Signature** : le nouveau `.app` doit être signé (idéalement notarisé) pour éviter des blocages Gatekeeper après remplacement.
- **Robustesse** : en cas d’échec en milieu de copie, risque d’app cassée ; prévoir une copie de secours ou une vérification de l’app téléchargée avant remplacement.
- **Sandbox** : si l’app est sandboxée, l’écriture en dehors du conteneur (ex. `/Applications`) n’est en général pas autorisée sans entitlement spécifique ; une mise à jour « in-place » vers le conteneur est possible mais peu standard pour une app « globale ».

#### C. Installer un petit binaire de mise à jour (updater dédié)

- Fournir un petit exécutable (ou une seconde app) dont le seul rôle est :
  - télécharger la nouvelle version (DMG ou zip),
  - remplacer l’app (ou l’installer dans `/Applications`),
  - relancer l’app.
- L’app principale lance cet updater puis se quitte ; l’updater fait le travail et relance la nouvelle version.

**Avantages** : on peut éviter de modifier l’app en cours d’exécution (pas d’écrasement de soi-même).  
**Inconvénients** : concevoir, signer et distribuer un second binaire, et gérer son cycle de vie (versionning, compatibilité).

#### D. Utiliser un framework tiers

- **Sparkle** (https://sparkle-project.org/) : standard sur macOS pour les mises à jour hors App Store.
  - Gère le téléchargement, la signature (DSA/EdDSA), l’extraction, le remplacement et le redémarrage.
  - Nécessite d’héberger un **appcast** (XML) décrivant les versions et les URLs de téléchargement.
  - Les releases GitHub peuvent être utilisées comme source des binaires ; il faut en revanche générer un **appcast** (à la main, par script ou par CI) et l’héberger (GitHub Pages, repo, ou autre).
- **Squirrel.Mac** (et variantes) : autre option, moins répandue pour des apps Swift/natives.

**Recommandation** : pour une mise à jour automatisée fiable et maintenable, Sparkle est l’option la plus adaptée sur macOS (hors App Store).

---

## 3. Synthèse et ordre de mise en œuvre suggéré

| Étape | Description | Statut |
|-------|-------------|--------|
| 1 | Notifier l’utilisateur qu’une mise à jour est disponible (GitHub Releases) + lien manuel vers la page / le DMG | ✅ Implémenté |
| 2 | Optionnel : ouvrir directement l’URL du DMG (lien de téléchargement) au lieu de la page Releases | À faire si souhaité |
| 3 | Étudier l’intégration de **Sparkle** (appcast + signature) pour mise à jour en un clic | Recommandé pour automatisation |
| 4 | Si pas de Sparkle : implémenter un flux type B (téléchargement + montage DMG + copie) avec gestion d’erreurs et privilèges | Plus lourd et plus risqué |

Pour l’instant, l’utilisateur est notifié et peut télécharger manuellement le DMG depuis les releases GitHub. Pour aller vers une mise à jour à distance automatisée sans retéléchargement manuel du DMG, la voie la plus propre est d’intégrer **Sparkle** et d’alimenter un **appcast** à partir de vos releases GitHub (par script ou CI).
