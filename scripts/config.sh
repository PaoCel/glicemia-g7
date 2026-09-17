#!/bin/zsh
# Shared configuration for the build / archive / upload scripts.
set -euo pipefail

ROOT="$(cd "$(dirname "${(%):-%N}")/.." && pwd)"
PROJECT="$ROOT/Glicemia.xcodeproj"
SCHEME="Glicemia"
TEAM_ID="787YK9YUB3"
BUNDLE_ID="com.paolocelestini.glicemia"
WATCH_BUNDLE_ID="com.paolocelestini.glicemia.watchkitapp"

# Build artefacts stay off the exFAT project volume: codesign and xcarchive need
# POSIX permissions and extended attributes that exFAT cannot store.
WORK="${GLICEMIA_WORK:-$HOME/Library/Developer/Glicemia}"
ARCHIVE_DIR="$WORK/archives"
EXPORT_DIR="$WORK/export"
DD="$WORK/DerivedData"

export COPYFILE_DISABLE=1
