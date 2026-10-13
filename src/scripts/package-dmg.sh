#!/bin/bash
# src/scripts/package-dmg.sh — met une HydroBar.app déjà signée dans une image disque.
#
# Usage :
#   ./src/scripts/package-dmg.sh chemin/vers/HydroBar.app HydroBar-v2.0.dmg
#
# Appelé par src/scripts/build-dmg.sh (build locale ou CI) et par src/scripts/notarize-release.sh
# (release signée et notarisée). La mise en page est décrite dans
# src/scripts/dmg/dmg-settings.py.
#
# Prérequis : dmgbuild (python3 -m pip install --user dmgbuild).

set -euo pipefail

APP="${1:?Usage : $0 HydroBar.app sortie.dmg}"
DMG="${2:?Usage : $0 HydroBar.app sortie.dmg}"

cd "$(dirname "$0")/../.."

if ! python3 -c "import dmgbuild" 2>/dev/null; then
  echo "✗ dmgbuild introuvable — python3 -m pip install --user dmgbuild"
  exit 1
fi
if [ ! -d "$APP" ]; then
  echo "✗ $APP n'existe pas"
  exit 1
fi

rm -f "$DMG"
python3 -m dmgbuild \
  -s src/scripts/dmg/dmg-settings.py \
  -D app="$APP" \
  -D background="src/scripts/dmg/DMG-background.tiff" \
  "HydroBar" "$DMG"

# L'app doit ressortir du DMG avec une signature intacte : une image disque qui
# l'abîme (attribut Finder, fichier ajouté dans le bundle) ne se voit qu'ici.
MOUNT="$(mktemp -d)"
hdiutil attach -nobrowse -readonly -mountpoint "$MOUNT" "$DMG" > /dev/null
status=0
codesign --verify --deep --strict "$MOUNT/$(basename "$APP")" || status=$?
hdiutil detach "$MOUNT" > /dev/null
rmdir "$MOUNT" 2>/dev/null || true
if [ "$status" -ne 0 ]; then
  echo "✗ La signature de l'app ne survit pas à la mise en DMG."
  exit 1
fi

echo "✓ $DMG"
