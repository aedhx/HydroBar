#!/bin/bash
# build-appstore.sh — archive HydroBar pour le Mac App Store et l'envoie sur
# App Store Connect (ou l'exporte en .pkg pour Transporter).
#
# La build App Store diffère de la build DMG (build-dmg.sh) sur deux points :
#   - condition de compilation APP_STORE : pas de vérification des mises à
#     jour via GitHub (règle 2.4.5 : c'est le Store qui met à jour) ;
#   - pas d'accès réseau sortant : l'app n'en a alors plus besoin.
#
# Usage :
#   ./build-appstore.sh                    # archive + export d'un .pkg
#   UPLOAD=1 ./build-appstore.sh           # archive + envoi sur App Store Connect
#   BUILD_NUMBER=5 UPLOAD=1 ./build-appstore.sh
#
# Variables :
#   DEVELOPMENT_TEAM  équipe Apple Developer (défaut : celle du projet)
#   BUILD_NUMBER      numéro de build ; chaque envoi en demande un nouveau
#                     (défaut : CURRENT_PROJECT_VERSION du projet)
#   UPLOAD=1          envoie directement sur App Store Connect
#   ASC_KEY_PATH, ASC_KEY_ID, ASC_ISSUER_ID
#                     clé d'API App Store Connect (.p8). Sans elle, Xcode
#                     utilise le compte connecté dans Réglages › Comptes.

set -euo pipefail

SCHEME="HydroBar"
PROJECT="src/HydroBar/HydroBar.xcodeproj"
OUT_DIR="build/appstore"
ARCHIVE="$OUT_DIR/HydroBar.xcarchive"

DEVELOPMENT_TEAM="${DEVELOPMENT_TEAM:-S8YKU5RDHK}"
UPLOAD="${UPLOAD:-0}"

setting() {
  xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration Release -showBuildSettings 2>/dev/null \
    | awk -F' = ' -v key="$1" '$1 ~ "[[:space:]]" key "$" {print $2; exit}'
}

VERSION=$(setting MARKETING_VERSION)
BUILD_NUMBER="${BUILD_NUMBER:-$(setting CURRENT_PROJECT_VERSION)}"
if [ -z "$VERSION" ] || [ -z "$BUILD_NUMBER" ]; then
  echo "✗ Impossible de lire la version depuis $PROJECT"
  exit 1
fi
echo "→ HydroBar $VERSION ($BUILD_NUMBER) pour le Mac App Store, équipe $DEVELOPMENT_TEAM"

AUTH_ARGS=()
if [ -n "${ASC_KEY_PATH:-}" ]; then
  AUTH_ARGS=(-authenticationKeyPath "$ASC_KEY_PATH"
             -authenticationKeyID "${ASC_KEY_ID:?ASC_KEY_ID manquant}"
             -authenticationKeyIssuerID "${ASC_ISSUER_ID:?ASC_ISSUER_ID manquant}")
fi

rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"

echo "→ Archive (Release, APP_STORE)…"
set +e
xcodebuild archive \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -archivePath "$ARCHIVE" \
  -allowProvisioningUpdates \
  ${AUTH_ARGS[@]+"${AUTH_ARGS[@]}"} \
  DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM" \
  CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
  SWIFT_ACTIVE_COMPILATION_CONDITIONS=APP_STORE \
  ENABLE_OUTGOING_NETWORK_CONNECTIONS=NO \
  > "$OUT_DIR/archive.log" 2>&1
status=$?
set -e
if [ $status -ne 0 ]; then
  grep -E "error:|BUILD FAILED|ARCHIVE FAILED" "$OUT_DIR/archive.log" | head -40
  echo "✗ L'archive a échoué (journal complet : $OUT_DIR/archive.log)"
  exit $status
fi

APP="$ARCHIVE/Products/Applications/HydroBar.app"

echo "→ Vérifications…"
# Aucune trace du vérificateur de mises à jour dans le binaire.
if strings "$APP/Contents/MacOS/HydroBar" | grep -q "api.github.com"; then
  echo "✗ Le binaire contient encore le vérificateur GitHub : APP_STORE n'a pas été pris en compte."
  exit 1
fi
# Sandbox présente, réseau absent, pour l'app comme pour le widget.
for bundle in "$APP" "$APP/Contents/PlugIns/HydroBarWidgetExtension.appex"; do
  entitlements=$(codesign -d --entitlements - --xml "$bundle" 2>/dev/null || true)
  if ! grep -q "com.apple.security.app-sandbox" <<<"$entitlements"; then
    echo "✗ $bundle n'est pas sandboxé."
    exit 1
  fi
  if grep -q "com.apple.security.network.client" <<<"$entitlements"; then
    echo "✗ $bundle demande encore l'accès réseau."
    exit 1
  fi
done
echo "  ✓ Sandbox, pas de réseau, pas de vérificateur GitHub"

EXPORT_OPTIONS="$OUT_DIR/ExportOptions.plist"
DESTINATION=$([ "$UPLOAD" = "1" ] && echo upload || echo export)
cat > "$EXPORT_OPTIONS" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key>
  <string>app-store-connect</string>
  <key>destination</key>
  <string>$DESTINATION</string>
  <key>teamID</key>
  <string>$DEVELOPMENT_TEAM</string>
  <key>signingStyle</key>
  <string>automatic</string>
  <key>uploadSymbols</key>
  <true/>
  <key>manageAppVersionAndBuildNumber</key>
  <false/>
</dict>
</plist>
PLIST

echo "→ Export ($DESTINATION)…"
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportOptionsPlist "$EXPORT_OPTIONS" \
  -exportPath "$OUT_DIR/export" \
  -allowProvisioningUpdates \
  ${AUTH_ARGS[@]+"${AUTH_ARGS[@]}"}

if [ "$UPLOAD" = "1" ]; then
  echo "✓ HydroBar $VERSION ($BUILD_NUMBER) envoyé sur App Store Connect."
  echo "  Il apparaît dans TestFlight après le traitement par Apple (souvent 10 à 30 min)."
else
  echo "✓ Paquet prêt : $(ls "$OUT_DIR"/export/*.pkg)"
  echo "  Envoie-le avec l'app Transporter, ou relance avec UPLOAD=1."
fi
