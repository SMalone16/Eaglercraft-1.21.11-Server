#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=/dev/null
source "$ROOT_DIR/stack-versions.env"

VELOCITY_PLUGINS="$ROOT_DIR/velocity/plugins"
PAPER_PLUGINS="$ROOT_DIR/server/plugins"

mkdir -p "$VELOCITY_PLUGINS" "$PAPER_PLUGINS"

if ! command -v curl >/dev/null 2>&1; then
  echo "ERROR: curl is required to install managed dependencies." >&2
  exit 1
fi
if ! command -v sha256sum >/dev/null 2>&1; then
  echo "ERROR: sha256sum is required to verify managed dependencies." >&2
  exit 1
fi

download_verified() {
  local name="$1"
  local url="$2"
  local sha256="$3"
  local destination="$4"
  local temp="${destination}.download"

  if [ -f "$destination" ] && printf '%s  %s\n' "$sha256" "$destination" | sha256sum -c - >/dev/null 2>&1; then
    echo "OK: $name already matches the pinned SHA-256."
    return
  fi

  echo "Installing $name..."
  rm -f "$temp"
  curl -L --fail --show-error --retry 3 --retry-delay 2 "$url" -o "$temp"

  if ! printf '%s  %s\n' "$sha256" "$temp" | sha256sum -c - >/dev/null 2>&1; then
    echo "ERROR: SHA-256 verification failed for $name." >&2
    rm -f "$temp"
    exit 1
  fi

  mv "$temp" "$destination"
  echo "Installed: $destination"
}

remove_other_versions() {
  local keep="$1"
  shift
  local pattern file
  for pattern in "$@"; do
    for file in $pattern; do
      [ -e "$file" ] || continue
      [ "$file" = "$keep" ] || rm -f "$file"
    done
  done
}

echo "Preparing managed Eaglercraft dependencies..."

# EaglerXServer belongs on Velocity. EaglerWeb serves the browser assets.
# EaglerXRewind is retained so legacy Eagler clients can still be translated.
download_verified "EaglerXServer $EAGLERX_VERSION" "$EAGLERX_SERVER_URL" "$EAGLERX_SERVER_SHA256" "$VELOCITY_PLUGINS/EaglerXServer.jar"
download_verified "EaglerWeb $EAGLERX_VERSION" "$EAGLERWEB_URL" "$EAGLERWEB_SHA256" "$VELOCITY_PLUGINS/EaglerWeb.jar"
download_verified "EaglerXRewind $EAGLERX_VERSION" "$EAGLERX_REWIND_URL" "$EAGLERX_REWIND_SHA256" "$VELOCITY_PLUGINS/EaglerXRewind.jar"

# TuffX+ expects Via* on the backend only, not on the proxy.
rm -f "$VELOCITY_PLUGINS"/ViaVersion*.jar "$VELOCITY_PLUGINS"/ViaBackwards*.jar "$VELOCITY_PLUGINS"/ViaRewind*.jar
rm -f "$VELOCITY_PLUGINS"/EaglerXSupervisor.jar

# Remove the deprecated TuffX plugin and stale managed backend versions.
rm -f "$PAPER_PLUGINS/TuffX.jar"
remove_other_versions "$PAPER_PLUGINS/ViaVersion-$VIAVERSION_VERSION.jar" "$PAPER_PLUGINS"/ViaVersion-*.jar
remove_other_versions "$PAPER_PLUGINS/ViaBackwards-$VIAVERSION_VERSION.jar" "$PAPER_PLUGINS"/ViaBackwards-*.jar
remove_other_versions "$PAPER_PLUGINS/ViaRewind-$VIAREWIND_VERSION.jar" "$PAPER_PLUGINS"/ViaRewind-*.jar
remove_other_versions "$PAPER_PLUGINS/TuffXPlus-$TUFFXPLUS_VERSION.jar" "$PAPER_PLUGINS"/TuffXPlus-*.jar

download_verified "ViaVersion $VIAVERSION_VERSION" "$VIAVERSION_URL" "$VIAVERSION_SHA256" "$PAPER_PLUGINS/ViaVersion-$VIAVERSION_VERSION.jar"
download_verified "ViaBackwards $VIAVERSION_VERSION" "$VIABACKWARDS_URL" "$VIABACKWARDS_SHA256" "$PAPER_PLUGINS/ViaBackwards-$VIAVERSION_VERSION.jar"
download_verified "ViaRewind $VIAREWIND_VERSION" "$VIAREWIND_URL" "$VIAREWIND_SHA256" "$PAPER_PLUGINS/ViaRewind-$VIAREWIND_VERSION.jar"
download_verified "TuffXPlus $TUFFXPLUS_VERSION" "$TUFFXPLUS_URL" "$TUFFXPLUS_SHA256" "$PAPER_PLUGINS/TuffXPlus-$TUFFXPLUS_VERSION.jar"

echo "Managed dependencies are ready."
