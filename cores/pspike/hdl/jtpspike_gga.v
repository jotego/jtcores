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

    Author: Andrea Bogazzi <andreabogazzi79@gmail.com>
    Version: 1.0
    Date: 11-8-2026 */

// Video System C7-01 GGA - video timing gate array.
// Write-only address/data pair: even byte = data, odd byte = address latch.
// The counter body is jtframe_vtimer with the parameters turned into wires.
//
// Registers hold the count in units of 4 pixels (H) or 2 lines (V), biased by
// one unit, so the programmed edge is (reg+1)*4 or (reg+1)*2. Captured from
// MAME (skeleton device, logs every write):
//
//        reg  00   01   02   03   08   09   0a   0b
//   pspikes   352  400  424  456  240  244  248  256   also turbofrc
//   aerofgtb  320  376  400  456  224  226  230  250
//
// Regs 04/05/0c/0d read 1f/00/1f/00 on every game in MAME's table (aerofgtb
// puts 02 in 0d) and have no known effect. They are stored, not used.
//
// H totals above 511 do not fit the 9-bit counters. Every known game programs
// 456.

module jtpspike_gga(
    input             rst,
    input             clk,
    input             pxl_cen,
    input             aerofgt,    // picks the reset default table

    // CPU write port. Data is the low byte of the 68000 word (umask 00ff)
    input             cs,
    input             we,
    input             addr,       // 0 = data, 1 = address latch
    input      [ 7:0] din,

    output     [ 8:0] h_last,     // last H count, for the layer hdump lead
    output reg [ 8:0] vdump,
    output reg [ 8:0] vrender,    // 1 line ahead of vdump
    output reg [ 8:0] vrender1,   // 2 lines ahead
    output reg [ 8:0] H,
    output reg        Hinit,
    output reg        Vinit,
    output reg        LHBL,
    output reg        LVBL,
    output reg        HS,
    output reg        VS
);

reg  [7:0] regs[0:15];
reg  [3:0] alatch;
reg        LVBL2, LVBL1;

// (reg+1)*4 for H, (reg+1)*2 for V
function [8:0] hval(input [7:0] r); hval = { r[6:0], 2'd0 } + 9'd4; endfunction
function [8:0] vval(input [7:0] r); vval = { r[7:0], 1'd0 } + 9'd2; endfunction

wire [8:0] hb_start = hval(regs[ 0]) - 9'd1;    // last visible pixel
wire [8:0] hs_start = hval(regs[ 1]);
wire [8:0] hs_end   = hval(regs[ 2]);
assign     h_last   = hval(regs[ 3]) - 9'd1;
wire [8:0] vb_start = vval(regs[ 8]) - 9'd1;    // last visible line
wire [8:0] vs_start = vval(regs[ 9]);
wire [8:0] vs_end   = vval(regs[10]);
wire [8:0] v_last   = vval(regs[11]) - 9'd1;

// Reset loads the table the game is going to program anyway, so the picture is
// stable through reset and the ROM download. It also IS the configuration for
// scene replay, where NOMAIN means no CPU ever writes the chip.
always @(posedge clk) begin
    if( rst ) begin
        regs[ 0] <= aerofgt ? 8'h4f : 8'h57;
        regs[ 1] <= aerofgt ? 8'h5d : 8'h63;
        regs[ 2] <= aerofgt ? 8'h63 : 8'h69;
        regs[ 3] <= 8'h71;
        regs[ 4] <= 8'h1f; regs[ 5] <= 8'h00; regs[ 6] <= 8'h00; regs[ 7] <= 8'h00;
        regs[ 8] <= aerofgt ? 8'h6f : 8'h77;
        regs[ 9] <= aerofgt ? 8'h70 : 8'h79;
        regs[10] <= aerofgt ? 8'h72 : 8'h7b;
        regs[11] <= aerofgt ? 8'h7c : 8'h7f;
        regs[12] <= 8'h1f;
        regs[13] <= aerofgt ? 8'h02 : 8'h00;
        regs[14] <= 8'h00; regs[15] <= 8'h00;
        alatch   <= 0;
    end else if( cs & we ) begin
        if( addr )
            alatch <= din[3:0];
        else
            regs[alatch] <= din;
    end
end

// H counter. The wrap compares are >= so a register write that moves the
// total below the current count cannot wedge the counter.
always @(posedge clk) begin
    if( rst ) begin
        H     <= hb_start;  // start of horizontal blanking, matches MAME
        Hinit <= 0;
    end else if( pxl_cen ) begin
        Hinit <= H == hs_start;
        H     <= H >= h_last ? 9'd0 : H + 9'd1;
    end
end

always @(posedge clk) begin
    if( rst ) begin
        // start at the top of vertical blanking, as jtframe_vtimer does
        vdump    <= vb_start;
        vrender  <= vb_start + 9'd1;
        vrender1 <= vb_start + 9'd2;
        Vinit    <= 0;
        LVBL     <= 0;
        LVBL1    <= 0;
        LVBL2    <= 0;
        LHBL     <= 1;
        HS       <= 0;
        VS       <= 0;
    end else if( pxl_cen ) begin
        if( H == hs_start ) begin
            Vinit    <= vdump == v_last;
            vrender1 <= vrender1 >= v_last ? 9'd0 : vrender1 + 9'd1;
            vrender  <= vrender1;
            vdump    <= vrender;
        end

        if( H == hb_start ) LHBL <= 0; else if( H == h_last ) LHBL <= 1;

        if( H == hb_start ) begin
            { LVBL, LVBL1 } <= { LVBL1, LVBL2 };
            if     ( vrender1 == vb_start ) LVBL2 <= 0;
            else if( vrender1 == v_last   ) LVBL2 <= 1;
        end

        if( H == hs_start ) HS <= 1;
        if( H == hs_end   ) begin
            HS <= 0;
            if( vdump == vs_start ) VS <= 1;
            if( vdump == vs_end   ) VS <= 0;
        end
    end
end

`ifdef SIMULATION
// the reset defaults are the pspikes table, so for that game the grid never
// changes and only the write probe proves the decode is alive
always @(posedge clk) if( cs & we )
    $display("GGA write %s = %02x", addr ? "addr" : "data", din);

// report the programmed grid once the game has written its table
reg [8:0] last_h=0, last_v=0;
always @(posedge clk) if( !rst ) begin
    if( h_last != last_h || v_last != last_v ) begin
        last_h <= h_last;
        last_v <= v_last;
        $display("GGA: %0dx%0d visible, %0dx%0d total, HS %0d-%0d, VS %0d-%0d",
            hb_start+9'd1, vb_start+9'd1, h_last+9'd1, v_last+9'd1,
            hs_start, hs_end, vs_start, vs_end);
    end
end
`endif

endmodule
