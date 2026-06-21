FROM debian:bookworm

RUN sed -i -e 's/deb.debian.org/debian.ethz.ch/' /etc/apt/sources.list.d/debian.sources

RUN dpkg --add-architecture arm64 \
    && apt-get update \
    && apt-get install -y \
        crossbuild-essential-arm64 \
        curl \
        libncurses-dev:arm64 \
        librtlsdr-dev:arm64 \
        pkg-config \
        build-essential \
        golang

RUN cd $(mktemp -d) \
    && curl -fsSL https://github.com/libusb/libusb/releases/download/v1.0.27/libusb-1.0.27.tar.bz2 | tar xj --strip-components=1 \
    && ./configure --host=aarch64-linux-gnu --disable-udev --enable-static --disable-shared --prefix=/usr/local/arm64 \
    && make -j$(nproc) \
    && make install

COPY buildtar.sh /usr/local/bin/buildtar.sh

WORKDIR /tmp

ENTRYPOINT ["/usr/local/bin/buildtar.sh"]