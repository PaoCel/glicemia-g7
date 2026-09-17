#!/bin/zsh
# Debug build of both targets for a real device. No signing, no install: this is the
# fast "does it still compile for Series 3" check.
source "$(dirname "${(%):-%N}")/config.sh"

cd "$ROOT"
xcodegen generate

xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Debug \
  -destination 'generic/platform=iOS' \
  -derivedDataPath "$DD" \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" \
  build

APP="$DD/Build/Products/Debug-iphoneos/Glicemia.app"
echo
echo "== architetture =="
lipo -info "$APP/Glicemia"
lipo -info "$APP/Watch/Glicemia.app/Glicemia"
