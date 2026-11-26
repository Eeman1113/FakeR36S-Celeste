# Installing

## 1. Get the port

Download `celeste-port-<version>.zip` from
[Releases](https://github.com/Eeman1113/FakeR36S-Celeste/releases), or build it
yourself (below).

## 2. Unzip it over HOME

The zip is already laid out the way `fr-ports-sync` expects, so it extracts at the
root of the card's `HOME` partition:

```
ports/celeste/                              the port
.local/share/applications/celeste.puppy     the Ports menu entry
.local/share/icons/celeste.png              its icon
```

With the card in a Mac:

```sh
cd /Volumes/HOME
unzip -o ~/Downloads/celeste-port-0.0.1.zip
```

## 3. Add the game and FMOD

Follow `ports/celeste/gamedata/README-FIRST.txt`. You need the DRM-free Linux
build's `game/` contents in `gamedata/`, and FMOD's two armhf `.so` files in
`libs/`.

## 4. Launch

Ports → Celeste. Reboot once first if it does not show up.

Everything the run produces goes to `ports/celeste/log.txt`; read that before
reporting anything.

## Building it yourself

Needs Docker only; the image brings its own armhf cross toolchain.

```sh
docker build -t fr36s-celeste .
docker run --rm -v "$PWD:/work" -w /work fr36s-celeste ./build.sh 0.0.1
```

Output lands in `out/`. Individual stages, for when one of them breaks:

```sh
docker run --rm -v "$PWD:/work" -w /work -e STAGE=sdl2  fr36s-celeste ./build.sh
docker run --rm -v "$PWD:/work" -w /work -e STAGE=fna3d fr36s-celeste ./build.sh
docker run --rm -v "$PWD:/work" -w /work -e STAGE=mono  fr36s-celeste ./build.sh
```

### If it starts and dies

`log.txt` first. Two knobs cover the likely causes:

- **Assembly or entry-point errors.** The port moves the game's bundled `mscorlib`
  and `System.*` into `bcl-bundled/` on first run and uses Mono 6.8's own BCL
  instead, which is what the working aarch64 port does. To go back to the game's
  own set: `CELESTE_BUNDLED_BCL=1`.
- **A missing native entry point.** `FNA3D_REF` pins the native FNA3D to the release contemporary with Celeste 1.4.0.0,
because the game's bundled managed `FNA3D.dll` exposes 96 entry points and a current
`libFNA3D.so` does not match it. If the game starts and immediately dies with a
missing-entry-point error, that pin is the first thing to move.
