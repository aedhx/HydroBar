#!/bin/bash

# Script de création de DMG pour HydroBar
# Ce script crée un DMG prêt à distribuer

set -e  # Arrêter en cas d'erreur

echo "📦 Création du DMG pour HydroBar..."

# Variables
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_NAME="HydroBar"
APP_NAME="$PROJECT_NAME.app"
BUILD_DIR="$SCRIPT_DIR/build"
APP_PATH="$BUILD_DIR/$APP_NAME"
DMG_DIR="$BUILD_DIR/dmg"
DMG_NAME="${PROJECT_NAME}-v1.0"
DMG_PATH="$BUILD_DIR/${DMG_NAME}.dmg"

# Vérifier que l'application existe
if [ ! -d "$APP_PATH" ]; then
    echo "❌ Erreur: L'application n'existe pas à $APP_PATH"
    echo "💡 Exécutez d'abord ./build-release.sh"
    exit 1
fi

# Nettoyer le dossier DMG précédent
echo "🧹 Nettoyage du dossier DMG..."
rm -rf "$DMG_DIR"
rm -f "$DMG_PATH"

# Créer le dossier DMG
mkdir -p "$DMG_DIR"

# Copier l'application
echo "📋 Copie de l'application dans le DMG..."
cp -R "$APP_PATH" "$DMG_DIR/"

# Créer un lien symbolique vers Applications
echo "🔗 Création du lien vers Applications..."
ln -s /Applications "$DMG_DIR/Applications"

# Copier le fichier README s'il existe, sinon en créer un
if [ -f "$SCRIPT_DIR/README-DMG.txt" ]; then
    echo "📄 Copie du fichier README..."
    cp "$SCRIPT_DIR/README-DMG.txt" "$DMG_DIR/README.txt"
else
    echo "📄 Création d'un fichier README basique..."
    cat > "$DMG_DIR/README.txt" << EOF
HydroBar - Guide d'installation

1. Glissez HydroBar.app dans le dossier Applications
2. Ouvrez Applications et lancez HydroBar
3. Lors de la première ouverture, faites un clic droit > Ouvrir
4. Autorisez l'application dans les Préférences Système si nécessaire

Pour plus d'informations, visitez: [Votre site web]

Version 1.0
EOF
fi

# Chercher l'image de fond du DMG (supporte PNG, JPG, JPEG)
DMG_BACKGROUND=""
# Chercher dans plusieurs emplacements et formats
for location in "$SCRIPT_DIR/DMG-background" "$SCRIPT_DIR/dmg-assets/DMG-background" "$SCRIPT_DIR/../DMG-background"; do
    for ext in png jpg jpeg PNG JPG JPEG; do
        if [ -f "${location}.${ext}" ]; then
            DMG_BACKGROUND="${location}.${ext}"
            break 2
        fi
    done
done

if [ -n "$DMG_BACKGROUND" ]; then
    echo "🎨 Image de fond trouvée: $DMG_BACKGROUND"
    # Copier l'image dans le DMG (cachée, toujours en .png pour compatibilité)
    # Si ce n'est pas un PNG, on le convertit (nécessite sips, disponible sur macOS)
    if [[ "$DMG_BACKGROUND" == *.png ]] || [[ "$DMG_BACKGROUND" == *.PNG ]]; then
        cp "$DMG_BACKGROUND" "$DMG_DIR/.background.png"
    else
        # Convertir en PNG avec sips (outil macOS intégré)
        sips -s format png "$DMG_BACKGROUND" --out "$DMG_DIR/.background.png" >/dev/null 2>&1
        if [ ! -f "$DMG_DIR/.background.png" ]; then
            # Si sips échoue, copier quand même (Finder peut gérer d'autres formats)
            cp "$DMG_BACKGROUND" "$DMG_DIR/.background.png"
        fi
    fi
    # Marquer comme fichier caché
    SetFile -a V "$DMG_DIR/.background.png" 2>/dev/null || chflags hidden "$DMG_DIR/.background.png" 2>/dev/null || true
    echo "✅ Image de fond ajoutée au DMG"
else
    echo "ℹ️  Aucune image de fond trouvée (optionnel)"
fi

# Obtenir la taille du contenu pour dimensionner le DMG
CONTENT_SIZE=$(du -sm "$DMG_DIR" | cut -f1)
DMG_SIZE=$((CONTENT_SIZE + 10))  # Ajouter 10 MB de marge

echo "💾 Création du DMG (taille: ${DMG_SIZE}MB)..."
hdiutil create -srcfolder "$DMG_DIR" \
    -volname "$PROJECT_NAME" \
    -fs HFS+ \
    -fsargs "-c c=64,a=16,e=16" \
    -format UDRW \
    -size ${DMG_SIZE}m \
    "$DMG_PATH.tmp.dmg"

# Monter le DMG
echo " mount du DMG pour configuration..."
MOUNT_POINT=$(hdiutil attach -readwrite -noverify -noautoopen "$DMG_PATH.tmp.dmg" | \
    egrep '^/dev/' | sed 1q | awk '{print $3}')

# Attendre un peu pour que le montage se termine
sleep 2

# Configurer la vue du DMG
echo "🎨 Configuration de la vue du DMG..."
BACKGROUND_FILE="$MOUNT_POINT/.background.png"
if [ -n "$DMG_BACKGROUND" ] && [ -f "$BACKGROUND_FILE" ]; then
    # Script avec image de fond
    osascript <<EOF
tell application "Finder"
    tell disk "$PROJECT_NAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {400, 100, 920, 420}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 72
        try
            set background picture of viewOptions to file ".background.png"
        on error
            -- Si l'image ne peut pas être définie, continuer sans
        end try
        set position of item "$APP_NAME" of container window to {160, 205}
        set position of item "Applications" of container window to {360, 205}
        close
        open
        update without registering applications
        delay 2
    end tell
end tell
EOF
else
    # Script sans image de fond
    osascript <<EOF
tell application "Finder"
    tell disk "$PROJECT_NAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {400, 100, 920, 420}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 72
        set position of item "$APP_NAME" of container window to {160, 205}
        set position of item "Applications" of container window to {360, 205}
        close
        open
        update without registering applications
        delay 2
    end tell
end tell
EOF
fi

# Démonter le DMG
echo "🔽 Démonter le DMG..."
# Attendre un peu pour que les opérations se terminent
sleep 1
# Essayer de démonter, ignorer les erreurs si déjà démonté
hdiutil detach "$MOUNT_POINT" 2>/dev/null || hdiutil detach "/Volumes/$PROJECT_NAME" 2>/dev/null || true

# Convertir en DMG final (compressé et en lecture seule)
echo "🗜️  Compression du DMG..."
hdiutil convert "$DMG_PATH.tmp.dmg" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -o "$DMG_PATH"

# Nettoyer le fichier temporaire
rm -f "$DMG_PATH.tmp.dmg"

# Vérifier le DMG
if [ -f "$DMG_PATH" ]; then
    echo ""
    echo "✅ DMG créé avec succès!"
    echo "📍 Fichier: $DMG_PATH"
    echo "📏 Taille:"
    du -sh "$DMG_PATH"
    echo ""
    echo "🎉 Le DMG est prêt à être distribué!"
else
    echo "❌ Erreur: Le DMG n'a pas été créé"
    exit 1
fi
