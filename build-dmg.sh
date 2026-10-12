#!/bin/bash
# build-dmg.sh — builds HydroBar.app in Release and packages it as a DMG + ZIP.
#
# Usage:
#   ./build-dmg.sh
#
# Distribution signée (recommandé — supprime l'écran « app endommagée ») :
#   DEVELOPMENT_TEAM=XXXXXXXXXX \
#   SIGNING_IDENTITY="Developer ID Application: Ton Nom (XXXXXXXXXX)" \
#   NOTARY_PROFILE=HydroBarNotary \
#   ./build-dmg.sh
#
# Préparer NOTARY_PROFILE une seule fois (le mot de passe reste dans le keychain) :
#   xcrun notarytool store-credentials HydroBarNotary \
#     --apple-id "toi@exemple.com" \
#     --team-id XXXXXXXXXX \
#     --password "mot-de-passe-pour-application"
#
# Sans SIGNING_IDENTITY, le script retombe sur une signature ad-hoc et le dit
# clairement : utilisable pour tester localement, PAS pour distribuer.

set -euo pipefail

SCHEME="HydroBar"
PROJECT="src/HydroBar/HydroBar.xcodeproj"
BUILD_DIR="/tmp/HydroBar-build"
DMG_BACKGROUND="Resources/DMG-background.png"

# Paramètres de signature, tous optionnels — voir l'en-tête.
DEVELOPMENT_TEAM="${DEVELOPMENT_TEAM:-}"
SIGNING_IDENTITY="${SIGNING_IDENTITY:-}"
NOTARY_PROFILE="${NOTARY_PROFILE:-}"

# La version vient du projet : la coder en dur ici garantissait un DMG mal nommé
# tôt ou tard (cf. docs/AUDIT_TECHNIQUE.md § P3-7).
VERSION=$(xcodebuild -project "$PROJECT" -scheme "$SCHEME" -showBuildSettings 2>/dev/null \
          | awk -F' = ' '/[[:space:]]MARKETING_VERSION = /{print $2; exit}')
if [ -z "$VERSION" ]; then
  echo "✗ Impossible de lire MARKETING_VERSION depuis $PROJECT"
  exit 1
fi
DMG_NAME="HydroBar-v${VERSION}.dmg"
ZIP_NAME="HydroBar-v${VERSION}.zip"
echo "→ Version $VERSION (lue depuis le projet)"

echo "→ Cleaning previous build..."
rm -rf "$BUILD_DIR" "$DMG_NAME" "$ZIP_NAME"

echo "→ Building HydroBar (Release)..."
# Pas de `| grep … || true` ici : ça masquait le code de sortie de xcodebuild et
# un build en échec passait inaperçu. La sortie va dans un fichier, et seules les
# lignes utiles sont affichées.
BUILD_LOG="$BUILD_DIR.log"
set +e
xcodebuild build \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Release \
  -derivedDataPath "$BUILD_DIR" \
  ${DEVELOPMENT_TEAM:+DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM"} \
  > "$BUILD_LOG" 2>&1
BUILD_STATUS=$?
set -e
grep -E "error:|warning:" "$BUILD_LOG" || true
if [ "$BUILD_STATUS" -ne 0 ]; then
  echo "✗ Build failed (code $BUILD_STATUS) — journal complet : $BUILD_LOG"
  exit 1
fi

APP_PATH=$(find "$BUILD_DIR" -name "HydroBar.app" -not -path "*/Index*" | head -1)
if [ -z "$APP_PATH" ]; then
  echo "✗ HydroBar.app not found — journal complet : $BUILD_LOG"
  exit 1
fi
echo "→ App built: $APP_PATH"

# ── Signature ────────────────────────────────────────────────────────────────
# Le profil de provisioning embarqué sert au développement, pas à la
# distribution hors App Store : on le retire dans les deux cas.
find "$APP_PATH" -name "embedded.provisionprofile" -delete

if [ -n "$SIGNING_IDENTITY" ]; then
  echo "→ Signing with Developer ID..."
  # De l'intérieur vers l'extérieur : signer l'app avant ses extensions
  # invaliderait la signature de l'app.
  # --options runtime (hardened runtime) et --timestamp sont tous deux exigés
  # par la notarisation.
  while IFS= read -r ext; do
    [ -n "$ext" ] || continue
    echo "   · $(basename "$ext")"
    codesign --force --options runtime --timestamp \
      --sign "$SIGNING_IDENTITY" "$ext"
  done < <(find "$APP_PATH/Contents/PlugIns" -name "*.appex" 2>/dev/null)

  codesign --force --options runtime --timestamp \
    --sign "$SIGNING_IDENTITY" "$APP_PATH"

  echo "→ Verifying signature..."
  codesign --verify --deep --strict --verbose=2 "$APP_PATH"
  SIGNED=1
else
  echo "⚠  SIGNING_IDENTITY absent — signature ad-hoc."
  echo "   L'app affichera « HydroBar est endommagé » chez les utilisateurs."
  echo "   Utilisable pour tester localement, pas pour distribuer."
  while IFS= read -r ext; do
    [ -n "$ext" ] || continue
    codesign --force --sign "-" "$ext"
  done < <(find "$APP_PATH/Contents/PlugIns" -name "*.appex" 2>/dev/null)
  codesign --force --sign "-" "$APP_PATH"
  SIGNED=0
fi

# ── Packaging ────────────────────────────────────────────────────────────────
echo "→ Creating DMG..."
create-dmg \
  --volname "HydroBar" \
  --background "$DMG_BACKGROUND" \
  --window-pos 200 120 \
  --window-size 660 400 \
  --icon-size 128 \
  --icon "HydroBar.app" 180 185 \
  --hide-extension "HydroBar.app" \
  --app-drop-link 480 185 \
  --add-file "README.txt" "Resources/README.txt" 330 310 \
  "$DMG_NAME" \
  "$APP_PATH"

echo "→ Creating ZIP..."
ditto -c -k --keepParent "$APP_PATH" "$ZIP_NAME"

# ── Notarisation ─────────────────────────────────────────────────────────────
# Le ticket est agrafé au DMG, pas au ZIP : `stapler` ne sait pas agrafer une
# archive. Un ZIP notarisé fonctionne quand même — Gatekeeper interroge Apple
# en ligne au premier lancement — mais le DMG agrafé marche hors connexion.
if [ "$SIGNED" -eq 1 ] && [ -n "$NOTARY_PROFILE" ]; then
  echo "→ Notarizing $DMG_NAME (peut prendre quelques minutes)..."
  xcrun notarytool submit "$DMG_NAME" \
    --keychain-profile "$NOTARY_PROFILE" \
    --wait

  echo "→ Stapling ticket..."
  xcrun stapler staple "$DMG_NAME"

  echo "→ Gatekeeper check..."
  spctl -a -vvv -t install "$DMG_NAME" || true
elif [ "$SIGNED" -eq 1 ]; then
  echo "⚠  NOTARY_PROFILE absent — DMG signé mais NON notarisé."
  echo "   Gatekeeper le bloquera quand même. Voir l'en-tête du script."
fi

echo ""
echo "✓ Done:"
echo "  $(pwd)/$DMG_NAME"
echo "  $(pwd)/$ZIP_NAME"
if [ "$SIGNED" -eq 1 ] && [ -n "$NOTARY_PROFILE" ]; then
  echo "  signé + notarisé — prêt à distribuer"
elif [ "$SIGNED" -eq 1 ]; then
  echo "  signé, non notarisé"
else
  echo "  ad-hoc — test local uniquement"
fi
