#!/bin/zsh
# Builds a launcher app (default "~/Applications/Claude Home.app") that starts a second,
# isolated instance of the regular Claude desktop app next to the default one.
#
# Isolation per profile:
#   --user-data-dir   -> app data (sign-in, cookies, settings, MCP config, sessions).
#                        Also gives the instance its own single-instance lock, so both run in parallel.
#   CLAUDE_CONFIG_DIR -> Claude Code config (the ~/.claude equivalent: settings, CLAUDE.md,
#                        skills, hooks, history, credentials keychain entry).
# CLAUDE_USER_DATA_DIR is ignored by signed Claude builds, hence the --user-data-dir switch.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: make-claude-home.sh [options]

  --profile NAME   Profile name (default: Home)
                   Data:   ~/Library/Application Support/Claude-<NAME>
                   Config: ~/.claude-<name, lowercased>
  --name NAME      Launcher app name (default: "Claude <profile>")
  --icon FILE      Use this .icns or .png as the launcher icon (skips the badge)
  --badge SYMBOL   SF Symbol drawn as a badge on Claude's icon (default: house.fill)
  --color HEX      Badge color (default: 34A853)
  --no-badge       Use Claude's icon unchanged
  --dest DIR       Where to put the launcher (default: ~/Applications)
  -h, --help       Show this help
EOF
}

PROFILE="Home"
NAME=""
ICON=""
BADGE="house.fill"
COLOR="34A853"
DEST="$HOME/Applications"

while (( $# )); do
  case "$1" in
    --profile)  PROFILE="$2"; shift 2 ;;
    --name)     NAME="$2"; shift 2 ;;
    --icon)     ICON="$2"; shift 2 ;;
    --badge)    BADGE="$2"; shift 2 ;;
    --color)    COLOR="$2"; shift 2 ;;
    --no-badge) BADGE=""; shift ;;
    --dest)     DEST="$2"; shift 2 ;;
    -h|--help)  usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 64 ;;
  esac
done

HERE="${0:A:h}"
CLAUDE_APP="/Applications/Claude.app"
BUNDLE_ID="com.anthropic.claudefordesktop"
NAME="${NAME:-Claude $PROFILE}"
DATA_DIR="$HOME/Library/Application Support/Claude-$PROFILE"
PROFILE_LC="${(L)PROFILE}"
CONFIG_DIR="$HOME/.claude-$PROFILE_LC"
APP="$DEST/$NAME.app"
LAUNCHER_ID="local.claude-launcher.${PROFILE_LC//[^a-z0-9]/-}"

[[ -d "$CLAUDE_APP" ]] || { echo "Claude.app not found in /Applications" >&2; exit 1; }
[[ -z "$ICON" || -f "$ICON" ]] || { echo "Icon not found: $ICON" >&2; exit 1; }

WORK=$(mktemp -d -t claude-launcher)
trap 'rm -rf "$WORK"' EXIT

# --- Icon -------------------------------------------------------------------
ICNS="$WORK/applet.icns"
make_icns() {  # $1 = 1024px png
  local set="$WORK/icon.iconset" s
  mkdir -p "$set"
  for s in 16 32 128 256 512; do
    sips -z $s $s "$1" --out "$set/icon_${s}x${s}.png" >/dev/null
    sips -z $((s*2)) $((s*2)) "$1" --out "$set/icon_${s}x${s}@2x.png" >/dev/null
  done
  iconutil -c icns "$set" -o "$ICNS"
}

if [[ -n "$ICON" ]]; then
  case "${ICON:l}" in
    *.icns) cp "$ICON" "$ICNS" ;;
    *)      sips -s format png -z 1024 1024 "$ICON" --out "$WORK/custom.png" >/dev/null
            make_icns "$WORK/custom.png" ;;
  esac
elif [[ -n "$BADGE" ]]; then
  echo "Rendering badge icon (first Swift run can take ~30s)..."
  swift "$HERE/icon/badge-icon.swift" "$CLAUDE_APP/Contents/Resources/electron.icns" \
        "$WORK/badged.png" "$BADGE" "$COLOR"
  make_icns "$WORK/badged.png"
else
  cp "$CLAUDE_APP/Contents/Resources/electron.icns" "$ICNS"
fi

# --- Launcher app -----------------------------------------------------------
mkdir -p "$DEST" "$DATA_DIR" "$CONFIG_DIR"

cat > "$WORK/launcher.applescript" <<EOF
set dataDir to "$DATA_DIR"
set configDir to "$CONFIG_DIR"
do shell script "open -n -b $BUNDLE_ID --env CLAUDE_CONFIG_DIR=" & quoted form of configDir & " --args --user-data-dir=" & quoted form of dataDir
EOF

rm -rf "$APP"
osacompile -o "$APP" "$WORK/launcher.applescript"

cp "$ICNS" "$APP/Contents/Resources/applet.icns"
rm -f "$APP/Contents/Resources/Assets.car"   # would override applet.icns on newer macOS
PLIST="$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Delete :CFBundleIconName" "$PLIST" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :LSUIElement bool true" "$PLIST"   # launcher never shows in the Dock
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $LAUNCHER_ID" "$PLIST" 2>/dev/null \
  || /usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string $LAUNCHER_ID" "$PLIST"
codesign --force --sign - "$APP" 2>/dev/null

# Make Finder/Dock pick up the new icon.
touch "$APP"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APP" 2>/dev/null || true

echo "Built:  $APP"
echo "Data:   $DATA_DIR"
echo "Config: $CONFIG_DIR"
