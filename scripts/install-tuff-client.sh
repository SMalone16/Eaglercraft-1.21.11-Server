#!/usr/bin/env bash
# Install an isolated, pinned TuffClient browser build. Never change the stable
# /js/ client or any Paper world/chunk files.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WEB_ROOT="$ROOT_DIR/velocity/plugins/eaglerweb/web"
TARGET="$WEB_ROOT/tuff"

# Official TuffNetwork/tufftest v2 tree, pinned to a reviewed Git commit.
VERSION="1.1UT15"
UPSTREAM_COMMIT="fc5f9eb2b738c24129d1ec85f288373c205a737b"
ARCHIVE_GIT_BLOB="dfeba8c1ffa6d935ab9b5ae9f4d4b8ffb884233e"
URL="https://raw.githubusercontent.com/TuffNetwork/tufftest/$UPSTREAM_COMMIT/files/1_1UT15/JS/JS.zip"

if [ -f "$TARGET/tigercraft-ready.txt" ] &&
   grep -Fxq "$VERSION $ARCHIVE_GIT_BLOB" "$TARGET/tigercraft-ready.txt"; then
  echo "TuffClient $VERSION (below-Y0 test client) is already installed at /tuff/."
  exit 0
fi

# Never overwrite someone else's /tuff/ directory or an incomplete manual build.
if [ -e "$TARGET" ]; then
  echo "TuffClient installer: $TARGET already exists but is not our pinned build." >&2
  echo "Preserving it. Inspect or rename this folder manually before retrying." >&2
  exit 1
fi

for cmd in curl git python3; do
  command -v "$cmd" >/dev/null 2>&1 || {
    echo "TuffClient installer: missing dependency: $cmd" >&2
    exit 1
  }
done

work="$(mktemp -d "$WEB_ROOT/.tuff-install.XXXXXXXX")"
trap 'rm -rf "$work"' EXIT
echo "Fetching pinned TuffClient $VERSION browser build (~27 MB)..."
curl --fail --location --silent --show-error --retry 3 --retry-delay 2 \
  --connect-timeout 15 --max-time 180 "$URL" -o "$work/tuff.zip"

actual="$(git hash-object "$work/tuff.zip")"
if [ "$actual" != "$ARCHIVE_GIT_BLOB" ]; then
  echo "TuffClient installer: upstream archive integrity check FAILED." >&2
  echo "Expected Git blob $ARCHIVE_GIT_BLOB, received $actual." >&2
  exit 1
fi

# Unpack without trusting archive paths, preserve upstream launcher and client
# scripts, then inject only TigerCraft's same-origin server-list entry.
python3 - "$work" <<'PY'
import pathlib
import re
import shutil
import stat
import sys
import zipfile

work = pathlib.Path(sys.argv[1])
dest = work / "client"
extracted = work / "extracted"
extracted.mkdir()
with zipfile.ZipFile(work / "tuff.zip") as archive:
    files = archive.infolist()
    if sum(x.file_size for x in files) > 140 * 1024 * 1024:
        raise SystemExit("TuffClient installer: archive expands beyond 140 MB")
    for info in files:
        path = pathlib.PurePosixPath(info.filename)
        if (path.is_absolute() or ".." in path.parts or
                "\\" in info.filename or
                stat.S_IFMT(info.external_attr >> 16) == stat.S_IFLNK):
            raise SystemExit("TuffClient installer: unsafe ZIP entry")
    archive.extractall(extracted)

candidates = [
    p.parent for p in extracted.rglob("classes.js")
    if (p.parent / "index.html").is_file() and
       (p.parent / "assets.epk").is_file()
]
if len(candidates) != 1:
    raise SystemExit("TuffClient installer: expected one JS client root in archive")
shutil.copytree(candidates[0], dest)

# Injected before upstream scripts, so the game still owns its launcher and
# receives a normal server-list entry pointing to this Codespace's WebSocket.
bootstrap = """
<script>
(function () {
  var currentOptions = window.eaglercraftXOpts;
  var endpoint = window.location.origin.replace(/^http/, "ws");
  function addClassroomServer(options) {
    if (!options || typeof options !== "object") return;
    var servers = Array.isArray(options.servers) ? options.servers : [];
    if (!servers.some(function(s) { return s && s.addr === endpoint; })) {
      servers.unshift({addr: endpoint, name: "TigerCraft (full-depth mining)"});
    }
    options.servers = servers;
  }
  addClassroomServer(currentOptions);
  try {
    Object.defineProperty(window, "eaglercraftXOpts", {
      configurable: true,
      enumerable: true,
      get: function() { return currentOptions; },
      set: function(value) {
        currentOptions = value;
        addClassroomServer(value);
      }
    });
  } catch (e) {
    // Retain upstream client behavior if the launcher has a locked option.
  }
})();
</script>
"""
index = dest / "index.html"
html = index.read_text(encoding="utf-8-sig")
patched, count = re.subn(r"<head\\b[^>]*>", lambda m: m.group(0) + bootstrap,
                         html, count=1, flags=re.IGNORECASE)
if count != 1:
    raise SystemExit("TuffClient installer: upstream HTML has no <head> tag")
index.write_text(patched, encoding="utf-8")
(dest / "tigercraft-ready.txt").write_text(
    "1.1UT15 dfeba8c1ffa6d935ab9b5ae9f4d4b8ffb884233e\n",
    encoding="utf-8"
)
PY

mv -T "$work/client" "$TARGET"
echo "TuffClient available at /tuff/ (the stable /js/ client was not modified)."
