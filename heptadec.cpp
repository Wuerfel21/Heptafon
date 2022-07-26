#include "heptafon.hpp"
using namespace heptafon;

static inline int32_pair
decodeSubsampled(UnitData data,History &fastHist,History &slowHist,uint fastScale,uint slowScale,uint fastPred,uint slowPred,uint smp) {
    int fdata = signx(data.fast>>(smp*4),4);
    int32_t fnew = fastHist.integrate_push(fdata<<fastScale,fastPred);
    int sdata = signx(data.slow>>((smp>>1)*4),4);
    int32_t snew = slowHist.integrate(sdata<<slowScale,slowPred);
    if (smp&1) slowHist.push(snew);
    else snew = (snew+slowHist.samples[0])>>1;
    return {fnew,snew};
}

static inline int get6bit(UnitData data,uint smp) {
    // Todo: faster-to-decode storage (rotates and XOR)
    return (((data.slow>>(smp*2))&3)<<4) + ((data.fast>>(smp*4))&15);
}

void heptafon::decodeSector(const PackedSector &sector, int16_pair *buffer) {    
    History xhist,yhist;
    for (uint i=0;i<PRED_SAMPLES;i++) {
        auto s = sector.pred_init[i];
        xhist.push(s.first);
        yhist.push(s.second);
        *buffer++ = clamp_output(xy_to_lr(expand_input(s),sector.rotation));
    }
    for (uint unit=0;unit<SECTOR_UNITS;unit++) {
        auto param = sector.params[unit];
        auto data = sector.data[unit];
        uint xscale = param.xScale;
        uint yscale = param.yScale;
        for (uint smp=0;smp<UNIT_SAMPLES;smp++) {
            if (smp==8) {
                xscale -= 2;
                xscale += param.xRide;
            }
            switch (param.encMode) {
            case ENCMODE_3BIT: {
                int sdata = get6bit(data,smp);
                int32_t xnew = xhist.integrate_push(signx(sdata&7,3)<<xscale,param.xPred);
                int32_t ynew = yhist.integrate_push(signx(sdata>>3,3)<<yscale,param.yPred);
                *buffer++ = clamp_output(xy_to_lr({xnew,ynew},sector.rotation));
            } break;
            case ENCMODE_6BIT: {
                int32_t xnew = xhist.integrate_push(signx(get6bit(data,smp),6)<<xscale,param.xPred);
                int32_t ynew = yhist.integrate_push(0,param.yPred);
                *buffer++ = clamp_output(xy_to_lr({xnew,ynew},sector.rotation));
            } break;
            case ENCMODE_YSUB:
                *buffer++ = clamp_output(xy_to_lr(          decodeSubsampled(data,xhist,yhist,xscale,yscale,param.xPred,param.yPred,smp),sector.rotation));
                break;
            case ENCMODE_XSUB:
                *buffer++ = clamp_output(xy_to_lr(swap_pair(decodeSubsampled(data,yhist,xhist,yscale,xscale,param.yPred,param.xPred,smp)),sector.rotation));
                break;
            default: __builtin_unreachable();
            }
        }
    }


}