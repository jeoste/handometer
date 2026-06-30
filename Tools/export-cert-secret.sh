#!/bin/bash
# Affiche le certificat de signature encodé en base64, à coller dans le secret
# GitHub `SIGNING_CERT_P12_BASE64` (le workflow CI signe alors chaque release
# avec le même certificat → permission Accessibilité stable côté utilisateurs).
#
# Le secret `SIGNING_CERT_PASSWORD` doit valoir le mot de passe du .p12
# (par défaut « handometer », cf. Tools/make-signing-cert.sh).
set -euo pipefail

P12="${1:-$HOME/handometer-signing-cert.p12}"

if [ ! -f "$P12" ]; then
    echo "✗ Introuvable : $P12" >&2
    echo "  Lancez d'abord Tools/make-signing-cert.sh." >&2
    exit 1
fi

echo "▶︎ Base64 de $P12 (copié dans le presse-papier) :" >&2
base64 -i "$P12" | tee >(pbcopy)
echo >&2
echo "✓ Collez-le dans GitHub → Settings → Secrets and variables → Actions :" >&2
echo "   • SIGNING_CERT_P12_BASE64 = (cette valeur)" >&2
echo "   • SIGNING_CERT_PASSWORD   = handometer" >&2
