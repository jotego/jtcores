#!/bin/bash
# SPDX-FileCopyrightText: 2026 Andrea Bogazzi
# SPDX-License-Identifier: GPL-3.0-or-later
# Date: 26-10-2026

set -euo pipefail
task_root=$(cd "$(dirname "$0")/../../../.." && pwd)
image=${SIM_IMAGE:-jotego/simulator:arm64}
target=${SIM_TARGET:-sidi128}
case "$target" in
    mister|sidi128) ;;
    *) echo "SIM_TARGET must be mister or sidi128" >&2; exit 1;;
esac
if [[ $# -eq 0 ]]; then set -- 2400 2700; fi
for frame in "$@"; do
    [[ "$frame" =~ ^[1-9][0-9]*$ ]] || { echo "Usage: $0 [scene frames...]" >&2; exit 1; }
done
docker image inspect "$image" >/dev/null
mkdir -p "$task_root/cores/crshrc/ver/crshrace/scratch/bin" "$task_root/cores/crshrc/ver/crshrace/scratch/bench"
docker run --rm --pull=never -e SIM_TARGET="$target" \
    -v "$task_root:/jtroot" -w /jtroot/cores/crshrc/ver/crshrace \
    "$image" -lc '
        set -euo pipefail
        export JTROOT=/jtroot JTFRAME=/jtroot/modules/jtframe MODULES=/jtroot/modules CORES=/jtroot/cores
        export JTBIN=/jtroot/release ROM=/jtroot/rom RLS=/jtroot/release MRA=/jtroot/release/mra
        export PATH="$PWD/scratch/bin:$JTFRAME/bin:$PATH"
        if [ ! -x scratch/bin/jtframe ] ||
           [ -n "$(find "$JTFRAME/src/jtframe" -name "*.go" -newer scratch/bin/jtframe -print -quit)" ]; then
            (cd "$JTFRAME/src/jtframe" && go build -o "$CORES/crshrc/ver/crshrace/scratch/bin/jtframe" .)
        fi
        for bank in 0 1 2 3; do
            [ -s "sdram_bank$bank.bin" ] || { echo "Run ver/game/sim.sh first to download the ROM" >&2; exit 1; }
        done
        for frame in "$@"; do
            export CRSHRC_SCENE_DUMP="$PWD/scenes/$frame/dump.bin"
            "$CORES/crshrc/ver/game/rest2bin.sh" "$CRSHRC_SCENE_DUMP"
            export CRSHRC_BENCH_ROWS="$PWD/scratch/bench/$frame-rows.csv"
            export CRSHRC_BENCH_SUMMARY="$PWD/scratch/bench/$frame-summary.log"
            cat > scratch/roz_bench.hpp <<"CPP"
// SPDX-FileCopyrightText: 2026 Andrea Bogazzi
// SPDX-License-Identifier: GPL-3.0-or-later
// Date: 26-10-2026
#include "UUT___024root.h"
#include <array>
#include <cstdio>
#include <cstdlib>
#include <vector>
#define CRVIDEO(n) r->game_test__DOT__u_game__DOT__u_game__DOT__u_video__DOT__##n
#define CRROZ(n) CRVIDEO(u_roz__DOT__##n)
struct CrRozBench {
    struct Row { unsigned pixels=0, underruns=0; };
    std::vector<unsigned char> rom, map;
    std::array<Row,512> rows{};
    unsigned char expected_pixels[2][512]{};
    unsigned tags[2]={511,511}, written[2]={0,0};
    FILE *csv=nullptr,*summary=nullptr;
    bool last_clk=false,edge=false,last_vs=false,seen_reset=false,pending=false;
    bool pixel_tick=false,expected_on=false,restore_checked=false;
    unsigned expected_output=0,st=0,address=0,held_address=0,expected_address=0,write_line=0;
    unsigned edge_h=0,edge_v=0,edge_pal=0;
    unsigned expected_x=0,expected_color=0,target_line=0,target_h=0;
    unsigned frame=0,pixels=0,underruns=0,completed=0,peak=0;
    unsigned bad_words=0,bad_addresses=0,bad_pixels=0,unstable=0;
    static std::vector<unsigned char> read(const char* name) {
        FILE* f=fopen(name,"rb");if(!f) {perror(name);exit(2);}
        fseek(f,0,SEEK_END);long size=ftell(f);rewind(f);if(size<0) exit(2);
        std::vector<unsigned char> bytes(static_cast<size_t>(size));
        if(fread(bytes.data(),1,bytes.size(),f)!=bytes.size()) exit(2);
        fclose(f);return bytes;
    }
    static unsigned word(const std::vector<unsigned char>& bytes,unsigned a) {
        if(2*a+1>=bytes.size()) exit(2);
        return a>=0x180000 ? 0 : (unsigned(bytes[2*a])<<8)|bytes[2*a+1];
    }
    CrRozBench() : rom(read("sdram_bank2.bin")),map(read("rozvram.bin")) {
        csv=fopen(getenv("CRSHRC_BENCH_ROWS"),"w");
        summary=fopen(getenv("CRSHRC_BENCH_SUMMARY"),"w");
        if(!csv || !summary || map.size()!=8192) exit(2);
        setvbuf(csv,nullptr,_IONBF,0);setvbuf(summary,nullptr,_IONBF,0);
        fprintf(csv,"frame,raw_line,pixel_ticks,buffer_underrun_ticks\n");
    }
    void report() {
        if(!pixels) return;
        fprintf(summary,"ROZ_BENCH frame=%u pixels=%u underruns=%u completed=%u bad_words=%u bad_addresses=%u bad_pixels=%u unstable_address=%u peak_queue=%u\n",
            frame,pixels,underruns,completed,bad_words,bad_addresses,bad_pixels,unstable,peak);
        for(unsigned y=0;y<rows.size();++y) if(rows[y].pixels)
            fprintf(csv,"%u,%u,%u,%u\n",frame,y,rows[y].pixels,rows[y].underruns);
        if(underruns || bad_words || bad_addresses || bad_pixels || unstable) exit(2);
        rows={};pixels=underruns=completed=peak=0;
    }
    template<class T> static void verify_bytes(const char* file,const T& lo,const T& hi) {
        auto bytes=read(file);
        if(bytes.size()!=2*lo.size()) exit(2);
        for(unsigned i=0;i<lo.size();++i)
            if(bytes[2*i]!=hi[i] || bytes[2*i+1]!=lo[i]) {
                fprintf(stderr,"RESTORE mismatch %s word=%u\n",file,i);exit(2);
            }
    }
    void verify_restore(UUT& game) {
        auto* r=game.rootp;
        verify_bytes("fgvram.bin",r->game_test__DOT__u_game__DOT__u_bram_fgvram__DOT__u_lo__DOT__u_ram__DOT__mem,r->game_test__DOT__u_game__DOT__u_bram_fgvram__DOT__u_hi__DOT__u_ram__DOT__mem);
        verify_bytes("rozvram.bin",r->game_test__DOT__u_game__DOT__u_bram_rozvram__DOT__u_lo__DOT__u_ram__DOT__mem,r->game_test__DOT__u_game__DOT__u_bram_rozvram__DOT__u_hi__DOT__u_ram__DOT__mem);
        verify_bytes("sprcg.bin",r->game_test__DOT__u_game__DOT__u_bram_sprcg__DOT__u_lo__DOT__u_ram__DOT__mem,r->game_test__DOT__u_game__DOT__u_bram_sprcg__DOT__u_hi__DOT__u_ram__DOT__mem);
        verify_bytes("sprvram.bin",r->game_test__DOT__u_game__DOT__u_bram_sprvram__DOT__u_lo__DOT__u_ram__DOT__mem,r->game_test__DOT__u_game__DOT__u_bram_sprvram__DOT__u_hi__DOT__u_ram__DOT__mem);
        verify_bytes("pal.bin",r->game_test__DOT__u_game__DOT__u_bram_pal__DOT__u_lo__DOT__u_ram__DOT__mem,r->game_test__DOT__u_game__DOT__u_bram_pal__DOT__u_hi__DOT__u_ram__DOT__mem);
        verify_bytes("sprcg_buf.bin",CRVIDEO(u_lookup__DOT__u_buffer__DOT__u_lo__DOT__u_ram__DOT__mem),CRVIDEO(u_lookup__DOT__u_buffer__DOT__u_hi__DOT__u_ram__DOT__mem));
        verify_bytes("sprvram_buf.bin",CRVIDEO(u_attrs__DOT__u_buffer__DOT__u_lo__DOT__u_ram__DOT__mem),CRVIDEO(u_attrs__DOT__u_buffer__DOT__u_hi__DOT__u_ram__DOT__mem));
        auto raw=read("mmr.bin"), psac=read("psac.bin");
        if(raw.size()!=40 || psac.size()!=32) exit(2);
        for(unsigned i=0;i<8;++i)
            if(r->game_test__DOT__u_game__DOT__u_game__DOT__u_main__DOT__u_scene__DOT__mmr[i]!=raw[i]) exit(2);
        for(unsigned i=0;i<16;++i)
            if(CRROZ(u_xy__DOT__mmr)[i]!=(unsigned(psac[2*i])|(unsigned(psac[2*i+1])<<8))) exit(2);
        fprintf(summary,"RESTORE_OK live=90112 buffered=73728 mmr=40\n");
    }
    void pre(UUT& game) {
        edge=game.clk48 && !last_clk;last_clk=game.clk48;if(!edge) return;
        auto* r=game.rootp;
        if(r->game_test__DOT__u_game__DOT__rst48_h) {
            seen_reset=true;last_vs=game.VS;pending=false;
            tags[0]=tags[1]=511;written[0]=written[1]=0;
            rows={};pixels=underruns=completed=peak=frame=0;
            bad_words=bad_addresses=bad_pixels=unstable=0;edge=false;return;
        }
        if(!seen_reset) {edge=false;return;}
        if(!restore_checked) {verify_restore(game);restore_checked=true;}
        if(game.VS && !last_vs) {report();++frame;}last_vs=game.VS;
        st=CRROZ(st);address=r->game_test__DOT__u_game__DOT__roz_addr;
        unsigned count=CRROZ(queued);if(count>peak) peak=count;
        if(pending && r->game_test__DOT__u_game__DOT__roz_cs && address!=held_address) ++unstable;
        if((st==0 || st==5) && count && CRROZ(map_age)>=2) {
            auto head=CRROZ(requests)[CRROZ(rd_ptr)];
            unsigned x=head&1023,y=(head>>10)&1023;
            unsigned tile=word(map,((y>>4)<<6)|(x>>4));
            target_h=(head>>20)&511;target_line=(head>>29)&511;
            expected_address=(((head>>38)&7)<<18)|((tile&4095)<<6)|((y&15)<<2)|((x>>2)&3);
            expected_x=x&15;expected_color=tile>>12;
            unsigned nibble=(word(rom,expected_address)>>((3-(expected_x&3))*4))&15;
            expected_pixels[target_line&1][target_h]=(expected_color<<4)|nibble;
        }
        write_line=CRROZ(req_line);
        pixel_tick=game.pxl_cen;
        if(pixel_tick) {
            unsigned h=CRVIDEO(hdump),v=CRVIDEO(vdump),bank=v&1;
            edge_h=h;edge_v=v;edge_pal=r->game_test__DOT__u_game__DOT__mix_pal&32767;
            if(h==0) {
                expected_on=tags[bank]==v && written[bank]==320;
                unsigned next=v==261?0:v+1;
                tags[bank^1]=next;written[bank^1]=0;
            }
            if(h<320 && v<224) {
                ++pixels;++rows[v].pixels;
                if(!expected_on) {++underruns;++rows[v].underruns;}
                expected_output=expected_pixels[bank][h];
            } else expected_on=false;
        }
    }
    void post(UUT& game) {
        if(!edge) return;auto* r=game.rootp;
        if(pixel_tick && edge_v==0 && (edge_h<3 || edge_h==319 || edge_h==320 || edge_h==321))
            fprintf(summary,"VIDEO_EDGE frame=%u raw_h=%u active=%u rgb=%04x palette=%04x\n",frame,edge_h,
                unsigned(game.LHBL && game.LVBL),unsigned((game.red<<10)|(game.green<<5)|game.blue),edge_pal);
        if((st==0 || st==5) && CRROZ(st)==3) {
            held_address=r->game_test__DOT__u_game__DOT__roz_addr;pending=true;
            if(held_address!=expected_address) ++bad_addresses;
        }
        if(st==4 && CRROZ(st)==5) {
            ++completed;pending=false;
            if(CRROZ(gfx_word)!=word(rom,address) || CRROZ(xl2)!=expected_x || CRROZ(col)!=expected_color)
                ++bad_words;
        }
        if(st==5 && tags[write_line&1]==write_line) ++written[write_line&1];
        if(pixel_tick && (bool(CRROZ(valid))!=expected_on ||
            (expected_on && CRROZ(display_pixel)!=expected_output))) ++bad_pixels;
    }
};
static CrRozBench& crroz_bench() {static CrRozBench bench;return bench;}
static void crshrc_roz_bench_pre(UUT& game) {crroz_bench().pre(game);}
static void crshrc_roz_bench_post(UUT& game) {crroz_bench().post(game);}
#undef CRVIDEO
#undef CRROZ

CPP
            awk '\''
                /^void JTSim::clock/ { print "#include \"scratch/roz_bench.hpp\"" }
                /game.eval\(\);/ { print "        crshrc_roz_bench_pre(game);" }
                { print }
                /game.eval\(\);/ { print "        crshrc_roz_bench_post(game);" }
            '\'' "$JTFRAME/verilator/test.cpp" > test.cpp
            log="scratch/bench/$frame.log"
            echo "Measuring ROZ fetches in scene $frame ($SIM_TARGET)"
            if ! jtsim -skipROM "-$SIM_TARGET" -u JTFRAME_180SHIFT -d NOMAIN -q \
                -d SIMSCENE -video 3 -keepcpp > "$log" 2>&1; then
                tail -40 "$log" >&2;exit 1
            fi
            if ! grep -q "Verilator sim starts" "$log" || grep -Eq "FAIL:|%Error:|: error:" "$log"; then
                tail -40 "$log" >&2; exit 1
            fi
            cat "$CRSHRC_BENCH_SUMMARY"
        done
    ' bench "$@"
