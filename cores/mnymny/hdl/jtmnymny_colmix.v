/*  jtmnymny_colmix.v — 1B11140 colour mixer
    Pen scramble into the 9F/9G PROMs + LS374/resistor DAC.
    PROM address = { pal[4:2], pix[2:0], pal[1:0], obj/bg }.
    GPL3 — see jtcores LICENSE
*/

module jtmnymny_colmix(
    input               clk,
    input               pxl_cen,
    input       [ 8:0]  scr_pxl,     // { pal[4:0], pix[3:0] }, pix[3]=0
    input       [ 8:0]  obj_pxl,
    output      [ 8:0]  pal_addr,
    input       [ 3:0]  pal9f_data,
    input       [ 3:0]  pal9g_data,
    output      [ 3:0]  red, green, blue
);

wire [2:0] mix_pix;
wire [4:0] mix_pal;
wire       obj_sel = obj_pxl[2:0] != 0;

assign mix_pix  = obj_sel ? obj_pxl[2:0] : scr_pxl[2:0];
assign mix_pal  = obj_sel ? obj_pxl[8:4] : scr_pxl[8:4];
assign pal_addr = { mix_pal[4:2], mix_pix, mix_pal[1:0], obj_sel };

// resistor DAC: RG 1200/1000/820 (390 down), B 1000/820 (470 down)
// 9G = R[1200,1000,820]+G[1200]; 9F = G[1000,820]+B[1000,820] (sheet 1 hookup)
function [7:0] rgw( input b0, input b1, input b2 );
    rgw = ( b0 ? 8'd70 : 8'd0 ) + ( b1 ? 8'd83 : 8'd0 ) + ( b2 ? 8'd102 : 8'd0 );
endfunction

reg  [3:0] rl, gl, bl;
wire [7:0] r8 = rgw( pal9g_data[3], pal9g_data[2], pal9g_data[1] );
wire [7:0] g8 = rgw( pal9g_data[0], pal9f_data[3], pal9f_data[2] );
wire [7:0] b8 = ( pal9f_data[1] ? 8'd115 : 8'd0 ) + ( pal9f_data[0] ? 8'd140 : 8'd0 );

always @(posedge clk) if(pxl_cen) begin
    if( mix_pix==0 ) begin
        { rl, gl, bl } <= 0;   // pen 0 is always black (see MAME note on Jack Rabbit)
    end else begin
        rl <= r8[7:4];
        gl <= g8[7:4];
        bl <= b8[7:4];
    end
end

assign red   = rl;
assign green = gl;
assign blue  = bl;

endmodule
