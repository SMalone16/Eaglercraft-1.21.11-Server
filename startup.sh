#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VELOCITY_JAR="$ROOT_DIR/velocity/velocity-3.5.0-all.jar"
PAPER_JAR="$ROOT_DIR/server/server.jar"

PAPER_VERSION="1.21.11"
PAPER_USER_AGENT="Eaglercraft-Classroom-Server/1.0 (https://github.com/SMalone16/Eaglercraft-1.21.11-Server)"

echo "============================================================"
echo " Eaglercraft Classroom Server"
echo "============================================================"

if ! command -v java >/dev/null 2>&1; then
  echo "ERROR: Java is not installed. Java 21 or newer is required."
  exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
  echo "ERROR: curl is not installed."
  exit 1
fi

if [ ! -f "$VELOCITY_JAR" ]; then
  echo "ERROR: Velocity JAR not found: $VELOCITY_JAR"
  exit 1
fi

if [ ! -f "$PAPER_JAR" ]; then
  echo "Paper $PAPER_VERSION launcher is not present yet."
  echo "Finding the latest stable Paper $PAPER_VERSION build..."

  BUILDS_JSON="$(curl -L --fail --show-error -sS \
    -H "User-Agent: $PAPER_USER_AGENT" \
    "https://fill.papermc.io/v3/projects/paper/versions/$PAPER_VERSION/builds")"

  if ! command -v jq >/dev/null 2>&1; then
    echo "jq is not installed. Installing it..."
    sudo apt-get update -qq
    sudo apt-get install -y jq
  fi

  PAPER_URL="$(printf '%s' "$BUILDS_JSON" | \
    jq -r 'first(.[] | select(.channel == "STABLE") | .downloads."server:default".url) // empty')"

  if [ -z "$PAPER_URL" ]; then
    echo "ERROR: Could not find a stable Paper $PAPER_VERSION download."
    exit 1
  fi

  echo "Downloading official Paper $PAPER_VERSION server..."
  curl -L --fail --show-error \
    -H "User-Agent: $PAPER_USER_AGENT" \
    "$PAPER_URL" \
    -o "$PAPER_JAR"

  echo "Paper downloaded."
fi

VELOCITY_PID=""

cleanup() {
  echo
  echo "Stopping Eaglercraft proxy..."
  if [ -n "${VELOCITY_PID:-}" ]; then
    kill "$VELOCITY_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT INT TERM

echo
echo "Starting Velocity proxy on port 25567..."
cd "$ROOT_DIR/velocity"
java -jar "$VELOCITY_JAR" &
VELOCITY_PID=$!
sleep 5

if ! kill -0 "$VELOCITY_PID" 2>/dev/null; then
  echo "ERROR: Velocity exited during startup."
  echo "Check velocity/logs/latest.log for details."
  exit 1
fi

echo
echo "Starting Paper $PAPER_VERSION classroom server on port 25565..."
echo
echo "When the server is ready:"
echo "  1. Open the PORTS tab in Codespaces."
echo "  2. Make port 25567 PUBLIC."
echo "  3. Share the forwarded 25567 URL with /js/ added to the end."
echo
echo "Codespaces should detect this address and forward the port:"
echo "http://localhost:25567/js/"
echo
echo "Waiting for Paper to finish starting..."
echo "------------------------------------------------------------"

cd "$ROOT_DIR/server"
set +e
java -jar "$PAPER_JAR" --nogui
PAPER_EXIT=$?
set -e

if [ "$PAPER_EXIT" -ne 0 ]; then
  echo
  echo "============================================================"
  echo " PAPER SERVER STOPPED WITH AN ERROR (exit code $PAPER_EXIT)"
  echo " The Eaglercraft proxy will now be stopped as well."
  echo " Review the Paper error immediately above this message."
  echo "============================================================"
  exit "$PAPER_EXIT"
fi

echo
echo "Paper has stopped normally."
