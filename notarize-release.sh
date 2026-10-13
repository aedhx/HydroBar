#!/bin/bash
# notarize-release.sh — signe une release avec le certificat Developer ID du
# compte développeur, la fait notariser par Apple, et refait le DMG et le ZIP.
# Une app notarisée s'ouvre d'un double-clic : plus de « HydroBar est
# endommagé », plus de `xattr -cr`.
#
# Usage :
#   ./notarize-release.sh v2.0            # signe, notarise, empaquette
#   UPLOAD=1 ./notarize-release.sh v2.0   # et remplace les fichiers de la release GitHub
#   APP=chemin/HydroBar.app ./notarize-release.sh v2.0   # part d'une app locale
#
# D'où vient l'app : du ZIP de la release GitHub, construit par la CI avec
# Xcode 26 (workflow Release). Ce script ne compile rien ; il peut donc tourner
# sur un Mac dont le Xcode est plus ancien.
#
# Avec quoi elle est signée : le compte connecté dans Xcode (Réglages › Comptes),
# par la signature « gérée dans le cloud ». Aucun certificat ni mot de passe à
# installer sur le Mac : Xcode demande à Apple de signer, puis envoie l'app à la
# notarisation. C'est pour passer par ce chemin que l'app est d'abord rangée
# dans une archive Xcode montée à la main.
#
# Ce que la signature ne change pas : l'app reste hors sandbox, comme les
# versions 1.x et la 2.0 publiée, pour retrouver les données au même endroit.
# Le widget et le bouton du Centre de contrôle restent donc réservés à la
# version du Mac App Store.
#
# Prérequis : gh (connecté), dmgbuild (python3 -m pip install --user dmgbuild).

set -euo pipefail

TAG="${1:?Usage : $0 vX.Y}"
VERSION="${TAG#v}"
TEAM="${DEVELOPMENT_TEAM:-S8YKU5RDHK}"
UPLOAD="${UPLOAD:-0}"
# La notarisation prend en général quelques minutes ; la toute première d'un
# compte peut en prendre beaucoup plus.
TIMEOUT_MIN="${TIMEOUT_MIN:-60}"

cd "$(dirname "$0")"
ROOT="$(pwd)"
WORK="$ROOT/build/notarize"
ARCHIVE="$WORK/HydroBar.xcarchive"
DMG="HydroBar-v$VERSION.dmg"
ZIP="HydroBar-v$VERSION.zip"

rm -rf "$WORK"
mkdir -p "$WORK/source" "$ARCHIVE/Products/Applications"

# ── 1. L'app à signer ────────────────────────────────────────────────────────
if [ -n "${APP:-}" ]; then
  echo "→ App locale : $APP"
  cp -R "$APP" "$WORK/source/HydroBar.app"
else
  echo "→ Téléchargement de $ZIP depuis la release $TAG"
  gh release download "$TAG" --pattern "$ZIP" --dir "$WORK"
  ditto -x -k "$WORK/$ZIP" "$WORK/source"
fi
SRC="$WORK/source/HydroBar.app"

BUNDLED=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$SRC/Contents/Info.plist")
BUILD=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$SRC/Contents/Info.plist")
if [ "$BUNDLED" != "$VERSION" ]; then
  echo "✗ L'app est en version $BUNDLED, pas $VERSION."
  exit 1
fi

# ── 2. Préparer la signature ─────────────────────────────────────────────────
# Xcode re-signe en conservant les options de la signature en place. La
# notarisation exige le « hardened runtime » : on le pose ici, en ad-hoc, de
# l'intérieur vers l'extérieur. Sans entitlements, comme les builds publiées.
echo "→ Hardened runtime"
while IFS= read -r ext; do
  [ -n "$ext" ] || continue
  codesign --force --options runtime --sign - "$ext"
done < <(find "$SRC/Contents/PlugIns" -name "*.appex" 2>/dev/null)
codesign --force --options runtime --sign - "$SRC"

# ── 3. Une archive Xcode autour de l'app ─────────────────────────────────────
mv "$SRC" "$ARCHIVE/Products/Applications/HydroBar.app"
cat > "$ARCHIVE/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>ApplicationProperties</key>
  <dict>
    <key>ApplicationPath</key><string>Applications/HydroBar.app</string>
    <key>CFBundleIdentifier</key><string>com.adxcool.HydroBar</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleVersion</key><string>$BUILD</string>
    <key>SigningIdentity</key><string>-</string>
    <key>Team</key><string>$TEAM</string>
  </dict>
  <key>ArchiveVersion</key><integer>2</integer>
  <key>CreationDate</key><date>$(date -u +%Y-%m-%dT%H:%M:%SZ)</date>
  <key>Name</key><string>HydroBar</string>
  <key>SchemeName</key><string>HydroBar</string>
</dict>
</plist>
PLIST

cat > "$WORK/ExportOptions.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key><string>developer-id</string>
  <key>destination</key><string>upload</string>
  <key>teamID</key><string>$TEAM</string>
  <key>signingStyle</key><string>automatic</string>
</dict>
</plist>
PLIST

# ── 4. Signature Developer ID et envoi à la notarisation ─────────────────────
echo "→ Signature Developer ID et envoi à Apple"
if ! xcodebuild -exportArchive \
      -archivePath "$ARCHIVE" \
      -exportOptionsPlist "$WORK/ExportOptions.plist" \
      -exportPath "$WORK/upload" \
      -allowProvisioningUpdates > "$WORK/upload.log" 2>&1; then
  grep -E "error:|EXPORT FAILED" "$WORK/upload.log" | sort -u | head -20
  echo "✗ L'envoi a échoué (journal complet : $WORK/upload.log)"
  echo "  Vérifie que ton compte est connecté dans Xcode › Réglages › Comptes."
  exit 1
fi

# ── 5. Attendre le verdict d'Apple ───────────────────────────────────────────
echo "→ Notarisation en cours (jusqu'à $TIMEOUT_MIN min)…"
deadline=$(( $(date +%s) + TIMEOUT_MIN * 60 ))
until xcodebuild -exportNotarizedApp \
        -archivePath "$ARCHIVE" \
        -exportPath "$WORK/notarized" > "$WORK/notarized.log" 2>&1; do
  if ! grep -q "is processing" "$WORK/notarized.log"; then
    grep -E "error:" "$WORK/notarized.log" | sort -u | head -20
    echo "✗ Apple a refusé la notarisation (journal complet : $WORK/notarized.log)"
    exit 1
  fi
  if [ "$(date +%s)" -ge "$deadline" ]; then
    echo "✗ Toujours en cours après $TIMEOUT_MIN min. L'archive est conservée : relance plus tard"
    echo "  xcodebuild -exportNotarizedApp -archivePath \"$ARCHIVE\" -exportPath \"$WORK/notarized\""
    exit 1
  fi
  rm -rf "$WORK/notarized"
  sleep 30
done
SIGNED="$WORK/notarized/HydroBar.app"

# ── 6. Vérifier ce qu'un utilisateur vivra ───────────────────────────────────
echo "→ Vérifications"
codesign --verify --deep --strict "$SIGNED"
xcrun stapler validate "$SIGNED" > /dev/null
verdict=$(spctl -a -vv -t exec "$SIGNED" 2>&1 || true)
if ! grep -q "source=Notarized Developer ID" <<<"$verdict"; then
  echo "$verdict"
  echo "✗ Gatekeeper n'accepte pas l'app."
  exit 1
fi
echo "  ✓ $(grep origin= <<<"$verdict" | sed 's/origin=//'), notarisée, ticket agrafé"

# ── 7. DMG et ZIP ────────────────────────────────────────────────────────────
./package-dmg.sh "$SIGNED" "$DMG"
rm -f "$ZIP"
ditto -c -k --keepParent "$SIGNED" "$ZIP"

if [ "$UPLOAD" = "1" ]; then
  echo "→ Remplacement des fichiers de la release $TAG"
  gh release upload "$TAG" "$DMG" "$ZIP" --clobber
fi

echo ""
echo "✓ $ROOT/$DMG"
echo "✓ $ROOT/$ZIP"
[ "$UPLOAD" = "1" ] && echo "  en ligne sur la release $TAG" || echo "  pour les publier : UPLOAD=1 $0 $TAG"
