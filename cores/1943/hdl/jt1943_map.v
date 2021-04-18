/*  This file is part of JT_GNG.
    JT_GNG program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JT_GNG program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JT_GNG.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 18-4-2021 */

module jt1943_map #( parameter
    [8:0] HOFFSET   = 9'd5,
    parameter
    LAYOUT          = 0,   // 0 = 1943, 3 = Bionic Commando, 8 = Side Arms, 9=SF
    VPOSW           = (LAYOUT==3 || LAYOUT==8) ? 16 : 8, // vertical offset bit width,
    // MAP SIZE
    MAPAW           = LAYOUT==9 ? 16 : 14, // address width
    MAPDW           = LAYOUT==9 ? 32 : 16  // data width
)(
    input                  rst,
    input                  clk,  // >12 MHz
    input                  pxl_cen,
    input           [ 8:0] V128, // V128-V1
    input           [ 8:0] H, // H256-H1
    input           [15:0] hpos,
    input      [VPOSW-1:0] vpos,
    input                  SCxON,
    input                  flip,
    // Map ROM
    output reg [MAPAW-1:0] map_addr,
    input      [MAPDW-1:0] map_data,
    input                  map_ok,
    output   [MAPDW/2-1:0] dout_high,
    output   [MAPDW/2-1:0] dout_low,
    // Coordinates for tiler
    output reg       [4:0] HS,
    output reg       [4:0] SVmap // SV latched at the time the map_addr is set
);

localparam SHW = (LAYOUT==8 || LAYOUT==9) ?  9 : 8;
localparam SVW = LAYOUT==8 ? 12 : 8;

// H goes from 80h to 1FFh
wire [8:0] Hfix_prev = H+HOFFSET;
wire [8:0] Hfix = !Hfix_prev[8] && H[8] ? Hfix_prev|9'h80 : Hfix_prev; // Corrects pixel output offset

reg  [    7:0] PICV, PIC;
reg  [SVW-1:0] SV;
reg  [SHW-1:0] SH;
wire [    8:0] V128sh;
reg  [    8:0] VF;

// Because we process the signal a bit ahead of time
// (exactly HOFFSET pixels ahead of time), this creates
// an unbalance between the vertical line counter change
// and the current output   at the end of each line. It wasn't
// noticeable in 1943, but it can be seen in GunSmoke
// In order to avoid it, the V counter must be delayed by the same
// HOFFSET amount
jtframe_sh #(.width(9), .stages(HOFFSET) ) u_vsh
(
    .clk    ( clk     ),
    .clk_en ( pxl_cen ),
    .din    ( V128    ),
    .drop   ( V128sh  )
);

reg [7:0] HF;
reg [9:0] SCHF;
reg       H7;

always @(*) begin
    if( LAYOUT==8 ) begin // Side Arms
        PIC[6:3] = SV[11:8];
        { PIC[7], PIC[2:0], SH } = {4'd0, H^{9{flip}}} + hpos[12:0];
    end else if(LAYOUT==9) begin // Street Fighter
        { PIC, SH } = {4'd0, H^{9{flip}}} + hpos;
    end else begin
        HF          = {8{flip}}^Hfix[7:0]; // SCHF2_1-8
        H7          = (~Hfix[8] & (~flip ^ HF[6])) ^HF[7];
        SCHF        = { HF[6]&~Hfix[8], ~Hfix[8], H7, HF[6:0] };
        if(LAYOUT==7) begin // Trojan only has 8-bit scrolling
            {PIC,  SH } = {8'd0, hpos[7:0] } +
                + { {6{SCHF[9]}},SCHF } + (flip?16'h16:16'h8);
        end else begin
            {PIC,  SH } = hpos + { {6{SCHF[9]}},SCHF } + (flip?16'h8:16'h0);
        end
    end
end

generate
    if (LAYOUT==0) begin
        // 1943 32x32
        always @(posedge clk) if(pxl_cen) begin
            // always update the map at the same pixel count
            if( SH[2:0]==3'd7 ) begin
                VF <= {8{flip}}^V128sh[7:0];
                {PICV, SV } <= { {16-VPOSW{vpos[7]}}, vpos } + { {8{VF[7]}}, VF };
                HS[4:3] <= SH[4:3] ^{2{flip}};
                map_addr <= { PIC, SH[7:6], SV[7:5]/*^{3{flip}}*/, SH[5] }; // SH[5] is LSB
                    // in order to optimize cache use
            end
        end
    end
    if(LAYOUT==3 || LAYOUT==7) begin
        // Tiger Road 32x32 - Trojan 16x16
        always @(*) begin
            VF          = flip ? 9'd240-V128sh[8:0] : V128sh[8:0];
            {PICV, SV } = { {7{VF[8]}}, VF } - vpos;
        end
        wire [7:0] col = {PIC,  SH}>>(LAYOUT==3 ? 5 : 4);
        wire [7:0] row = {PICV, SV}>>(LAYOUT==3 ? 5 : 4);
        always @(posedge clk) if(pxl_cen) begin
            // always update the map at the same pixel count
            if( SH[2:0]==3'd7 ) begin
                HS[4:3] <= SH[4:3];
                map_addr <= LAYOUT==3 ?
                    {  ~row[6:3], col[6:3], ~row[2:0], col[2:0] } : // Tiger Road
                    {  {row[3:0], 2'b0 }, col[7:0] }+ {2'b0, hpos[15:8], 4'd0}; // Trojan 6 + 8
            end
        end
    end
    if (LAYOUT==8) begin
        // Side Arms 32x32
        always @(posedge clk) begin
            VF <= {8{flip}}^V128[7:0];
            SV <= { {VPOSW-9{1'b0}}, VF } + vpos;
        end
        always @(posedge clk) if(pxl_cen) begin
            // always update the map at the same pixel count
            if( SH[2:0]==3'd7 ) begin
                HS[4:3] <= SH[4:3] /*^{2{flip}}*/;
                map_addr <= { PIC[6:0], SH[8:5], SV[7:5] };
            end
        end
    end
    if (LAYOUT==9) begin
        // Street Fighter 16x16
        always @(posedge clk) begin
            VF <= {8{flip}}^V128[7:0];
            SV <= VF;
        end
        always @(posedge clk) if(pxl_cen) begin
            // always update the map at the same pixel count
            if( SH[2:0]==3'd7 ) begin
                HS[3] <= SH[3] /*^flip*/;
                // Map address shifted left because of 32-bit read
                map_addr <= { PIC[5:0], SH[8:4], SV[7:4], 1'b0 }; // 6+5+4+1=16
            end
        end
    end
endgenerate

always @(posedge clk) if(pxl_cen) begin
    if( SH[2:0]==3'd7 ) begin
        SVmap <= SV[4:0];
    end
    HS[2:0] <= SH[2:0] ^ {3{flip}};
end

assign dout_high = map_data[MAPDW/2-1:0];
assign dout_low  = map_data[MAPDW-1:MAPDW/2];

endmodule