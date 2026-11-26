#!/bin/sh
# Celeste launcher for FakeR36S-OS.
#
# POSIX sh on purpose: the device has no bash and no python3, so none of the usual
# PortMaster launcher idioms (${BASH_SOURCE[0]}, arrays, mount of a squashfs runtime)
# are available here. Learned the hard way on the OMORI port.
set -u

PORT=$(cd "$(dirname "$0")" && pwd)
GAME="$PORT/gamedata"
LOG="$PORT/log.txt"

exec >"$LOG" 2>&1
echo "=== Celeste $(date) ==="

# ---- sanity: the player has to supply the game themselves ----------------
if [ ! -f "$GAME/Celeste.exe" ]; then
    echo "!! no Celeste.exe in $GAME"
    echo "   Copy the DRM-free Linux build's game/ contents into gamedata/."
    exit 1
fi
if [ ! -f "$PORT/libs/libfmod.so.10" ]; then
    echo "!! no armhf libfmod.so.10 in $PORT/libs"
    echo "   See gamedata/README-FIRST.txt -- FMOD's armhf blobs cannot be redistributed."
    exit 1
fi

# ---- reclaim RAM: 512 MB total, and Celeste wants most of it -------------
# EmulationStation holds 100-200 MB with gamelists loaded. appctl stops it cleanly
# and the OS brings it back when we exit.
if command -v appctl >/dev/null 2>&1; then
    echo "-- stopping EmulationStation to free RAM"
    appctl stop || true
fi

# Full clocks. The battery-saver profile caps at 816 MHz, which is what froze FCEUmm;
# Celeste on two Cortex-A7s has nothing to spare.
command -v cpuprofile >/dev/null 2>&1 && cpuprofile max || true

# Drop caches so the FMOD banks and texture atlases get a clean page cache.
sync; echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || true

# ---- runtime environment -------------------------------------------------
MONODIR="$PORT/mono"
export LD_LIBRARY_PATH="$PORT/libs:$MONODIR/lib:${LD_LIBRARY_PATH:-}"
export PATH="$MONODIR/bin:$PATH"
export MONO_PATH="$GAME"
export MONO_CONFIG="$GAME/monoconfig"

# Mono on a 2-core A7: the SGen nursery default (4 MB) thrashes; a smaller nursery
# with more frequent, cheaper collections keeps frame times flatter.
export MONO_GC_PARAMS="nursery-size=2m,soft-heap-limit=300m"
export MONO_THREADS_PER_CPU=1

# Renderer: FNA3D wants desktop GL 2.1. Lima can render it but the OS ships no
# libGL.so.1 (Buildroot gates that behind a full X11 stack), so the port carries
# gl4es as its own libGL and gl4es talks to the system GLES 2.0 underneath.
# Deliberately NO FNA3D_OPENGL_FORCE_ES3: Lima has no GLES 3.0 at all.
export FNA3D_OPENGL_FORCE_VBO_DISCARD=1
export FNA3D_DISABLE_LATEBINDING=1
export SDL_VIDEODRIVER=kmsdrm
export SDL_AUDIODRIVER=alsa
export SDL_VIDEO_GL_DRIVER="$PORT/libs/libGL.so.1"

# gl4es tuning for Mali-400 (Utgard):
#   ES=2/GL=21   present GL 2.1 over GLES 2.0
#   NPOT=2       Utgard's non-power-of-two support is partial; let gl4es handle it
#   NOINTOVLHACK keep it quiet and predictable rather than clever
export LIBGL_ES=2
export LIBGL_GL=21
export LIBGL_NPOT=2
export LIBGL_MIPMAP=3
export LIBGL_BATCH=10
export LIBGL_NOBANNER=1
export LIBGL_SILENTSTUB=1

# Saves live beside the port, not in a HOME that gets reflashed.
export XDG_DATA_HOME="$PORT/savedata"
mkdir -p "$PORT/savedata/Celeste"

cd "$GAME"

# ---- BCL: the runtime's own, not the game's --------------------------------
# Celeste ships a MonoKickstart bundle: its own mscorlib and System.* assemblies
# built for the Mono it was packaged with in 2021. We run Debian's Mono 6.8, and
# mixing a 6.8 runtime with an older BCL is the known-bad combination -- the
# working aarch64 port deletes those assemblies outright for the same reason.
#
# Moved aside rather than deleted, so nothing of the player's copy is destroyed and
# CELESTE_BUNDLED_BCL=1 puts it back.
BCL_ASIDE="$PORT/bcl-bundled"
if [ "${CELESTE_BUNDLED_BCL:-0}" = "1" ]; then
    if [ -d "$BCL_ASIDE" ]; then
        echo "-- restoring the game's bundled BCL on request"
        cp -a "$BCL_ASIDE/." "$GAME/" 2>/dev/null || true
    fi
else
    if [ ! -d "$BCL_ASIDE" ]; then
        echo "-- moving the game's bundled BCL aside, using Mono 6.8's own"
        mkdir -p "$BCL_ASIDE"
        for f in "$GAME"/System*.dll "$GAME"/mscorlib.dll "$GAME"/Mono.*.dll; do
            [ -e "$f" ] || continue
            mv "$f" "$BCL_ASIDE/" 2>/dev/null || true
        done
        # FNA.dll, FNA3D.dll, Celeste.exe and Celeste.Content.dll deliberately stay:
        # the native libFNA3D is pinned to the release that matches them.
    fi
fi

# macOS leaves AppleDouble stubs on FAT32 cards; FNA opens them as content and dies.
# Same breakage that made the GBA ROMs show up as ">_".
find "$GAME" -name '._*' -delete 2>/dev/null || true

MONO_BIN=$(command -v mono-sgen || command -v mono)
echo "-- mono: $MONO_BIN"
echo "-- GL: $(command -v glxinfo >/dev/null 2>&1 && glxinfo -B 2>/dev/null | head -3 || echo 'glxinfo absent')"

"$MONO_BIN" Celeste.exe "$@"
RC=$?
echo "-- Celeste exited rc=$RC"

command -v cpuprofile >/dev/null 2>&1 && cpuprofile normal || true
command -v appctl >/dev/null 2>&1 && appctl start || true
exit $RC
