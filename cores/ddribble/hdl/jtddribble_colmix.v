/*  jtddribble_colmix.v — colour mixer for Double Dribble (Konami GX690)
    007327 palette LUT/RGB DAC + LS157 layer-priority mux + LS32/LS08 PRI/BLK gates.
    Author: Andrea Bogazzi <andreabogazzi79@gmail.com>
    GPL3 — see jtcores LICENSE
*/

module jtddribble_colmix(
    input               rst,
    input               clk,
    input               pxl_cen,

    input      [ 4:0]   g1col,        // FG, chip 1 (E16)
    input      [ 4:0]   g2col,        // BG, chip 2 (H16)

    output     [ 6:0]   pal_addr,
    input      [ 7:0]   pal_dout,

    output reg [ 3:0]   red,
    output reg [ 3:0]   green,
    output reg [ 3:0]   blue
);

// PRI = (|G1COL[3:0]) & G2COL[4]   (LS32 H12 + LS08 G11)
wire pri = (|g1col[3:0]) & g2col[4];
// LS157 H13/H14 layer mux: pri ? FG : BG
wire [4:0] col_mux = pri ? g1col : g2col;
wire blk = pri ? (|g1col[3:0]) : (|g2col[3:0]);

reg         pal_half;
reg  [15:0] pxl_aux;
assign pal_addr = { pri, col_mux, pal_half };

always @(posedge clk, posedge rst) begin
    if (rst) begin
        pal_half <= 1'b0;
        pxl_aux  <= 16'h0000;
    end else begin
        pxl_aux <= { pxl_aux[7:0], pal_dout };
        if (pxl_cen) begin
            pal_half <= 1'b0;
        end else begin
            pal_half <= ~pal_half;
        end
    end
end

// xBGR_555 → 4-bit RGB (drop each field's LSB). BLK gates transparent pixels.
always @(posedge clk, posedge rst) begin
    if (rst) begin
        red <= 4'h0; green <= 4'h0; blue <= 4'h0;
    end else if (pxl_cen) begin
        red   <= blk ? pxl_aux[ 4: 1] : 4'h0;
        green <= blk ? pxl_aux[ 9: 6] : 4'h0;
        blue  <= blk ? pxl_aux[14:11] : 4'h0;
    end
end

endmodule
