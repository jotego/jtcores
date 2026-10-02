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
// one unit: the programmed edge is (reg+1)*4 or (reg+1)*2.
//
//        reg  00   01   02   03   08   09   0a   0b
//   pspikes   352  400  424  456  240  244  248  256
//
// That table is the only default in this module. Every game programs its own
// grid at boot, and scene replay - which has no CPU - restores the register
// file from gga.bin, the way jt053936 restores itself from psac.bin.
//
// Regs 04/05/0c/0d have no known effect. H total must stay under 512.

module jtpspike_gga(
    input             rst,
    input             clk,
    input             pxl_cen,

    // CPU write port. Data is the low byte of the 68000 word (umask 00ff)
    input             cs,
    input             we,
    input             addr,       // 0 = data, 1 = address latch
    input      [ 7:0] din,

    output     [ 8:0] h_last,     // last H count, for the layer hdump lead
    output     [ 8:0] hsize,      // visible width  in pixels
    output     [ 8:0] vsize,      // visible height in lines
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

// Scene replay has no CPU to program the grid, so the registers are restored
// from the dump - the same way jt053936 loads psac.bin. Absent the file the
// power-on table below is used, so a normal boot sim is unaffected.
`ifdef SIMULATION
reg  [7:0] gga_init[0:15];
reg        gga_ok=0;
integer    ggaf, ggacnt, gi;
initial begin
    for( gi=0; gi<16; gi=gi+1 ) gga_init[gi] = 8'd0;
    ggaf = $fopen("gga.bin","rb");
    if( ggaf!=0 ) begin
        ggacnt = $fread(gga_init,ggaf);
        $fclose(ggaf);
        if( ggacnt==16 ) begin
            gga_ok = 1;
            $display("GGA %m - restored %0d registers from gga.bin",ggacnt);
        end else begin
            $display("GGA %m - gga.bin is %0d bytes, expected 16",ggacnt);
        end
    end
end
`define GGA_R(k,dflt) (gga_ok ? gga_init[k] : dflt)
`else
`define GGA_R(k,dflt) dflt
`endif
reg  [3:0] alatch;
reg        LVBL2, LVBL1;

// (reg+1)*4 for H, (reg+1)*2 for V
function [8:0] hval(input [7:0] r); hval = { r[6:0], 2'd0 } + 9'd4; endfunction
function [8:0] vval(input [7:0] r); vval = { r[7:0], 1'd0 } + 9'd2; endfunction
// reg 08 = 7a decodes to 246 but only 240 lines reach the screen, on every
// game that programs it: f1gp, sformula, tail2nos, welltris, pipedrm, hatris
// and the fromance family. Every other value is displayed in full. See
// doc/GGA.md. The six lines are cut, not blanked - hardware footage is
// centred with no dead lines at either edge
function [8:0] vheight(input [7:0] r);
    vheight = vval(r)==9'd246 ? 9'd240 : vval(r);
endfunction

// The CPU programs the table one byte at a time, so the raw registers pass
// through nonsense combinations mid-sequence. Latch them once per frame: the
// counters then only ever see a complete table, and the video mode changes
// exactly once instead of wobbling through garbage modes that the MiSTer
// scaler can lock onto until a reset.
reg [8:0] hb_start, hs_start, hs_end, h_lastr, vb_start, vs_start, vs_end, v_last;
assign    h_last = h_lastr;
assign    hsize  = hb_start + 9'd1;
assign    vsize  = vb_start + 9'd1;

// Candidate table, straight off the raw registers
wire [8:0] nhb = hval(regs[ 0]) - 9'd1,   // last visible pixel
           nhs = hval(regs[ 1]),
           nhe = hval(regs[ 2]),
           nhl = hval(regs[ 3]) - 9'd1,
           nvb = vheight(regs[ 8]) - 9'd1,   // last visible line
           nvs = vval(regs[ 9]),
           nve = vval(regs[10]),
           nvl = vval(regs[11]) - 9'd1;

// Every counter event below is an equality, and H only ever sweeps 0..h_last,
// vdump only 0..v_last. An edge programmed beyond its total is therefore never
// reached: the vertical counter stops, HS and VS stop, and because this latch
// is itself gated on those events nothing can ever restore it - the module
// wedges until reset. Reject such a table and keep the previous one.
wire tbl_ok = nhb<=nhl && nhs<=nhl && nhe<=nhl && nhs<nhe &&
              nvb<=nvl && nvs<=nvl && nve<=nvl && nvs<nve;

// The CPU writes the eight registers one byte at a time, so a latch landing
// mid-sequence still snapshots a mix of old and new bytes. tbl_ok rejects the
// mixes that would stop the counters, but belt and braces: if the normal latch
// point has not been seen for ~2 frames the table is reloaded anyway, so no
// combination of writes can leave the timing dead.
reg  [17:0] wdog;
wire        tick_norm = H==hs_start && vdump==vs_start;
wire        do_latch  = tick_norm | (&wdog);

always @(posedge clk) begin
    if( rst ) wdog <= 0;
    else if( pxl_cen ) wdog <= do_latch ? 18'd0 : wdog + 18'd1;
end

always @(posedge clk) begin
    if( rst ) begin
        // regs[] are loaded this same cycle, so take the defaults directly
        hb_start <= hval(`GGA_R( 0,8'h57)) - 9'd1;
        hs_start <= hval(`GGA_R( 1,8'h63));
        hs_end   <= hval(`GGA_R( 2,8'h69));
        h_lastr  <= hval(`GGA_R( 3,8'h71)) - 9'd1;
        vb_start <= vheight(`GGA_R( 8,8'h77)) - 9'd1;
        vs_start <= vval(`GGA_R( 9,8'h79));
        vs_end   <= vval(`GGA_R(10,8'h7b));
        v_last   <= vval(`GGA_R(11,8'h7f)) - 9'd1;
    end else if( pxl_cen && do_latch && tbl_ok ) begin
        hb_start <= nhb;
        hs_start <= nhs;
        hs_end   <= nhe;
        h_lastr  <= nhl;
        vb_start <= nvb;
        vs_start <= nvs;
        vs_end   <= nve;
        v_last   <= nvl;
    end
end

// Reset defaults are also the scene-replay configuration: NOMAIN never writes
always @(posedge clk) begin
    if( rst ) begin
        regs[ 0] <= `GGA_R( 0,8'h57);
        regs[ 1] <= `GGA_R( 1,8'h63);
        regs[ 2] <= `GGA_R( 2,8'h69);
        regs[ 3] <= `GGA_R( 3,8'h71);
        regs[ 4] <= `GGA_R( 4,8'h1f); regs[ 5] <= `GGA_R( 5,8'h00);
        regs[ 6] <= `GGA_R( 6,8'h00); regs[ 7] <= `GGA_R( 7,8'h00);
        regs[ 8] <= `GGA_R( 8,8'h77);
        regs[ 9] <= `GGA_R( 9,8'h79);
        regs[10] <= `GGA_R(10,8'h7b);
        regs[11] <= `GGA_R(11,8'h7f);
        regs[12] <= `GGA_R(12,8'h1f);
        regs[13] <= `GGA_R(13,8'h00);
        regs[14] <= 8'h00; regs[15] <= 8'h00;
        alatch   <= 0;
    end else if( cs & we ) begin
        if( addr )
            alatch <= din[3:0];
        else
            regs[alatch] <= din;
    end
end

// wrap compares are >=: a register write below the current count must not wedge
always @(posedge clk) begin
    if( rst ) begin
        H     <= 9'd0;
        Hinit <= 0;
    end else if( pxl_cen ) begin
        Hinit <= H == hs_start;
        H     <= H >= h_last ? 9'd0 : H + 9'd1;
    end
end

always @(posedge clk) begin
    if( rst ) begin
        // start at the top of vertical blanking, as jtframe_vtimer does
        vdump    <= 9'd0;
        vrender  <= 9'd1;
        vrender1 <= 9'd2;
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

endmodule
