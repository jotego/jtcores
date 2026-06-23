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

    output     [ 3:0]   red,
    output     [ 3:0]   green,
    output     [ 3:0]   blue
);

// PRI = (|G1COL[3:0]) & G2COL[4]   (LS32 H12 + LS08 G11)
wire pri = (|g1col[3:0]) & g2col[4];

// LS157 H13/H14 layer mux: pri ? FG : BG
wire [4:0] col_mux = pri ? g1col : g2col;

// BLK = OR of post-mux COL[3:0]   (LS32 OR-tree)
wire blk = pri ? (|g1col[3:0]) : (|g2col[3:0]);

// blk is combinational from the current pixel; col_in is the previous pixel's
// palette word (latched on pxl_cen). Register blk on pxl_cen so they align.
reg blk_q = 1'b0;
always @(posedge clk, posedge rst) begin
    if(rst)          blk_q <= 1'b0;
    else if(pxl_cen) blk_q <= blk;
end

// Read both palette bytes per pixel by toggling pal_half each clk, shifting into
// a 16-bit accumulator, latching the colour word on pxl_cen.
//   pal_addr = { PRI, col_mux[4:0], pal_half }  (pal_half: 0=low byte, 1=high)
reg         pal_half;
reg  [15:0] pxl_aux;
reg  [15:0] col_in;

assign pal_addr = { pri, col_mux, pal_half };

always @(posedge clk, posedge rst) begin
    if (rst) begin
        pal_half <= 1'b0;
        pxl_aux  <= 16'h0000;
        col_in   <= 16'h0000;
    end else begin
        pxl_aux <= { pxl_aux[7:0], pal_dout };
        if (pxl_cen) begin
            col_in   <= pxl_aux;
            pal_half <= 1'b0;
        end else begin
            pal_half <= ~pal_half;
        end
    end
end

// xBGR_555 → 4-bit RGB (drop each field's LSB). BLK gates transparent pixels.
wire [4:0] r5 = col_in[ 4: 0];
wire [4:0] g5 = col_in[ 9: 5];
wire [4:0] b5 = col_in[14:10];

assign red   = blk_q ? r5[4:1] : 4'h0;
assign green = blk_q ? g5[4:1] : 4'h0;
assign blue  = blk_q ? b5[4:1] : 4'h0;

endmodule
