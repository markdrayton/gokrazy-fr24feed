pwd := $(shell pwd)
fr24feed := _gokrazy/extrafiles_arm64/src/fr24feed
libusb := _gokrazy/extrafiles_arm64/src/libusb
rtlsdr := _gokrazy/extrafiles_arm64/src/rtlsdr
ncurses := _gokrazy/extrafiles_arm64/src/ncurses
dump1090 := _gokrazy/extrafiles_arm64/src/dump1090

all: _gokrazy/extrafiles_arm64.tar

_gokrazy/extrafiles_arm64.tar: $(fr24feed) $(dump1090)/dump1090
	mkdir -p _gokrazy/extrafiles_arm64/usr/local/bin
	cd _gokrazy/extrafiles_arm64 && \
		mkdir -p usr/local/bin && \
		mv fr24feed dump1090 usr/local/bin && \
		tar cf ../extrafiles_arm64.tar usr
	rm -rf _gokrazy/extrafiles_arm64

_gokrazy/extrafiles_arm64:
	mkdir -p _gokrazy/extrafiles_arm64

$(fr24feed): _gokrazy/extrafiles_arm64
	curl -fsSL https://repo-feed.flightradar24.com/rpi_binaries/fr24feed_1.0.54-0_arm64.tgz | \
		tar zx --strip-components=1 -C _gokrazy/extrafiles_arm64 fr24feed_arm64/fr24feed

$(libusb)/libusb/.libs/libusb-1.0.a:
	mkdir -p $(libusb) && \
		cd $(libusb) && \
		(curl -fsSL https://github.com/libusb/libusb/releases/download/v1.0.29/libusb-1.0.29.tar.bz2 | tar jx --strip-components=1) && \
		CC=/usr/bin/aarch64-linux-gnu-gcc ./configure --host=aarch64-linux-gnu --disable-udev && \
		make

$(rtlsdr)/src/.libs/librtlsdr.a: $(libusb)/libusb/.libs/libusb-1.0.a
	mkdir -p $(rtlsdr) && \
		cd $(rtlsdr) && \
		(curl -fsSL https://github.com/osmocom/rtl-sdr/archive/refs/tags/v2.0.2.tar.gz | tar zx --strip-components=1) && \
		autoreconf -i && \
		CC=/usr/bin/aarch64-linux-gnu-gcc LDFLAGS=-L$(pwd)/$(libusb)/libusb/.libs CFLAGS=-I$(pwd)/$(libusb)/libusb ./configure --host=aarch64-linux-gnu && \
		make

$(ncurses)/lib/libncurses.a:
	mkdir -p $(ncurses) && \
		cd $(ncurses) && \
		(curl -fsSL https://invisible-mirror.net/archives/ncurses/ncurses-6.6.tar.gz | tar zx --strip-components=1) && \
		CC=/usr/bin/aarch64-linux-gnu-gcc ./configure --host=aarch64-linux-gnu --without-cxx-binding --without-progs --disable-widec && \
		make

$(dump1090)/dump1090: _gokrazy/extrafiles_arm64 $(libusb)/libusb/.libs/libusb-1.0.a $(rtlsdr)/src/.libs/librtlsdr.a $(ncurses)/lib/libncurses.a
	mkdir -p $(dump1090) && \
		cd $(dump1090) && \
		(curl -fsSL https://github.com/flightaware/dump1090/archive/refs/tags/v10.2.tar.gz | tar zx --strip-components=1) && \
			CC=/usr/bin/aarch64-linux-gnu-gcc \
			LDFLAGS="-L$(pwd)/$(libusb)/libusb/.libs -L$(pwd)/$(rtlsdr)/src/.libs -L$(pwd)/$(ncurses)/lib -static" \
			CFLAGS="-I$(pwd)/$(ncurses)/include -I$(pwd)/include/ncurses -I$(pwd)/$(rtlsdr)/include -Wno-error=unterminated-string-initialization" \
			CPUFEATURES=no \
			make RTLSDR_PREFIX=$(pwd)/$(rtlsdr)/src/.libs
	cp -prv $(dump1090)/dump1090 $(pwd)/_gokrazy/extrafiles_arm64

clean:
	rm _gokrazy/extrafiles_arm64.tar
