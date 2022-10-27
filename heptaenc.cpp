#include "heptafon.hpp"
using namespace heptafon;

static constexpr uint8_t scaleTryOrder[16] = {0,7,8,6,9,5,10,4,11,3,12,2,13,1,14,15};

// Extended history class with noise-shaping functions
struct EncHistory : public History {
    int32_t error;

    inline int32_t noiseshape_step(int16_t decorr_weight,int32_t sample) {
        // Also borrowed from adpcm-xq
        error += samples[0]; // Compute actual error value from previous sample
        int32_t shaping_weight = decorr_weight < 512 ? 1024 : 1536 - decorr_weight;
        int32_t shape_value = -((shaping_weight * error)>>10);

        if (shaping_weight < 0 && shape_value) {
            if (shape_value == error) shape_value += (shape_value<0 ? +1 : -1); // ???
            error = -sample;
        } else {
            error = -(sample+shape_value);
        }
        return sample+shape_value;
    };
};

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

static inline uint64_t quantizePair(EncHistory &hist, const EncoderSettings &settings, uint pmode, uint encbits, bool subsample, int scale, const int16_t *samples, int8_t *out) {
    // Note: samples points into array
    if (subsample) {
        int32_t noise_shape = -(samples[-1] - hist.samples[0])*settings.ns_strength/256*settings.ns_strength/256;
        auto [qdata,err] = quantizeSubsample(hist,pmode,scale,encbits,samples[0]+noise_shape,samples[1]+noise_shape);
        out[0] = qdata;
        out[1] = 0;
        return err;
    } else {
        uint64_t erracc = 0;
        {
            int32_t noise_shape = -(samples[-1] - hist.samples[0])*settings.ns_strength/256;
            auto [qdata,err,_] = quantizeSample(hist,pmode,scale,encbits,samples[0]+noise_shape);
            erracc += err;
            out[0] = qdata;
        }
        {
            int32_t noise_shape = -(samples[0] - hist.samples[0])*settings.ns_strength/256;
            auto [qdata,err,_] = quantizeSample(hist,pmode,scale,encbits,samples[1]+noise_shape);
            erracc += err;
            out[1] = qdata;
        }
        return erracc;
    }
}



void heptafon::EncoderState::encodeSector(PackedSector &sector, const int16_pair *buffer) {

    PackedSector workSectors[4] = {};
    uint64_t rot_errs[4];
    EncHistory finalXHist[4],finalYHist[4];
    int16_t mslrData[4][SECTOR_SAMPLES];
    int16_t mslrDecorr[4][SECTOR_SAMPLES];

    // Do this nonsense outside the parallel loop...
    for (uint rot=0;rot<=3;rot++) {
        int16_t prev0 = prev_smps[rot][0];
        int16_t prev1 = prev_smps[rot][1];
        for (uint i=0;i<SECTOR_SAMPLES;i++) {
            auto [smp,_] = lr_to_xy(buffer[i],rot);
            mslrData[rot][i] = smp;
            // Funny decorrelation weighting algorithm from adpcm-xq
            if (settings.dynamic_shaping) {
                int32_t pred = (3*prev0 - prev1)>>1;
                int32_t temp = smp - (((prev_decorr_weight[rot]*pred)+512)>>10);
                if (pred && temp) prev_decorr_weight[rot] += (((pred^temp)>>29)&4)-2; // either +2 or -2
                mslrDecorr[rot][i] = (prev_decorr_weight[rot]*settings.ns_strength)/256;
            } else {
                mslrDecorr[rot][i] = -settings.ns_strength*2; // Constant low-pass;
            }
            prev1 = prev0;
            prev0 = smp;
        }
        prev_smps[rot][0] = prev0;
        prev_smps[rot][1] = prev1;
    }

    #pragma omp parallel for
    for (uint rot=0;rot<=3;rot++) {
        auto &workSector = workSectors[rot];
        workSector.rotation = rot;
        if ((settings.rotmask>>rot)&1) {
            rot_errs[rot] = UINT64_MAX;
            continue;
        }
        int16_pair compareBuffer[SECTOR_SAMPLES];
        
        EncHistory xhist,yhist;
        // Noise shaping requires previous block's last encoded sample
        auto oldhist_tmp = lr_to_xy(xy_to_lr(prev_histsmp,prevblock_rotation),rot);
        xhist.samples[0] = oldhist_tmp.first;
        yhist.samples[0] = oldhist_tmp.first;
        // Set up prediction
        for (uint i=0;i<PRED_SAMPLES;i++) {
            int16_pair smp = {mslrData[rot][i],mslrData[rot^1][i]};
            workSector.pred_init[i] = smp;
            xhist.push(smp.first);
            yhist.push(smp.second);
        }
        for (uint unit=0;unit<SECTOR_UNITS;unit++) {
            const int16_t *unitbuf_x = mslrData[rot] + (unit*UNIT_SAMPLES+PRED_SAMPLES);
            const int16_t *unitbuf_y = mslrData[rot^1] + (unit*UNIT_SAMPLES+PRED_SAMPLES);
            uint64_t best_enc_err = UINT64_MAX;
            EncHistory xhist_best,yhist_best;
            for (uint enc=0;enc<=3;enc++) {
                if ((settings.encmask>>enc)&1) continue;
                uint64_t best_x_err = UINT64_MAX, best_y_err = UINT64_MAX;
                uint best_xpsr = 0,best_yps = 0;
                std::array<int8_t,UNIT_SAMPLES> best_xdat = {},best_ydat = {};
                EncHistory xhist_best_inner,yhist_best_inner;

                // Find best pred/scale for Y (64 combos)
                // Do this one first because it's faster to prune out a bad encmode this way
                for (uint yps=0;yps<64;yps++) {
                    uint64_t err = 0;
                    EncHistory workhist = yhist;
                    std::array<int8_t,UNIT_SAMPLES> workdat;
                    int scale = scaleTryOrder[yps>>2];
                    if (enc == ENCMODE_6BIT && scale != 0) break;
                    uint pred = yps&3;
                    if ((settings.predmask>>pred)&1) continue;

                    for (uint i=0;i<16;i+=2) {
                        err += quantizePair(workhist,settings,pred,encmodeYbits[enc],enc==ENCMODE_YSUB,scale,unitbuf_y+i,&workdat[i]);
                        if (err >= best_y_err) goto exceed_y_err; // Continue outer
                    }

                    best_y_err = err;
                    best_yps = yps;
                    best_ydat = workdat;
                    yhist_best_inner = workhist;

                    exceed_y_err:;
                }

                if (best_y_err >= best_enc_err) continue; // Early out for poor encmode

                // Find best pred/scale/ride for X (256 combos)
                for (uint xpsr=0;xpsr<256;xpsr++) {
                    uint64_t err = 0;
                    EncHistory workhist = xhist;
                    std::array<int8_t,UNIT_SAMPLES> workdat;
                    uint pred = xpsr&3;
                    if ((settings.predmask>>pred)&1) continue;
                    int scale1 = scaleTryOrder[xpsr>>4];
                    int scale2 = scale1+((xpsr>>2)&3)-2;
                    if (scale2 < 0 || scale2 > 15) continue;

                    for (uint i=0;i<8;i+=2) {
                        err += quantizePair(workhist,settings,pred,encmodeXbits[enc],enc==ENCMODE_XSUB,scale1,unitbuf_x+i,&workdat[i]);
                        if (err >= best_x_err) goto exceed_x_err; // Continue outer
                    }
                    for (uint i=8;i<16;i+=2) {
                        err += quantizePair(workhist,settings,pred,encmodeXbits[enc],enc==ENCMODE_XSUB,scale2,unitbuf_x+i,&workdat[i]);
                        if (err >= best_x_err) goto exceed_x_err; // Continue outer
                    }

                    best_x_err = err;
                    best_xpsr = xpsr;
                    best_xdat = workdat;
                    xhist_best_inner = workhist;

                    exceed_x_err:;
                }

                if (best_x_err + best_y_err < best_enc_err) {
                    best_enc_err = best_x_err + best_y_err;
                    xhist_best = xhist_best_inner;
                    yhist_best = yhist_best_inner;
                    // Pack data into sector struct
                    workSector.params[unit] = {
                        .xScale=uint16_t(scaleTryOrder[best_xpsr>>4]),
                        .yScale=uint16_t(scaleTryOrder[best_yps>>2]),
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
        rot_errs[rot] = 0;
        for (uint i=0;i<SECTOR_SAMPLES;i++) rot_errs[rot] += compErrorLR(compareBuffer[i],buffer[i]);
        finalXHist[rot] = xhist;
        finalYHist[rot] = yhist;
    }
    uint bestRot = 0;
    for (uint i=0;i<4;i++) if (rot_errs[i] < rot_errs[bestRot]) bestRot = i;
    sector = workSectors[bestRot];
    prevblock_rotation = bestRot;
    prev_error = {finalXHist[bestRot].error,finalYHist[bestRot].error};
    prev_histsmp = {finalXHist[bestRot].samples[0],finalYHist[bestRot].samples[0]};
}
