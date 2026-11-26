# Cross-build environment for FakeR36S-Celeste.
#
# bullseye on purpose: its armhf glibc is 2.31, the same floor the OMORI port
# proved on this device. Build against a newer glibc and the binaries load on
# the builder and die on the handheld.
FROM debian:bullseye

ENV DEBIAN_FRONTEND=noninteractive

RUN dpkg --add-architecture armhf && apt-get update && apt-get install -y --no-install-recommends \
      crossbuild-essential-armhf \
      cmake ninja-build pkg-config git curl ca-certificates xz-utils unzip file \
      python3 \
      mono-devel mono-mcs \
      libgl1-mesa-dev:armhf libgles2-mesa-dev:armhf libegl1-mesa-dev:armhf \
      libdrm-dev:armhf libgbm-dev:armhf \
      libasound2-dev:armhf libudev-dev:armhf \
    && rm -rf /var/lib/apt/lists/*

# Everything cross-compiles for the A23: Cortex-A7, NEON+VFPv4, hard float,
# matching the OS's own BR2_TARGET_OPTIMIZATION so we do not fight its ABI.
ENV CC=arm-linux-gnueabihf-gcc \
    CXX=arm-linux-gnueabihf-g++ \
    AR=arm-linux-gnueabihf-ar \
    STRIP=arm-linux-gnueabihf-strip \
    PKG_CONFIG_PATH=/usr/lib/arm-linux-gnueabihf/pkgconfig \
    PKG_CONFIG_LIBDIR=/usr/lib/arm-linux-gnueabihf/pkgconfig \
    CFLAGS="-O2 -march=armv7-a -mtune=cortex-a7 -mfpu=neon-vfpv4 -mfloat-abi=hard -ftree-vectorize" \
    CXXFLAGS="-O2 -march=armv7-a -mtune=cortex-a7 -mfpu=neon-vfpv4 -mfloat-abi=hard -ftree-vectorize"

WORKDIR /work
