#!/bin/bash

package="MathTheme.tar.gz"

if [ -e "$package" ]; then
    rm $package
fi

tar -czvf "$package" --exclude="$package" --exclude=make_pkg.sh *
