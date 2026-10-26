#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$SCRIPT_DIR/paths.conf"
[[ $THEME_DIR = /* ]] || THEME_DIR="$SCRIPT_DIR/$THEME_DIR"

package="$SCRIPT_DIR/../${THEME_NAME}.tar.gz"
tar -czvf "$package" -C "$THEME_DIR" "${THEME_FILES[@]}"
