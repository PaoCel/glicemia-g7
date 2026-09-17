#!/bin/zsh
# Reads or bumps the version numbers held in project.yml.
#
#   ./scripts/version.sh                 -> print current version and build
#   ./scripts/version.sh bump            -> build number +1
#   ./scripts/version.sh set 0.2.0       -> set marketing version, reset build to 1
set -euo pipefail
ROOT="$(cd "$(dirname "${(%):-%N}")/.." && pwd)"
YML="$ROOT/project.yml"

current_version() { grep -m1 'MARKETING_VERSION:' "$YML" | sed 's/.*"\(.*\)".*/\1/'; }
current_build()   { grep -m1 'CURRENT_PROJECT_VERSION:' "$YML" | sed 's/.*"\(.*\)".*/\1/'; }

case "${1:-show}" in
  show)
    echo "version $(current_version) build $(current_build)"
    ;;
  bump)
    next=$(( $(current_build) + 1 ))
    /usr/bin/sed -i '' "s/CURRENT_PROJECT_VERSION: \".*\"/CURRENT_PROJECT_VERSION: \"$next\"/" "$YML"
    echo "build -> $next"
    ;;
  set)
    [ -n "${2:-}" ] || { echo "usage: version.sh set <x.y.z>"; exit 1; }
    /usr/bin/sed -i '' "s/MARKETING_VERSION: \".*\"/MARKETING_VERSION: \"$2\"/" "$YML"
    /usr/bin/sed -i '' "s/CURRENT_PROJECT_VERSION: \".*\"/CURRENT_PROJECT_VERSION: \"1\"/" "$YML"
    echo "version -> $2, build -> 1"
    ;;
  *)
    echo "usage: version.sh [show|bump|set <x.y.z>]"; exit 1
    ;;
esac
