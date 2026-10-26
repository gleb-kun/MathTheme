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

# Remove only active assignments. During uninstall, retain assignments to other
# themes and shell expressions we cannot safely identify without evaluating them.
filter_config() {
    MATCH_THEME="$THEME_PATH/theme.txt" awk '
    # Decode literal shell words only; never execute the GRUB configuration.
    function ours(rhs, value, quote, c, nextc, i, tail) {
        value = ""
        quote = ""
        for (i = 1; i <= length(rhs); i++) {
            c = substr(rhs, i, 1)
            if (quote == sprintf("%c", 39)) {
                if (c == quote) quote = ""
                else value = value c
            } else if (c == "\\") {
                if (i == length(rhs)) return 0
                nextc = substr(rhs, ++i, 1)
                if (quote == "\"" && nextc !~ /^[\\$`"]$/) value = value "\\"
                value = value nextc
            } else if (quote == "\"") {
                if (c == quote) quote = ""
                else if (c == "$" || c == "`") return 0
                else value = value c
            } else if (c == "\"" || c == sprintf("%c", 39)) {
                quote = c
            } else if (c ~ /^[ \t]$/) {
                tail = substr(rhs, i)
                if (tail !~ /^[ \t]*$/ && tail !~ /^[ \t]+#/) return 0
                break
            } else if (c ~ /^[$`;|&<>()]$/) {
                return 0
            } else {
                value = value c
            }
        }
        return quote == "" && value == ENVIRON["MATCH_THEME"]
    }
    {
        if ($0 ~ /^[ \t]*(export[ \t]+)?GRUB_THEME[ \t]*=/) {
            rhs = $0
            sub(/^[ \t]*(export[ \t]+)?GRUB_THEME[ \t]*=[ \t]*/, "", rhs)
            if (ours(rhs)) next
        }
        print
    }' "$GRUB_CONFIG"
}

cleanup() {
    local status=$?
    trap - EXIT
    if (( ! TRANSACTION_COMMITTED && CONFIG_CHANGED )); then
        if ! cat -- "$WORK_DIR/original" > "$GRUB_CONFIG"; then
            echo "Could not restore $GRUB_CONFIG; backup: $WORK_DIR/original" >&2
            exit "$status"
        fi
        echo "Operation failed; GRUB configuration may need regeneration after resolving the error." >&2
    fi
    rm -rf -- "$WORK_DIR" || status=1
    exit "$status"
}

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_DIR/paths.conf"
[[ -n $THEME_NAME && $THEME_NAME != . && $THEME_NAME != .. && $THEME_NAME != */* ]] || fail "Invalid theme name."
[[ $GRUB_THEMES_DIR = /* && $GRUB_THEMES_DIR != / ]] || fail "Invalid themes directory."
THEME_PATH="${GRUB_THEMES_DIR%/}/$THEME_NAME"
[[ $THEME_PATH != *$'\n'* ]] || fail "Invalid theme path."
[[ -f $GRUB_CONFIG && -r $GRUB_CONFIG && -w $GRUB_CONFIG ]] || fail "GRUB configuration must be a readable, writable file: $GRUB_CONFIG"
command -v grub-mkconfig >/dev/null || fail "grub-mkconfig is required."
[[ ! -L $THEME_PATH ]] || fail "Refusing to replace a symlink: $THEME_PATH"
[[ ! -e $THEME_PATH || -d $THEME_PATH ]] || fail "Theme path is not a directory: $THEME_PATH"
WORK_DIR=$(mktemp -d "${GRUB_CONFIG}.MathTheme.XXXXXX")
TRANSACTION_COMMITTED=0
CONFIG_CHANGED=0
trap cleanup EXIT
cp -p -- "$GRUB_CONFIG" "$WORK_DIR/original"
filter_config > "$WORK_DIR/updated"
if ! cmp -s -- "$GRUB_CONFIG" "$WORK_DIR/updated"; then
    CONFIG_CHANGED=1
    cat -- "$WORK_DIR/updated" > "$GRUB_CONFIG"
    # Keep the assets available until the new boot configuration is generated.
    grub-mkconfig -o "${GRUB_OUTPUT:-/boot/grub/grub.cfg}"
fi
if [[ -d $THEME_PATH ]]; then
    rm -rf -- "$THEME_PATH"
fi
TRANSACTION_COMMITTED=1
echo "Theme $THEME_NAME has been removed; settings for other themes were preserved."
