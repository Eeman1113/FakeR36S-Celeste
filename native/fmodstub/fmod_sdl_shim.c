/* libfmod_SDL.so -- the one symbol FMOD itself does not provide.
 *
 * Celeste P/Invokes FMOD_SDL_Register to route FMOD's output through SDL, and
 * ships a small libfmod_SDL.so to supply it. That shim is x86 only, and FMOD's
 * own download does not contain it: a real FMOD 1.10.20 armhf build covers 489
 * of the 490 entry points Celeste imports, and this is the one left over.
 *
 * Reporting FMOD_OK without registering anything leaves FMOD on its default
 * output, which is ALSA on this device, and ALSA is what the board uses
 * anyway. Celeste gets its successful return and never learns the difference.
 */

/* FMOD_RESULT, of which only FMOD_OK = 0 matters here. */
int FMOD_SDL_Register(void *system)
{
    (void) system;
    return 0;
}
