/*  jtddrbl_colmix.v — colour mixer for Double Dribble (Konami GX690)
    007327 palette LUT/RGB DAC + LS157 layer-priority mux + LS32/LS08 PRI/BLK gates.
    Author: Andrea Bogazzi <andreabogazzi79@gmail.com> - Jose Tejada
    GPL3 — see jtcores LICENSE
*/

module jtddrbl_colmix(
    input               rst,
    input               clk,
    input               pxl_cen,
    input               lhbl, lvbl,

    input      [ 4:0]   g1col,        // FG, chip 1 (E16)
    input      [ 4:0]   g2col,        // BG, chip 2 (H16)

    output     [ 6:0]   pal_addr,
    input      [ 7:0]   pal_dout,

    output     [ 4:0]   red,
    output     [ 4:0]   green,
    output     [ 4:0]   blue,
    input      [ 7:0]   debug_bus
);

wire blank = ~lhbl | ~lvbl;
// PRI = (|G1COL[3:0]) & G2COL[4]   (LS32 H12 + LS08 G11)
wire pri = (|g1col[3:0]) & g2col[4];
// LS157 H13/H14 layer mux: pri ? FG : BG
wire [4:0] col_mux = pri ? g1col : g2col;

reg         pal_half;
reg  [15:0] pxl_aux;
assign pal_addr = { pri, col_mux, pal_half };

assign red   = blank ? 5'h0 : pxl_aux[ 4: 0];
assign green = blank ? 5'h0 : pxl_aux[ 9: 5];
assign blue  = blank ? 5'h0 : pxl_aux[14:10];

always @(posedge clk) begin
    pal_half <= pxl_cen ? 1'b1 : ~pal_half;
    if(pal_half)
        pxl_aux[15:8] <= pal_dout;
    else
        pxl_aux[ 7:0] <= pal_dout;
end

endmodule
