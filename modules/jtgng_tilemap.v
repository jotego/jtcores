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
    SELBIT      = 2,
    INVERT_SCAN = 0,
    DATAREAD    = 3'd2,
    SCANW       = 10,
    BUSY_ON_H0  = 0     // if 1, the busy signal is asserted only at H0 posedge, otherwise it uses the regular clock
) (
    input            clk,
    input            pxl_cen /* synthesis direct_enable = 1 */,
    input            Asel,  // This is the address bit that selects
                            // between the low and high tile map
    input      [SCANW-1:0] AB,
    input      [7:0] V,
    input      [7:0] H,
    input            flip,
    input      [7:0] din,
    output reg [7:0] dout,
    // Bus arbitrion
    input            cs,
    input            wr_n,
    output reg       busy,
    // Pause screen
    input            pause,
    output reg [SCANW-1:0] scan,
    input      [7:0] msg_low,
    input      [7:0] msg_high,
    // Current tile
    output reg [7:0] dout_low,
    output reg [7:0] dout_high
);

reg scan_sel = 1'b1;

always @(*) begin
    if( SCANW <= 10) begin
        scan = (INVERT_SCAN ? { {SCANW{flip}}^{H[7:3],V[7:3]}} 
            : { {SCANW{flip}}^{V[7:3],H[7:3]}}) >> (10-SCANW);
    end else begin
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

reg [7:0] dlatch;
reg last_scan;

always @(posedge clk) begin : mem_mux
    reg last_Asel;

    if( scan_sel ) begin
        addr      <= scan;
        we_low    <= 1'b0;
        we_high   <= 1'b0;
    end else begin
        addr      <= AB;
        we_low    <= cs && !wr_n && !Asel;
        we_high   <= cs && !wr_n &&  Asel;
        dlatch    <= din;
        last_Asel <= Asel;
    end

    // Output latch
    last_scan <= scan_sel;
    if( !last_scan )
        dout <= last_Asel ? mem_high : mem_low;
end

// block ID
jtgng_ram #(.aw(SCANW)) u_ram_low(
    .clk    ( clk      ),
    .cen    ( 1'b1     ),
    .data   ( dlatch   ),
    .addr   ( addr     ),
    .we     ( we_low   ),
    .q      ( mem_low  )
);

// attributes
// the default value for synthesis will display a ROM load message using
// the palette attributes
jtgng_ram #(.aw(SCANW)/*,.synfile("rom_loadv.hex")*/) u_ram_high(
    .clk    ( clk      ),
    .cen    ( 1'b1     ),
    .data   ( dlatch   ),
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
