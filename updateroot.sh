#!/bin/bash

set -euo pipefail

if [ $(git rev-parse --show-toplevel) != $(pwd) ]; then
    echo "run from git root" >&2
    exit 1
fi

FR24FEED_VERSION=$(curl --silent -o - https://repo-feed.flightradar24.com/CHANGELOG.md \
    | awk '/^#\[/ { print $1 }' \
    | grep -o -m 1 '[0-9\.-]\+')

sed -i -e "s/^FR24FEED_VERSION=.*/FR24FEED_VERSION=$FR24FEED_VERSION/" buildtar.sh 

./buildroot.sh
