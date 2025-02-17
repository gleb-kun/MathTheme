#!/bin/bash

source paths.conf

THEME_LINE="GRUB_THEME=$THEME_PATH/theme.txt"

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
fi

for item in "${FILES_TO_COPY[@]}"; do
    if [ -e "$THEME_DIR/$item" ]; then
        cp -r "$THEME_DIR/$item" "$GRUB_THEMES_DIR/$THEME_NAME/"
    fi
done

if grep -q "^GRUB_THEME=" "$GRUB_CONFIG"; then
    sed -i "s|^GRUB_THEME=.*|$THEME_LINE|" "$GRUB_CONFIG"
else
    echo "$THEME_LINE" | tee -a "$GRUB_CONFIG" > /dev/null
fi

grub-mkconfig -o /boot/grub/grub.cfg
echo "Theme $THEME_NAME has been successfully installed!"
