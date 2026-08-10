#!/usr/bin/env bash
# Push the localization output from this WSL working copy to the play environments.
#
# Windows cannot use a \\wsl.localhost\... path as a working directory — it falls
# back to C:\Windows — and the game resolves Data/, Scripts/ and patch/ relative
# to the working directory, so it must be launched from a native Windows path.
# This copy stays the source of truth; only the localization output is pushed.
#
#   jp_translation/tools/sync.sh            # push to both targets
#   jp_translation/tools/sync.sh windows    # push to C:\Games only
#   jp_translation/tools/sync.sh linux      # push to the Linux AppImage build only
set -euo pipefail

# The source is this checkout, found from the script's own location, so the
# script works wherever the repository is cloned. The two targets are whatever
# the person running it happens to have installed, so they are overridable:
#
#   REBORN_JA_WIN=/mnt/d/Games/Reborn jp_translation/tools/sync.sh windows
#
# A target that does not exist is skipped, so the defaults are harmless.
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WIN="${REBORN_JA_WIN:-/mnt/c/Games/Reborn-19.5.0}"
LIN="${REBORN_JA_LINUX:-$(dirname "$SRC")/Reborn-19.5.0-linux}"

FILES=(
  "patch/Fonts/pokemonemerald.ttf"
  "patch/Data/japanese.dat"
  "Scripts/DrawText.rb"
  "Scripts/System.rb"
  "Scripts/Load.rb"
  "Scripts/PBIntl.rb"
  "Scripts/Reborn/Settings.rb"
  "Scripts/Summary.rb"
  "Scripts/SpriteWindow.rb"
  # Move names in battle: the fight menu drew PokeBattle_Move#name, which held
  # the raw data name and never went through the message table.
  "Scripts/Battle_Move.rb"
  "Scripts/Battle_MoveEffects.rb"
  "Scripts/Battle_Scene.rb"
  "Scripts/Battler.rb"
  "Scripts/BattleData.rb"
)

push() {
  local dest="$1" label="$2"
  if [ ! -d "$dest" ]; then
    echo "  skip $label: $dest not found"
    return
  fi
  local n=0
  for f in "${FILES[@]}"; do
    if [ ! -f "$SRC/$f" ]; then
      echo "  MISSING in source: $f" >&2
      continue
    fi
    if ! cmp -s "$SRC/$f" "$dest/$f" 2>/dev/null; then
      mkdir -p "$(dirname "$dest/$f")"
      cp "$SRC/$f" "$dest/$f"
      echo "    updated  $f"
      n=$((n + 1))
    fi
  done
  echo "  $label: $n file(s) updated"
}

target="${1:-all}"
echo "syncing from $SRC"
if [ "$target" = "all" ] || [ "$target" = "windows" ]; then
  push "$WIN" "windows (C:\\Games)"
fi
if [ "$target" = "all" ] || [ "$target" = "linux" ]; then
  push "$LIN" "linux (AppImage)"
fi
echo "done"
