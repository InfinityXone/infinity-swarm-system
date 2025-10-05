#!/bin/bash
# ======================================================
# Infinity Swarm Dashboard Icon Installer
# ======================================================

ICON_SRC="$HOME/infinity-swarm-system/frontend/public/icons/infinity_eye.png"
ICON_DEST="$HOME/.local/share/icons/infinity_eye.png"
DESKTOP_FILE="$HOME/.local/share/applications/infinity-dashboard.desktop"

mkdir -p "$(dirname "$ICON_DEST")"
cp "$ICON_SRC" "$ICON_DEST"

if [ -f "$DESKTOP_FILE" ]; then
  # Replace or add the Icon line
  if grep -q '^Icon=' "$DESKTOP_FILE"; then
    sed -i "s|^Icon=.*|Icon=$ICON_DEST|" "$DESKTOP_FILE"
  else
    echo "Icon=$ICON_DEST" >> "$DESKTOP_FILE"
  fi
  echo "✅ Updated launcher icon → $ICON_DEST"
else
  echo "⚠️  Desktop launcher not found at $DESKTOP_FILE"
fi

# Refresh icon cache if available
if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database ~/.local/share/applications
fi

echo "✨ Done. Your dashboard icon is now installed."
