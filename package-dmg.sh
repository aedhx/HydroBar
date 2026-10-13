#!/bin/bash
# package-dmg.sh — met une HydroBar.app déjà signée dans une image disque.
#
# Usage :
#   ./package-dmg.sh chemin/vers/HydroBar.app HydroBar-v2.0.dmg
#
# Appelé par build-dmg.sh (build locale ou CI) et par notarize-release.sh
# (release signée et notarisée). La mise en page est décrite dans
# Resources/dmg-settings.py.
#
# Prérequis : dmgbuild (python3 -m pip install --user dmgbuild).

set -euo pipefail

APP="${1:?Usage : $0 HydroBar.app sortie.dmg}"
DMG="${2:?Usage : $0 HydroBar.app sortie.dmg}"

cd "$(dirname "$0")"

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
  -s Resources/dmg-settings.py \
  -D app="$APP" \
  -D background="Resources/DMG-background.tiff" \
  "HydroBar" "$DMG"

echo "✓ $DMG"
