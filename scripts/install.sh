#!/bin/bash
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
    echo "This script requires superuser privileges (sudo)." >&2
    exit 1
fi

fail() {
    echo "$*" >&2
    exit 1
}

# Quote a path for a POSIX shell assignment.
quote_path() {
    local escaped=${1//\'/\'\\\'\'}
    printf "'%s'" "$escaped"
}

begin_transaction() {
    WORK_DIR=$(mktemp -d "${GRUB_CONFIG}.MathTheme.XXXXXX")
    TRANSACTION_COMMITTED=0
    STAGING=""
    CONFIG_CHANGED=0
    THEME_REPLACED=0
    PREVIOUS_THEME=""
    trap cleanup EXIT
    cp -p -- "$GRUB_CONFIG" "$WORK_DIR/original"
}

cleanup() {
    local status=$?
    local recovery_failed=0
    trap - EXIT
    if (( ! TRANSACTION_COMMITTED )); then
        if (( CONFIG_CHANGED )); then
            if ! cat -- "$WORK_DIR/original" > "$GRUB_CONFIG"; then
                echo "Could not restore $GRUB_CONFIG; backup: $WORK_DIR/original" >&2
                recovery_failed=1
            fi
        fi
        if (( THEME_REPLACED )); then
            rm -rf -- "$THEME_PATH" || echo "Could not remove incomplete theme: $THEME_PATH" >&2
        fi
        if [[ -n $PREVIOUS_THEME && -d $PREVIOUS_THEME ]]; then
            if ! mv -T -- "$PREVIOUS_THEME" "$THEME_PATH"; then
                echo "Could not restore theme from $PREVIOUS_THEME" >&2
                recovery_failed=1
            fi
        fi
        echo "Operation failed; GRUB configuration may need regeneration after resolving the error." >&2
    fi
    if [[ -n $STAGING && -d $STAGING ]]; then
        rm -rf -- "$STAGING" || status=1
    fi
    if (( TRANSACTION_COMMITTED )) && [[ -n $PREVIOUS_THEME ]]; then
        rm -rf -- "$PREVIOUS_THEME" || status=1
    fi
    # A failed restoration must not destroy the only copy of the old theme.
    if [[ -n $PREVIOUS_THEME && -e $PREVIOUS_THEME ]]; then
        echo "Previous theme retained at $PREVIOUS_THEME" >&2
    elif (( ! recovery_failed )); then
        rm -rf -- "$WORK_DIR" || status=1
    fi
    exit "$status"
}

write_config() {
    CONFIG_CHANGED=1
    cat -- "$WORK_DIR/updated" > "$GRUB_CONFIG"
}

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_DIR/paths.conf"
[[ $THEME_DIR = /* ]] || THEME_DIR="$SCRIPT_DIR/$THEME_DIR"
[[ -n $THEME_NAME && $THEME_NAME != . && $THEME_NAME != .. && $THEME_NAME != */* ]] || fail "Invalid theme name."
[[ $GRUB_THEMES_DIR = /* && $GRUB_THEMES_DIR != / ]] || fail "Invalid themes directory."
THEME_PATH="${GRUB_THEMES_DIR%/}/$THEME_NAME"
[[ $THEME_PATH != *$'\n'* ]] || fail "Invalid theme path."
[[ -f $GRUB_CONFIG && -r $GRUB_CONFIG && -w $GRUB_CONFIG ]] || fail "GRUB configuration must be a readable, writable file: $GRUB_CONFIG"
command -v grub-mkconfig >/dev/null || fail "grub-mkconfig is required."
[[ ! -L $THEME_PATH ]] || fail "Refusing to replace a symlink: $THEME_PATH"
[[ ! -e $THEME_PATH || -d $THEME_PATH ]] || fail "Theme path is not a directory: $THEME_PATH"

command -v grub-install >/dev/null || fail "The GRUB boot loader is not installed."
for item in "${THEME_FILES[@]}"; do
    [[ -n $item && $item != . && $item != .. && $item != */* ]] || fail "Invalid theme file name: $item"
    [[ -e $THEME_DIR/$item ]] || fail "Required theme asset is missing: $THEME_DIR/$item"
done
[[ -f $THEME_DIR/theme.txt && -f $THEME_DIR/background.png && -d $THEME_DIR/icons ]] || fail "Theme assets are incomplete."

mkdir -p -- "$GRUB_THEMES_DIR"
begin_transaction
# Stage beside the target so replacement uses a rename on the same filesystem.
STAGING=$(mktemp -d "$GRUB_THEMES_DIR/.${THEME_NAME}.XXXXXX")
if [[ -d $THEME_PATH ]]; then
    cp -a -- "$THEME_PATH/." "$STAGING/"
fi
for item in "${THEME_FILES[@]}"; do
    rm -rf -- "$STAGING/$item"
    cp -a -- "$THEME_DIR/$item" "$STAGING/$item"
done
awk '!/^[ \t]*(export[ \t]+)?GRUB_THEME[ \t]*=/' "$GRUB_CONFIG" > "$WORK_DIR/updated"
printf 'GRUB_THEME=%s\n' "$(quote_path "$THEME_PATH/theme.txt")" >> "$WORK_DIR/updated"
if [[ -d $THEME_PATH ]]; then
    PREVIOUS_THEME="$GRUB_THEMES_DIR/.${THEME_NAME}.previous.$$.${RANDOM}"
    mv -T -- "$THEME_PATH" "$PREVIOUS_THEME"
fi
THEME_REPLACED=1
mv -T -- "$STAGING" "$THEME_PATH"
write_config
grub-mkconfig -o "${GRUB_OUTPUT:-/boot/grub/grub.cfg}"
TRANSACTION_COMMITTED=1
echo "Theme $THEME_NAME has been successfully installed!"
