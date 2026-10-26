// SPDX-License-Identifier: GPL-3.0-or-later
// Reuse the simulation parser; serialize only run-length input changes for the MCU.
#include "cabinet.h"
#include <array>
#include <cstdint>
#include <cstdio>
#include <fstream>
#include <iostream>
#include <limits>
#include <stdexcept>
#include <string>
#include <vector>

using namespace std;
struct Record { uint32_t duration, inputs, dipsw; bool has_dipsw, dump; };

static void put32(ostream& out, uint32_t value) {
    for( unsigned b=0; b<4; b++ ) out.put(static_cast<char>(value >> (b*8)));
}

static uint32_t crc_byte(uint32_t crc, uint8_t byte) {
    crc ^= byte;
    for( unsigned b=0; b<8; b++ ) crc = (crc >> 1) ^ ((crc & 1) ? 0xedb88320U : 0U);
    return crc;
}

int main(int argc, char **argv) {
    try {
        if( argc<3 || argc>4 ) throw runtime_error("usage: jtframe-cab-pack input.cab output.jtcab [frames]");
        CabinetScript script(argv[1]);
        const uint64_t script_frames = script.frame_count();
        size_t end = 0;
        const uint64_t frames = argc==4 ? stoull(argv[3], &end) : script_frames;
        if( argc==4 && end!=string(argv[3]).size() ) throw runtime_error("invalid frame limit");
        if( frames==0 || frames>0x7fffffff || frames<script_frames )
            throw runtime_error("frame limit must be 1..2147483647 and cover the complete CAB script");
        vector<Record> records;
        uint32_t dipsw = 0;
        uint32_t dumps = 0;
        bool has_dipsw = false;
        auto append = [&](uint64_t count, uint32_t inputs, bool dump) {
            if( !count ) return;
            if( !records.empty() && records.back().inputs==inputs &&
                records.back().has_dipsw==has_dipsw && records.back().dipsw==dipsw && records.back().dump==dump )
                records.back().duration += count;
            else records.push_back({static_cast<uint32_t>(count),inputs,dipsw,has_dipsw,dump});
            if(dump) dumps+=count;
        };
        uint64_t position = 0;
        while( !script.done() ) {
            const CabinetRun run = script.next_run();
            const auto& frame = run.frame;
            if( !frame.cheats.empty() ) {
                throw runtime_error("cheat at CAB frame "+to_string(position)+" is not supported by the hardware input protocol");
            }
            if( frame.tracing_on ) cerr << "CAB tracing_on marker at frame " << position << " (no hardware waveform)\n";
            if( frame.has_dipsw ) { dipsw=frame.dipsw; has_dipsw=true; }
            append(run.count, frame.inputs, frame.dump);
            position += run.count;
        }
        append(frames-script_frames,0,false);
        const unsigned version=dumps ? 3 : has_dipsw ? 2 : 1;
        uint32_t crc=0xffffffffU;
        for( const auto& record : records ) {
            const uint32_t words[] = {record.duration,record.inputs | (record.has_dipsw ? 0x00200000U : 0U) | (record.dump ? 0x00400000U : 0U),record.dipsw};
            for( unsigned w=0; w<(version>1 ? 3U : 2U); w++ )
                for( unsigned b=0;b<4;b++ ) crc=crc_byte(crc,words[w]>>(b*8));
        }
        crc ^= 0xffffffffU;
        // All parsing/capability checks precede opening the requested output file.
        ofstream output(argv[2],ios::binary|ios::trunc);
        if( !output ) throw runtime_error("cannot create output file");
        output.write(version==3 ? "JTCAB03\0" : version==2 ? "JTCAB02\0" : "JTCAB01\0",8);
        put32(output,version); put32(output,frames); put32(output,records.size());
        put32(output,dumps); put32(output,crc); put32(output,32);
        for( const auto& record : records ) {
            put32(output,record.duration); put32(output,record.inputs | (record.has_dipsw ? 0x00200000U : 0U) | (record.dump ? 0x00400000U : 0U));
            if( version>1 ) put32(output,record.dipsw);
        }
        output.close();
        if( !output ) throw runtime_error("error writing output file");
        cout << "CAB: " << frames << " raster frames, " << records.size()
             << " input runs, " << dumps << " dumps, " << 32+records.size()*(version>1 ? 12 : 8) << " bytes\n";
    } catch( const exception& error ) {
        cerr << "CAB export: " << error.what() << '\n';
        return 1;
    }
}
