#!/bin/bash

source paths.conf

THEME_PATH="$GRUB_THEMES_DIR/$THEME_NAME"

if [[ $EUID -ne 0 ]]; then
    echo "This script requires superuser privileges (sudo)."
    exit 1
fi

if [ ! -d "$THEME_PATH" ]; then
    echo "Theme $THEME_NAME is not installed. Nothing to remove."
    exit 0
fi

rm -rf "$THEME_PATH"

if grep -q "^GRUB_THEME=" "$GRUB_CONFIG"; then
    sed -i "/^GRUB_THEME=/d" "$GRUB_CONFIG"
    echo "Removed GRUB_THEME entry from $GRUB_CONFIG."
fi

grub-mkconfig -o /boot/grub/grub.cfg

echo "GRUB configuration updated."
echo "Theme $THEME_NAME has been removed."
