#!/bin/zsh
# Release archive signed for App Store distribution, then export an .ipa.
# Provisioning is created/updated on demand, so a fresh App ID or a missing
# distribution certificate does not stop the run.
source "$(dirname "${(%):-%N}")/config.sh"

cd "$ROOT"
xcodegen generate

VERSION=$(grep -m1 'MARKETING_VERSION:' project.yml | sed 's/.*"\(.*\)".*/\1/')
BUILD=$(grep -m1 'CURRENT_PROJECT_VERSION:' project.yml | sed 's/.*"\(.*\)".*/\1/')
ARCHIVE="$ARCHIVE_DIR/Glicemia-$VERSION-$BUILD.xcarchive"

mkdir -p "$ARCHIVE_DIR" "$EXPORT_DIR"
rm -rf "$ARCHIVE"

AUTH=()
if [ -n "${ASC_KEY_PATH:-}" ]; then
  AUTH=(-allowProvisioningUpdates \
        -authenticationKeyPath "$ASC_KEY_PATH" \
        -authenticationKeyID "$ASC_KEY_ID" \
        -authenticationKeyIssuerID "$ASC_ISSUER_ID")
else
  AUTH=(-allowProvisioningUpdates)
fi

xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "$ARCHIVE" \
  -derivedDataPath "$DD" \
  "${AUTH[@]}" \
  archive

echo
echo "== architetture nell'archive =="
lipo -info "$ARCHIVE/Products/Applications/Glicemia.app/Glicemia"
lipo -info "$ARCHIVE/Products/Applications/Glicemia.app/Watch/Glicemia.app/Glicemia"

rm -rf "$EXPORT_DIR/$VERSION-$BUILD"
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportPath "$EXPORT_DIR/$VERSION-$BUILD" \
  -exportOptionsPlist "$ROOT/scripts/ExportOptions.plist" \
  "${AUTH[@]}"

echo
echo "IPA: $EXPORT_DIR/$VERSION-$BUILD/Glicemia.ipa"
