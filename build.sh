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

SDL_PREFIX="$WORK/sdl2-prefix"
mkdir -p "$WORK" "$OUT" "$LIBS" "$SDL_PREFIX"

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
        -DSDL_ALSA=ON -DSDL_PULSEAUDIO=OFF \
        -DCMAKE_INSTALL_PREFIX="$SDL_PREFIX"
    cmake --build "$WORK/b-sdl" -j"$(nproc)"
    # Installed rather than copied out of the build tree: SDL_config.h and
    # SDL_revision.h are generated, so FNA3D needs a proper prefix to include from.
    cmake --install "$WORK/b-sdl" >/dev/null
    cp -P "$SDL_PREFIX"/lib/libSDL2-2.0.so* "$LIBS/"
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
    if [ ! -d "$WORK/FNA3D" ]; then
        git clone -q --depth 1 -b "$FNA3D_REF" https://github.com/FNA-XNA/FNA3D.git "$WORK/FNA3D"
        # Submodules are fetched separately, after rewriting git:// in the checked-in
        # .gitmodules. The image sets a global insteadOf too; this covers a local run
        # where that is not configured.
        sed -i 's|git://github.com/|https://github.com/|g' "$WORK/FNA3D/.gitmodules"
        git -C "$WORK/FNA3D" submodule sync --recursive
        git -C "$WORK/FNA3D" submodule update --init --recursive --depth 1
    fi
    [ -f "$WORK/FNA3D/MojoShader/mojoshader.c" ] \
        || { echo "!! MojoShader submodule missing"; exit 1; }
    cmake -S "$WORK/FNA3D" -B "$WORK/b-fna3d" -G Ninja \
        -DCMAKE_TOOLCHAIN_FILE="$HERE/toolchain-armhf.cmake" \
        -DCMAKE_BUILD_TYPE=Release \
        -DSDL2_INCLUDE_DIRS="$SDL_PREFIX/include/SDL2" \
        -DSDL2_LIBRARIES="$SDL_PREFIX/lib/libSDL2.so"
    cmake --build "$WORK/b-fna3d" -j"$(nproc)"
    cp -P "$WORK/b-fna3d"/libFNA3D.so* "$LIBS/"
    [ -e "$LIBS/libFNA3D.so.0" ] || { echo "!! no libFNA3D.so.0 produced"; exit 1; }
    # MojoShader is a static target in FNA3D 21.03 and ends up inside libFNA3D,
    # so unlike the game's x86 lib/ there is no libmojoshader.so to ship.
}

# ---------------------------------------------------------------- Mono (armhf)
# PortMaster ships only mono-6.12-aarch64 -- useless on a Cortex-A7. Debian's armhf
# mono 6.8 is built against glibc 2.31, which is the device's floor, so we unpack the
# .debs into the port instead of building a runtime from source.
stage_mono() {
    echo "==> Mono runtime (armhf, Debian $MONO_SUITE)"
    local MROOT="$WORK/stage/mono"; mkdir -p "$MROOT" "$WORK/debs"
    # The image clears /var/lib/apt/lists to stay small, so re-fetch the index here
    # or apt-get download has nothing to resolve against.
    apt-get update -qq
    ( cd "$WORK/debs"
      apt-get download \
          mono-runtime:armhf mono-runtime-common:armhf mono-runtime-sgen:armhf \
          libmonosgen-2.0-1:armhf libmono-corlib4.5-dll \
          libmono-system4.0-cil libmono-system-core4.0-cil \
          libmono-system-xml4.0-cil libmono-system-xml-linq4.0-cil \
          libmono-system-configuration4.0-cil libmono-system-security4.0-cil \
          libmono-system-drawing4.0-cil libmono-system-numerics4.0-cil \
          libmono-system-data4.0-cil libmono-system-runtime-serialization4.0-cil \
          libmono-posix4.0-cil libmono-security4.0-cil \
        || { echo "!! apt-get download failed for armhf mono"; exit 1; }
      for d in *.deb; do dpkg-deb -x "$d" "$MROOT"; done )
    # Flatten to the layout run.sh expects: mono/bin, mono/lib.
    mkdir -p "$MROOT/bin" "$MROOT/lib"
    find "$MROOT/usr/bin" -maxdepth 1 -type f -exec cp -a {} "$MROOT/bin/" \; 2>/dev/null || true
    cp -a "$MROOT/usr/lib/arm-linux-gnueabihf/." "$MROOT/lib/" 2>/dev/null || true
    # libmonosgen-2.0.so.1 installs to plain /usr/lib, not the multiarch triplet
    # directory, so the copy above walks straight past the runtime itself.
    find "$MROOT/usr/lib" -maxdepth 1 -name '*.so*' -exec cp -a {} "$MROOT/lib/" \; 2>/dev/null || true
    cp -a "$MROOT/usr/lib/mono" "$MROOT/lib/" 2>/dev/null || true
    # etc/mono comes out of the debs where run.sh wants it (MONO_CFG_DIR) and only
    # usr/ gets flattened away, so the config tree needs nothing doing to it --
    # just checking, below, that it is actually there.
    rm -rf "$MROOT/usr"
    # Belt and braces: mono-runtime-common carries helper binaries and an arch slip
    # in the deb list silently drops an amd64 ELF into the port. Anything that is not
    # 32-bit ARM goes, since nothing here can execute it anyway.
    find "$MROOT" -type f | while read -r f; do
        case $(file -b "$f") in
            *ELF\ 32-bit*ARM*) ;;
            *ELF*) echo "    dropping non-ARM binary: ${f#$MROOT/}"; rm -f "$f" ;;
        esac
    done

    # Assert the three pieces without which the runtime cannot start, rather than
    # shipping a port that fails on the device for a reason we could have caught here.
    [ -x "$MROOT/bin/mono-sgen" ] || [ -x "$MROOT/bin/mono" ] \
        || { echo "!! no mono binary unpacked"; exit 1; }
    ls "$MROOT"/lib/libmonosgen-2.0.so* >/dev/null 2>&1 \
        || { echo "!! libmonosgen-2.0.so missing -- mono-sgen will not link"; exit 1; }
    [ -f "$MROOT/lib/mono/4.5/mscorlib.dll" ] \
        || { echo "!! mscorlib.dll missing -- the runtime cannot start"; exit 1; }
    [ -f "$MROOT/etc/mono/config" ] \
        || echo "   (warning: no etc/mono/config -- system dllmaps will be absent)"
    echo "    mono ok: $(ls "$MROOT"/lib/libmonosgen-2.0.so* | head -1 | xargs basename), mscorlib present"
}

# ---------------------------------------------------------------- FMOD stand-ins
# Packaged separately, never inside the port: these produce no sound, and the real
# armhf libfmod must be able to overwrite them without ceremony. They exist so the
# port can be launched before an FMOD account is involved, which is what lets us
# find out whether Celeste renders on Mali-400 and fits in 512 MB.
stage_fmodstub() {
    echo "==> silent FMOD stand-ins (armhf)"
    cmake -S "$HERE/native/fmodstub" -B "$WORK/b-fmodstub" -G Ninja \
        -DCMAKE_TOOLCHAIN_FILE="$HERE/toolchain-armhf.cmake" \
        -DCMAKE_BUILD_TYPE=Release
    cmake --build "$WORK/b-fmodstub" -j"$(nproc)"
    local SD="$WORK/stub/ports/celeste/libs"
    rm -rf "$WORK/stub"; mkdir -p "$SD"
    cp "$WORK/b-fmodstub/libfmod.so.10" "$WORK/b-fmodstub/libfmodstudio.so.10" "$SD/"
    "${STRIP:-strip}" "$SD"/*.so.10 2>/dev/null || true
    for so in libfmod.so.10 libfmodstudio.so.10; do
        file "$SD/$so" | grep -q "ELF 32-bit.*ARM" \
            || { echo "!! $so is not 32-bit ARM"; exit 1; }
    done
    cp "$HERE/native/fmodstub/README.md" "$WORK/stub/ports/celeste/libs/FMOD-STUB-README.md"
    ( cd "$WORK/stub" && zip -qr "$OUT/celeste-fmod-stub-$VERSION.zip" . )
    ( cd "$OUT" && sha256sum "celeste-fmod-stub-$VERSION.zip" > "celeste-fmod-stub-$VERSION.zip.sha256" )
    echo "    $OUT/celeste-fmod-stub-$VERSION.zip  (SILENT -- no audio by design)"
}

# ---------------------------------------------------------------- package
stage_package() {
    echo "==> packaging port v$VERSION"
    # Split deliberately: in a single `local a=.. b=$a` bash does not yet see a,
    # and with set -u that is an unbound-variable abort rather than an empty path.
    local PKG="$WORK/pkg"
    local PORT="$PKG/ports/celeste"
    rm -rf "$PKG"
    mkdir -p "$PORT/gamedata" "$PORT/libs" "$PORT/savedata" \
             "$PKG/.local/share/applications" "$PKG/.local/share/icons"

    cp -a "$LIBS/." "$PORT/libs/"
    # Celeste's own FMOD-to-SDL shim. Not part of FMOD, so even a real armhf
    # libfmod lacks FMOD_SDL_Register and Celeste would throw on the P/Invoke.
    cmake -S "$HERE/native/fmodstub" -B "$WORK/b-fmodsdl" -G Ninja \
        -DCMAKE_TOOLCHAIN_FILE="$HERE/toolchain-armhf.cmake" -DCMAKE_BUILD_TYPE=Release >/dev/null
    cmake --build "$WORK/b-fmodsdl" --target fmod_sdl_shim -j"$(nproc)" >/dev/null
    cp "$WORK/b-fmodsdl/libfmod_SDL.so" "$PORT/libs/"
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
    fmodstub) stage_fmodstub ;;
    package) stage_package ;;
    all)     stage_sdl2; stage_gl4es; stage_fna3d; stage_mono; stage_package; stage_fmodstub ;;
    *)       echo "unknown STAGE=$STAGE"; exit 1 ;;
esac
echo "==> done"
