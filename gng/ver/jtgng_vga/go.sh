#!/bin/bash
# VGA Test

SIMPLL=NOSIMPLL
SIMULATOR=iverilog

while [ $# -gt 0 ]; do
    case "$1" in
        "-pll")
            SIMPLL=SIMPLL
            echo Using PLL model
            ;;
        "-nc")
            SIMULATOR=NCVERILOG
            echo Simulate with NCVerilog
            ;;
        *)        
           echo "Unknown option $1"
           exit 1;;
    esac
    shift
    continue
done

case $SIMULATOR in
    iverilog)
        iverilog jtgng_vga_test.v ../../hdl/jtgng_{vga,timer,cen,pll0}.v \
            ../common/altera_mf.v \
            -s jtgng_vga_test -o sim -D$SIMPLL \
            && sim -lxt;;
    NCVERILOG)
        ncverilog +access+r +nc64bit +define+NCVERILOG \
            jtgng_vga_test.v ../../hdl/jtgng_{vga,vgapxl,timer,cen,pll0,dual_clk_ram}.v \
            ../common/altera_mf.v \
            +define+SIMULATION;;
    *)
        echo "Unsupported option"
        exit 1;;
esac