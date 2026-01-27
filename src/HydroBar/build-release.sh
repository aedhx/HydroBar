#!/bin/bash

# Script de build pour HydroBar
# Ce script compile l'application en mode Release

set -e  # Arrêter en cas d'erreur

echo "🚀 Démarrage du build de HydroBar..."

# Variables
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_NAME="HydroBar"
SCHEME="HydroBar"
BUILD_DIR="$PROJECT_DIR/build"
ARCHIVE_PATH="$BUILD_DIR/$PROJECT_NAME.xcarchive"
APP_PATH="$BUILD_DIR/$PROJECT_NAME.app"

# Nettoyer le build précédent
echo "🧹 Nettoyage du build précédent..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Build de l'application
echo "🔨 Compilation de l'application..."
xcodebuild clean build \
    -project "$PROJECT_DIR/$PROJECT_NAME.xcodeproj" \
    -scheme "$SCHEME" \
    -configuration Release \
    -derivedDataPath "$BUILD_DIR/DerivedData" \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO

# Trouver l'application compilée
APP_BUILD_PATH=$(find "$BUILD_DIR/DerivedData" -name "$PROJECT_NAME.app" -type d | head -1)

if [ -z "$APP_BUILD_PATH" ]; then
    echo "❌ Erreur: Application non trouvée après le build"
    exit 1
fi

# Copier l'application dans le dossier build
echo "📦 Copie de l'application..."
cp -R "$APP_BUILD_PATH" "$APP_PATH"

# Vérifier que l'application existe
if [ ! -d "$APP_PATH" ]; then
    echo "❌ Erreur: L'application n'a pas été copiée correctement"
    exit 1
fi

# Ad Hoc Signing (optionnel mais recommandé pour réduire certains avertissements)
echo "🔐 Application de l'ad hoc signing..."
if command -v codesign &> /dev/null; then
    # Supprimer d'abord toute signature existante
    codesign --remove-signature "$APP_PATH" 2>/dev/null || true
    # Appliquer l'ad hoc signing
    codesign --force --deep --sign - "$APP_PATH" 2>/dev/null || {
        echo "⚠️  Ad hoc signing échoué (non bloquant, l'application fonctionnera quand même)"
    }
    echo "✅ Ad hoc signing appliqué"
else
    echo "ℹ️  codesign non disponible, signature ignorée"
fi

echo "✅ Build terminé avec succès!"
echo "📍 Application disponible à: $APP_PATH"
echo ""
echo "📏 Taille de l'application:"
du -sh "$APP_PATH"
