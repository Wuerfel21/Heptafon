#include "heptafon.hpp"
#include <cstdio>
using namespace heptafon;

void Statistics::accumulateStats(const PackedSector &sector) {
    seccnt++;
    rots[sector.rotation]++;
    for (int i=0;i<SECTOR_UNITS;i++) {
        auto par = sector.params[i];
        enc_by_rot[sector.rotation][par.encMode]++;
        xpred_by_enc[par.encMode][par.xPred]++;
        ypred_by_enc[par.encMode][par.yPred]++;
        xride_by_enc[par.encMode][par.xRide]++;

        xscale_lsb[par.xScale]++;
        xscale_msb[par.xScale+encmodeXbits[par.encMode]-1]++;
        if (par.encMode!=ENCMODE_6BIT) {
            yscale_lsb[par.yScale]++;
            yscale_msb[par.yScale+encmodeYbits[par.encMode]-1]++;
        }

    }
}

static double percent(uint val,uint total) {
    return (double(val)/double(total))*100.0;
}

void Statistics::printStats() {
    uint utotal = seccnt*SECTOR_UNITS;

    uint encsums[4] = {};
    for (uint i=0;i<4;i++) for (uint j=0;j<4;j++) encsums[j] += enc_by_rot[i][j];
    uint xpsums[4] = {};
    for (uint i=0;i<4;i++) for (uint j=0;j<4;j++) xpsums[j] += xpred_by_enc[i][j];
    uint ypsums[4] = {};
    for (uint i=0;i<4;i++) for (uint j=0;j<4;j++) ypsums[j] += ypred_by_enc[i][j];
    uint xrsums[4] = {};
    for (uint i=0;i<4;i++) for (uint j=0;j<4;j++) xrsums[j] += xride_by_enc[i][j];

    printf("Statistics over %u sectors (%u coding units)...\n",seccnt,utotal);
    printf("\n");
    printf("Rotation modes:\n");
    printf("  MID  : %6.1f%% (%u)\n",percent(rots[ROTMODE_MID],seccnt),rots[ROTMODE_MID]);
    printf("  SIDE : %6.1f%% (%u)\n",percent(rots[ROTMODE_SIDE],seccnt),rots[ROTMODE_SIDE]);
    printf("  LEFT : %6.1f%% (%u)\n",percent(rots[ROTMODE_LEFT],seccnt),rots[ROTMODE_LEFT]);
    printf("  RIGHT: %6.1f%% (%u)\n",percent(rots[ROTMODE_RIGHT],seccnt),rots[ROTMODE_RIGHT]);
    printf("\n");
    printf("Encoding modes by rotation:\n");
    printf("             MID    SIDE    LEFT   RIGHT    TOTAL\n");
    printf("  6BIT : %6.1f%% %6.1f%% %6.1f%% %6.1f%%  %6.1f%% (%u)\n",
        percent(enc_by_rot[ROTMODE_MID][ENCMODE_6BIT],utotal),
        percent(enc_by_rot[ROTMODE_SIDE][ENCMODE_6BIT],utotal),
        percent(enc_by_rot[ROTMODE_LEFT][ENCMODE_6BIT],utotal),
        percent(enc_by_rot[ROTMODE_RIGHT][ENCMODE_6BIT],utotal),
        percent(encsums[ENCMODE_6BIT],utotal),encsums[ENCMODE_6BIT]);
    printf("  3BIT : %6.1f%% %6.1f%% %6.1f%% %6.1f%%  %6.1f%% (%u)\n",
        percent(enc_by_rot[ROTMODE_MID][ENCMODE_3BIT],utotal),
        percent(enc_by_rot[ROTMODE_SIDE][ENCMODE_3BIT],utotal),
        percent(enc_by_rot[ROTMODE_LEFT][ENCMODE_3BIT],utotal),
        percent(enc_by_rot[ROTMODE_RIGHT][ENCMODE_3BIT],utotal),
        percent(encsums[ENCMODE_3BIT],utotal),encsums[ENCMODE_3BIT]);
    printf("  YSUB : %6.1f%% %6.1f%% %6.1f%% %6.1f%%  %6.1f%% (%u)\n",
        percent(enc_by_rot[ROTMODE_MID][ENCMODE_YSUB],utotal),
        percent(enc_by_rot[ROTMODE_SIDE][ENCMODE_YSUB],utotal),
        percent(enc_by_rot[ROTMODE_LEFT][ENCMODE_YSUB],utotal),
        percent(enc_by_rot[ROTMODE_RIGHT][ENCMODE_YSUB],utotal),
        percent(encsums[ENCMODE_YSUB],utotal),encsums[ENCMODE_YSUB]);
    printf("  XSUB : %6.1f%% %6.1f%% %6.1f%% %6.1f%%  %6.1f%% (%u)\n",
        percent(enc_by_rot[ROTMODE_MID][ENCMODE_XSUB],utotal),
        percent(enc_by_rot[ROTMODE_SIDE][ENCMODE_XSUB],utotal),
        percent(enc_by_rot[ROTMODE_LEFT][ENCMODE_XSUB],utotal),
        percent(enc_by_rot[ROTMODE_RIGHT][ENCMODE_XSUB],utotal),
        percent(encsums[ENCMODE_XSUB],utotal),encsums[ENCMODE_XSUB]);
    printf("\n");
    printf("X Predictors by encoding:\n");
    printf("                 6BIT    3BIT    YSUB    XSUB   TOTAL\n");
    printf("       HOLD : %6.1f%% %6.1f%% %6.1f%% %6.1f%%  %6.1f%% (%u)\n",
        percent(xpred_by_enc[ENCMODE_6BIT][PMODE_HOLD],utotal),
        percent(xpred_by_enc[ENCMODE_3BIT][PMODE_HOLD],utotal),
        percent(xpred_by_enc[ENCMODE_YSUB][PMODE_HOLD],utotal),
        percent(xpred_by_enc[ENCMODE_XSUB][PMODE_HOLD],utotal),
        percent(xpsums[PMODE_HOLD],utotal),xpsums[PMODE_HOLD]);
    printf("     LINEAR : %6.1f%% %6.1f%% %6.1f%% %6.1f%%  %6.1f%% (%u)\n",
        percent(xpred_by_enc[ENCMODE_6BIT][PMODE_LINEAR],utotal),
        percent(xpred_by_enc[ENCMODE_3BIT][PMODE_LINEAR],utotal),
        percent(xpred_by_enc[ENCMODE_YSUB][PMODE_LINEAR],utotal),
        percent(xpred_by_enc[ENCMODE_XSUB][PMODE_LINEAR],utotal),
        percent(xpsums[PMODE_LINEAR],utotal),xpsums[PMODE_LINEAR]);
    printf("  QUADRATIC : %6.1f%% %6.1f%% %6.1f%% %6.1f%%  %6.1f%% (%u)\n",
        percent(xpred_by_enc[ENCMODE_6BIT][PMODE_QUADRATIC],utotal),
        percent(xpred_by_enc[ENCMODE_3BIT][PMODE_QUADRATIC],utotal),
        percent(xpred_by_enc[ENCMODE_YSUB][PMODE_QUADRATIC],utotal),
        percent(xpred_by_enc[ENCMODE_XSUB][PMODE_QUADRATIC],utotal),
        percent(xpsums[PMODE_QUADRATIC],utotal),xpsums[PMODE_QUADRATIC]);
    printf("   WEIGHTED : %6.1f%% %6.1f%% %6.1f%% %6.1f%%  %6.1f%% (%u)\n",
        percent(xpred_by_enc[ENCMODE_6BIT][PMODE_WEIGHTED],utotal),
        percent(xpred_by_enc[ENCMODE_3BIT][PMODE_WEIGHTED],utotal),
        percent(xpred_by_enc[ENCMODE_YSUB][PMODE_WEIGHTED],utotal),
        percent(xpred_by_enc[ENCMODE_XSUB][PMODE_WEIGHTED],utotal),
        percent(xpsums[PMODE_WEIGHTED],utotal),xpsums[PMODE_WEIGHTED]);
    printf("\n");
    printf("Y Predictors by encoding:\n");
    printf("                 6BIT    3BIT    YSUB    XSUB   TOTAL\n");
    printf("       HOLD : %6.1f%% %6.1f%% %6.1f%% %6.1f%%  %6.1f%% (%u)\n",
        percent(ypred_by_enc[ENCMODE_6BIT][PMODE_HOLD],utotal),
        percent(ypred_by_enc[ENCMODE_3BIT][PMODE_HOLD],utotal),
        percent(ypred_by_enc[ENCMODE_YSUB][PMODE_HOLD],utotal),
        percent(ypred_by_enc[ENCMODE_XSUB][PMODE_HOLD],utotal),
        percent(ypsums[PMODE_HOLD],utotal),ypsums[PMODE_HOLD]);
    printf("     LINEAR : %6.1f%% %6.1f%% %6.1f%% %6.1f%%  %6.1f%% (%u)\n",
        percent(ypred_by_enc[ENCMODE_6BIT][PMODE_LINEAR],utotal),
        percent(ypred_by_enc[ENCMODE_3BIT][PMODE_LINEAR],utotal),
        percent(ypred_by_enc[ENCMODE_YSUB][PMODE_LINEAR],utotal),
        percent(ypred_by_enc[ENCMODE_XSUB][PMODE_LINEAR],utotal),
        percent(ypsums[PMODE_LINEAR],utotal),ypsums[PMODE_LINEAR]);
    printf("  QUADRATIC : %6.1f%% %6.1f%% %6.1f%% %6.1f%%  %6.1f%% (%u)\n",
        percent(ypred_by_enc[ENCMODE_6BIT][PMODE_QUADRATIC],utotal),
        percent(ypred_by_enc[ENCMODE_3BIT][PMODE_QUADRATIC],utotal),
        percent(ypred_by_enc[ENCMODE_YSUB][PMODE_QUADRATIC],utotal),
        percent(ypred_by_enc[ENCMODE_XSUB][PMODE_QUADRATIC],utotal),
        percent(ypsums[PMODE_QUADRATIC],utotal),ypsums[PMODE_QUADRATIC]);
    printf("   WEIGHTED : %6.1f%% %6.1f%% %6.1f%% %6.1f%%  %6.1f%% (%u)\n",
        percent(ypred_by_enc[ENCMODE_6BIT][PMODE_WEIGHTED],utotal),
        percent(ypred_by_enc[ENCMODE_3BIT][PMODE_WEIGHTED],utotal),
        percent(ypred_by_enc[ENCMODE_YSUB][PMODE_WEIGHTED],utotal),
        percent(ypred_by_enc[ENCMODE_XSUB][PMODE_WEIGHTED],utotal),
        percent(ypsums[PMODE_WEIGHTED],utotal),ypsums[PMODE_WEIGHTED]);
    printf("\n");
    printf("X Ride by encoding(?) :\n");
    printf("          6BIT    3BIT    YSUB    XSUB   TOTAL\n");
    for (int i=0;i<4;i++) {
        printf("  %+d : %6.1f%% %6.1f%% %6.1f%% %6.1f%%  %6.1f%% (%u)\n",i-2,
            percent(xride_by_enc[ENCMODE_6BIT][i],utotal),
            percent(xride_by_enc[ENCMODE_3BIT][i],utotal),
            percent(xride_by_enc[ENCMODE_YSUB][i],utotal),
            percent(xride_by_enc[ENCMODE_XSUB][i],utotal),
            percent(xrsums[i],utotal),xrsums[i]);
    }
    printf("\n");
    printf("Scale values :\n");
    printf("          XMSB    YMSB    XLSB    YLSB\n");
    for (int i=0;i<24;i++) {
        printf("  %2d : %6.1f%% %6.1f%% %6.1f%% %6.1f%%\n",i,
            percent(xscale_msb[i],utotal),percent(yscale_msb[i],utotal),percent(xscale_lsb[i],utotal),percent(yscale_lsb[i],utotal));
    }






}