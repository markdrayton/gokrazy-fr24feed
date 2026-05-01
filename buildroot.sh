#!/bin/bash

set -euo pipefail

set -x
srcroot=$(mktemp -d)
installroot=$(mktemp -d)
buildroot=$(mktemp -d)
reporoot=$(git rev-parse --show-toplevel)
set +x

CC=/usr/bin/aarch64-linux-gnu-gcc

cleanup() {
	rm -rf $srcroot
	rm -rf $installroot
	rm -rf $buildroot
}

trap cleanup INT TERM

# install a binary that exits true at each of the given paths
install_true() {
	dests=("$@")

	mkdir $srcroot/true
	pushd $srcroot/true
	cat <<-EOF > true.c
	int main(int argc, char **argv) {
		return 0;
	}
	EOF

	$CC -static -o true true.c
	for dest in "${dests[@]}"; do
		mkdir -p $buildroot/$(dirname $dest)
		install -m 755 true $buildroot/$dest
	done
	popd
}

# install a binary that exits false at each of the given paths
install_false() {
	dests=("$@")

	mkdir $srcroot/false
	pushd $srcroot/false
	cat <<-EOF > false.c
	int main(int argc, char **argv) {
		return 1;
	}
	EOF

	$CC -static -o false false.c
	for dest in "${dests[@]}"; do
		mkdir -p $buildroot/$(dirname $dest)
		install -m 755 false $buildroot/$dest
	done
	popd
}

install_dump1090() {
	pushd $srcroot

	mkdir ncurses
	pushd ncurses
	curl -fsSL https://invisible-mirror.net/archives/ncurses/ncurses-6.6.tar.gz | tar zx --strip-components=1
	CC=$CC ./configure \
		--host=aarch64-linux-gnu \
		--without-cxx-binding \
		--without-progs \
		--disable-widec \
		--prefix=$installroot
	make && make install
	popd

	mkdir libusb
	pushd libusb
	curl -fsSL https://github.com/libusb/libusb/releases/download/v1.0.29/libusb-1.0.29.tar.bz2 | tar jx --strip-components=1
	CC=$CC ./configure \
		--host=aarch64-linux-gnu \
		--disable-udev \
		--prefix=$installroot
	make && make install
	popd

	mkdir librtlsdr
	pushd librtlsdr
	curl -fsSL https://github.com/osmocom/rtl-sdr/archive/refs/tags/v2.0.2.tar.gz | tar zx --strip-components=1
	autoreconf -i && \
	CC=$CC LDFLAGS=-L$installroot/lib CFLAGS=-I$installroot/include ./configure \
		--host=aarch64-linux-gnu \
		--prefix=$installroot
	make && make install
	popd

	mkdir dump1090
	pushd dump1090
	curl -fsSL https://github.com/flightaware/dump1090/archive/refs/tags/v10.2.tar.gz | tar zx --strip-components=1
	CC=$CC \
		LDFLAGS="-L$installroot/lib -static" \
		CFLAGS="-I$installroot/include -I$installroot/include/ncurses -Wno-error=unterminated-string-initialization" \
		CPUFEATURES=no \
		make RTLSDR_PREFIX=$installroot
	mkdir -p $buildroot/usr/local/bin
	install -m 755 dump1090 $buildroot/usr/local/bin
	popd

	popd
}

install_fr24feed() {
	pushd $srcroot
	curl -fsSL https://repo-feed.flightradar24.com/rpi_binaries/fr24feed_1.0.56-0_arm64.tgz | \
		tar zx --strip-components=1 fr24feed_arm64/fr24feed
	mkdir -p $buildroot/usr/local/bin
	install -m 755 fr24feed $buildroot/usr/local/bin
	popd
}

# install a dummy /bin/bash
install_bash() {
	GOARCH=arm64 go build -o $buildroot/bin/bash $reporoot/cmd/bash/bash.go
}

# fr24feed needs root certs inside the mount namespace
install_ssl() {
	for file in /etc/ssl/certs/ca-certificates.crt; do
		target_dir=$buildroot/$(dirname $file)
		mkdir -p $target_dir
		install -m 444 $file $target_dir
	done
}

install_true /sbin/rmmod
install_false /usr/bin/pgrep
install_dump1090
install_fr24feed
install_bash
install_ssl

pushd $buildroot
mkdir fr24feed
# root.tar is unpacked by the fr24feed binary
tar cf fr24feed/root.tar bin etc sbin usr
# put it inside extrafiles so it's built into the gokrazy image
tar cf $reporoot/_gokrazy/extrafiles_arm64.tar fr24feed/root.tar
popd
