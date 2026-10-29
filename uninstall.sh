#!/usr/bin/env bash
# Removes what install.sh added to ~/.config/omarchy/lock-designs.
#   ./uninstall.sh [--no-restart]
set -euo pipefail

DEST="$HOME/.config/omarchy/lock-designs"
MANIFEST="$DEST/.jgarza-designs.manifest"

restart=1
for a in "$@"; do
  case "$a" in
    --no-restart) restart=0 ;;
    *) echo "usage: $0 [--no-restart]" >&2; exit 2 ;;
  esac
done

[[ -f $MANIFEST ]] || { echo "nothing to uninstall (no $MANIFEST)"; exit 0; }

while IFS= read -r n; do
  [[ -n $n && $n != /* && $n != *..* ]] || continue
  rm -f "$DEST/$n"
  if [[ -e $DEST/$n.bak-install ]]; then mv -f "$DEST/$n.bak-install" "$DEST/$n"; fi
done < "$MANIFEST"
rm -f "$MANIFEST"
rmdir "$DEST/shaders" 2>/dev/null || true
echo "removed installed designs from $DEST"

if ((restart)); then omarchy restart shell; else echo "run: omarchy restart shell"; fi
