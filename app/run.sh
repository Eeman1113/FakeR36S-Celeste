#!/bin/sh
# Celeste launcher for FakeR36S-OS.
#
# POSIX sh on purpose: the device has no bash and no python3, so none of the
# usual PortMaster launcher idioms are available here.
set -u

PORT=$(cd "$(dirname "$0")" && pwd)
GAME="$PORT/gamedata"
LOG="$PORT/log.txt"
APPCTL=/usr/local/bin/appctl

# ---- stage 1: hand off to appd ------------------------------------------
# EmulationStation holds 100-200 MB, which matters a lot on a 512 MB board, but
# this script cannot free it by itself: run.sh is started BY EmulationStation and
# so lives in the launcher cgroup that `appctl stop` kills. Calling it from here
# takes this script down mid-launch, which is exactly what happened -- the log
# ended on "Stopping appd" and Celeste never started. appctl's own header warns
# about this.
#
# The daemon is the only thing allowed to do that kill. launch-application asks
# it to stop the launcher and start us again in the application cgroup, and when
# the game exits its on_exit handler brings EmulationStation back unprompted, so
# there is nothing to restore on the way out either.
if [ "${1:-}" != --stage2 ]; then
    {
        echo "=== Celeste $(date) ==="
        if [ ! -f "$GAME/Celeste.exe" ]; then
            echo "!! no Celeste.exe in $GAME -- see gamedata/README-FIRST.txt"
            exit 1
        fi
    } > "$LOG" 2>&1
    [ -f "$GAME/Celeste.exe" ] || exit 1

    # Closing EmulationStation is worth 100-200 MB on a 512 MB board, but only appd
    # may do it: run.sh is started BY EmulationStation and lives in the launcher
    # cgroup, so calling `appctl stop` here kills this script mid-launch.
    #
    # appd is not always up, though. On this device it was not running at all, so
    # every launch-application died with "appd: daemon is not running" and nothing
    # ever spawned -- which looked exactly like Celeste crashing on startup. So the
    # daemon is used when present and skipped when not, rather than assumed.
    #
    # The redirect belongs inside the command string: appd runs the app with stdout
    # pointed at a tmpfs log under /dev/shm, which does not survive a power cut.
    if "$APPCTL" status 2>/dev/null | grep -q "appd: running"; then
        echo "-- handing off to appd so EmulationStation can be closed" >> "$LOG"
        exec "$APPCTL" launch-application "$PORT/run.sh --stage2 >>$PORT/log.txt 2>&1"
    fi

    echo "-- appd is not running; launching in place" >> "$LOG"
    echo "   EmulationStation stays up, so ~150 MB less memory is available" >> "$LOG"
    exec >> "$LOG" 2>&1
fi

# ---- stage 2: we are the application now --------------------------------
# stdout/stderr are already pointed at the card by the handoff above.
echo "-- stage 2 alive: uid=$(id -u 2>/dev/null) pwd=$(pwd) shell=${0}"
echo "-- EmulationStation is down"

# Full clocks. The battery-saver profile caps at 816 MHz, which is what froze
# FCEUmm; Celeste on two Cortex-A7s has nothing to spare.
doas /usr/local/bin/cpuprofile max 2>/dev/null || true

MONODIR="$PORT/mono"
export LD_LIBRARY_PATH="$PORT/libs:$MONODIR/lib:${LD_LIBRARY_PATH:-}"
export PATH="$MONODIR/bin:$PATH"
export MONO_PATH="$GAME"
export MONO_CFG_DIR="$MONODIR/etc"

# Mono on two A7s: the default SGen nursery thrashes, so a smaller one with
# cheaper, more frequent collections keeps frame times flatter.
export MONO_GC_PARAMS="nursery-size=2m,soft-heap-limit=300m"
export MONO_THREADS_PER_CPU=1

# Renderer: FNA3D wants desktop GL 2.1. Lima can draw it but the OS ships no
# libGL.so.1, so the port carries gl4es and that talks to the system GLES 2.0.
# Deliberately no FNA3D_OPENGL_FORCE_ES3: Lima has no GLES 3.0 at all.
export FNA3D_OPENGL_FORCE_VBO_DISCARD=1
export FNA3D_DISABLE_LATEBINDING=1
export SDL_VIDEODRIVER=kmsdrm
export SDL_AUDIODRIVER=alsa
export SDL_VIDEO_GL_DRIVER="$PORT/libs/libGL.so.1"
export LIBGL_ES=2
export LIBGL_GL=21
export LIBGL_NPOT=2
export LIBGL_MIPMAP=3
export LIBGL_BATCH=10
export LIBGL_NOBANNER=1
export LIBGL_SILENTSTUB=1

export XDG_DATA_HOME="$PORT/savedata"
mkdir -p "$PORT/savedata/Celeste"

cd "$GAME"

# macOS leaves AppleDouble stubs on FAT32 cards and FNA opens them as content.
find "$GAME" -name '._*' -delete 2>/dev/null || true

# Hand back the page cache before a 1.1 GB content load. Harmless if it fails:
# without appd, EmulationStation is still resident and we need every MB.
sync
doas sh -c 'echo 3 > /proc/sys/vm/drop_caches' 2>/dev/null || true

echo "-- memory available at launch:"
free -m 2>/dev/null | sed 's/^/   /'

MONO_BIN=$(command -v mono-sgen || command -v mono)
echo "-- mono: $MONO_BIN"
echo "-- starting Celeste; if this is the last line, it died without a word"
"$MONO_BIN" Celeste.exe "$@"
RC=$?
echo "-- Celeste exited rc=$RC"

doas /usr/local/bin/cpuprofile normal 2>/dev/null || true
# No appctl start here: appd's on_exit handler returns to the launcher by itself.
exit $RC
