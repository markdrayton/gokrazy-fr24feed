#!/bin/bash

set -euo pipefail

if [ ! -f /.dockerenv ]; then
    echo "this should only be run from a Docker container" >&2
    exit 1
fi

FR24FEED_VERSION=$1

if [ -z "$FR24FEED_VERSION" ]; then
    echo "usage: $(basename $0) version" >&2
    exit 1
fi

buildroot=/tmp/buildroot
mkdir -p $buildroot

installroot=/tmp/installroot
mkdir -p $installroot

cleanup() {
    rm -rf $buildroot
    rm -rf $installroot
}

trap cleanup INT TERM EXIT

install_dump1090() {
    cd $(mktemp -d $buildroot/tmp.XXXXXX)
    curl -fsSL https://github.com/flightaware/dump1090/archive/refs/tags/v10.2.tar.gz | tar zx --strip-components=1
    make CC=aarch64-linux-gnu-gcc \
        CPUFEATURES=no \
        RTLSDR=yes \
        LDFLAGS="-static -L/usr/local/arm64/lib" \
        CFLAGS="-I/usr/local/arm64/include/libusb-1.0" \
        LIBS="-lrtlsdr -lusb-1.0 -lncurses -ltinfo -lpthread -lm -lrt"
    mkdir -p $installroot/usr/local/bin
    install -m 755 dump1090 $installroot/usr/local/bin
}

install_fr24feed() {
    cd $(mktemp -d $buildroot/tmp.XXXXXX)
	curl -fsSL https://repo-feed.flightradar24.com/rpi_binaries/fr24feed_${FR24FEED_VERSION}_arm64.tgz | \
		tar zx --strip-components=1 fr24feed_arm64/fr24feed
	mkdir -p $buildroot/usr/local/bin
	install -m 755 fr24feed $installroot/usr/local/bin
}

truefalse() {
    path=$1
    retval=$2
    aarch64-linux-gnu-gcc -static -o $path -xc - <<EOF
int main(int argc, char **argv) {
    return $retval;
}
EOF
}

link() {
    src=$1
    shift
    for dest in "$@"; do
        mkdir -p $installroot/$(dirname $dest)
        install -m 755 $src $installroot/$dest
    done
}

install_true() {
    src=$(mktemp $buildroot/tmp.XXXXXX)
    truefalse $src 0
    link $src "$@"
}

install_false() {
    src=$(mktemp $buildroot/tmp.XXXXXX)
    truefalse $src 1
    link $src "$@"
}

install_bash() {
    mkdir -p $installroot/bin
	install -m 755 /tmp/buildresult/bash $installroot/bin/bash
}

# fr24feed needs root certs inside the mount namespace
install_ssl() {
	for file in /etc/ssl/certs/ca-certificates.crt; do
		dest_dir=$installroot/$(dirname $file)
		mkdir -p $dest_dir
		install -m 444 $file $dest_dir
	done
}

install_dump1090
install_fr24feed
install_true /sbin/rmmod
install_false /usr/bin/pgrep
install_bash
install_ssl

mkdir $installroot/fr24feed
cd $installroot
tar cf fr24feed/root.tar bin etc sbin usr
tar cf /tmp/buildresult/extrafiles_arm64.tar fr24feed/root.tar
