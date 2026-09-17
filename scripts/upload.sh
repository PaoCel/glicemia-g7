#!/bin/zsh
# Uploads the most recently exported .ipa to App Store Connect / TestFlight.
# Requires an App Store Connect API key:
#   export ASC_KEY_PATH=/path/AuthKey_XXXXXXXX.p8
#   export ASC_KEY_ID=XXXXXXXX
#   export ASC_ISSUER_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
source "$(dirname "${(%):-%N}")/config.sh"

: "${ASC_KEY_PATH:?serve ASC_KEY_PATH}"
: "${ASC_KEY_ID:?serve ASC_KEY_ID}"
: "${ASC_ISSUER_ID:?serve ASC_ISSUER_ID}"

IPA="${1:-$(ls -t "$EXPORT_DIR"/*/Glicemia.ipa 2>/dev/null | head -1)}"
[ -n "$IPA" ] || { echo "nessun .ipa trovato, esegui prima archive.sh"; exit 1; }
echo "upload: $IPA"

# altool wants the key in one of its search paths.
mkdir -p "$HOME/.appstoreconnect/private_keys"
cp -f "$ASC_KEY_PATH" "$HOME/.appstoreconnect/private_keys/AuthKey_$ASC_KEY_ID.p8"

xcrun altool --upload-app -f "$IPA" -t ios \
  --apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID" \
  --output-format normal
