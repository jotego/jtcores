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

    input             hs,
    input             vs,
    input       [8:0] hdump,
    input       [8:0] vrender,
    input             flip,

    input             cs,
    input       [4:0] addr,
    input             rnw,
    input       [7:0] din,
    output reg  [7:0] dout,

    // Tile map readout (BRAM)
    output reg [14:1] tmap_addr,
    input      [15:0] tmap_data,
    // Mask readout (SDRAM)
    output reg        mask_cs,
    input             mask_ok,
    output reg [16:0] mask_addr,
    input      [ 7:0] mask_data,
    // Tile readout (SDRAM)
    output            scr_cs,
    input             scr_ok,
    output reg [19:0] scr_addr,
    input      [ 7:0] scr_data,
    // Pixel output
    output     [10:0] pxl,
    output     [ 2:0] prio,
    // IOCTL dump
    input      [ 4:0] ioctl_addr,
    output     [ 7:0] ioctl_din,
    // Debug
    input      [ 7:0] debug_bus,
    output reg [ 7:0] st_dout
);

localparam [ 8:0] HMARGIN=9'h8,
                  HSTART=9'h40-HMARGIN,
                  HEND=9'd288+HSTART+(HMARGIN<<1); // hdump is non blank from 'h40 to 'h160

// MMR
// 0~F scroll positions
// tilemap 3 bits - scroll X/Y 1 bit - upper/lower byte sel 1 bit
// 10~17 priority
// 18~1F color

reg  [ 7:0] mmr[0:31]; // upper bits probably did not exist for the upper half of the MMR
reg  [15:0] hpos, vpos, nx_hpos, nx_vpos;
reg  [ 2:0] pal, mlyr, mst;
reg  [ 5:0] mreq;
wire [ 2:0] tcnt;
// mapped by priority
reg  [ 7:0] nx_mask[0:7], mask[0:7];
reg  [22:0] info[0:7];
reg  [ 8:0] hcnt;
reg  [10:0] bpxl;
reg  [ 9:0] lin_row;   // linear "row" count (does not count during blanks)
reg  [ 9:0] linear;    // linear position ("row"+col)
reg  [ 2:0] bprio, win, nx_prio, hcnt0, hcnt1, hcnt2, hcnt3;
reg         hs_l, done, alt_cen, vs_l;
wire        buf_we, rom_ok, hs_edge;
// Horizontal scroll
wire [15:0] hscr0, hscr1, hscr2, hscr3;
integer     i;
`ifdef SIMULATION
    reg       miss;
`endif

assign scr_cs    = 1;
assign tcnt      = hcnt[2:0];
assign ioctl_din = mmr[ioctl_addr];
assign buf_we    = alt_cen & ~done;
assign rom_ok    = scr_ok & (mask_ok | ~mask_cs) & mlyr==7;
assign hscr0     = {mmr[{3'd0,2'd0}], mmr[{3'd0,2'd1}]}/*+aux[15:0]*/;
assign hscr1     = {mmr[{3'd1,2'd0}], mmr[{3'd1,2'd1}]}/*+aux[15:0]*/;
assign hscr2     = {mmr[{3'd2,2'd0}], mmr[{3'd2,2'd1}]}/*+aux[15:0]*/;
assign hscr3     = {mmr[{3'd3,2'd0}], mmr[{3'd3,2'd1}]}/*+aux[15:0]*/;
assign hs_edge   = hs & ~hs_l;

// Memory Mapped Registers
always @(posedge clk, posedge rst) begin
    if( rst ) begin
        for(i=0;i<32;i=i+1) `ifndef SIMULATION
            mmr[i]<=0; // ignore latch warning by Quartus here
        `else
            mmr[i]<=mmr_init[i];
        `endif
    end else begin
        dout    <= mmr[addr];
        st_dout <= mmr[debug_bus[4:0]];
        if( cs & ~rnw ) mmr[addr]<=din;
    end
end

always @* begin
    mlyr = 7;
    if( hcnt0==0 && mreq[0] ) mlyr = 0; else
    if( hcnt1==0 && mreq[1] ) mlyr = 1; else
    if( hcnt2==0 && mreq[2] ) mlyr = 2; else
    if( hcnt3==0 && mreq[3] ) mlyr = 3; else
    if( hcnt[2:0]==0 ) begin
        if( mreq[4] ) mlyr = 4; else
        if( mreq[5] ) mlyr = 5;
    end
end
// fixed tile maps are packed in memory and do not fit into a H-V binary split
always @* begin
    case( mlyr )
        0: tmap_addr = { 2'd0, vpos[3+:6], hpos[3+:6] };
        1: tmap_addr = { 2'd1, vpos[3+:6], hpos[3+:6] };
        2: tmap_addr = { 2'd2, vpos[3+:6], hpos[3+:6] };
        3: tmap_addr = { 3'd3, vpos[3+:5], hpos[3+:6] };
        4: tmap_addr = { 4'b1110, linear };
        5: tmap_addr = { 4'b1111, linear };
        default: tmap_addr = 0;
    endcase
end

// Horizontal counter that waits for SDRAM
always @(posedge clk, posedge rst) begin
    if( rst ) begin
        hs_l <= 0;
        hcnt <= 0;
        done <= 0;
        lin_row <= 0;
        alt_cen <= 0;
    end else begin
        alt_cen <= ~alt_cen & rom_ok;
        if( hcnt < HEND && alt_cen) begin
            hcnt  <= hcnt +9'd1;
            hcnt0 <= hcnt0+3'd1;
            hcnt1 <= hcnt1+3'd1;
            hcnt2 <= hcnt2+3'd1;
            hcnt3 <= hcnt3+3'd1;
        end
        `ifdef SIMULATION miss <= 0; `endif
        hs_l    <= hs;

        if( hs_edge ) begin
            `ifdef SIMULATION miss  <= !done; `endif
            hcnt  <= HSTART;
            hcnt0 <= hscr0[2:0];
            hcnt1 <= hscr1[2:0];
            hcnt2 <= hscr2[2:0];
            hcnt3 <= hscr3[2:0];
            if(vrender[2:0]==7) lin_row <= lin_row+10'd36;
        end
        if( vrender==9'h110 ) lin_row <= 0;
        done <= hcnt==HEND;
    end
end

always @* begin
    if( mlyr>3 )
        { nx_vpos, nx_hpos } = { 7'd0, vrender, 7'd0, hcnt };
    else
        { nx_vpos, nx_hpos } = { {7'd0,vrender}-{mmr[{mlyr,2'd2}], mmr[{mlyr,2'd3}]},
                                 {7'd0,   hcnt}-{mmr[{mlyr,2'd0}], mmr[{mlyr,2'd1}]} /*+ aux[15:0]*/};
    nx_hpos = nx_hpos;
    if( flip ) begin
        nx_hpos = -nx_hpos;
        nx_vpos = -nx_vpos;
    end
end

// Determines the active layer
always @* begin // Keep the line order (priority)
    win = 0;
    if( mask[1][7] ) win = 1;
    if( mask[2][7] ) win = 2;
    if( mask[3][7] ) win = 3;
    if( mask[4][7] ) win = 4;
    if( mask[5][7] ) win = 5;
    if( mask[6][7] ) win = 6;
    if( mask[7][7] ) win = 7;
end

// reg [2:0] hoffset;

// always @* begin
//     hoffset = debug_bus[2:0];
//     case(mlyr)
//         0: hoffset = 5;      // verified - splatter logo
//         4,5: hoffset = 5;
//         // default: hoffset = aux[2:0];
//     endcase
// end

// Pixel drawing
always @(posedge clk, posedge rst) begin
    if( rst ) begin
        vpos      <= 0;
        hpos      <= 0;
        mask_cs   <= 0;
        mask_addr <= 0;
        bpxl      <= 0;
        bprio     <= 0;
        pal       <= 0;
        mreq      <= 0;
        mst       <= 0;
    end else begin
        // register scroll position
        { vpos, hpos } <= { nx_vpos, nx_hpos };
        linear <= lin_row + {4'd0,hpos[3+:6]};

        if( mlyr!=7 & (mask_ok|~mask_cs) ) mst<= mst==4 ? 3'd0 : mst+3'd1;

        case( mst )
            2: begin
                mask_addr  <= { tmap_data[13:0], vpos[2:0]+debug_bus[2:0] }; // 17 bits
                mask_cs    <= ~mmr[{2'b10,mlyr}][3]; // do not request disabled layers
            end
            4: begin
                if(mask_cs) begin
                    mask[mmr[{2'b10,mlyr}][2:0]] <= mask_data;
                    info[mmr[{2'b10,mlyr}][2:0]] <= { mmr[{2'b11,mlyr}][2:0], tmap_data[13:0], vpos[2:0], debug_bus[6:4]-tcnt };
                end
                mreq[mlyr] <= ~(mask_ok | ~mask_cs);
                mask_cs    <= 0;
            end
        endcase
        if( alt_cen ) begin
            if( hcnt0==7 ) mreq[0] <= 1;
            if( hcnt1==7 ) mreq[1] <= 1;
            if( hcnt2==7 ) mreq[2] <= 1;
            if( hcnt3==7 ) mreq[3] <= 1;
            if( hcnt[2:0]==7 ) mreq[5:4] <= 3;
            { bprio, bpxl } <= { nx_prio, pal, scr_data };
            for( i=0; i<8; i=i+1 ) mask[i] <= mask[i] << 1;
            // Get next pixel information
            { nx_prio, pal, scr_addr } <= { win, info[win][3+:20], info[win][2:0]+tcnt };
        end
        if( hs_edge ) begin
            mreq <= 0;
            mst  <= 0;
        end
    end
end

jtframe_linebuf #(.DW(14)) u_buffer(
    .clk        ( clk       ),
    .LHBL       ( ~hs       ),
    .wr_addr    ( hcnt      ),
    .wr_data    ({bpxl,bprio}),
    .we         ( buf_we    ),
    .rd_addr    ( hdump     ),
    .rd_data    ({pxl,prio} ),
    .rd_gated   (           )
);

integer aux;

always @(posedge clk) begin
    vs_l <= vs;
    if( vs & ~vs_l ) aux <= aux+1;
end

`ifdef SIMULATION
/* verilator tracing_off */
integer f, fcnt;
reg [7:0] mmr_init[0:31];
initial begin
    f=$fopen("rest.bin","rb");
    if( f!=0 ) begin
        fcnt=$fread(mmr_init,f);
        $display("INFO: Read %d bytes for %m.mmr",fcnt);
    end
    $fclose(f);
end

int reported=0;

always @(posedge miss) begin
    if(reported==1 ) $display("Scroll line missed");
    reported<=reported+1;
end
`endif

endmodule