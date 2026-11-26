# FakeR36S-Celeste

Celeste on the fake R36S (GA36-MB, Allwinner A23), packaged as a port for
[FakeR36S-OS](https://github.com/Eeman1113/FakeR36S-OS).

This is a from-scratch armhf port. The existing PortMaster Celeste is **aarch64 only**
and depends on two things this hardware does not have, so none of it carries over:

| PortMaster's Celeste needs | This device has | What we do instead |
|---|---|---|
| `mono-6.12.0.122-aarch64` | Cortex-A7, ARMv7, 32-bit only | armhf Mono 6.8 (Debian bullseye, glibc 2.31) |
| `FNA3D_OPENGL_FORCE_ES3=1` | Mali-400, GLES 2.0 only | Mesa/Lima's **desktop GL 2.1**, FNA3D's native path |
| ASTC 4x4 texture compression | Mali-400 has no ASTC | nothing yet — see *Known risks* |

## What actually had to be built

Celeste splits cleanly, and the big half needs no work at all:

**Architecture-neutral, reused untouched (~1.11 GB of 1.2 GB)** — `Celeste.exe`,
`FNA.dll`, `FNA3D.dll`, the bundled Mono BCL, and all of `Content/`. These are
managed CIL and plain data. The game logic already runs on ARM.

**Built here for armhf** — `libSDL2`, `libFNA3D`, `libmojoshader`, plus an armhf
Mono runtime unpacked from Debian. `libfmod`/`libfmodstudio` come from FMOD's own
official armhf build, which the player downloads (the licence forbids shipping it).

`Celeste.bin.x86` is dropped entirely: it is only MonoKickstart, and we invoke
`mono Celeste.exe` directly.

## Why glibc 2.31

The OS is Buildroot and its defconfig names no libc, but the OMORI port runs here
built against `arm-linux-gnueabihf.2.31` — so the device has glibc 2.31 or newer.
The build pins Debian **bullseye** (armhf glibc 2.31) for exactly that reason;
bookworm's 2.36 would load on the builder and fail on the handheld.

## Install

See [INSTALL.md](INSTALL.md). Short version: unzip the release over `HOME`, then
put the game and FMOD's armhf libs in place as `gamedata/README-FIRST.txt` describes.

## Known risks

Honest status: **this is not yet confirmed playable.** The build is sound; the
hardware budget is the open question.

- **RAM.** 512 MB plus 256 MB of zstd zram. Celeste's working set is ~700 MB–1 GB,
  and PortMaster treats 1 GB as the floor. Without ASTC we also lose the texture
  compression that makes it fit elsewhere. `run.sh` stops EmulationStation to claw
  back 100–200 MB. This is the likeliest failure.
- **CPU.** Two Cortex-A7 at ~1.2 GHz, against PortMaster's RK3326 baseline of four
  Cortex-A35 at 1.5 GHz. Expect well under 60 fps, which matters for a precision
  platformer on a fixed timestep.
- **Lima's GL 2.1.** Real desktop GL, but a young driver on Utgard hardware. The
  MojoShader-generated GLSL is the part most likely to surprise us.

If RAM is the wall, the next move is an ETC1 + separate-alpha repacker — the
Mali-400-compatible stand-in for ASTC. That is a real project, not a flag.

## Credits

- [FNA](https://github.com/FNA-XNA/FNA) / [FNA3D](https://github.com/FNA-XNA/FNA3D) — Ethan Lee
- [JohnnyonFlame](https://github.com/JohnnyonFlame) — the aarch64 PortMaster Celeste
  this work learned its shape from
- Celeste is by [Maddy Makes Games](https://www.celestegame.com/). Buy it.
