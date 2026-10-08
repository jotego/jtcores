/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 24-1-2021 */


module jtcps1_obj_tile_match(
    input             rst,
    input             clk,
    input             cen,

    input      [15:0] obj_code,
    input      [ 3:0] tile_n,
    input      [ 3:0] tile_m,
    input      [ 3:0] n,

    input             vflip,
    input      [ 8:0] vrenderf,
    input      [ 9:0] obj_y,

    output reg [ 3:0] vsub,
    output reg        inzone,
    output reg [15:0] code_mn
);

localparam YW=10;

wire [15:0] match;
reg  [ 3:0] m, mflip;

reg  [YW-1:0] bottom;
reg  [YW-1:0] ycross;
wire [YW-1:0] vs = { {YW-9{vrenderf[8]}}, vrenderf };
reg  [YW-1:0] vd;

wire [YW-1:0] objy_ext = { {YW-10{obj_y[9]}}, obj_y };

always @(*) begin
    /*verilator lint_off width*/
    bottom = objy_ext + { {YW-8{1'b0}}, tile_m, 4'd0 }+5'h10;
    /*verilator lint_on width*/
    ycross = vs-objy_ext;
    m      = ycross[7:4];
    vd     = vrenderf-obj_y[8:0];
    mflip  = tile_m-m;
end

// the m,n sum carries on, at least for CPS2 games (SPF2T)
// The carry didn't seem to be needed for CPS1/1.5 games, so
// it might be a difference with the old CPS-A chip
always @(posedge clk, posedge rst) begin
    if( rst ) begin
        inzone  <= 0;
        code_mn <= 0;
        vsub    <= 0;
    end else if(cen) begin
        inzone <= (bottom>vs) && (vs >= objy_ext || (obj_y>10'hf0 && bottom <10'h100));
        vsub   <= vd[3:0] ^ {4{vflip}};
        case( {tile_m!=4'd0, tile_n!=4'd0 } )
            2'b00: code_mn <= obj_code;
            2'b01: code_mn <= obj_code + { 12'd0, n };
            2'b10: code_mn <= obj_code + { 8'd0, vflip ? mflip : m, 4'd0};
            2'b11: code_mn <= obj_code + { 8'd0, vflip ? mflip : m, n};
        endcase
    end
end

endmodule
