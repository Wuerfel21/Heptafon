Heptafon ADPCM Codec
--------------------

Yet another proof-of-concept audio codec. Now featuring an actual ASM implementation!

The goals have stayed the same as the [previous](https://github.com/Wuerfel21/habane) [two](https://github.com/Wuerfel21/raven):
- low decode complexity (suitable for old scrimbly microcontrollers)
- consume (less than) one 512 byte sector per 60Hz video frame
- reasonable quality stereo music

This new attempt is really just a refinement over [the last one](https://github.com/Wuerfel21/raven), dropping the per-unit channel matrixing (is now per-sector) in favor of other features, such as shorter units (16smp instead of 32) and 3rd order prediction. The overall bitrate used is also slightly higher (less samples per sector).
The basic concept of coding a "main" and "sub" channel remians, but they are now called X and Y. Instead Y always being coded with less bits, there is now an encoding mode that provides 3 bits to both channels. Another interesting feature is "X scale ride", wherein two of the unused bits in the sector allow to move the scale value for the X channel at the 8th unit sample onwards, which should(tm) provide a lot of the benefits that using actual 8smp units would, but with 1/8th the overhead (or no overhead, considering these bits would otherwise go unused)


