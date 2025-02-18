#!/bin/bash

source paths.conf

THEME_LINE="GRUB_THEME=$GRUB_THEMES_DIR/$THEME_NAME/theme.txt"

if [[ $EUID -ne 0 ]]; then
    echo "This script requires superuser privileges (sudo)."
    exit 1
fi

if ! command -v grub-install &> /dev/null; then
    echo "The GRUB boot loader is not installed. The theme cannot be installed further."
    exit 1
fi

if [ ! -d "$GRUB_THEMES_DIR" ]; then
    mkdir -p "$GRUB_THEMES_DIR"
fi

if [ -d "$GRUB_THEMES_DIR/$THEME_NAME" ]; then
    echo "Theme $THEME_NAME is already installed. No changes made."
    exit 0
else
    mkdir -p "$GRUB_THEMES_DIR/$THEME_NAME"
fi

for item in "${THEME_FILES[@]}"; do
    if [ -e "$THEME_DIR/$item" ]; then
        cp -r "$THEME_DIR/$item" "$GRUB_THEMES_DIR/$THEME_NAME/$item"
    fi
done

sed -i '/^[^#]*GRUB_THEME/d' "$GRUB_CONFIG"
if grep -q "^#GRUB_THEME" "$GRUB_CONFIG"; then
    sed -i "/^#GRUB_THEME=/a $THEME_LINE" "$GRUB_CONFIG"
else
    echo "$THEME_LINE" >> "$GRUB_CONFIG"
fi

grub-mkconfig -o /boot/grub/grub.cfg
echo "Theme $THEME_NAME has been successfully installed!"
