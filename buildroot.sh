#!/bin/bash

set -euo pipefail

if [ $(git rev-parse --show-toplevel) != $(pwd) ]; then
    echo "run from git root" >&2
    exit 1
fi

mkdir _build

cleanup() {
    rm -rf _build
}

trap cleanup INT TERM EXIT

GOARCH=arm64 go build -o _build/bash cmd/bash/bash.go

docker build -t gokrazy-fr24feed-build .
docker run --rm -v $(pwd)/_build:/tmp/buildresult -u $(id -u):$(id -g) gokrazy-fr24feed-build

cp _build/extrafiles_arm64.tar _gokrazy
