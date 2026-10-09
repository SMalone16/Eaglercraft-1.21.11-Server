#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CATALOG_FILE="$ROOT_DIR/classroom/plugins.conf"
PLUGIN_DIR="$ROOT_DIR/server/plugins"
STATE_FILE="$ROOT_DIR/.classroom-plugin-selection"
RUNTIME_PREFIX="classroom-session-"

if [ ! -f "$CATALOG_FILE" ]; then
  echo "ERROR: Classroom plugin catalog is missing: $CATALOG_FILE" >&2
  exit 1
fi

mkdir -p "$PLUGIN_DIR"

declare -a PLUGIN_IDS=()
declare -A PLUGIN_NAME=()
declare -A PLUGIN_REPO=()
declare -A PLUGIN_BRANCH=()
declare -A PLUGIN_JAR_PATH=()
declare -A PLUGIN_EXPECTED_VERSION=()
declare -A PLUGIN_DEFAULT=()
declare -A PLUGIN_LEGACY_PREFIX=()
declare -A PLUGIN_URL=()
declare -A PLUGIN_AVAILABLE=()
declare -A PLUGIN_SELECTED=()

while IFS='|' read -r id display_name repository branch jar_path expected_version default_enabled legacy_prefix; do
  [ -z "${id:-}" ] && continue
  [ "${id:0:1}" = "#" ] && continue

  if [[ ! "$id" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
    echo "ERROR: Invalid plugin id '$id' in $CATALOG_FILE" >&2
    exit 1
  fi

  if [ -n "${PLUGIN_NAME[$id]+x}" ]; then
    echo "ERROR: Duplicate plugin id '$id' in $CATALOG_FILE" >&2
    exit 1
  fi

  PLUGIN_IDS+=("$id")
  PLUGIN_NAME["$id"]="$display_name"
  PLUGIN_REPO["$id"]="$repository"
  PLUGIN_BRANCH["$id"]="$branch"
  PLUGIN_JAR_PATH["$id"]="$jar_path"
  PLUGIN_EXPECTED_VERSION["$id"]="$expected_version"
  PLUGIN_DEFAULT["$id"]="$default_enabled"
  PLUGIN_LEGACY_PREFIX["$id"]="$legacy_prefix"
  PLUGIN_URL["$id"]="https://raw.githubusercontent.com/$repository/$branch/$jar_path"
  PLUGIN_AVAILABLE["$id"]=0
  PLUGIN_SELECTED["$id"]=0
done < "$CATALOG_FILE"

if [ "${#PLUGIN_IDS[@]}" -eq 0 ]; then
  echo "ERROR: No classroom plugins are configured in $CATALOG_FILE" >&2
  exit 1
fi

load_default_selection() {
  local id
  for id in "${PLUGIN_IDS[@]}"; do
    if [ "${PLUGIN_DEFAULT[$id]}" = "1" ]; then
      PLUGIN_SELECTED["$id"]=1
    else
      PLUGIN_SELECTED["$id"]=0
    fi
  done
}

load_saved_selection() {
  load_default_selection

  [ -f "$STATE_FILE" ] || return 0

  local saved
  saved="$(head -n 1 "$STATE_FILE" 2>/dev/null || true)"
  local id
  for id in "${PLUGIN_IDS[@]}"; do
    PLUGIN_SELECTED["$id"]=0
  done

  IFS=',' read -r -a saved_ids <<< "$saved"
  local saved_id
  for saved_id in "${saved_ids[@]}"; do
    [ -z "$saved_id" ] && continue
    if [ -n "${PLUGIN_NAME[$saved_id]+x}" ]; then
      PLUGIN_SELECTED["$saved_id"]=1
    fi
  done
}

refresh_availability() {
  local id
  echo
  echo "Checking classroom plugin builds from GitHub main..."
  for id in "${PLUGIN_IDS[@]}"; do
    if curl -L --fail --silent --show-error --head --max-time 8 "${PLUGIN_URL[$id]}" >/dev/null 2>&1; then
      PLUGIN_AVAILABLE["$id"]=1
    else
      PLUGIN_AVAILABLE["$id"]=0
    fi
  done
}

print_menu() {
  clear 2>/dev/null || true
  echo "============================================================"
  echo " Classroom Plugin Lab - choose this session's plugins"
  echo "============================================================"
  echo
  echo "Core server/compatibility plugins stay enabled automatically."
  echo "Toggle only the student/classroom plugins you want to test."
  echo "Select u for the full four-plugin Undercity adventure."
  echo

  local index=1
  local id mark status
  for id in "${PLUGIN_IDS[@]}"; do
    mark=" "
    [ "${PLUGIN_SELECTED[$id]}" = "1" ] && mark="x"

    if [ "${PLUGIN_AVAILABLE[$id]}" = "1" ]; then
      status="READY"
    else
      status="NOT BUILT / UNAVAILABLE"
    fi

    printf " %2d) [%s] %-28s %-23s %s\n"       "$index" "$mark" "${PLUGIN_NAME[$id]}" "$status" "${PLUGIN_REPO[$id]}"
    index=$((index + 1))
  done

  echo
  echo " u) UNDERCITY - City + Zombies + Lucky Chests + Eaglervators"
  echo " a) enable every READY plugin"
  echo " n) disable all classroom plugins"
  echo " r) refresh build availability"
  echo " s) START SERVER with this selection"
  echo " q) cancel startup"
  echo
}

toggle_by_number() {
  local number="$1"
  if ! [[ "$number" =~ ^[0-9]+$ ]]; then
    return 1
  fi

  if [ "$number" -lt 1 ] || [ "$number" -gt "${#PLUGIN_IDS[@]}" ]; then
    return 1
  fi

  local id="${PLUGIN_IDS[$((number - 1))]}"

  if [ "${PLUGIN_AVAILABLE[$id]}" != "1" ] && [ "${PLUGIN_SELECTED[$id]}" != "1" ]; then
    echo
    echo "${PLUGIN_NAME[$id]} does not have a downloadable build yet."
    echo "Once its dist/ JAR exists on GitHub, refresh and it will become selectable."
    read -r -p "Press Enter to continue..." _
    return 0
  fi

  if [ "${PLUGIN_SELECTED[$id]}" = "1" ]; then
    PLUGIN_SELECTED["$id"]=0
  else
    PLUGIN_SELECTED["$id"]=1
  fi
}

set_selection_from_env() {
  local requested="$1"
  local id

  for id in "${PLUGIN_IDS[@]}"; do
    PLUGIN_SELECTED["$id"]=0
  done

  case "$requested" in
    ""|default)
      load_default_selection
      return
      ;;
    none)
      return
      ;;
    undercity)
      for id in luckychests zombies city eaglervators; do
        PLUGIN_SELECTED["$id"]=1
      done
      return
      ;;
    all)
      for id in "${PLUGIN_IDS[@]}"; do
        if [ "${PLUGIN_AVAILABLE[$id]}" = "1" ]; then
          PLUGIN_SELECTED["$id"]=1
        fi
      done
      return
      ;;
  esac

  IFS=',' read -r -a requested_ids <<< "$requested"
  local requested_id
  for requested_id in "${requested_ids[@]}"; do
    if [ -z "${PLUGIN_NAME[$requested_id]+x}" ]; then
      echo "ERROR: Unknown classroom plugin id '$requested_id'." >&2
      echo "Valid ids: ${PLUGIN_IDS[*]}" >&2
      exit 1
    fi
    PLUGIN_SELECTED["$requested_id"]=1
  done
}

save_selection() {
  local -a enabled=()
  local id
  for id in "${PLUGIN_IDS[@]}"; do
    if [ "${PLUGIN_SELECTED[$id]}" = "1" ]; then
      enabled+=("$id")
    fi
  done

  local joined=""
  if [ "${#enabled[@]}" -gt 0 ]; then
    local IFS=,
    joined="${enabled[*]}"
  fi
  printf '%s\n' "$joined" > "$STATE_FILE"
}

remove_managed_classroom_jars() {
  rm -f "$PLUGIN_DIR"/"$RUNTIME_PREFIX"*.jar

  local id prefix
  for id in "${PLUGIN_IDS[@]}"; do
    prefix="${PLUGIN_LEGACY_PREFIX[$id]}"
    if [ -n "$prefix" ]; then
      rm -f "$PLUGIN_DIR"/"$prefix"*.jar
    fi
  done
}

install_selected_plugins() {
  remove_managed_classroom_jars

  local id target temp
  local installed_count=0
  echo
  echo "Preparing classroom plugins for this session..."

  for id in "${PLUGIN_IDS[@]}"; do
    [ "${PLUGIN_SELECTED[$id]}" = "1" ] || continue

    if [ "${PLUGIN_AVAILABLE[$id]}" != "1" ]; then
      echo "ERROR: ${PLUGIN_NAME[$id]} is selected but its compiled JAR is unavailable." >&2
      echo "Repository: https://github.com/${PLUGIN_REPO[$id]}" >&2
      echo "Expected JAR: ${PLUGIN_JAR_PATH[$id]}" >&2
      exit 1
    fi

    target="$PLUGIN_DIR/$RUNTIME_PREFIX$id.jar"
    temp="$target.download"

    echo "  -> ${PLUGIN_NAME[$id]}"
    curl -L --fail --show-error --silent --retry 3 --retry-delay 1       "${PLUGIN_URL[$id]}" -o "$temp"

    if ! jar tf "$temp" >/dev/null 2>&1; then
      rm -f "$temp"
      echo "ERROR: Downloaded file for ${PLUGIN_NAME[$id]} is not a valid JAR." >&2
      exit 1
    fi

    expected_version="${PLUGIN_EXPECTED_VERSION[$id]}"
    if [ -n "$expected_version" ]; then
      verify_dir="$(mktemp -d)"
      (
        cd "$verify_dir"
        jar xf "$temp" plugin.yml
      )

      if [ ! -f "$verify_dir/plugin.yml" ]; then
        rm -rf "$verify_dir" "$temp"
        echo "ERROR: ${PLUGIN_NAME[$id]} JAR does not contain plugin.yml." >&2
        exit 1
      fi

      actual_version="$(awk -F: '/^version:/ { print $2; exit }' "$verify_dir/plugin.yml" | xargs)"
      rm -rf "$verify_dir"

      if [ "$actual_version" != "$expected_version" ]; then
        rm -f "$temp"
        echo "ERROR: ${PLUGIN_NAME[$id]} version mismatch." >&2
        echo "Expected: $expected_version" >&2
        echo "Downloaded JAR reports: ${actual_version:-unknown}" >&2
        echo "Source: ${PLUGIN_URL[$id]}" >&2
        exit 1
      fi
    fi

    checksum="$(sha256sum "$temp" | awk '{print $1}')"
    mv "$temp" "$target"
    echo "     source: ${PLUGIN_URL[$id]}"
    if [ -n "${PLUGIN_EXPECTED_VERSION[$id]}" ]; then
      echo "     verified plugin version: ${PLUGIN_EXPECTED_VERSION[$id]}"
    fi
    echo "     sha256: $checksum"
    installed_count=$((installed_count + 1))
  done

  save_selection

  if [ "$installed_count" -eq 0 ]; then
    echo "  No classroom project plugins enabled. Running the base server only."
  else
    echo
    echo "Active classroom plugins:"
    for id in "${PLUGIN_IDS[@]}"; do
      if [ "${PLUGIN_SELECTED[$id]}" = "1" ]; then
        echo "  - ${PLUGIN_NAME[$id]}"
      fi
    done
  fi
}

load_saved_selection
refresh_availability

if [ -n "${CLASSROOM_PLUGINS:-}" ]; then
  set_selection_from_env "$CLASSROOM_PLUGINS"
  install_selected_plugins
  exit 0
fi

if [ ! -t 0 ]; then
  echo "No interactive terminal detected; using the saved/default classroom plugin selection."
  install_selected_plugins
  exit 0
fi

while true; do
  print_menu
  read -r -p "Choice: " choice

  case "$choice" in
    u|U)
      missing=""
      for plugin_id in luckychests zombies city eaglervators; do
        if [ "${PLUGIN_AVAILABLE[$plugin_id]}" != "1" ]; then
          missing="$missing $plugin_id"
        fi
      done
      if [ -n "$missing" ]; then
        echo "Undercity preset cannot start until these builds are READY:$missing"
        read -r -p "Press Enter to continue..." _
      else
        for plugin_id in "${PLUGIN_IDS[@]}"; do PLUGIN_SELECTED["$plugin_id"]=0; done
        for plugin_id in luckychests zombies city eaglervators; do PLUGIN_SELECTED["$plugin_id"]=1; done
      fi
      ;;
    a|A)
      for id in "${PLUGIN_IDS[@]}"; do
        if [ "${PLUGIN_AVAILABLE[$id]}" = "1" ]; then
          PLUGIN_SELECTED["$id"]=1
        fi
      done
      ;;
    n|N)
      for id in "${PLUGIN_IDS[@]}"; do
        PLUGIN_SELECTED["$id"]=0
      done
      ;;
    r|R)
      refresh_availability
      ;;
    s|S|"")
      install_selected_plugins
      exit 0
      ;;
    q|Q)
      echo "Startup cancelled."
      exit 130
      ;;
    *)
      if ! toggle_by_number "$choice"; then
        echo
        echo "Unknown choice: $choice"
        read -r -p "Press Enter to continue..." _
      fi
      ;;
  esac
done
