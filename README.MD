Heptafon ADPCM Codec
--------------------

![](cantbelieve.png)

Yet another proof-of-concept audio codec. Now featuring an actual ASM implementation!

The goals have stayed the same as the [previous](https://github.com/Wuerfel21/habane) [two](https://github.com/Wuerfel21/raven):
- low decode complexity (suitable for old scrimbly microcontrollers)
- consume (less than) one 512 byte sector per 60Hz video frame
- reasonable quality stereo music

This new attempt is really just a refinement over [the last one](https://github.com/Wuerfel21/raven), dropping the per-unit channel matrixing (is now per-sector) in favor of other features, such as shorter units (16smp instead of 32) and 3rd order prediction. The overall bitrate used is also slightly higher (less samples per sector).
The basic concept of coding a "main" and "sub" channel remains, but they are now called X and Y. Instead of Y always being coded with less bits, there is now an encoding mode that provides 3 bits to both channels. Another interesting feature is "X scale ride", wherein two of the unused bits in the sector allow to move the scale value for the X channel at the 8th unit sample onwards, which should(tm) provide a lot of the benefits that using actual 8smp units would, but with 1/8th the overhead (or no overhead, considering these bits would otherwise go unused)

See FORMAT.MD for the format specification.

The C++ source in the root directory is for the reference decoder/encoder. The decoder part is unoptimized, but represents the living format spec. The encoder is optimized for quality rather than real-time performance.

Usage info (for the C++ reference code):
 - Use `build.sh` to build `heptafon.exe`
 - Use `heptafon encode input.raw output.hep` to encode a raw file into heptafon format
   - By default, dynamic noise shaping is enabled. Specify `-noise-shape 0` to disable it, `-noise-shape 192` (or other integer 1..255) to enable static noise shaping with a given strength or `-noise-shape -1` to explicity enable dynamic shaping
 - Use `heptafon decode input.hep output.raw` to decode again

As said, all I/O is with raw files, 16 bit, little endian, stereo. The codec is sample rate agnostic, but the intended rate is 32.0 kHz.

The Spin/PASM code in the "propeller" directory is an optimized example decoder for Parallax Propeller 1.

A not-quite-as-optimized Propeller 2 port exists in the "propeller2" directory.

Their memory footprint could be further reduced by aliasing variables and re-using the init code area, but this has not been done for readability reasons.