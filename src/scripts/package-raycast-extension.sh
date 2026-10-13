#!/usr/bin/env bash
# src/scripts/package-raycast-extension.sh — met l'extension Raycast dans un zip
# à joindre à une release GitHub. Sans node_modules ni dist : on lance
# `npm install` après l'avoir décompressée (voir src/raycast-hydrobar/README.md).

set -euo pipefail

cd "$(dirname "$0")/../.."
ROOT="$(pwd)"
OUTPUT_ZIP="$ROOT/hydrobar-raycast-extension.zip"

if [ ! -d src/raycast-hydrobar ]; then
  echo "✗ src/raycast-hydrobar introuvable."
  exit 1
fi

echo "→ Packaging the Raycast extension..."
rm -f "$OUTPUT_ZIP"
# Depuis src/ : l'archive contient un dossier raycast-hydrobar, sans préfixe.
(cd src && zip -qr "$OUTPUT_ZIP" raycast-hydrobar \
  -x "raycast-hydrobar/node_modules/*" \
  -x "raycast-hydrobar/dist/*" \
  -x "*.DS_Store")

echo "✓ $OUTPUT_ZIP"
