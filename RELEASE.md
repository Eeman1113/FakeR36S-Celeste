First armhf build of the Celeste port.

Built from scratch for 32-bit ARM: armhf Mono 6.8 (glibc 2.31), SDL2 2.28.5,
FNA3D 21.3 and MojoShader, all cross-compiled for Cortex-A7. Renders through
Mesa/Lima's desktop GL 2.1 rather than forcing GLES 3.0 the way the aarch64
PortMaster port does.

You supply the game and FMOD's armhf libraries — see `gamedata/README-FIRST.txt`.

**Not yet confirmed playable on hardware.** RAM is the open question: 512 MB plus
zram, against a game that wants closer to 1 GB and cannot use ASTC compression on
a Mali-400. Read `log.txt` after a failed launch.
