#!/bin/bash
cd "$(dirname "$0")"
ZIP=${POPEYE_ZIP:-/mnt/c/Roms/Mame/popeyeu.zip}
JT2020=${JT2020:-../../../../../popeye-2020/hdl/jtpopeye_buf.v}
JTFRAME=${JTFRAME:-../../../../modules/jtframe}
TMP=$(mktemp -d)
trap "rm -rf $TMP" EXIT
unzip -p "$ZIP" tpp2-v.7j > $TMP/tpp2-v.7j || exit 1
sed -e 's/jtframe_ram #/jt2020_ram #/' "$JT2020" > $TMP/jtpopeye_buf_2020.v || exit 1
cat > $TMP/jt2020_ram.v <<'EOV'
module jt2020_ram #(parameter dw=8, aw=10, simhexfile="")(
    input               clk,
    input               cen,
    input      [dw-1:0] data,
    input      [aw-1:0] addr,
    input               we,
    output reg [dw-1:0] q
);
reg [dw-1:0] mem[0:(2**aw)-1];
integer i;
initial for( i=0; i<2**aw; i=i+1 ) mem[i] = 0;
always @(posedge clk) if( cen ) begin
    q <= mem[addr];
    if( we ) mem[addr] <= data;
end
endmodule
EOV
FAIL=0
for RUN in ${RUNS:-"~rv:9" "rv:4"}; do
    RVN=${RUN%:*}
    iverilog -g2012 -o $TMP/sim -s test -DSIMULATION -DJT2020 -DPROM=\"$TMP/tpp2-v.7j\" \
        -DRVN2020="$RVN" -DRVN2020S="\"$RVN\"" -Ptest.NFIELDS=${RUN#*:} "$@" test.v ../../hdl/jtpopeye_objbuf.v \
        ../../hdl/jtpopeye_timing.v ../../hdl/jtpopeye_dma.v $JTFRAME/hdl/ram/jtframe_prom.v \
        $JTFRAME/hdl/ram/jtframe_ram.v $TMP/jtpopeye_buf_2020.v $TMP/jt2020_ram.v || exit 1
    vvp -n $TMP/sim | tee $TMP/log
    grep -q "^PASS" $TMP/log || FAIL=1
done
exit $FAIL
