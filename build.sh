#!/bin/bash
# Compile Handometer et assemble un bundle .app autonome (avec Sparkle).
set -euo pipefail

cd "$(dirname "$0")"

APP_NAME="Handometer"
EXEC_NAME="Handometer"
BUNDLE_ID="com.jeoste.handometer"
APP_DIR="${APP_NAME}.app"
CONFIG="${1:-release}"

# Version : argument 2, sinon variable d'env VERSION, sinon défaut.
VERSION="${2:-${VERSION:-1.0.0}}"
# Numéro de build (CI) ou horodatage pour les builds locaux.
BUILD_NUMBER="${BUILD_NUMBER:-${GITHUB_RUN_NUMBER:-$(date +%s)}}"
BUILD_DATE="$(date '+%d %b %Y at %H:%M')"

# Flux Sparkle (dépôt public) + clé publique EdDSA.
FEED_URL="https://raw.githubusercontent.com/jeoste/handometer/main/appcast.xml"
PUBLIC_ED_KEY="OoyEB4nsmmFkP8z2s71XV+3rTETsmD9yQXYqhwsqY70="

echo "▶︎ Compilation ($CONFIG) version ${VERSION}…"
swift build -c "$CONFIG"

BIN_DIR="$(swift build -c "$CONFIG" --show-bin-path)"
BIN_PATH="${BIN_DIR}/${EXEC_NAME}"

echo "▶︎ Assemblage de ${APP_DIR}…"
rm -rf "$APP_DIR"
mkdir -p "${APP_DIR}/Contents/MacOS"
mkdir -p "${APP_DIR}/Contents/Resources"
mkdir -p "${APP_DIR}/Contents/Frameworks"

cp "$BIN_PATH" "${APP_DIR}/Contents/MacOS/${EXEC_NAME}"

# Icône d'app (.icns) + images de la barre de menu (template monochrome).
cp Resources/AppIcon.icns "${APP_DIR}/Contents/Resources/AppIcon.icns"
cp Resources/menubar.png Resources/menubar@2x.png "${APP_DIR}/Contents/Resources/"
cp Resources/brand-logo.png Resources/brand-logo@2x.png "${APP_DIR}/Contents/Resources/"

# Copie Sparkle.framework dans le bundle (le binaire le résout via @rpath).
SPARKLE_FW="$(find .build -type d -name "Sparkle.framework" -path "*macos*" 2>/dev/null | head -1)"
if [ -z "$SPARKLE_FW" ]; then
    SPARKLE_FW="$(find .build -type d -name "Sparkle.framework" 2>/dev/null | head -1)"
fi
if [ -z "$SPARKLE_FW" ]; then
    echo "✗ Sparkle.framework introuvable dans .build (lancer 'swift build' ?)" >&2
    exit 1
fi
echo "▶︎ Copie de $(basename "$(dirname "$SPARKLE_FW")")/Sparkle.framework…"
cp -R "$SPARKLE_FW" "${APP_DIR}/Contents/Frameworks/"

cat > "${APP_DIR}/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleExecutable</key>
    <string>${EXEC_NAME}</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleVersion</key>
    <string>${BUILD_NUMBER}</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>HMBuildDate</key>
    <string>${BUILD_DATE}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>SUFeedURL</key>
    <string>${FEED_URL}</string>
    <key>SUPublicEDKey</key>
    <string>${PUBLIC_ED_KEY}</string>
    <key>SUEnableAutomaticChecks</key>
    <true/>
</dict>
</plist>
PLIST

# Signature : on privilégie un certificat de code-signing stable pour que la
# permission Accessibilité (TCC) persiste entre les mises à jour. À défaut, repli
# sur signature ad-hoc (permission redemandée à chaque update).
# Voir Tools/make-signing-cert.sh.
# NB : le certificat auto-signé est « untrusted » → il n'apparaît que via
# `find-identity` SANS `-v` (codesign sait néanmoins l'utiliser).
SIGNING_IDENTITY="${SIGNING_IDENTITY:-Handometer Self-Signed}"
if security find-identity 2>/dev/null | grep -q "$SIGNING_IDENTITY"; then
    SIGN_ID="$SIGNING_IDENTITY"
    echo "▶︎ Signature avec « $SIGN_ID »…"
else
    SIGN_ID="-"
    echo "⚠︎ Identité « $SIGNING_IDENTITY » introuvable — repli sur signature ad-hoc." >&2
    echo "   La permission Accessibilité sera instable entre les mises à jour." >&2
    echo "   Lancez Tools/make-signing-cert.sh pour créer le certificat stable." >&2
    echo "▶︎ Signature ad-hoc…"
fi

# Framework d'abord, puis l'app (les erreurs ne sont plus masquées).
codesign --force --sign "$SIGN_ID" "${APP_DIR}/Contents/Frameworks/Sparkle.framework"
codesign --force --deep --sign "$SIGN_ID" "$APP_DIR"

echo "✓ Terminé : ${APP_DIR} (v${VERSION} build ${BUILD_NUMBER})"
echo "  Lancer :  open \"${APP_DIR}\""
