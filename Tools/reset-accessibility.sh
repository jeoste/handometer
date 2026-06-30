#!/bin/bash
# Purge l'entrée Accessibilité (TCC) périmée de Handometer. À lancer UNE fois,
# après le premier build signé avec le certificat stable
# (voir Tools/make-signing-cert.sh), puis ré-accorder la permission au prochain
# lancement de l'app.
set -euo pipefail

BUNDLE_ID="${BUNDLE_ID:-com.jeoste.handometer}"

echo "▶︎ Réinitialisation de l'entrée Accessibilité pour ${BUNDLE_ID}…"
tccutil reset Accessibility "$BUNDLE_ID"
echo "✓ Fait. Rouvrez Handometer et accordez l'Accessibilité une dernière fois."
