# Silent FMOD stand-ins

Celeste routes all audio through FMOD, which is proprietary: the real armhf
`libfmod.so.10` has to be downloaded from fmod.com behind an account, and cannot
be redistributed here.

These stubs exist so the port can be **launched without it**. That matters
because the open questions about this hardware are whether Celeste renders on a
Mali-400 through gl4es and whether it fits in 512 MB — neither of which has
anything to do with sound.

**There is no audio. That is the whole design.** For real sound, drop the genuine
`libfmod.so.10` and `libfmodstudio.so.10` into the port's `libs/` and they take
precedence; delete the stubs or just overwrite them.

## Why a stub is viable

FMOD's C API is opaque handles and error codes. Celeste never dereferences a
handle — it passes them back into FMOD. When the stub *is* FMOD, nothing
dereferences them, so returning an arbitrary non-null token is safe.

490 entry points are generated from the symbols Celeste actually imports. All
report `FMOD_OK`. Twenty write a handle to an out-parameter, because returning
success with a null handle makes Celeste's audio init give up. A few polled
state getters return a plausible terminal value — banks report LOADED, event
instances report STOPPED — so nothing waits forever on a load or a one-shot that
will never play.

## Regenerating

`symbols.txt` came from the game's own assembly:

```sh
strings -a Celeste.exe | grep -oE '^FMOD_[A-Za-z0-9_]+$' | sort -u > symbols.txt
python3 gen.py
```

## Honest status

Unproven on hardware. The arities and out-parameter positions for the twenty
handle functions come from the public FMOD signatures, but nothing here has been
run on the device yet. If Celeste dies in audio init, `log.txt` names the call.
