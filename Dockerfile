# Cross-build environment for FakeR36S-Celeste.
#
# bookworm, not bullseye: bullseye has been archived and its pool 404s. The device
# runs Buildroot 2026.08, whose glibc is 2.44, so bookworm's 2.36 is comfortably
# below the floor -- binaries built here load there, not the other way round.
FROM debian:bookworm

ENV DEBIAN_FRONTEND=noninteractive

RUN dpkg --add-architecture armhf && apt-get update && apt-get install -y --no-install-recommends \
      crossbuild-essential-armhf \
      cmake ninja-build pkg-config git curl ca-certificates xz-utils unzip zip file \
      python3 \
      libegl-dev:armhf libgles-dev:armhf libgl-dev:armhf \
      libdrm-dev:armhf libgbm-dev:armhf \
      libasound2-dev:armhf libudev-dev:armhf \
    && rm -rf /var/lib/apt/lists/*

# Everything cross-compiles for the A23: Cortex-A7, NEON+VFPv4, hard float, matching
# the OS's own BR2_TARGET_OPTIMIZATION so we are not fighting its ABI.
ENV CC=arm-linux-gnueabihf-gcc \
    CXX=arm-linux-gnueabihf-g++ \
    AR=arm-linux-gnueabihf-ar \
    STRIP=arm-linux-gnueabihf-strip \
    PKG_CONFIG_PATH=/usr/lib/arm-linux-gnueabihf/pkgconfig \
    PKG_CONFIG_LIBDIR=/usr/lib/arm-linux-gnueabihf/pkgconfig \
    CFLAGS="-O2 -march=armv7-a -mtune=cortex-a7 -mfpu=neon-vfpv4 -mfloat-abi=hard -ftree-vectorize" \
    CXXFLAGS="-O2 -march=armv7-a -mtune=cortex-a7 -mfpu=neon-vfpv4 -mfloat-abi=hard -ftree-vectorize"

# FNA3D 21.03 predates GitHub dropping the git:// protocol in 2022, and its
# .gitmodules still points MojoShader and Vulkan-Headers at git://. Rewrite the
# protocol globally so submodule clones resolve.
RUN git config --global url."https://github.com/".insteadOf "git://github.com/" \
 && git config --global advice.detachedHead false

WORKDIR /work
