Celeste for FakeR36S-OS -- two things you must add yourself
===========================================================

Neither can be shipped in this port: one is the game, the other is a closed-source
audio engine whose licence forbids redistribution. Both are free to obtain if you
already own Celeste.

1. THE GAME
   Get the DRM-free Linux build:
       https://maddymakesgamesinc.itch.io/celeste
   Copy the *contents* of its  game/  folder into this  gamedata/  folder, so you
   end up with  gamedata/Celeste.exe  and  gamedata/Content/.

   Do NOT copy  lib/  or  lib64/  -- those are x86 and useless here. Do NOT copy
   Celeste.bin.x86*  either; this port runs Celeste.exe on its own armhf Mono.

   If you copy from a Mac, use  cp -X  (not plain cp) or the card fills with
   AppleDouble "._" stubs that FNA opens as content and chokes on.

2. FMOD (armhf) -- version 1.10.x, NOT the current one
   Celeste does all its audio through FMOD. Download "FMOD Engine" for Linux
   (free account) from:
       https://www.fmod.com/download
   You must pick a **1.10.x** build (1.10.22 is the last one), from the Legacy
   section or the version selector. This is not a preference:

     - FMOD's soname tracks its version one-for-one: 1.10 -> libfmod.so.10,
       2.00 -> .so.11, ... 2.04 -> .so.15. Celeste dllmaps "fmod" to
       libfmod.so.10, so only 1.10 satisfies it.
     - Celeste's bindings are the 1.10 API. FMOD 2.04 is missing 25 of the 490
       entry points Celeste imports, all of them the old parameter API
       (SetParameterValue, GetParameterValue, TriggerCue, HasCue,
       FMOD_SDL_Register). Celeste would die with EntryPointNotFoundException
       as soon as audio started.
     - FMOD_System_Create checks the version constant it is handed and returns
       FMOD_ERR_HEADER_MISMATCH on a mismatch, so 2.x refuses before that.

   From the 1.10 archive, copy these two into the port's libs/ folder, which
   overwrites the silent stand-ins that ship there:
       api/lowlevel/lib/arm/libfmod.so.10
       api/studio/lib/arm/libfmodstudio.so.10
   Note "lowlevel", not "core" -- 1.10 used that name, api/core/ is 2.x only.
   And "arm", not "arm64": this board is 32-bit.

   Until you do this, the port runs SILENTLY on the bundled stand-ins. That is
   enough to find out whether the game renders and fits in memory.

SPACE
   The full game is ~1.2 GB. If the card is tight, you can delete
       Content/FMOD/Desktop/dlc_music.bank      (64 MB)
       Content/FMOD/Desktop/dlc_sfx.bank        (33 MB)
   and the game still runs -- you lose the Farewell DLC audio only.

THEN
   Open Celeste from the Ports menu. If it does not appear, reboot once so
   fr-ports-sync picks it up. If it starts and exits, read  log.txt  in the
   port folder; that is where everything goes.
