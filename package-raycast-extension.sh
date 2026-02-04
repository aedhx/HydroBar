#!/usr/bin/env bash
# Package the HydroBar Raycast extension for distribution.
# Creates a zip excluding node_modules (user runs npm install after unzip).

set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
EXT_DIR="$SCRIPT_DIR/raycast-hydrobar"
OUTPUT_ZIP="$SCRIPT_DIR/hydrobar-raycast-extension.zip"

if [ ! -d "$EXT_DIR" ]; then
  echo "Error: raycast-hydrobar folder not found."
  exit 1
fi

echo "Packaging Raycast extension..."
cd "$SCRIPT_DIR"
zip -r "$OUTPUT_ZIP" raycast-hydrobar \
  -x "raycast-hydrobar/node_modules/*" \
  -x "raycast-hydrobar/.git/*" \
  -x "*.DS_Store" \
  -x "raycast-hydrobar/dist/*"

echo "Created: $OUTPUT_ZIP"
echo ""
echo "Distribution: Upload $OUTPUT_ZIP to GitHub Releases (e.g. as a release asset)."
echo "Users: unzip → cd raycast-hydrobar → npm install → Raycast: Add from folder → npm run dev"
