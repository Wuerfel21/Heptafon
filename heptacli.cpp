#include "heptafon.hpp"
using namespace heptafon;
#include <iostream>
#include <cstring>
#include <cstdio>
#include <cerrno>


static void printUsage() {
    std::cout << "Usage:" << std::endl;
    std::cout << "  encode [in.raw] [out.hep]" << std::endl;
    std::cout << "  decode [in.hep] [out.raw]" << std::endl;
    std::cout << "  stats [in.hep]" << std::endl;
    std::cout << "  rawdiff [a.raw] [b.raw]" << std::endl;
}

#define DIFF_BLOCK_SIZE 2048
#define ENC_JOB_SIZE 256

int main(int argc, char **argv) {
    std::cout << "HEPTAFON Audio Codec" << std::endl;
    
    if (argc < 2) {
        printUsage();
    } else if (!strcmp(argv[1],"decode")) {
        if (argc != 4) {
            printUsage();
            return -1;
        }
        FILE *infile = fopen(argv[2],"rb");
        if (!infile) {
            std::cout << "Input open error: " << strerror(errno) << std::endl;
            return -1;
        }
        FILE *outfile = fopen(argv[3],"wb");
        if (!outfile) {
            std::cout << "Output open error: " << strerror(errno) << std::endl;
            return -1;
        }
        for(;;) {
            PackedSector sector;
            int16_pair buffer[SECTOR_SAMPLES];
            if (!fread(&sector,sizeof(PackedSector),1,infile)) return 0;
            decodeSector(sector,buffer);
            fwrite(buffer,SECTOR_SAMPLES*sizeof(int16_pair),1,outfile);
        }
    } else if (!strcmp(argv[1],"encode")) {
        if (argc != 4) {
            printUsage();
            return -1;
        }
        FILE *infile = fopen(argv[2],"rb");
        if (!infile) {
            std::cout << "Input open error: " << strerror(errno) << std::endl;
            return -1;
        }
        FILE *outfile = fopen(argv[3],"wb");
        if (!outfile) {
            std::cout << "Output open error: " << strerror(errno) << std::endl;
            return -1;
        }
        for(;;) {
            PackedSector sectors[ENC_JOB_SIZE];
            int16_pair buffer[SECTOR_SAMPLES*ENC_JOB_SIZE];
            auto gotsmp = fread(buffer,sizeof(int16_pair),SECTOR_SAMPLES*ENC_JOB_SIZE,infile);
            if (!gotsmp) return 0;
            auto gotsectors = (gotsmp+SECTOR_SAMPLES-1)/SECTOR_SAMPLES;
            auto zerofill = gotsectors*SECTOR_SAMPLES - gotsmp;
            if (zerofill) memset(buffer+(gotsectors*SECTOR_SAMPLES-zerofill),0,zerofill*sizeof(int16_pair));
            #pragma omp parallel for
            for (uint i=0;i<ENC_JOB_SIZE;i++) {
                if (i>=gotsectors) continue;
                encodeSector(sectors[i],buffer+(i*SECTOR_SAMPLES));
            }
            fwrite(sectors,sizeof(PackedSector),gotsectors,outfile);
        }
    } else if (!strcmp(argv[1],"stats")) {
        if (argc != 3) {
            printUsage();
            return -1;
        }
        FILE *infile = fopen(argv[2],"rb");
        if (!infile) {
            std::cout << "Input open error: " << strerror(errno) << std::endl;
            return -1;
        }
        Statistics stats = {};
        for(;;) {
            PackedSector sector;
            if (!fread(&sector,sizeof(PackedSector),1,infile)) break;
            stats.accumulateStats(sector);
        }
        stats.printStats();
    } else if (!strcmp(argv[1],"rawdiff")) {
        if (argc != 4) {
            printUsage();
            return -1;
        }
        FILE *infileA = fopen(argv[2],"rb");
        if (!infileA) {
            std::cout << "Input A open error: " << strerror(errno) << std::endl;
            return -1;
        }
        FILE *infileB = fopen(argv[3],"rb");
        if (!infileB) {
            std::cout << "Input B open error: " << strerror(errno) << std::endl;
            return -1;
        }
        uint64_t err = 0;
        for (;;) {
            int16_pair bufferA[DIFF_BLOCK_SIZE],bufferB[DIFF_BLOCK_SIZE];
            auto gotA = fread(bufferA,sizeof(int16_pair),DIFF_BLOCK_SIZE,infileA);
            auto gotB = fread(bufferB,sizeof(int16_pair),DIFF_BLOCK_SIZE,infileB);
            if (gotA != gotB) {
                std::cout << "File sizes don't match (comparsion stops at first EOF)..." << std::endl;
            }
            if (gotA == 0 || gotB == 0) break;
            for (uint i=0;i<std::min(gotA,gotB);i++) err += compErrorLR(bufferB[i],bufferA[i]);
        }
        std::cout << "Difference: " << err << std::endl;
    } else {
        printUsage();
        return -1;
    }
    return 0;
}