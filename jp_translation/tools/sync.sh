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
  # Nature names and ability descriptions on the summary screen came straight
  # from the data objects instead of the message tables.
  "Scripts/Items.rb"
  "Scripts/SpriteWindow.rb"
  # Move names in battle: the fight menu drew PokeBattle_Move#name, which held
  # the raw data name and never went through the message table.
  "Scripts/Battle_Move.rb"
  "Scripts/Battle_MoveEffects.rb"
  "Scripts/Battle_Scene.rb"
  "Scripts/Battler.rb"
  "Scripts/BattleData.rb"
  # Field notes: the note bodies and field names are baked into fieldnotes.dat /
  # fields.dat, which are compiled once and shared by every language.
  "Scripts/FieldNotes.rb"
  "Scripts/Reborn/FieldNoteCompiler.rb"
  # Messages that never went through _INTL: the message helpers now look the
  # text up themselves, and the rest are wrapped at the call site.
  "Scripts/Messages.rb"
  "Scripts/TextEntry.rb"
  "Scripts/Options.rb"
  # Controls screens: the keyboard/gamepad lists are bare strings drawn with
  # pbDrawTextPositions, so no key was ever registered for them.
  "Scripts/Controls.rb"
  "Scripts/Storage.rb"
  "Scripts/Party.rb"
  "Scripts/PurifyChamber.rb"
  "Scripts/Updater.rb"
  "Scripts/Reborn/RebornScripts.rb"
  "Scripts/Reborn/TrainerSelect.rb"
  # Reopens Scene_FieldNotes and replaces the whole list menu, so the
  # field names have to be looked up there as well.
  "Scripts/Reborn/RebornPokegear.rb"
  "Scripts/Randomizer/RandomizerUtils.rb"
  # PULSE dex: the entry names are plain strings and each page is one
  # picture with the description drawn into it.
  "Scripts/PulseDex.rb"
  # Area names: every caller read MapInfos directly, so the map-name
  # message section was filled at compile time and never read back.
  "Scripts/Game_Map.rb"
  "Scripts/Field.rb"
  # Pokédex: the classification and the dex entry were read straight off
  # the data object instead of their message sections.
  "Scripts/PokedexScene.rb"
  "Scripts/BattleSwap.rb"
  # Stat-change messages: the stat names and the "sharply"/"harshly"
  # adverbs were hard-coded English spliced into translated sentences.
  "Scripts/Battle.rb"
  "Scripts/Battle_Effects.rb"
  "Scripts/Battle_ZMove.rb"
  "Scripts/ItemEffects.rb"
  # Pokegear "Time & Weather": the weather words double as bitmap filenames,
  # and the date line came straight from strftime, which is English-only.
  "Scripts/TimeWeather.rb"
  # Battle Tower: the intro line is stashed in a game variable and shown
  # with a variable reference, which never reaches the message table.
  "Scripts/OrgBattle.rb"
  # Inspect screen: stat labels were padded English spliced into the report.
  "Scripts/Battle_Inspect.rb"
)

# Whole directories, mirrored file by file. The type badges have their label
# drawn into the image, so there is one PNG per type rather than a string.
DIRS=(
  "patch/Graphics/Icons/ja"
  "patch/Graphics/Pictures/PulseDex/ja"
  "patch/Graphics/Pictures/Pokedex/ja"
  "patch/Graphics/Pictures/Battle/ja"
  "patch/Graphics/Pictures/ja"
  "patch/Graphics/Pictures/Party/ja"
  # Pokegear "Time & Weather": CURRENT WEATHER / WEATHER AT are painted
  # into the background image.
  "patch/Graphics/Pictures/Pokegear/TimeWeather/ja"
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
  for d in "${DIRS[@]}"; do
    for f in "$SRC/$d"/*; do
      [ -f "$f" ] || continue
      local rel="$d/$(basename "$f")"
      if ! cmp -s "$f" "$dest/$rel" 2>/dev/null; then
        mkdir -p "$dest/$d"
        cp "$f" "$dest/$rel"
        echo "    updated  $rel"
        n=$((n + 1))
      fi
    done
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
