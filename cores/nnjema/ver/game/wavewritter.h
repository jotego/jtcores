#ifndef JTFRAME_VERILATOR_WAVEWRITTER_H
#define JTFRAME_VERILATOR_WAVEWRITTER_H

#include <cstdint>
#include <fstream>
#include <string>

class WaveWritter {
    std::ofstream fsnd, fhex;
    std::string name;
    bool dump_hex;

    void Constructor(const char *filename, int sample_rate, bool hex );

public:
    WaveWritter(const char *filename, int sample_rate, bool hex );
    WaveWritter(const std::string &filename, int sample_rate, bool hex );
    void write( int16_t *lr );
    ~WaveWritter();
};

#endif
