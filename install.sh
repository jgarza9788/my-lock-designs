#!/usr/bin/env bash
# Adds these lock designs to the official omarchy-lock-explorer plugin by
# copying them into ~/.config/omarchy/lock-designs (they show up as "my-<name>"
# under Custom). Nothing in the plugin itself is modified.
#   ./install.sh [--dry-run] [--no-restart]
set -euo pipefail

PLUGIN_ID=io.github.sirjul1337.lock-explorer
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PLUGIN="$HOME/.config/omarchy/plugins/$PLUGIN_ID"
DEST="$HOME/.config/omarchy/lock-designs"
MANIFEST="$DEST/.jgarza-designs.manifest"
IMPORT="import \"../plugins/$PLUGIN_ID/designs\""

dry=0 restart=1
for a in "$@"; do
  case "$a" in
    --dry-run) dry=1 ;;
    --no-restart) restart=0 ;;
    *) echo "usage: $0 [--dry-run] [--no-restart]" >&2; exit 2 ;;
  esac
done
run() { if ((dry)); then echo "  would: $*"; else "$@"; fi; }

[[ -d $PLUGIN ]] || { echo "plugin not found: $PLUGIN" >&2; echo "install it first: omarchy plugin add https://github.com/SirJul1337/omarchy-lock-explorer.git --enable" >&2; exit 1; }

run mkdir -p "$DEST/shaders"
installed=()

for f in "$HERE"/designs/shaders/*; do
  n=shaders/$(basename "$f")
  run cp -f "$f" "$DEST/$n"
  installed+=("$n")
done

# A file with only comments/blank lines (e.g. the stub the explorer's
# "customize" leaves behind) has nothing worth keeping.
is_stub() { ! grep -qvE '^\s*(//.*)?$' "$1"; }

for f in "$HERE"/designs/*.qml; do
  n=$(basename "$f")
  out="$DEST/$n"
  tmp=$(mktemp)
  if grep -qF "$IMPORT" "$f"; then
    cat "$f" > "$tmp"
  else
    # after the last top-level import line
    awk -v imp="$IMPORT" '{ l[NR]=$0; if ($0 ~ /^import /) last=NR }
      END { for (i=1;i<=NR;i++) { print l[i]; if (i==last) print imp } }' "$f" > "$tmp"
  fi
  if [[ -e $out ]] && ! cmp -s "$tmp" "$out"; then
    if grep -qxF "$n" "$MANIFEST" 2>/dev/null || is_stub "$out"; then :
    else run cp -f "$out" "$out.bak-install"; echo "backed up existing $n"; fi
  fi
  run cp -f "$tmp" "$out"
  rm -f "$tmp"
  installed+=("$n")
done

if ((dry)); then
  echo "dry run: ${#installed[@]} files would be installed to $DEST"
  exit 0
fi
printf '%s\n' "${installed[@]}" > "$MANIFEST"
echo "installed ${#installed[@]} files to $DEST"

if ((restart)); then omarchy restart shell; else echo "run: omarchy restart shell"; fi
