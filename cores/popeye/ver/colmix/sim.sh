#!/bin/bash
cd "$(dirname "$0")"
ZIP=${POPEYE_ZIP:-/mnt/c/Roms/Mame/popeyeu.zip}
JT2020=${JT2020:-../../../../../popeye-2020/hdl/jtpopeye_colmix.v}
JTFRAME=${JTFRAME:-../../../../modules/jtframe}
TMP=$(mktemp -d)
for f in tpp2-v.7j tpp2-c.3a tpp2-c.4a tpp2-c.5a tpp2-c.5b; do
    unzip -p "$ZIP" $f > $TMP/$f || { rm -rf $TMP; exit 1; }
done
sed -e 's/module jtpopeye_colmix(/module jtpopeye_colmix_2020(/' \
    -e 's/jtframe_prom #/jt2020_prom #/' -e 's/jtframe_sh #/jt2020_sh #/' \
    -e "s|\.\./\.\./rom/|$TMP/|" "$JT2020" > $TMP/jtpopeye_colmix_2020.v
cat > $TMP/jt2020_shims.v <<'EOV'
module jt2020_prom #(parameter aw=8, dw=8, simfile="")(
    input clk, input cen, input [dw-1:0] data, input [aw-1:0] rd_addr,
    input [aw-1:0] wr_addr, input we, output reg [dw-1:0] q );
    reg [7:0] mem[0:(2**aw)-1];
    integer f, n;
    initial begin f=$fopen(simfile,"rb"); n=$fread(mem,f); $fclose(f); end
    always @(posedge clk) if(cen) q <= mem[rd_addr][dw-1:0];
endmodule
module jt2020_sh #(parameter width=2, stages=4)(
    input clk, input clk_en, input [width-1:0] din, output [width-1:0] drop );
    jtframe_sh #(.W(width),.L(stages)) u(.clk(clk),.clk_en(clk_en),.din(din),.drop(drop));
endmodule
EOV
iverilog -g2012 -DSIMULATION -s test -o $TMP/sim test.v ../../hdl/jtpopeye_colmix.v ../../hdl/jtpopeye_timing.v \
    $JTFRAME/hdl/ram/jtframe_prom.v $JTFRAME/hdl/video/jtframe_blank.v $JTFRAME/hdl/jtframe_sh.v \
    $TMP/jtpopeye_colmix_2020.v $TMP/jt2020_shims.v \
    -DP7J=\"$TMP/tpp2-v.7j\" -DP3A=\"$TMP/tpp2-c.3a\" -DP4A=\"$TMP/tpp2-c.4a\" \
    -DP5A=\"$TMP/tpp2-c.5a\" -DP5B=\"$TMP/tpp2-c.5b\" || { rm -rf $TMP; exit 1; }
vvp -n $TMP/sim | tee $TMP/sim.log
RESULT=${PIPESTATUS[0]}
grep -q "^PASS" $TMP/sim.log || RESULT=1
rm -rf $TMP
exit $RESULT
