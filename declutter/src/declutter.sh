#!/bin/bash
# Declutter: remove the optional Apple apps that come on a Mac
# (Pages, Numbers, Keynote, iMovie, GarageBand and GarageBand's sound library).
#
# Safari, Mail, Music, Photos and the other built-in apps live on macOS's sealed,
# read-only system volume. They cannot be removed without turning off System
# Integrity Protection, so Declutter does not touch them.
#
# Everything is moved to the Trash, so it can be put back until you empty it.
# Removed apps can also be downloaded again for free from the App Store.
#
# Usage: double-click Declutter.app, or run `bash declutter.sh [--dry-run]`.

set -u
export PATH="/usr/bin:/bin:/usr/sbin:/sbin:${PATH:-}"

TITLE="Declutter"
DRY_RUN=0
[ "${1:-}" = "--dry-run" ] && DRY_RUN=1

# Overridable for testing; the defaults are the real macOS locations.
ROOT="${DECLUTTER_ROOT:-}"
TRASH="${DECLUTTER_TRASH:-$HOME/.Trash}"

PROTECTED="Safari, Mail, Music, TV, Photos, Messages, FaceTime, Maps, News, Podcasts, Books, Stocks, Home, Freeform, Notes, Calendar and other built-in apps are part of macOS's protected system and can't be removed."

# ---------- dialogs (AppleScript, arguments passed safely through argv) ----------

# alert TEXT [BUTTON...]  -> prints the clicked button, empty on cancel
alert() {
  osascript - "$TITLE" "$@" <<'EOF' 2>/dev/null
on run argv
  set theTitle to item 1 of argv
  set theText to item 2 of argv
  if (count of argv) > 2 then
    set theButtons to items 3 thru -1 of argv
  else
    set theButtons to {"OK"}
  end if
  try
    set r to display dialog theText with title theTitle buttons theButtons default button (last item of theButtons) with icon note
    return button returned of r
  on error number -128
    return ""
  end try
end run
EOF
}

# pick PROMPT ITEM...  -> prints chosen items, one per line; empty on cancel
pick() {
  osascript - "$TITLE" "$@" <<'EOF' 2>/dev/null
on run argv
  set theTitle to item 1 of argv
  set thePrompt to item 2 of argv
  set theItems to items 3 thru -1 of argv
  set chosen to choose from list theItems with title theTitle with prompt thePrompt OK button name "Continue" cancel button name "Quit" with multiple selections allowed
  if chosen is false then return ""
  set AppleScript's text item delimiters to linefeed
  return chosen as text
end run
EOF
}

# ---------- what can be removed ----------

# label | bundle id | paths (colon separated)
CANDIDATES=(
  "Pages|com.apple.iWork.Pages|/Applications/Pages.app"
  "Numbers|com.apple.iWork.Numbers|/Applications/Numbers.app"
  "Keynote|com.apple.iWork.Keynote|/Applications/Keynote.app"
  "iMovie|com.apple.iMovieApp|/Applications/iMovie.app"
  "GarageBand|com.apple.garageband10|/Applications/GarageBand.app"
)

# GarageBand's sound library is shared with Logic Pro and MainStage, so it is only
# offered when neither of those is installed.
if [ ! -e "$ROOT/Applications/Logic Pro.app" ] && [ ! -e "$ROOT/Applications/Logic Pro X.app" ] \
   && [ ! -e "$ROOT/Applications/MainStage.app" ] && [ ! -e "$ROOT/Applications/MainStage 3.app" ]; then
  CANDIDATES+=("GarageBand sound library||/Library/Application Support/GarageBand:/Library/Application Support/Logic:/Library/Audio/Apple Loops/Apple")
fi

size_of() { du -skc "$@" 2>/dev/null | tail -1 | cut -f1; }   # KB

human() {
  local kb=$1
  if [ "$kb" -ge 1048576 ]; then awk -v k="$kb" 'BEGIN{printf "%.1f GB", k/1048576}'
  elif [ "$kb" -ge 1024 ]; then awk -v k="$kb" 'BEGIN{printf "%d MB", k/1024}'
  else echo "${kb} KB"; fi
}

LABELS=()      # what the user sees, e.g. "Pages (512 MB)"
PATHS=()       # matching existing paths, colon separated
IDS=()
for c in "${CANDIDATES[@]}"; do
  IFS='|' read -r label id paths <<<"$c"
  found=()
  IFS=':' read -r -a parts <<<"$paths"
  for p in "${parts[@]}"; do [ -e "$ROOT$p" ] && found+=("$ROOT$p"); done
  [ ${#found[@]} -eq 0 ] && continue
  kb=$(size_of "${found[@]}")
  LABELS+=("$label ($(human "$kb"))")
  PATHS+=("$(IFS=':'; echo "${found[*]}")")
  IDS+=("$id")
done

if [ ${#LABELS[@]} -eq 0 ]; then
  alert "Your Mac is already decluttered. Pages, Numbers, Keynote, iMovie and GarageBand aren't installed.

$PROTECTED" >/dev/null
  exit 0
fi

# ---------- ask ----------

CHOSEN=$(pick "Choose the Apple apps to remove. They go to the Trash and can be downloaded again for free from the App Store.

$PROTECTED" "${LABELS[@]}")
[ -z "$CHOSEN" ] && exit 0

SEL_PATHS=(); SEL_IDS=(); SEL_LABELS=()
while IFS= read -r line; do
  for i in "${!LABELS[@]}"; do
    if [ "${LABELS[$i]}" = "$line" ]; then
      IFS=':' read -r -a ps <<<"${PATHS[$i]}"
      SEL_PATHS+=("${ps[@]}")
      SEL_IDS+=("${IDS[$i]}")
      SEL_LABELS+=("${LABELS[$i]}")
    fi
  done
done <<<"$CHOSEN"
[ ${#SEL_PATHS[@]} -eq 0 ] && exit 0

LIST=$(printf '• %s\n' "${SEL_LABELS[@]}")
[ "$(alert "Move these to the Trash?

$LIST" "Cancel" "Move to Trash")" = "Move to Trash" ] || exit 0

if [ "$DRY_RUN" -eq 1 ]; then
  printf 'Would remove: %s\n' "${SEL_PATHS[@]}"
  exit 0
fi

# ---------- remove ----------

# Quit any selected app that is open so its files can be moved.
for id in "${SEL_IDS[@]}"; do
  [ -z "$id" ] && continue
  osascript -e "if application id \"$id\" is running then tell application id \"$id\" to quit" >/dev/null 2>&1
done
sleep 1

# First choice: Finder. It asks for your password itself and supports Put Back.
osascript - "${SEL_PATHS[@]}" <<'EOF' >/dev/null 2>&1
on run argv
  set theItems to {}
  repeat with p in argv
    set end of theItems to (POSIX file (contents of p)) as alias
  end repeat
  tell application "Finder" to delete theItems
end run
EOF

# Fallback for anything Finder couldn't move (e.g. Finder automation was declined):
# one administrator prompt, then move into this user's Trash.
LEFT=()
for p in "${SEL_PATHS[@]}"; do [ -e "$p" ] && LEFT+=("$p"); done
if [ ${#LEFT[@]} -gt 0 ]; then
  stamp=$(date +%H.%M.%S)
  cmd="mkdir -p $(printf %q "$TRASH")"
  for p in "${LEFT[@]}"; do
    name=$(basename "$p")
    case "$name" in *.app) ;; *) name="GarageBand library - $name";; esac
    dest="$TRASH/$name $stamp"
    cmd+=" && mv -f $(printf %q "$p") $(printf %q "$dest") && chown -R $(id -u) $(printf %q "$dest")"
  done
  osascript - "$cmd" <<'EOF' >/dev/null 2>&1
on run argv
  do shell script (item 1 of argv) with prompt "Declutter needs your password to move the selected apps to the Trash." with administrator privileges
end run
EOF
fi

FAILED=()
for p in "${SEL_PATHS[@]}"; do [ -e "$p" ] && FAILED+=("$(basename "$p")"); done

if [ ${#FAILED[@]} -eq 0 ]; then
  alert "Done. The apps are in the Trash. Empty the Trash to free up the space.

Changed your mind? Drag them back out of the Trash, or download them again for free from the App Store." >/dev/null
else
  alert "Some items couldn't be removed:

$(printf '• %s\n' "${FAILED[@]}")

If you cancelled the password prompt, open Declutter again. If macOS said the operation isn't permitted, go to System Settings → Privacy & Security → App Management, turn on Declutter, and try again." >/dev/null
  exit 1
fi
