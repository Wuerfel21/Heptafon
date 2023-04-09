Heptafon Stream Format Specification
====================================

This is the preliminary spec for the Heptafon format. The format is defined in terms of its decoder, since the encoder may employ many different approaches to optimize for speed or quality.

If in doubt, the reference source code is right and this spec is wrong.

---

A Heptafon stream consists of a series of 512 byte _Sectors_, coding 563 stereo samples each. Each Sector can be decoded independently from its predecessors, allowing for fast seeking and high data error tolerance.

To accomplish this, each Sector starts with three uncompressed samples and then consists of 35 _Units_ of 16 Samples each.

## Precautions

Unless specified otherwise, all numerical operations are performed on 32 bit two's-complement integers.

Unless specified otherwise, all multi-byte fields are stored in little-endian order.

## Sector Structure

|Offset| Size||
|-----:|----:|-|
|$000  |    8|Reserved for application-specific metadata|
|$008  |    2|1st uncompressed sample for X channel|
|$00A  |    2|1st uncompressed sample for Y channel|
|$00C  |    2|2nd uncompressed sample for X channel|
|$00E  |    2|2nd uncompressed sample for Y channel|
|$010  |    2|3rd uncompressed sample for X channel|
|$012  |    2|3rd uncompressed sample for Y channel|
|$014  |    1|Sector parameters|
|$015  |    1|Reserved, set to zero|
|$016  |   70|35 Unit parameters (2 bytes each)|
|$05C  |  420|35 Unit data blocks (12 bytes each)|

The uncompressed samples are 16 bit, signed.

## Sector parameter structure

The one byte at $014 contains parameters applying to the entire sector. Only the bottom two bits are used:

|Bits   ||
|------:|-|
|0..1   |Rotation matrixing mode|
|2..7   |Reserved, set to zero|

The _Rotation matrixing mode_ decides how the encoded "X" and "Y" channels map to the left and right output channels.

|Value|Name |Left|Right|
|----:|:---:|----|-----|
|    0|MID  |X+Y |X-Y  |
|    1|SIDE |Y+X |Y-X  |
|    2|LEFT |X   |Y    |
|    3|RIGHT|Y   |X    |

This matrixing must be applied to the unclamped 32 bit decoded samples.

## Unit parameter word

The Unit parameter words contain parameters that apply to each Unit.

|Bits   ||
|------:|-|
|0..3   |X scale|
|4..7   |Y scale|
|8..9   |X Predictor|
|10..11 |Y Predictor|
|12..13 |Bit allocation mode|
|14..15 |X scale ride|

The X and Y scale are values between 0 and 15 used to scale the encoded deltas, as explained later.

The X and Y predictor fields decide how the next sample is predicted from the previous three.

|Value|Name     |Expression|
|----:|:-------:|-|
|    0|HOLD     |p[n] = d[n-1]|
|    1|LINEAR   |p[n] = 2*d[n-1] - d[n-2]|
|    2|QUADRATIC|p[n] = 3\*( d[n-1] - d[n-2] ) + d[n-3]|
|    3|WEIGHTED |p[n] = ( 2\*d[n-1] + d[n-2] + d[n-3] ) >> 2|

The bit allocation mode field (also sometimes "encoding mode") decides how the 6 data bits available to each sample are divided between the channels.

|Value|Name|X bits       |Y bits       |
|----:|:--:|:-----------:|:-----------:|
|    0|6BIT|            6|            0|
|    1|3BIT|            3|            3|
|    2|YSUB|            4|4 (half-rate)|
|    3|XSUB|4 (half-rate)|            4|

The "X scale ride" field encodes the change to the X scale value at the 8th sample in the Unit, biased by -2

|Value|Change|
|----:|:----:|
|    0|-2    |
|    1|-1    |
|    2| 0    |
|    3|+1    |

## Data Block structure

The structure of the data blocks depends on the bit allocation mode used, but is always split into 3 32 bit words.

### 6BIT

The first word contains the high 2 bits of each sample, MSB first.
The second word contains the lower 4 bits of each sample of the first half, MSB first.
The third word contains the lower 4 bits of each sample of the second half, MSB first.

```
| Bit |31|30|29|28|27|26|25|24|23|22|21|20|19|18|17|16|15|14|13|12|11|10|09|08|07|06|05|04|03|02|01|00|
|     | H00 | H01 | H02 | H03 | H04 | H05 | H06 | H07 | H08 | H09 | H10 | H11 | H12 | H13 | H14 | H15 |
|     |    L00    |    L01    |    L02    |    L03    |    L04    |    L05    |    L06    |    L07    |
|     |    L08    |    L09    |    L10    |    L11    |    L12    |    L13    |    L14    |    L15    |
```

### 3BIT

The first word contains 16 pairs of sign bits of all samples, MSB first. In each pair, the upper bit is for the X channel.
The second word contains the lower 2 bits of each sample of the first half, MSB first, X first.
The third word contains the lower 2 bits of each sample of the second half, MSB first, X first.

```
| Bit |31|30|29|28|27|26|25|24|23|22|21|20|19|18|17|16|15|14|13|12|11|10|09|08|07|06|05|04|03|02|01|00|
|     | S00 | S01 | S02 | S03 | S04 | S05 | S06 | S07 | S08 | S09 | S10 | S11 | S12 | S13 | S14 | S15 |
|     | X00 | Y00 | X01 | Y01 | X02 | Y02 | X03 | Y03 | X04 | Y04 | X05 | Y05 | X06 | Y06 | X07 | Y07 |
|     | X08 | Y08 | X09 | Y09 | X10 | Y10 | X11 | Y11 | X12 | Y12 | X13 | Y13 | X14 | Y14 | X15 | Y15 |
```

### YSUB

The first word contains 8 half-rate samples for the Y channel, MSB first.
The second word contains the first half of samples for X, MSB first.
The second word contains the second half of samples for X, MSB first.

```
| Bit |31|30|29|28|27|26|25|24|23|22|21|20|19|18|17|16|15|14|13|12|11|10|09|08|07|06|05|04|03|02|01|00|
|     |    Y01    |    Y03    |    Y05    |    Y07    |    Y09    |    Y11    |    Y13    |    Y15    |
|     |    X00    |    X01    |    X02    |    X03    |    X04    |    X05    |    X06    |    X07    |
|     |    X08    |    X09    |    X10    |    X11    |    X12    |    X13    |    X14    |    X15    |
```

### XSUB

See above, but with the channels swapped.


## Decoding process

Both the X and Y channel are decoded independently until they are matrixed together in the final step. Each channel has it's own history buffer, containing the last three decoded samples.

### Decoding the uncompressed samples

The first three samples in a Sector are stored uncompressed and are used as follows:

 - sign-extend stored sample from 16 to 32 bits
 - push onto history buffer
 - matrix with other channel (see above)
 - clamp output to 16 bit range

### Decoding a compressed sample

This applies to all samples, except those that are stored in half-rate mode:

 - extract stored sample from data block (Y channel for 6BIT is always zero)
 - sign-extend from stored width to 32 bits
 - left-shift by current scale value
 - negate sample if last sample in history buffer is negative
 - compute predictor value and add to sample
 - push onto history buffer
 - matrix with other channel (see above)
 - clamp output to 16 bit range

Half-rate samples go through the same process, but only for odd-numbered samples. All even samples are the linear average of the previous history sample and the following odd sample.

## Notes

### Recommended sample rate

Heptafon is designed for 32000 samples per second.

At this sampling rate, each Sector contains ~17.6 milliseconds of audio, which allows for efficient buffer polling in systems timed around NTSC video fields, never requiring the reading of more than one Sector per field and always leaving at least 1 millisecond of slack per field for double buffer replenishment.



