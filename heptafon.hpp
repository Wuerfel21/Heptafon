#pragma once
#include <cstdint>
#include <utility>
#include <algorithm>

namespace heptafon {

typedef std::pair<int16_t,int16_t> int16_pair;
typedef std::pair<int32_t,int32_t> int32_pair;

typedef unsigned uint;

template<typename A,typename B>
inline constexpr std::pair<B,A> swap_pair(std::pair<A,B> pair) {
    return {pair.second,pair.first};
}

enum {
    PRED_SAMPLES = 3,
    SECTOR_UNITS = 35,
    UNIT_SAMPLES = 16,
    SECTOR_SAMPLES = SECTOR_UNITS*UNIT_SAMPLES+PRED_SAMPLES,
};

enum {
    ROTMODE_MID,ROTMODE_SIDE,ROTMODE_LEFT,ROTMODE_RIGHT
};
enum {
    ENCMODE_6BIT,ENCMODE_3BIT,ENCMODE_YSUB,ENCMODE_XSUB
};
enum {
    PMODE_HOLD,PMODE_LINEAR,PMODE_QUADRATIC,PMODE_WEIGHTED
};

struct __attribute__((packed))
ParamWord {
    uint16_t xScale:4;
    uint16_t yScale:4;
    uint16_t xPred:2;
    uint16_t yPred:2;
    uint16_t encMode:2;
    uint16_t xRide:2;
};
static_assert(sizeof(ParamWord) == 2);

struct __attribute__((packed))
UnitData {
    uint32_t slow;
    union {
        uint64_t fast;
        struct{
            uint32_t fast1;
            uint32_t fast2;
        };
    };
};
static_assert(sizeof(UnitData) == 12);

struct
PackedSector {
    int32_t branch_offset; // nyi
    uint32_t branch_condition; // nyi
    int16_pair pred_init[3];
    uint8_t rotation:2;
    uint8_t __unusedPar:6;
    uint8_t __unused1;
    ParamWord params[SECTOR_UNITS];
    UnitData data[SECTOR_UNITS];
};
static_assert(sizeof(PackedSector) == 512);


struct History {
    int32_t samples[PRED_SAMPLES];
    inline void push(int32_t v) {
        for (int i=PRED_SAMPLES-1;i>=1;i--) samples[i] = samples[i-1];
        samples[0] = v;
    }
    inline const int32_t predict(uint pmode) {
        switch (pmode) {
        case PMODE_HOLD:      return samples[0];
        case PMODE_LINEAR:    return 2*samples[0] - samples[1];
        case PMODE_QUADRATIC: return 3*(samples[0] - samples[1]) + samples[2];
        case PMODE_WEIGHTED:  return (2*samples[0] + samples[1] + samples[2]) >> 2;
        default: __builtin_unreachable();
        }
    }
    inline const int32_t integrate(int32_t v,uint pmode) {
        auto pred = predict(pmode);
        return (samples[0] < 0) ? pred-v : pred+v; // Maybe use pred<0 as condition instead?
    }
    inline int32_t integrate_push(int32_t v,uint pmode) {
        auto i = integrate(v,pmode);
        push(i);
        return i;
    }
};


// decode functions (heptadec.cpp)
void decodeSector(const PackedSector &sector, int16_pair *buffer);

// encode functions (heptaenc.cpp)
void encodeSector(PackedSector &sector, const int16_pair *buffer);

// inline functions

inline constexpr int32_t signx(int32_t v, int bits) {
    int shift = (32-bits)&31;
    return (v<<shift)>>shift;
}

inline constexpr int32_pair expand_input(int16_pair in) {
    return {in.first, in.second};
}
inline constexpr int16_pair clamp_output(int32_pair out) {
    return {
        std::clamp(out.first,INT16_MIN,INT16_MAX),
        std::clamp(out.second,INT16_MIN,INT16_MAX)
    };
}

template <typename T>
inline constexpr std::pair<T,T> lr_to_ms(std::pair<T,T> lr) {
    auto [l,r] = lr;
    return {(l+r)/2,(l-r)/2};
}

template <typename T>
inline constexpr std::pair<T,T> ms_to_lr(std::pair<T,T> ms) {
    auto [m,s] = ms;
    return {m+s,m-s};
}

// Not a template, because 16bit could overflow. Use separate clamp function.
inline constexpr int32_pair xy_to_lr(int32_pair xy,uint rmode) {
    switch (rmode) {
    case ROTMODE_MID:   return ms_to_lr(xy);
    case ROTMODE_SIDE:  return ms_to_lr(swap_pair(xy));
    case ROTMODE_LEFT:  return xy;
    case ROTMODE_RIGHT: return swap_pair(xy);
    default: __builtin_unreachable();
    }
}

template <typename T>
inline constexpr std::pair<T,T> lr_to_xy(std::pair<T,T> lr,uint rmode) {
    switch (rmode) {
    case ROTMODE_MID:   return lr_to_ms(lr);
    case ROTMODE_SIDE:  return swap_pair(lr_to_ms(lr));
    case ROTMODE_LEFT:  return lr;
    case ROTMODE_RIGHT: return swap_pair(lr);
    default: __builtin_unreachable();
    }
}


inline uint64_t compError(int32_t value, int32_t expect) {
    int64_t err = value-expect;
    return err*err;
}

inline uint64_t compErrorLR(int16_pair value, int16_pair expect) {
    return compError(value.first,expect.first) + compError(value.second,expect.second);
}

constexpr uint encmodeXbits[4] = {
    [ENCMODE_6BIT] = 6,
    [ENCMODE_3BIT] = 3,
    [ENCMODE_YSUB] = 4,
    [ENCMODE_XSUB] = 4,
};

constexpr uint encmodeYbits[4] = {
    [ENCMODE_6BIT] = 0,
    [ENCMODE_3BIT] = 3,
    [ENCMODE_YSUB] = 4,
    [ENCMODE_XSUB] = 4,
};


// Statistics stuff (hepstats.cpp)
class Statistics {
    uint rots[4];
    uint enc_by_rot[4][4];
    uint xpred_by_enc[4][4];
    uint ypred_by_enc[4][4];
    uint xride_by_enc[4][4];
    uint xscale_lsb[24];
    uint yscale_lsb[24];
    uint xscale_msb[24];
    uint yscale_msb[24];
    uint seccnt;
public:
    void accumulateStats(const PackedSector &sector);
    void printStats();
};


}
