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
    Date: 27-10-2017 */

// 2-word tile memory

//////////////////////////////////////////////////////////////////
// Original board behaviour
// Commando / G&G / 1942 / 1943
// Scroll: when CPU tries to access hold the CPU until H==4, then
//         release the CPU and keep it in control of the bus until
//         the CPU releases the CS signal

`timescale 1ns/1ps

module jtgng_tilemap #(parameter 
    DW          = 8,
    INVERT_SCAN = 0,
    DATAREAD    = 3'd2,
    SCANW       = 10,
    BUSY_ON_H0  = 0,    // if 1, the busy signal is asserted only at H0 posedge, otherwise it uses the regular clock
    SIMID       = "",
    VHW         = 8
) (
    input                  clk,
    input                  pxl_cen,
    input                  Asel,  // This is the address bit that selects
                            // between the low and high tile map
    input            [1:0] dseln,
    input                  layout,  // use by Black Tiger to change scan
    input      [SCANW-1:0] AB,
    input        [VHW-1:0] V,
    input        [VHW-1:0] H,
    input                  flip,
    input         [DW-1:0] din,
    output    reg [DW-1:0] dout,
    // Bus arbitrion
    input                  cs,
    input                  wr_n,
    output       reg       busy,
    // Pause screen
    input                  pause,
    output reg [SCANW-1:0] scan,
    input            [7:0] msg_low,
    input            [7:0] msg_high,
    // Current tile
    output       reg [7:0] dout_low,
    output       reg [7:0] dout_high
);

reg scan_sel = 1'b1;

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
            // { V[6:5], H[7:5], V[4:1], H[4:1] };
            //layout ? { V[7:1], H[7:2] } : { V[7:2], H[7:1] };
        end else // other games
            scan = { V[7:2], H[7:2] }; // SCANW assumed to be 12
    end
end

reg [SCANW-1:0] addr;
reg we_low, we_high;
wire [7:0] mem_low, mem_high;

reg last_H0;
wire posedge_H0 = BUSY_ON_H0 ? (!last_H0 && H[0] && pxl_cen) : 1'b1;

always @(posedge clk) begin : busy_latch
    last_H0 <= H[0];
    if( cs && scan_sel && posedge_H0 )
        busy <= 1'b1;
    else busy <= 1'b0;
end

always @(posedge clk) if(pxl_cen) begin : scan_select
    if( !cs )
        scan_sel <= 1'b1;
    else if(H[2:0]==DATAREAD)
        scan_sel <= 1'b0;
end

reg [7:0] udlatch, ldlatch;
reg last_scan;

always @(posedge clk) begin : mem_mux
    reg last_Asel;

    if( scan_sel ) begin
        addr      <= scan;
        we_low    <= 1'b0;
        we_high   <= 1'b0;
    end else begin
        addr      <= AB;
        if( DW == 16 ) begin
            we_low    <= cs && !wr_n && !dseln[0];
            we_high   <= cs && !wr_n && !dseln[1];
            udlatch    <= din[15:8];
            ldlatch    <= din[7:0];
        end else begin
            we_low    <= cs && !wr_n && !Asel;
            we_high   <= cs && !wr_n &&  Asel;
            udlatch    <= din;
            ldlatch    <= din;
        end
        last_Asel <= Asel;
    end

    // Output latch
    last_scan <= scan_sel;
    if( !last_scan )
        if(DW==8)
            dout <= last_Asel ? mem_high : mem_low;
        else
            dout <= { mem_high, mem_low };
end

// Use these macros to add simulation files
// like 
// ',.simhexfile("sim.hex")' or
// ',.simfile("sim.bin")'
// when calling the simulation script:
// go.sh \
//    -d JTCHAR_LOWER_SIMFILE=',.simfile("scr0.bin")' \
//    -d JTCHAR_UPPER_SIMFILE=',.simfile("scr1.bin")' 


`ifndef JTCHAR_UPPER_SIMFILE
`define JTCHAR_UPPER_SIMFILE
`endif

`ifndef JTCHAR_LOWER_SIMFILE
`define JTCHAR_LOWER_SIMFILE
`endif

jtframe_ram #(.aw(SCANW) `JTCHAR_LOWER_SIMFILE) u_ram_low(
    .clk    ( clk      ),
    .cen    ( 1'b1     ),
    .data   ( ldlatch  ),
    .addr   ( addr     ),
    .we     ( we_low   ),
    .q      ( mem_low  )
);

// attributes
// the default value for synthesis will display a ROM load message using
// the palette attributes
jtframe_ram #(.aw(SCANW) `JTCHAR_UPPER_SIMFILE) u_ram_high(
    .clk    ( clk      ),
    .cen    ( 1'b1     ),
    .data   ( udlatch  ),
    .addr   ( addr     ),
    .we     ( we_high  ),
    .q      ( mem_high )
);

always @(posedge clk) begin
    if(last_scan) begin
        dout_low  <= pause ? msg_low  : mem_low;
        dout_high <= pause ? msg_high : mem_high;
    end
end

endmodule
