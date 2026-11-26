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

2. FMOD (armhf)
   Celeste does all its audio through FMOD. Download "FMOD Engine" for Linux
   (free account) from:
       https://www.fmod.com/download
   Pick version 2.00.x or 2.01.x -- Celeste expects the .so.10 ABI.
   From the archive, copy these two into the port's  libs/  folder:
       api/core/lib/arm/libfmod.so.10
       api/studio/lib/arm/libfmodstudio.so.10
   "arm" is the 32-bit hard-float build. Do not take "arm64".

SPACE
   The full game is ~1.2 GB. If the card is tight, you can delete
       Content/FMOD/Desktop/dlc_music.bank      (64 MB)
       Content/FMOD/Desktop/dlc_sfx.bank        (33 MB)
   and the game still runs -- you lose the Farewell DLC audio only.

THEN
   Open Celeste from the Ports menu. If it does not appear, reboot once so
   fr-ports-sync picks it up. If it starts and exits, read  log.txt  in the
   port folder; that is where everything goes.
