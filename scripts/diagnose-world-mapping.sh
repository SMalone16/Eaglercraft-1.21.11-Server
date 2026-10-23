#!/usr/bin/env bash
# Read-only audit for missing blocks/terrain or phantom mobs in TigerCraft.
# Execute from the repository root in the SAME Codespace as the live server.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

echo "=== TigerCraft terrain and protocol diagnostics (READ ONLY) ==="
echo "Repository: $(git rev-parse --short HEAD 2>/dev/null || echo unknown)"
echo "Current branch: $(git branch --show-current 2>/dev/null || echo unknown)"
echo "Do not post unredacted player names, IP addresses, or world backups online."
echo

# shellcheck source=/dev/null
source "$ROOT/stack-versions.env"
echo "EXPECTED CORE PLUGINS (downloaded to server/plugins on startup):"
echo "  ViaVersion   $VIAVERSION_VERSION"
echo "  ViaBackwards $VIAVERSION_VERSION"
echo "  ViaRewind    $VIAREWIND_VERSION"
echo "  TuffXPlus    $TUFFXPLUS_VERSION"
echo "  EaglerXServer $EAGLERX_VERSION (Velocity)"
echo

echo "INSTALLED JARS:"
for pattern in "$ROOT"/server/plugins/ViaVersion-*.jar \
               "$ROOT"/server/plugins/ViaBackwards-*.jar \
               "$ROOT"/server/plugins/ViaRewind-*.jar \
               "$ROOT"/server/plugins/TuffXPlus-*.jar \
               "$ROOT"/server/plugins/TuffX.jar; do
  [ -e "$pattern" ] || continue
  echo "  ${pattern#"$ROOT"/}"
done
echo

echo "GENERATED RUNTIME CONFIG:"
y0_cfg="$ROOT/server/plugins/TuffXPlus/config.yml"
vb_cfg="$ROOT/server/plugins/ViaBackwards/config.yml"
if [ -f "$y0_cfg" ]; then
  echo "  Found TuffXPlus/config.yml"
  echo "  y0 and ViaBlocks section excerpts:"
  grep -A 13 '^y0:' "$y0_cfg" | head -n 14 || true
  grep -A 4 '^viablocks:' "$y0_cfg" | head -n 5 || true
  if ! grep -Eq '^[[:space:]]*-[[:space:]]*[\"\x27]?world[\"\x27]?[[:space:]]*$' "$y0_cfg"; then
    echo "  WARNING: Could not confirm 'world' in the y0 enabled-world list."
    echo "           Inspect y0.enabled-worlds carefully."
  fi
else
  echo "  WARNING: TuffXPlus runtime config not present here."
  echo "           This may be a different Codespace from the one hosting the game."
fi

if [ -f "$vb_cfg" ]; then
  grep -E '^bedrock-at-y-0:' "$vb_cfg" || true
  if grep -Eq '^bedrock-at-y-0:[[:space:]]*true' "$vb_cfg"; then
    echo "  WARNING: ViaBackwards synthetic bedrock-at-y-0 is ON."
    echo "           This is not recommended when testing TuffClient below-Y0 mining."
  fi
fi
echo

echo "PAPER TERRAIN AND MOB DEFAULTS:"
grep -E '^(level-name|level-type|generator-settings|generate-structures|difficulty|simulation-distance|view-distance)=' \
  "$ROOT/server/server.properties" || true
grep -A 2 '^spawn-limits:' "$ROOT/server/bukkit.yml" | head -n 3 || true
echo

echo "WORLD FILE PRESENCE (no chunks will be created or edited):"
for name in world world_nether world_the_end; do
  path="$ROOT/server/$name"
  if [ -d "$path" ]; then
    count="$(find "$path" -type f -name '*.mca' 2>/dev/null | wc -l | tr -d ' ')"
    echo "  $name: $count region/entity/POI .mca files"
    if [ ! -f "$path/level.dat" ]; then
      echo "  WARNING: $name exists without level.dat"
    fi
  else
    echo "  $name: not found in this checkout"
  fi
done
echo

echo "RECENT PLUGIN / CHUNK / HEIGHT WARNINGS (may include user data):"
log="$ROOT/server/logs/latest.log"
if [ -f "$log" ]; then
  grep -Eai '(TuffXPlus|ViaBackwards|ViaVersion|Y0-Debug|chunk|packet|world.height|world height|below y ?0|multiple backing buffers)' "$log" | tail -n 45 || echo "  None found"
else
  echo "  No server/logs/latest.log; run on the Codespace hosting Paper."
fi

echo
echo "NEXT: In game, use F3 to confirm the DIMENSION (Overworld vs Nether),"
echo "      game client (/js/ vs /tuff/), and the exact coords of missing blocks."
echo "      Compare the SAME coordinates using a native 1.21.11 Java client."
echo "      If blocks exist for Java but vanish in TuffClient, this is a"
echo "      protocol/TuffXPlus chunk issue, not world generation."
echo "      Warning: never delete region files or regenerate the classroom world."
