/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 7-2-2025 */

module jtframe_scroll_offset #(parameter
    MAP_HW     = 9,
    MAP_VW     = 9,
    VDUMPW     = 9,
    HDUMPW     = 9,
    HLOOP      = 0, // when !=0, it is the value of hdump at which
                    // hdump[8:7] are set to 1, and hdf uses &hdump[8:7] for MSBs
                    // this is useful to have heff correctly operate at the
                    // trasition from blanking to active
    COL_SCROLL = 0, // set to 1 to enable 8-pixel column scroll
    LATCH_SCRX = 0, // set to 1 to latch scrx while hs is high
    FLIP_HW    = 8, // hdump bits inverted by flip
    FLIP_VW    = 8  // vdump bits inverted by flip
)(
    input       clk, 
                flip, hs,
    input [8:0] hdump, vdump,
    input [MAP_HW-1:0] scrx,
    input [MAP_VW-1:0] scry,

    output reg [VDUMPW-1:0] veff,
    output reg [HDUMPW-1:0] heff
);

localparam VDW=9, HDW=10,
           HEW = HDUMPW>HDW ? HDUMPW : HDW,
           VEW = VDUMPW>VDW ? VDUMPW : VDW;

reg  [VDW-1:0] vdf;
reg  [HDW-1:0] hdf;
reg  [MAP_HW-1:0] scrx_l;
reg  [HEW-1:0] hfull;
reg  [VEW-1:0] vfull;
wire h8,blank;
wire [8:0] hdfix;
wire [MAP_HW-1:0] scrx_eff;
reg  hsl, h8_l,
     line_changed, tile_changed, update_veff;

assign h8       = heff[3];
assign blank    = HLOOP==0 ? hdump[8] : &hdfix[8:7];
assign hdfix    = HLOOP==0 ? hdump :
                  hdump>HLOOP ? {2'b11,hdump[6:0]} : hdump;
assign scrx_eff = LATCH_SCRX==1 ? scrx_l : scrx;

always @* begin
    // hdf should make a perfect subtraction during blanking
    // HLOOP can be used to help achieve that
    hdf   = {blank,hdfix} ^ { {HDW-FLIP_HW{1'b0}}, {FLIP_HW{flip}} };
    hfull = hdf + {{HDW-MAP_HW{1'b0}},scrx_eff};
    heff  = hfull[HDUMPW-1:0];

    vdf   = vdump ^ { {VDW-FLIP_VW{1'b0}}, {FLIP_VW{flip}} };
    vfull = vdf + scry;
end

always @* begin
    line_changed = ~hs & hsl;
    tile_changed = h8 != h8_l;
    update_veff  = COL_SCROLL==1 ? tile_changed : line_changed;
end    

always @(posedge clk) begin
    hsl  <= hs;
    h8_l <= h8;
    if( hs ) scrx_l <= scrx;
    if( update_veff ) veff <= vfull[VDUMPW-1:0];
end

endmodule
