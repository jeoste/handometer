#!/bin/bash
# Crée (une seule fois) un certificat de code-signing auto-signé stable pour
# Handometer. Signer chaque release avec CE certificat rend le « designated
# requirement » constant d'une version à l'autre → la permission Accessibilité
# (TCC) n'est plus redemandée à chaque mise à jour.
#
# Idempotent : ne fait rien si l'identité existe déjà.
# Aucun compte Apple requis.
set -euo pipefail

IDENTITY="Handometer Self-Signed"
KEYCHAIN="${KEYCHAIN:-$HOME/Library/Keychains/login.keychain-db}"
BACKUP="${BACKUP:-$HOME/handometer-signing-cert.p12}"
DAYS=3650
# Mot de passe du .p12. macOS refuse les .p12 sans mot de passe produits par
# OpenSSL 3 ; on en utilise donc un, identique côté CI (secret SIGNING_CERT_PASSWORD).
CERT_PASSWORD="${CERT_PASSWORD:-handometer}"

# Le certificat auto-signé est « untrusted » : il n'apparaît que via
# `find-identity` SANS `-v` (codesign sait néanmoins l'utiliser).
if security find-identity | grep -q "$IDENTITY"; then
    echo "✓ Identité déjà présente : « $IDENTITY » — rien à faire."
    exit 0
fi

echo "▶︎ Création du certificat auto-signé « $IDENTITY » (validité ${DAYS} j)…"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Clé + certificat auto-signé avec EKU code-signing.
openssl req -x509 -newkey rsa:2048 -nodes \
    -keyout "$TMP/key.pem" -out "$TMP/cert.pem" -days "$DAYS" \
    -subj "/CN=$IDENTITY" \
    -addext "basicConstraints=critical,CA:false" \
    -addext "keyUsage=critical,digitalSignature" \
    -addext "extendedKeyUsage=critical,codeSigning"

# Empaquetage PKCS#12 (sans mot de passe). Les algos « legacy » SHA1 sont requis
# pour que le framework Security de macOS puisse importer le .p12 produit par
# OpenSSL 3.x (sinon : « MAC verification failed »).
openssl pkcs12 -export -inkey "$TMP/key.pem" -in "$TMP/cert.pem" \
    -out "$TMP/cert.p12" -passout pass:"$CERT_PASSWORD" -name "$IDENTITY" \
    -legacy -keypbe PBE-SHA1-3DES -certpbe PBE-SHA1-3DES -macalg sha1

# Import dans le trousseau « login » + autorisation pour codesign.
security import "$TMP/cert.p12" -k "$KEYCHAIN" -P "$CERT_PASSWORD" -T /usr/bin/codesign -A

# Évite l'invite trousseau à chaque build (non bloquant : si une invite
# apparaît au premier build, cliquer « Toujours autoriser »).
security set-key-partition-list -S apple-tool:,apple: -s -k "" "$KEYCHAIN" \
    >/dev/null 2>&1 || true

# Sauvegarde du certificat : à conserver pour réimporter sur une autre machine
# (ou après réinstallation) et garder un requirement identique.
cp "$TMP/cert.p12" "$BACKUP"

echo "✓ Identité « $IDENTITY » créée et importée."
echo "  Sauvegarde du certificat : $BACKUP"
echo "  ⚠︎ Conservez ce .p12 : toutes les releases DOIVENT utiliser le même certificat."
echo
echo "  Étapes suivantes :"
echo "   • Local   : ./build.sh release <version>"
echo "   • CI      : Tools/export-cert-secret.sh  → secrets GitHub"
echo "               SIGNING_CERT_P12_BASE64 = (base64)  /  SIGNING_CERT_PASSWORD = $CERT_PASSWORD"
echo "               (sinon les releases CI restent ad-hoc)."
