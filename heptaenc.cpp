#include "heptafon.hpp"
using namespace heptafon;

static inline std::tuple<int8_t,uint64_t,int32_t> quantizeSample(History &hist, uint pmode, int scale, uint encbits, int32_t target) {
    int32_t predict = hist.predict(pmode);
    int32_t diff = target-predict;
    bool negdiff = hist.samples[0] < 0;
    if (negdiff) diff = -diff;
    //int8_t qdata = encbits == 0 ? 0 : std::clamp((diff+((1<<scale)>>1))/(1<<scale),(-1<<encbits)>>1,((1<<encbits)-1)>>1);
    int8_t qdata = encbits == 0 ? 0 : std::clamp((diff+((1<<scale)>>1))>>scale,(-1<<encbits)>>1,((1<<encbits)-1)>>1);
    int32_t got = negdiff ? predict - (qdata<<scale) : predict + (qdata<<scale);
    hist.push(got);
    return {qdata,compError(got,target),got};
}

static inline std::tuple<int8_t,uint64_t> quantizeSubsample(History &hist, uint pmode, int scale, uint encbits, int32_t target1, int32_t target2) {
    auto [qdata,err2,got2] = quantizeSample(hist,pmode,scale,encbits,target2);
    int32_t got1 = (hist.samples[1]+got2)>>1;
    return {qdata,err2 + compError(got1,target1)};
}

static inline uint64_t quantizeMulti(History &hist, uint pmode, uint encbits, bool subsample, int scale, const int16_t *samples, int8_t *out, uint count) {
    // Note: samples points into interleaved array
    uint64_t erracc = 0;
    if (subsample) {
        for (uint i=0;i<count;i+=2) {
            auto [qdata,err] = quantizeSubsample(hist,pmode,scale,encbits,samples[i*2],samples[(i+1)*2]);
            erracc += err;
            out[i] = qdata;
            out[i+1] = 0;
        }
    } else {
        for (uint i=0;i<count;i++) {
            auto [qdata,err,_] = quantizeSample(hist,pmode,scale,encbits,samples[i*2]);
            erracc += err;
            out[i] = qdata;
        }
    }
    return erracc;
}



void heptafon::encodeSector(PackedSector &sector, const int16_pair *buffer) {

    int16_pair xyData[SECTOR_SAMPLES],compareBuffer[SECTOR_SAMPLES];
    uint64_t best_rot_err = UINT64_MAX;
    for (uint rot=0;rot<=3;rot++) {
        //if (rot != ROTMODE_LEFT) continue; // DEBUG
        PackedSector workSector = {.rotation=uint8_t(rot)};
        // Generate XY-encoded samples
        for (uint i=0;i<SECTOR_SAMPLES;i++) xyData[i] = lr_to_xy(buffer[i],rot);
        
        History xhist,yhist;
        for (uint i=0;i<PRED_SAMPLES;i++) {
            workSector.pred_init[i] = xyData[i];
            xhist.push(xyData[i].first);
            yhist.push(xyData[i].second);
        }
        for (uint unit=0;unit<SECTOR_UNITS;unit++) {
            const int16_pair *unitbuf = xyData + (unit*UNIT_SAMPLES+PRED_SAMPLES);
            uint64_t best_enc_err = UINT64_MAX;
            History xhist_best,yhist_best;
            for (uint enc=0;enc<=3;enc++) {
                //if (enc!=ENCMODE_3BIT) continue; // DEBUG
                uint64_t best_x_err = UINT64_MAX, best_y_err = UINT64_MAX;
                uint best_xpsr = 0,best_yps = 0;
                std::array<int8_t,UNIT_SAMPLES> best_xdat = {},best_ydat = {};
                History xhist_best_inner,yhist_best_inner;

                // Find best pred/scale/ride for X (256 combos)
                for (uint xpsr=0;xpsr<256;xpsr++) {
                    uint64_t err = 0;
                    History workhist = xhist;
                    std::array<int8_t,UNIT_SAMPLES> workdat;
                    uint pred = xpsr&3;
                    //if (pred != PMODE_HOLD) continue; // DEBUG
                    int scale1 = (xpsr>>4);
                    int scale2 = scale1+((xpsr>>2)&3)-2;
                    if (scale2 < 0 || scale2 > 15) continue;
                    err += quantizeMulti(workhist,pred,encmodeXbits[enc],enc==ENCMODE_XSUB,scale1,&unitbuf->first,&workdat[0],8);
                    err += quantizeMulti(workhist,pred,encmodeXbits[enc],enc==ENCMODE_XSUB,scale2,&unitbuf->first+16,&workdat[8],8);
                    if (err < best_x_err) {
                        best_x_err = err;
                        best_xpsr = xpsr;
                        best_xdat = workdat;
                        xhist_best_inner = workhist;
                    }
                }

                // Find best pred/scale for Y (64 combos)
                for (uint yps=0;yps<64;yps++) {
                    History workhist = yhist;
                    std::array<int8_t,UNIT_SAMPLES> workdat;
                    int scale = yps>>2;
                    if (enc == ENCMODE_6BIT && scale != 0) break;
                    uint pred = yps&3;
                    //if (pred != PMODE_HOLD) continue; // DEBUG
                    uint64_t err = quantizeMulti(workhist,pred,encmodeYbits[enc],enc==ENCMODE_YSUB,scale,&unitbuf->second,&workdat[0],16);
                    if (err < best_y_err) {
                        best_y_err = err;
                        best_yps = yps;
                        best_ydat = workdat;
                        yhist_best_inner = workhist;
                    }
                }

                if (best_x_err + best_y_err < best_enc_err) {
                    best_enc_err = best_x_err + best_y_err;
                    xhist_best = xhist_best_inner;
                    yhist_best = yhist_best_inner;
                    // Pack data into sector struct
                    workSector.params[unit] = {
                        .xScale=uint16_t(best_xpsr>>4),
                        .yScale=uint16_t(best_yps>>2),
                        .xPred=uint16_t(best_xpsr&3),
                        .yPred=uint16_t(best_yps&3),
                        .encMode=uint16_t(enc),
                        .xRide=uint16_t((best_xpsr>>2)&3),
                    };
                    auto &data = workSector.data[unit];
                    data = {};
                    switch(enc) {
                    case ENCMODE_6BIT:
                        for (uint i=0;i<UNIT_SAMPLES;i++) {
                            int8_t v = best_xdat[i]&63;
                            data.slow |= uint32_t(v>>4)<<(30-i*2);
                            data.fast |= uint64_t(v&15)<<((60-i*4)^32);
                        }
                        break;
                    case ENCMODE_3BIT:
                        for (uint i=0;i<UNIT_SAMPLES;i++) {
                            int8_t vl = ((best_xdat[i]&3)<<2) + ((best_ydat[i]&3));
                            int8_t vh = ((best_xdat[i]&4)>>1) + ((best_ydat[i]&4)>>2);
                            data.slow |= uint32_t(vh)<<(30-i*2);
                            data.fast |= uint64_t(vl)<<((60-i*4)^32);
                        }
                        break;
                    case ENCMODE_YSUB:
                        for (uint i=0;i<UNIT_SAMPLES;i++) {
                            data.fast |= uint64_t(best_xdat[i]&15)<<((60-i*4)^32);
                            if (!(i&1)) data.slow |= uint32_t(best_ydat[i]&15)<<(28-i*2);
                        }
                        break;
                    case ENCMODE_XSUB:
                        for (uint i=0;i<UNIT_SAMPLES;i++) {
                            data.fast |= uint64_t(best_ydat[i]&15)<<((60-i*4)^32);
                            if (!(i&1)) data.slow |= uint32_t(best_xdat[i]&15)<<(28-i*2);
                        }
                        break;
                    default: __builtin_unreachable();
                    }
                }
            }
            xhist = xhist_best;
            yhist = yhist_best;
        }

        decodeSector(workSector,compareBuffer);
        uint64_t this_rot_err = 0;
        for (uint i=0;i<SECTOR_SAMPLES;i++) this_rot_err += compErrorLR(compareBuffer[i],buffer[i]);
        if (this_rot_err < best_rot_err) {
            best_rot_err = this_rot_err;
            sector = workSector;
            if (best_rot_err == 0) break;
        }

    }
}