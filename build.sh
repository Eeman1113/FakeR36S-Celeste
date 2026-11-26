#!/usr/bin/env bash
# Build the armhf native stack Celeste needs on the fake R36S
# (GA36-MB, Allwinner A23: Cortex-A7, Mali-400 via Mesa/Lima, 512 MB + 256 MB zram)
# and package it as a FakeR36S-OS port.
#
# Celeste.exe, FNA.dll and all 1.1 GB of Content/ are managed CIL or plain data:
# architecture-neutral, reused untouched. Only the native layer is ours to build.
#
# Runs inside the image from ./Dockerfile (bullseye, armhf glibc 2.31 -- the floor
# the OMORI port proved on this hardware). Usage:  ./build.sh [version]
set -euo pipefail

VERSION=${1:-0.0.1}
HERE=$(cd "$(dirname "$0")" && pwd)
WORK="$HERE/work"; OUT="$HERE/out"; LIBS="$WORK/stage/libs"

# FNA3D contemporary with Celeste 1.4.0.0 (March 2021). The managed FNA3D.dll that
# ships with the game exposes 96 entry points; a current libFNA3D.so has more and a
# different struct layout, so the native side is pinned to match rather than guessed.
FNA3D_REF=${FNA3D_REF:-21.03}
SDL2_REF=${SDL2_REF:-release-2.28.5}
GL4ES_REF=${GL4ES_REF:-master}
MONO_SUITE=${MONO_SUITE:-bookworm}

mkdir -p "$WORK" "$OUT" "$LIBS"

# ---------------------------------------------------------------- SDL2
# Built rather than borrowed: FNA drives SDL directly and the OS's own SDL2 is
# configured for RetroArch, not for us. KMSDRM only -- there is no X11 on the device.
stage_sdl2() {
    echo "==> SDL2 $SDL2_REF (armhf)"
    [ -d "$WORK/SDL" ] || git clone -q --depth 1 -b "$SDL2_REF" https://github.com/libsdl-org/SDL.git "$WORK/SDL"
    cmake -S "$WORK/SDL" -B "$WORK/b-sdl" -G Ninja \
        -DCMAKE_TOOLCHAIN_FILE="$HERE/toolchain-armhf.cmake" \
        -DCMAKE_BUILD_TYPE=Release \
        -DSDL_SHARED=ON -DSDL_STATIC=OFF \
        -DSDL_KMSDRM=ON -DSDL_OPENGL=ON -DSDL_OPENGLES=ON \
        -DSDL_X11=OFF -DSDL_WAYLAND=OFF -DSDL_VULKAN=OFF \
        -DSDL_ALSA=ON -DSDL_PULSEAUDIO=OFF
    cmake --build "$WORK/b-sdl" -j"$(nproc)"
    cp -P "$WORK/b-sdl"/libSDL2-2.0.so* "$LIBS/"
}

# ---------------------------------------------------------------- gl4es (our libGL)
# FNA3D needs desktop GL 2.1. Mesa/Lima can render it, but Buildroot only installs
# libGL.so.1 alongside a full X11 stack (BR2_PACKAGE_LIBGLVND_DISPATCH_GL depends on
# BR2_PACKAGE_XORG7) and this OS has no X11. Rather than drag Xorg into the rootfs,
# the port carries its own libGL: gl4es, which presents GL 2.1 on top of the system's
# GLES 2.0. Shipped in libs/, found via LD_LIBRARY_PATH, no OS change at all.
stage_gl4es() {
    echo "==> gl4es $GL4ES_REF (armhf) -- our libGL.so.1"
    [ -d "$WORK/gl4es" ] || git clone -q --depth 1 -b "$GL4ES_REF" https://github.com/ptitSeb/gl4es.git "$WORK/gl4es"
    cmake -S "$WORK/gl4es" -B "$WORK/b-gl4es" -G Ninja \
        -DCMAKE_TOOLCHAIN_FILE="$HERE/toolchain-armhf.cmake" \
        -DCMAKE_BUILD_TYPE=Release \
        -DNOX11=ON -DNOEGL=OFF -DGLX_STUBS=ON -DEGL_WRAPPER=OFF \
        -DGBM=ON -DSTATICLIB=OFF
    cmake --build "$WORK/b-gl4es" -j"$(nproc)"
    find "$WORK/b-gl4es" "$WORK/gl4es/lib" -name 'libGL.so*' -exec cp -P {} "$LIBS/" \; 2>/dev/null || true
    [ -e "$LIBS/libGL.so.1" ] || { echo "!! gl4es produced no libGL.so.1"; exit 1; }
}

# ---------------------------------------------------------------- FNA3D (+ MojoShader)
# No FNA3D_OPENGL_FORCE_ES3 here, unlike every aarch64 PortMaster port. Those force
# GLES 3.0 because their Mali blobs are GLES-only; Lima cannot do GLES 3.0 at all, so
# that route is closed to us. Instead FNA3D takes its native desktop GL 2.1 path and
# gl4es (stage_gl4es) answers it over the system's GLES 2.0.
stage_fna3d() {
    echo "==> FNA3D $FNA3D_REF + MojoShader (armhf)"
    [ -d "$WORK/FNA3D" ] || git clone -q --recursive --depth 1 -b "$FNA3D_REF" \
        https://github.com/FNA-XNA/FNA3D.git "$WORK/FNA3D"
    cmake -S "$WORK/FNA3D" -B "$WORK/b-fna3d" -G Ninja \
        -DCMAKE_TOOLCHAIN_FILE="$HERE/toolchain-armhf.cmake" \
        -DCMAKE_BUILD_TYPE=Release \
        -DSDL2_INCLUDE_DIRS="$WORK/SDL/include" \
        -DSDL2_LIBRARIES="$LIBS/libSDL2-2.0.so.0"
    cmake --build "$WORK/b-fna3d" -j"$(nproc)"
    cp -P "$WORK/b-fna3d"/libFNA3D.so* "$LIBS/" 2>/dev/null || true
    # Older FNA3D builds MojoShader as a separate shared object; newer ones fold it in.
    cp -P "$WORK/b-fna3d"/libmojoshader.so* "$LIBS/" 2>/dev/null || true
}

# ---------------------------------------------------------------- Mono (armhf)
# PortMaster ships only mono-6.12-aarch64 -- useless on a Cortex-A7. Debian's armhf
# mono 6.8 is built against glibc 2.31, which is the device's floor, so we unpack the
# .debs into the port instead of building a runtime from source.
stage_mono() {
    echo "==> Mono runtime (armhf, Debian $MONO_SUITE)"
    local MROOT="$WORK/stage/mono"; mkdir -p "$MROOT" "$WORK/debs"
    ( cd "$WORK/debs"
      apt-get download \
          mono-runtime:armhf mono-runtime-common mono-runtime-sgen:armhf \
          libmonosgen-2.0-1:armhf libmono-corlib4.5-cil \
        || { echo "!! apt-get download failed for armhf mono"; exit 1; }
      for d in *.deb; do dpkg-deb -x "$d" "$MROOT"; done )
    # Flatten to the layout run.sh expects: mono/bin, mono/lib.
    mkdir -p "$MROOT/bin" "$MROOT/lib"
    find "$MROOT/usr/bin" -maxdepth 1 -type f -exec cp -a {} "$MROOT/bin/" \; 2>/dev/null || true
    cp -a "$MROOT/usr/lib/arm-linux-gnueabihf/." "$MROOT/lib/" 2>/dev/null || true
    cp -a "$MROOT/usr/lib/mono" "$MROOT/lib/" 2>/dev/null || true
    rm -rf "$MROOT/usr"
    [ -x "$MROOT/bin/mono-sgen" ] || [ -x "$MROOT/bin/mono" ] \
        || { echo "!! no mono binary unpacked"; exit 1; }
}

# ---------------------------------------------------------------- package
stage_package() {
    echo "==> packaging port v$VERSION"
    local PKG="$WORK/pkg" PORT="$PKG/ports/celeste"
    rm -rf "$PKG"
    mkdir -p "$PORT/gamedata" "$PORT/libs" "$PORT/savedata" \
             "$PKG/.local/share/applications" "$PKG/.local/share/icons"

    cp -a "$LIBS/." "$PORT/libs/"
    cp -a "$WORK/stage/mono" "$PORT/mono"
    "${STRIP:-strip}" "$PORT"/libs/*.so* 2>/dev/null || true

    install -m755 "$HERE/app/run.sh" "$PORT/run.sh"
    sed "s/@VERSION@/$VERSION/" "$HERE/app/celeste.puppy" > "$PKG/.local/share/applications/celeste.puppy"
    cp "$HERE/app/icon.png" "$PKG/.local/share/icons/celeste.png" 2>/dev/null || true
    cp "$HERE/app/README-FIRST.txt" "$PORT/gamedata/README-FIRST.txt"

    ( cd "$PKG" && zip -qr "$OUT/celeste-port-$VERSION.zip" . )
    echo "    $OUT/celeste-port-$VERSION.zip"
    ( cd "$OUT" && sha256sum "celeste-port-$VERSION.zip" > "celeste-port-$VERSION.zip.sha256" )
}

case "${STAGE:-all}" in
    sdl2)    stage_sdl2 ;;
    gl4es)   stage_gl4es ;;
    fna3d)   stage_fna3d ;;
    mono)    stage_mono ;;
    package) stage_package ;;
    all)     stage_sdl2; stage_gl4es; stage_fna3d; stage_mono; stage_package ;;
    *)       echo "unknown STAGE=$STAGE"; exit 1 ;;
esac
echo "==> done"
