#!/bin/bash
# src/scripts/upload-listing.sh — envoie la fiche App Store (textes et captures, 9 langues)
# sur App Store Connect, avec fastlane deliver.
#
# Usage :
#   ASC_KEY_ID=XXXXXXXXXX ASC_ISSUER_ID=xxxxxxxx-xxxx-… ./src/scripts/upload-listing.sh
#   SKIP_SCREENSHOTS=1 … ./src/scripts/upload-listing.sh      # les textes seulement
#   SKIP_METADATA=1 … ./src/scripts/upload-listing.sh         # les captures seulement
#
# La clé d'API (Utilisateurs et accès › Intégrations › API App Store Connect)
# est lue dans ~/.appstoreconnect/private_keys/AuthKey_<ASC_KEY_ID>.p8, ou dans
# ASC_KEY_PATH. Elle n'est jamais copiée dans le dépôt : le fichier que fastlane
# demande est écrit dans un dossier temporaire, puis effacé.
#
# Le script n'envoie pas de build et ne soumet rien à la review : il remplit la
# fiche de la version en préparation, que tu relis ensuite dans App Store Connect.
#
# Prérequis : fastlane (brew install fastlane).

set -euo pipefail

cd "$(dirname "$0")/../.."

KEY_ID="${ASC_KEY_ID:?ASC_KEY_ID manquant}"
ISSUER_ID="${ASC_ISSUER_ID:?ASC_ISSUER_ID manquant}"
KEY_PATH="${ASC_KEY_PATH:-$HOME/.appstoreconnect/private_keys/AuthKey_$KEY_ID.p8}"
if [ ! -f "$KEY_PATH" ]; then
  echo "✗ Clé introuvable : $KEY_PATH"
  exit 1
fi
if ! command -v fastlane >/dev/null; then
  echo "✗ fastlane introuvable — brew install fastlane"
  exit 1
fi

# La fiche doit être valide avant de partir : App Store Connect refuse champ par champ.
python3 src/fastlane/check_metadata.py

VERSION=$(awk -F' = ' '/MARKETING_VERSION = /{gsub(";", "", $2); print $2; exit}' src/HydroBar/HydroBar.xcodeproj/project.pbxproj)

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
KEY_ID="$KEY_ID" ISSUER_ID="$ISSUER_ID" KEY_PATH="$KEY_PATH" python3 - > "$TMP/key.json" <<'PY'
import json, os
print(json.dumps({
    "key_id": os.environ["KEY_ID"],
    "issuer_id": os.environ["ISSUER_ID"],
    "key": open(os.environ["KEY_PATH"]).read(),
    "in_house": False,
}))
PY
chmod 600 "$TMP/key.json"

ARGS=()
if [ "${SKIP_SCREENSHOTS:-0}" = "1" ]; then ARGS+=(--skip_screenshots); fi
if [ "${SKIP_METADATA:-0}" = "1" ]; then ARGS+=(--skip_metadata); fi

echo "→ Fiche de HydroBar $VERSION vers App Store Connect"
# fastlane travaille dans le dossier qui contient fastlane/ : c'est src/.
cd src
fastlane deliver \
  --api_key_path "$TMP/key.json" \
  --app_identifier com.adxcool.HydroBar \
  --platform osx \
  --app_version "$VERSION" \
  --metadata_path fastlane/metadata \
  --screenshots_path fastlane/screenshots \
  --skip_binary_upload \
  --overwrite_screenshots \
  --run_precheck_before_submit false \
  --submit_for_review false \
  --force \
  ${ARGS[@]+"${ARGS[@]}"}

echo "✓ Fiche envoyée. Relis-la dans App Store Connect avant de soumettre."
