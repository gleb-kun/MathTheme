#!/bin/bash

source paths.conf

package="${THEME_NAME}.tar.gz"

if [ -e "$package" ]; then
    rm "$package"
fi

tar -czvf "$package" "${THEME_FILES[@]}"
