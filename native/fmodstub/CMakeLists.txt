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
