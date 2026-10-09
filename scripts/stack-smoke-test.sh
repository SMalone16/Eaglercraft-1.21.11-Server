#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
# shellcheck source=/dev/null
source stack-versions.env

fail() {
  echo "SMOKE TEST FAILED: $*" >&2
  exit 1
}

bash -n startup.sh
bash -n scripts/install-managed-dependencies.sh
bash -n scripts/select-classroom-plugins.sh

# Regression: the Undercity handler must be VISIBLE, not merely wired in the case statement.
grep -Fq 'echo " u) UNDERCITY' scripts/select-classroom-plugins.sh ||
  fail "Undercity preset is missing from the displayed startup menu"
grep -Fq "    u|U)" scripts/select-classroom-plugins.sh ||
  fail "Undercity menu selection handler is missing"
grep -Fq "    undercity)" scripts/select-classroom-plugins.sh ||
  fail "Undercity environment preset is missing"
for required_id in city zombies luckychests eaglervators; do
  grep -q "^$required_id|" classroom/plugins.conf ||
    fail "Undercity preset plugin $required_id is missing from catalog"
done
[ -f classroom/plugins.conf ] || fail "classroom plugin catalog is missing"

grep -q '^network-compression-threshold=-1$' server/server.properties ||
  fail "Paper backend compression must be disabled behind local Velocity"
grep -q '^http_websocket_compression_level = 3$' velocity/plugins/eaglerxserver/settings.toml ||
  fail "EaglerXServer WebSocket compression level should be 3 for classroom CPU efficiency"
grep -q '^[[:space:]]*skin_cache_thread_count = 1$' velocity/plugins/eaglerxserver/settings.toml ||
  fail "EaglerXServer skin cache must use one worker thread"
grep -q '"cpus": 4' .devcontainer/devcontainer.json ||
  fail "Codespaces should request at least 4 CPU cores"
grep -q '"memory": "16gb"' .devcontainer/devcontainer.json ||
  fail "Codespaces should request 16 GB RAM"

[ ! -e server/plugins/ProtocolLib.jar ] || fail "ProtocolLib is not part of the managed classroom stack"
if compgen -G 'server/plugins/TAB*.jar' >/dev/null; then
  fail "TAB is not part of the managed classroom stack"
fi

[ -f velocity/plugins/eaglerweb/web/js/index.html ] || fail "stable /js/ client is missing"
grep -q 'Eaglercraft 1.12.2' velocity/plugins/eaglerweb/web/js/index.html || fail "stable /js/ client no longer identifies as 1.12.2"
[ -f velocity/plugins/eaglerweb/web/modern/index.html ] || fail "/modern/ client slot is missing"
[ -f velocity/plugins/eaglerweb/web/experimental/1.21/index.html ] || fail "/experimental/1.21/ client slot is missing"

if compgen -G 'velocity/plugins/Via*.jar' >/dev/null; then
  fail "Via* must not be installed on Velocity; TuffX+ requires backend-only Via placement"
fi
[ ! -e server/plugins/TuffX.jar ] || fail "deprecated TuffX.jar must not be installed beside TuffXPlus"

# Classroom project plugins are installed under a standardized runtime name by
# select-classroom-plugins.sh. Legacy direct copies would bypass session control.
if compgen -G 'server/plugins/LuckyChests*.jar' >/dev/null; then
  fail "legacy LuckyChests JAR found; classroom plugins must be session-managed"
fi
if compgen -G 'server/plugins/EaglerSoccer*.jar' >/dev/null; then
  fail "legacy EaglerSoccer JAR found; classroom plugins must be session-managed"
fi
if compgen -G 'server/plugins/EaglerZombiesFall26*.jar' >/dev/null; then
  fail "legacy EaglerZombiesFall26 JAR found; classroom plugins must be session-managed"
fi

grep -q 'http_websocket_max_frame_length = 196608' velocity/plugins/eaglerxserver/settings.toml ||
  fail "EaglerXServer WebSocket frame limit is not hardened"

managed_jars=(
  "velocity/plugins/EaglerXServer.jar"
  "velocity/plugins/EaglerWeb.jar"
  "velocity/plugins/EaglerXRewind.jar"
  "server/plugins/ViaVersion-$VIAVERSION_VERSION.jar"
  "server/plugins/ViaBackwards-$VIAVERSION_VERSION.jar"
  "server/plugins/ViaRewind-$VIAREWIND_VERSION.jar"
  "server/plugins/TuffXPlus-$TUFFXPLUS_VERSION.jar"
)

for jar_file in "${managed_jars[@]}"; do
  [ -f "$jar_file" ] || fail "managed JAR missing: $jar_file"
  jar tf "$jar_file" >/dev/null || fail "invalid JAR archive: $jar_file"
done

for jar_file in server/plugins/classroom-session-*.jar; do
  [ -e "$jar_file" ] || continue
  jar tf "$jar_file" >/dev/null || fail "invalid classroom session JAR: $jar_file"
done

echo "Stack smoke test passed."
