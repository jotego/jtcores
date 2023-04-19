/*  This file is part of JTCORES.
    JTCORES program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTCORES program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTCORES.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 27-10-2017 */

// 2-word tile memory

// Building the video with so many generate statements made
// it impossible to have clean warnings in verilator
/* verilator lint_off SELRANGE */
/* verilator lint_off WIDTH */

//////////////////////////////////////////////////////////////////
// Original board behaviour
// Commando / G&G / 1942 / 1943
// Scroll: when CPU tries to access hold the CPU until H==4, then
//         release the CPU and keep it in control of the bus until
//         the CPU releases the CS signal


module jtgng_tilemap #(parameter
    DW          = 8,
    INVERT_SCAN = 0,
    DATAREAD    = 3'd2,
    LAYOUT      = 0, // 0: all games, 8: Side Arms
    SCANW       = 10,
    BUSY_ON_H0  = 0,    // if 1, the busy signal is asserted only at H0 posedge, otherwise it uses the regular clock
    SIMID       = 0,    // selects the name for the simulation files
    VW          = 8,
    HW          = (LAYOUT==8 || LAYOUT==9 || LAYOUT==10) ? 9 : 8
) (
    input                  clk,
    input                  pxl_cen,
    input                  Asel,  // This is the address bit that selects
                            // between the low and high tile map
    input            [1:0] dseln,
    input                  layout,  // use by Black Tiger to change scan
    input      [SCANW-1:0] AB,
    input         [VW-1:0] V,
    input         [HW-1:0] H,
    input                  flip,
    input         [DW-1:0] din,
    output        [DW-1:0] dout,
    // Bus arbitrion
    input                  cs,
    input                  wr_n,
    // Current tile
    output           [7:0] dout_low,
    output           [7:0] dout_high
);

localparam LOWER_SIMFILE= SIMID==0 ? "char_lo.bin" :
                          SIMID==1 ? "scr1_lo.bin" : "scr2_lo.bin";

localparam UPPER_SIMFILE= SIMID==0 ? "char_hi.bin" :
                          SIMID==1 ? "scr1_hi.bin" : "scr2_hi.bin";

wire [7:0] scan_low, scan_high;
wire       we_low, we_high;
wire [7:0] udin   , mem_low, mem_high;
reg [SCANW-1:0] scan;

assign dout_low  = scan_low;
assign dout_high = scan_high;

always @(*) begin
    if( SCANW <= 10) begin
        scan = (INVERT_SCAN ? { {SCANW{flip}}^{H[7:3],V[7:3]}}
            : { {SCANW{flip}}^{V[7:3],H[7:3]}}) >> (10-SCANW);
    end else begin
        if( SCANW==13 ) begin // Black Tiger
            // 1 -> tile map 8x4
            // 0 -> tile map 4x8
            scan =  layout ?
                { V[8:7], H[9:7], V[6:3], H[6:3] } :
                { V[9:7], H[8:7], V[6:3], H[6:3] };
        end else if( LAYOUT==8 || LAYOUT==9 ) begin // Side Arms/Street Fighter
            scan = {SCANW{flip}}^{ V[7:3], H[8:3] }; // SCANW assumed to be 11
        end else if( LAYOUT==10 ) begin // The Speed Rumbler (SCANW=11 or 12)
            scan = {SCANW{flip}}^{ H[8:3], V[7:(SCANW==12?2:3)] };
        end else // other games
            scan = { V[7:2], H[7:2] }; // SCANW assumed to be 12
    end
end

generate
    if(DW==8) begin
        assign we_low  = cs && !wr_n && !Asel;
        assign we_high = cs && !wr_n &&  Asel;
        assign udin    = din;
        assign dout    = Asel ? mem_high : mem_low;
    end else begin
        assign we_low  = cs && !wr_n && !dseln[0];
        assign we_high = cs && !wr_n && !dseln[1];
        assign udin    = din[15:8];
        assign dout    = { mem_high, mem_low };
    end
endgenerate

`ifndef JTCHAR_UPPER_SIMFILE
`define JTCHAR_UPPER_SIMFILE
`endif

`ifndef JTCHAR_LOWER_SIMFILE
`define JTCHAR_LOWER_SIMFILE
`endif

jtframe_dual_ram #(.AW(SCANW),.SIMFILE(LOWER_SIMFILE)) u_ram_low(
    .clk0   ( clk      ),
    .clk1   ( clk      ),
    // CPU
    .data0  ( din[7:0] ),
    .addr0  ( AB       ),
    .we0    ( we_low   ),
    .q0     ( mem_low  ),
    // GFX
    .data1  ( 8'd0     ),
    .addr1  ( scan     ),
    .we1    ( 1'b0     ),
    .q1     ( scan_low )
);

// attributes
// the default value for synthesis will display a ROM load message using
// the palette attributes
jtframe_dual_ram #(.AW(SCANW),.SIMFILE(UPPER_SIMFILE)) u_ram_high(
    .clk0   ( clk      ),
    .clk1   ( clk      ),
    // CPU
    .data0  ( udin     ),
    .addr0  ( AB       ),
    .we0    ( we_high  ),
    .q0     ( mem_high ),
    // GFX
    .data1  ( 8'd0     ),
    .addr1  ( scan     ),
    .we1    ( 1'b0     ),
    .q1     ( scan_high)
);

endmodule

/* verilator lint_on SELRANGE */
/* verilator lint_on WIDTH */