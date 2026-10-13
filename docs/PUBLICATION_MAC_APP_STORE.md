# Publier HydroBar sur le Mac App Store

Ce guide part de l'état du dépôt et va jusqu'à la mise en vente. Ce qui est
déjà fait est listé d'abord ; le reste demande ton compte Apple ou un vrai
Mac, et ne peut pas se faire depuis la CI.

HydroBar a deux distributions :

| | Mac App Store | DMG GitHub |
|---|---|---|
| Script | `./build-appstore.sh` | `./build-dmg.sh` |
| Mises à jour | par le Store | bouton « Vérifier les mises à jour » (GitHub) |
| Accès réseau | aucun | GitHub uniquement |
| Synchro Concentration (ancienne) | masquée | disponible |

La différence tient à la condition de compilation `APP_STORE`. La CI compile
les deux variantes à chaque push.

---

## 0. Où on en est (13 octobre 2026)

`./build-appstore.sh` va au bout sur un vrai Mac : archive, vérifications
(sandbox, pas de réseau, pas de vérificateur GitHub) et export de
`build/appstore/export/HydroBar.pkg`, signé pour le Store.

Le seul blocage rencontré est levé : l'identifiant du **widget**
(`com.adxcool.HydroBar.HydroBarWidget`) n'avait pas le groupe d'apps
`group.com.adxcool.HydroBar` sur developer.apple.com, et l'archive s'arrêtait à
la signature (« Provisioning profile … doesn't match the entitlements file's
value for the com.apple.security.application-groups entitlement »). Il se règle
dans Identifiers › l'identifiant du widget › App Groups › Configure, puis
**Save** en haut de la page : sans ce Save, rien n'est appliqué.

Reste, dans l'ordre : § 2.3 (créer la fiche dans App Store Connect), § 5
(envoyer la build avec `UPLOAD=1`), § 3 et § 4 (fiche et captures), § 6
(TestFlight), § 7 (soumettre).

**Quel Xcode.** Le projet compile avec Xcode 16, mais le bouton du Centre de
contrôle et le Liquid Glass ne sont compilés qu'avec le SDK macOS 26. Le paquet
obtenu avec Xcode 16 est valide mais ne les contient pas ; pour la version du
Store, utilise Xcode 26 (le script prévient sinon). La fiche et les notes de
review parlent du bouton du Centre de contrôle.

---

## 1. Déjà prêt dans le dépôt

- **Sandbox** pour l'app et le widget. L'accès aux fichiers se limite à ceux
  que tu choisis (export / import). Pas de réseau dans la build App Store.
- **Privacy manifests** (`PrivacyInfo.xcprivacy`) pour l'app et le widget :
  aucun pistage, aucune donnée collectée, UserDefaults déclaré (raisons
  `CA92.1` et `1C8F.1`).
- **Conformité export** : `ITSAppUsesNonExemptEncryption = NO` dans
  Info.plist. App Store Connect ne posera plus la question.
- **Catégorie** Health & Fitness, copyright, équipe de signature `S8YKU5RDHK`
  sur l'app et le widget.
- Les **options de debug** n'existent que dans les builds Debug.
- **Fiche App Store** en 9 langues dans `fastlane/metadata/` : nom,
  sous-titre, mots-clés, texte promotionnel, description, notes de version,
  URL de support et de confidentialité. Vérification des longueurs :
  `python3 fastlane/check_metadata.py`.
- **Notes pour l'équipe de review** : `fastlane/metadata/review_information/notes.txt`.
- **Politique de confidentialité** : [`PRIVACY.md`](../PRIVACY.md), publiée à
  `https://github.com/aedhx/HydroBar/blob/main/PRIVACY.md`.
- **URL marketing** de la fiche : `https://hydrobar.adx.cool/`, la landing
  (`website/`, publiée par `./deploy-website.sh`). Une fois l'app en vente,
  colle le lien de la fiche dans `APP_STORE_URL`, en bas de
  `website/index.html`, et relance le script.

---

## 2. Compte et identifiants (une fois)

1. **Apple Developer Program** actif (99 $ par an) sur l'équipe `S8YKU5RDHK`.
   Si ton équipe est différente, remplace-la dans Xcode (cible HydroBar et
   cible HydroBarWidgetExtension › Signing & Capabilities) ou passe
   `DEVELOPMENT_TEAM=…` au script.
2. **Identifiants** sur developer.apple.com › Certificates, Identifiers &
   Profiles. Xcode les crée seul avec la signature automatique ; à vérifier :
   - App ID `com.adxcool.HydroBar`, avec la capability **App Groups** ;
   - App ID `com.adxcool.HydroBar.HydroBarWidget`, avec **App Groups** ;
   - App Group `group.com.adxcool.HydroBar`, coché sur les deux App ID.
     Sans lui, le widget ne voit plus les données de l'app.
3. **Fiche dans App Store Connect** › Apps › « + » › Nouvelle app :
   - plateforme **macOS** ;
   - nom : `HydroBar – Water Tracker`. S'il est pris, essaie
     `HydroBar – Hydration`, puis mets à jour `fastlane/metadata/*/name.txt` ;
   - langue principale : **English (U.S.)** ;
   - identifiant de lot : `com.adxcool.HydroBar` ;
   - SKU : `hydrobar-mac`.

---

## 3. Réglages de la fiche dans App Store Connect

| Rubrique | Réponse |
|---|---|
| **Confidentialité de l'app** | « Aucune donnée collectée » (Data Not Collected) |
| **URL de politique de confidentialité** | `https://github.com/aedhx/HydroBar/blob/main/PRIVACY.md` |
| **Classification par âge** | « Aucun » partout → 4+ |
| **Catégories** | Principale : Santé et forme. Secondaire : Productivité |
| **Droits sur le contenu** | Pas de contenu tiers |
| **Prix et disponibilité** | Ton choix : gratuit, ou un prix fixe. Tous les pays |
| **Coordonnées pour la review** | Ton nom, e-mail, téléphone. Pas de compte de démo : l'app n'a pas de connexion |

### Envoyer la fiche texte

**Option A, copier-coller.** Chaque champ est un fichier texte dans
`fastlane/metadata/<langue>/`. Ajoute d'abord les 8 langues en plus de
l'anglais dans App Store Connect (« Langues de l'app »).

**Option B, fastlane** (plus rapide pour 9 langues) :

```bash
brew install fastlane
# Clé d'API App Store Connect : Utilisateurs et accès › Intégrations › Clés.
fastlane deliver \
  --api_key_path ~/hydrobar-asc-key.json \
  --app_identifier com.adxcool.HydroBar \
  --platform osx \
  --skip_binary_upload --skip_screenshots \
  --metadata_path fastlane/metadata \
  --force
```

`hydrobar-asc-key.json` contient `key_id`, `issuer_id` et `key` (le contenu
du `.p8`) ; voir la documentation fastlane « App Store Connect API ».

---

## 4. Captures d'écran

**Déjà générées** : 6 écrans × 9 langues, en 2880 × 1800, dans
`fastlane/screenshots/<langue>/`. Elles s'envoient avec
`fastlane deliver --skip_metadata --skip_binary_upload`, ou se glissent dans
App Store Connect.

| # | Écran | Message |
|---|---|---|
| 1 | Popover du jour | Boire assez, sans y penser |
| 2 | Notification et ses actions | Des rappels utiles |
| 3 | Réglages › Rappels, section Jours off | Jours de travail, jours off |
| 4 | Statistiques | Bilan du mois, année |
| 5 | Mode gourde | |
| 6 | Menu de l'icône et widget | Partout sur le Mac, rien ailleurs |

Elles sont produites par `marketing/` à partir des textes de l'app (voir
[marketing/README.md](../marketing/README.md)). Ce sont des **recréations
fidèles** de l'interface : avant l'envoi, compare-les à l'app sur un Mac.
Apple demande que la fiche montre l'app telle qu'elle est (règle 2.3). Si un
écran diffère, corrige `marketing/template.html` et relance
`node marketing/render.cjs` : les 9 langues suivent.

Pour remplacer un écran par une vraie capture, utilise une build **Debug** :
clique 5 fois sur le numéro de version dans Réglages › Général, puis
**Generate Fake History Data** dans Réglages › Raccourcis › Debug.

**Aperçu social GitHub** : `Resources/v2/social-preview.jpg` (1280 × 640), à
déposer dans Settings › General › Social preview du dépôt.

---

## 5. Construire et envoyer la build

```bash
# Archive, vérifie (sandbox, pas de réseau, pas de vérificateur GitHub)
# et exporte un .pkg :
./build-appstore.sh

# Ou envoie directement sur App Store Connect :
UPLOAD=1 ./build-appstore.sh
```

- Chaque envoi demande un **numéro de build nouveau** :
  `BUILD_NUMBER=5 UPLOAD=1 ./build-appstore.sh`. Pense à reporter le numéro
  dans le projet (`CURRENT_PROJECT_VERSION`) après coup.
- Le script utilise le compte connecté dans Xcode (Réglages › Comptes). Sur
  une machine sans Xcode connecté, passe la clé d'API : `ASC_KEY_PATH`,
  `ASC_KEY_ID`, `ASC_ISSUER_ID`.
- L'archive est d'abord signée en développement, et un profil de développement
  ne couvre que des Mac enregistrés sur le compte. Si le script dit que ce Mac
  ne l'est pas, relance avec `REGISTER_DEVICE=1`.
- La build apparaît dans **TestFlight** après le traitement d'Apple, en
  général 10 à 30 minutes.

---

## 6. Tester la build TestFlight avant de soumettre

La build App Store est la première à tourner avec un vrai profil de
distribution. À vérifier sur un Mac propre, ou une session utilisateur neuve :

- [ ] premier lancement : écran d'accueil, puis icône dans la barre de menus ;
- [ ] ajout d'un verre, annulation (⌘Z), journal du jour ;
- [ ] **widget** : il affiche le bon total, et un ajout depuis le widget
      apparaît dans l'app. Ça valide le groupe d'apps ;
- [ ] **notifications** : autorisation demandée à l'activation, boutons
      presets, « Autre quantité… » avec saisie, Pause 1 h, dernier appel ;
- [ ] **appel** : pendant un appel FaceTime ou Zoom, aucun rappel ; un rappel
      une minute après si l'un était dû. Vérifier aussi que de la musique
      dans un casque ne compte pas comme un appel. C'est le point le plus
      incertain dans la sandbox ;
- [ ] **filtre de Concentration** : Réglages Système › Concentration ›
      Filtres › HydroBar, avec pastille et type de journée ;
- [ ] **Raccourcis** : les 6 actions apparaissent et fonctionnent ;
- [ ] **Centre de contrôle** (macOS 26) : le bouton « Add Water » ;
- [ ] **export CSV, sauvegarde et restauration JSON** : les panneaux
      d'enregistrement et d'ouverture fonctionnent dans la sandbox ;
- [ ] **ouverture à la connexion** ;
- [ ] **raccourcis clavier globaux** ;
- [ ] Réglages › Général : « Les mises à jour sont installées par l'App
      Store », sans bouton de vérification ;
- [ ] si la version DMG était installée sur ce Mac : l'historique est-il
      retrouvé ?

---

## 7. Soumettre

Dans App Store Connect, version 2.0 :

1. sélectionne la build ;
2. colle les notes de review (`fastlane/metadata/review_information/notes.txt`)
   si fastlane ne l'a pas fait ;
3. **Ajouter pour vérification**, puis **Soumettre**.

La review prend en général 1 à 3 jours.

### Ce qui pourrait coincer, et pourquoi c'est déjà traité

| Règle | Risque | Réponse |
|---|---|---|
| 2.4.5 | Une app qui se met à jour seule | Vérificateur GitHub absent de la build App Store |
| 2.1 | Une fonction cassée en review | Synchro Concentration (capability manquante) masquée ; le filtre la remplace |
| 5.1.1 | Données personnelles | Rien n'est collecté ; le poids n'est jamais enregistré ; politique publiée |
| 1.4.1 | Conseils de santé | Objectif suggéré présenté comme un point de départ, « pas un avis médical » ; même mention dans la description |
| 2.3 | Fiche fidèle à l'app | Captures réelles ; le bouton du Centre de contrôle est réservé à macOS 26 |
| Micro / caméra | Question du reviewer | Expliqué dans les notes : lecture de l'état « utilisé » uniquement, aucune autorisation demandée |

---

## 8. Après la publication

- **Mises à jour** : incrémente `MARKETING_VERSION` (2.0.1, 2.1…) et
  `CURRENT_PROJECT_VERSION`, mets à jour
  `fastlane/metadata/*/release_notes.txt`, puis `UPLOAD=1 ./build-appstore.sh`.
- **DMG GitHub** : `./build-dmg.sh` continue de fonctionner comme avant,
  pour ceux qui préfèrent l'installer hors du Store.
- **Passer du DMG au Store** : les deux versions ont le même identifiant,
  donc le même conteneur sandbox, et la version App Store devrait retrouver
  les données. Mais elles ne sont pas signées pareil (Developer ID ou ad hoc
  d'un côté, Apple de l'autre), et macOS peut alors demander l'accès au
  conteneur, voire le refuser. À vérifier au test TestFlight (§ 6) ; en
  cas de doute, il reste la sauvegarde JSON, à faire avant et à restaurer
  après.
