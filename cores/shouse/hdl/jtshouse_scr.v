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
    Date: 26-9-2023 */

// Implementation of C123 tilemaps
// based on MAME's namo_c123tmap.cpp and Atari's schematics
// 6 layers = 4 scroll + 2 fix
// 8x8 pixels, 8 bpp

module jtshouse_scr(
    input             rst,
    input             clk,

    input             pxl_cen,
    input       [8:0] hdump,
    input       [8:0] vdump,
    input             flip,

    input             cs,
    input       [4:0] addr,
    input             rnw,
    input       [7:0] din,
    output reg  [7:0] dout,

    // Tile map readout (BRAM)
    output     [14:1] tmap_addr,
    input      [15:0] tmap_dout,
    // Mask readout (SDRAM)
    output reg        mask_cs,
    input             mask_ok,
    output reg [16:0] mask_addr,
    input      [ 7:0] mask_data,
    // Tile readout (SDRAM)
    output            scr_cs,
    input             scr_ok,
    output     [19:0] scr_addr,
    input      [ 7:0] scr_data,
    // Pixel output
    output reg [10:0] pxl,
    output reg [ 2:0] prio,
    // Debug
    input      [ 7:0] debug_bus,
    output reg [ 7:0] st_dout
);

reg  [ 7:0] mmr[0:31];
reg  [ 7:0] maskin[0:5];
reg  [15:0] hpos, vpos, nx_hpos, nx_vpos;
reg  [13:0] mux;
reg  [ 2:0] tcnt, nx_prio, nx_pal;
wire [ 2:0] idx;
reg  [ 3:0] cfg[0:5];
reg  [13:0] info[0:5];
wire [ 3:0] nx_cfg;
// mapped by priority
reg  [ 7:0] maskll[0:7];
reg  [13:0] infoll[0:7];
integer     i, j;

assign idx = flip ? 3'd7 : 3'd0;
assign tmap_addr = tcnt<3 ? { tcnt[1:0],       hpos[3+:6], vpos[3+:6] }: // 3 + 12 = 14 bits
                   tcnt<4 ? { tcnt[1:0], 1'b0, hpos[3+:6], vpos[3+:5] }:
                            { 3'd7, tcnt[0],   hpos[3+:5], vpos[3+:5] }; // not sure about this one
assign scr_addr  = { mux[13:0], hpos[2:0], vpos[2:0] };
assign scr_cs    = 1;
assign nx_cfg    = mmr[{2'b10, tcnt }][3:0];

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        for(i=0;i<32;i=i+1) mmr[i]<=0; // ignore latch warning by Quartus here
    end else begin
        dout    <= mmr[addr];
        st_dout <= mmr[debug_bus[4:0]];
        if( cs & ~rnw ) mmr[addr]<=din;
    end
end

always @* begin
    if( tcnt>3 )
        { nx_vpos, nx_hpos } = { 7'd0, vdump, 7'd0, hdump };
    else
        { nx_vpos, nx_hpos } = { {mmr[{tcnt,2'd2}], mmr[{tcnt,2'd3}]}+{7'd0,vdump},
                                 {mmr[{tcnt,2'd0}], mmr[{tcnt,2'd1}]}+{7'd0,hdump} };
    if( flip ) begin
        nx_hpos = -nx_hpos;
        nx_vpos = -nx_vpos;
    end
end

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        tcnt      <= 0;
        vpos      <= 0;
        hpos      <= 0;
        mask_cs   <= 0;
        mask_addr <= 0;
        mux       <= 0;
        pxl       <= 0;
        prio      <= 0;
        nx_prio   <= 0;
        nx_pal    <= 0;
        for( i=0; i< 6; i=i+1 ) begin
            maskin[i] <= 0;
            info  [i] <= 0;
        end
        for( i=0; i< 8; i=i+1 ) begin
            maskll[i] <= 0;
            infoll[i] <= 0;
        end
    end else begin
        { vpos, hpos } <= { nx_vpos, nx_hpos };
        if( pxl_cen ) begin
            tcnt <= hdump[2:0]==0 ? 3'd0 : tcnt+3'd1;
            if( tcnt<6 ) begin
                mask_addr  <= { tmap_dout[13:0], vpos[2:0] }; // 17 bits
                mask_cs    <= 1;
                info[nx_cfg[2:0]] <= tmap_dout[13:0];
                cfg[tcnt]  <= nx_cfg;
            end else begin
                mask_cs    <= 0;
            end
            if( tcnt>=2 && tcnt<7 ) maskin[tcnt-3'd2] <= mask_data; // assumes mask_ok=1
            for( i=0; i<6; i=i+1 ) begin
                if( tcnt==7 ) begin
                    for( j=0; j<8; j=j+1 ) maskll[j] <= 0;
                    maskll[cfg[i][2:0]] <= cfg[i][3] ? 8'd0 : maskin[i] ;
                    infoll[cfg[i][2:0]] <= info[i];
                end else begin
                    maskll[i] <= flip ? maskll[i]<<1 : maskll[i]>>1;
                end
            end
            case(1'b1)
                maskll[0][idx]: begin mux <= infoll[0]; nx_prio <= 0; nx_pal <= mmr[5'h18][2:0]; end
                maskll[1][idx]: begin mux <= infoll[1]; nx_prio <= 1; nx_pal <= mmr[5'h19][2:0]; end
                maskll[2][idx]: begin mux <= infoll[2]; nx_prio <= 2; nx_pal <= mmr[5'h1A][2:0]; end
                maskll[3][idx]: begin mux <= infoll[3]; nx_prio <= 3; nx_pal <= mmr[5'h1B][2:0]; end
                maskll[4][idx]: begin mux <= infoll[4]; nx_prio <= 4; nx_pal <= mmr[5'h1C][2:0]; end
                maskll[5][idx]: begin mux <= infoll[5]; nx_prio <= 5; nx_pal <= mmr[5'h1D][2:0]; end
                maskll[6][idx]: begin mux <= infoll[6]; nx_prio <= 6; nx_pal <= mmr[5'h1E][2:0]; end
                maskll[7][idx]: begin mux <= infoll[7]; nx_prio <= 7; nx_pal <= mmr[5'h1F][2:0]; end
            endcase
            { pxl, prio } <= { nx_pal, scr_data, nx_prio };
        end
    end
end

endmodule