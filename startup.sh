#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VELOCITY_JAR="$ROOT_DIR/velocity/velocity-3.5.0-all.jar"
LIMBO_JAR="$ROOT_DIR/limbo/server.jar"
PAPER_JAR="$ROOT_DIR/server/versions/1.21.11/paper-1.21.11.jar"

echo "============================================================"
echo " Eaglercraft Classroom Server"
echo "============================================================"

if ! command -v java >/dev/null 2>&1; then
  echo "ERROR: Java is not installed. Java 21 or newer is required."
  exit 1
fi

if [ ! -f "$VELOCITY_JAR" ]; then
  echo "ERROR: Velocity JAR not found: $VELOCITY_JAR"
  exit 1
fi

if [ ! -f "$PAPER_JAR" ]; then
  echo "ERROR: Paper 1.21.11 JAR not found: $PAPER_JAR"
  exit 1
fi

if [ ! -f "$LIMBO_JAR" ]; then
  echo "NanoLimbo is not present yet. Downloading the latest release..."
  curl -L --fail --show-error \
    "https://github.com/Nan1t/NanoLimbo/releases/latest/download/NanoLimbo.jar" \
    -o "$LIMBO_JAR"
  echo "NanoLimbo downloaded."
fi

VELOCITY_PID=""
LIMBO_PID=""

cleanup() {
  echo
  echo "Stopping proxy and login server..."
  if [ -n "${LIMBO_PID:-}" ]; then
    kill "$LIMBO_PID" 2>/dev/null || true
  fi
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

echo
echo "Starting NanoLimbo login server on port 25566..."
cd "$ROOT_DIR/limbo"
java -jar "$LIMBO_JAR" &
LIMBO_PID=$!
sleep 3

echo
echo "Starting Paper 1.21.11 gameplay server on port 25565..."
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
java -jar "$PAPER_JAR"

echo
echo "Paper has stopped."
