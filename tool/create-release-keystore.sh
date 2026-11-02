#!/usr/bin/env bash
# Creates the permanent EduCore release keystore ONCE, outside the repository, and points android/key.properties at it.
#   RSA 4096, alias "educore", valid 10,000 days, file educore-release.jks
# Run it on your own computer. It asks for the password (nothing is shown or logged). It refuses to overwrite an existing keystore:
# a new key would stop phones that already have the app from updating it.
set -euo pipefail

DIR="${EDUCORE_KEYSTORE_DIR:-$HOME/.educore-keys}"
JKS="$DIR/educore-release.jks"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROPS="$ROOT/android/key.properties"

if [ -e "$JKS" ]; then
  echo "A release keystore already exists at $JKS. Not creating another one." >&2
  echo "Keep using it; if it is lost, apps signed with it can never be updated." >&2
  exit 1
fi
command -v keytool >/dev/null || { echo "keytool not found. Install a JDK (it comes with Android Studio)." >&2; exit 1; }

if [ -z "${EDUCORE_KEYSTORE_PASSWORD:-}" ]; then
  read -rsp "Choose a keystore password (at least 8 characters): " PASS; echo
  read -rsp "Type it again: " AGAIN; echo
  [ "$PASS" = "$AGAIN" ] || { echo "The passwords do not match." >&2; exit 1; }
else
  PASS="$EDUCORE_KEYSTORE_PASSWORD"
fi
[ "${#PASS}" -ge 8 ] || { echo "Use at least 8 characters." >&2; exit 1; }

mkdir -p "$DIR"; chmod 700 "$DIR"
export KS_PASS="$PASS"   # keytool reads it from the environment, so it never appears in the process list
keytool -genkeypair -storetype PKCS12 -keystore "$JKS" -alias educore \
  -keyalg RSA -keysize 4096 -validity 10000 \
  -storepass:env KS_PASS -keypass:env KS_PASS \
  -dname "CN=EduCore, O=CGP Issues Solutions, L=Gombe, C=NG" >/dev/null
chmod 600 "$JKS"

umask 077
{
  echo "storeFile=$JKS"
  echo "storePassword=$PASS"
  echo "keyAlias=educore"
  echo "keyPassword=$PASS"
} > "$PROPS"

echo
echo "Created $JKS"
echo "Wrote   $PROPS   (ignored by Git)"
echo
echo "Key details and the certificate fingerprint (SHA-256), the one Android app links need:"
keytool -list -v -keystore "$JKS" -alias educore -storepass:env KS_PASS | grep -E "Alias name|Valid from|Signature algorithm name|Subject Public Key Algorithm|SHA256"
unset KS_PASS PASS AGAIN
echo
echo "NOW BACK UP $JKS and the password somewhere safe (password manager and an offline copy)."
echo "If they are lost, the app can never be updated on phones that already have it."
echo
echo "To let GitHub build the signed APK, add four repository secrets (Settings > Secrets and variables > Actions):"
echo "  RELEASE_KEYSTORE_BASE64   = the file, base64:   base64 -w0 \"$JKS\"   (macOS: base64 -i \"$JKS\")"
echo "  RELEASE_KEYSTORE_PASSWORD = the password you chose"
echo "  RELEASE_KEY_ALIAS         = educore"
echo "  RELEASE_KEY_PASSWORD      = the same password"
echo "With the GitHub CLI:  gh secret set RELEASE_KEYSTORE_BASE64 < <(base64 -w0 \"$JKS\")   then   gh secret set RELEASE_KEYSTORE_PASSWORD   (it asks, nothing is echoed)"
