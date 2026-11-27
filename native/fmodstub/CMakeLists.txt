# Silent stand-ins for FMOD, so Celeste can be launched before a real armhf
# libfmod is in place. Celeste.exe.config dllmaps "fmod" -> libfmod.so.10 and
# "fmodstudio" -> libfmodstudio.so.10, so both the file name and the soname have
# to be exactly that -- no version symlinks.
cmake_minimum_required(VERSION 3.13)
project(fmodstub C)

function(fmod_stub target src soname)
    add_library(${target} SHARED ${src})
    set_target_properties(${target} PROPERTIES
        PREFIX ""
        OUTPUT_NAME "${soname}"
        SUFFIX ""
        LINK_FLAGS "-Wl,-soname,${soname}")
endfunction()

fmod_stub(fmod_stub       fmod_stub.c       libfmod.so.10)
fmod_stub(fmodstudio_stub fmodstudio_stub.c libfmodstudio.so.10)

# Unlike the two above, this one is needed even when the real FMOD is installed:
# FMOD_SDL_Register is Celeste's own shim, not part of FMOD, so a genuine FMOD
# armhf build does not carry it. It therefore ships inside the port.
fmod_stub(fmod_sdl_shim   fmod_sdl_shim.c   libfmod_SDL.so)
