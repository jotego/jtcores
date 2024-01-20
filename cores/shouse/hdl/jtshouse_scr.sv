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
    output      [7:0] dout,

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
    output     [ 7:0] st_dout
);

localparam [ 8:0] HMARGIN=9'h8,
                  HSTART=9'h40-HMARGIN,
                  HEND=9'd288+HSTART+(HMARGIN<<1); // hdump is non blank from 'h40 to 'h160
localparam [15:0] HSCR= 16'h73,
                  VSCR=-16'h07;

reg  [15:0] hpos, vpos;
reg  [ 2:0] mlyr, mst;
reg  [ 5:0] mreq, attr;
wire [ 2:0] tcnt;
// mapped by priority
reg  [ 7:0] nx_mask[0:7], mask[0:7];
reg  [22:0] info[0:7];
reg  [ 8:0] hcnt, buf_a;
reg  [10:0] bpxl;
reg  [ 9:0] lin_row;   // linear "row" count (does not count during blanks)
reg  [ 9:0] linear;    // linear position ("row"+col)
reg  [ 2:0] bprio, win, hcnt0, hcnt1, hcnt2, hcnt3;
reg         hs_l, done, alt_cen, vs_l;
wire        buf_we, rom_ok, hs_edge, mask_good;

// Layer configuration
wire [3:0][15:0] hscr, vscr;
wire [5:0][ 2:0] cfg_pal, cfg_prio;
wire [5:0]       cfg_enb;

integer     i;
`ifdef SIMULATION
    reg       miss;
`endif

assign scr_cs    = 1;
assign tcnt      = hcnt[2:0];
assign buf_we    = alt_cen & ~done;
assign rom_ok    = scr_ok & mlyr==7;
assign hs_edge   = hs & ~hs_l;
assign mask_good = mask_ok|~mask_cs;

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
            hcnt0 <= -hscr[0][2:0]+HSCR[2:0];
            hcnt1 <= -hscr[1][2:0]+HSCR[2:0];
            hcnt2 <= -hscr[2][2:0]+HSCR[2:0];
            hcnt3 <= -hscr[3][2:0]+HSCR[2:0];
            if(vrender[2:0]==7) lin_row <= lin_row+10'd36;
        end
        if( vrender==9'h110 ) lin_row <= 1;
        done <= hcnt==HEND;
    end
end

always @* begin
    if( mlyr>3 )
        { vpos, hpos } = { 7'd0, vrender, 7'd0, hcnt };
    else
        { vpos, hpos } = { {7'd0, vrender}-vscr[mlyr[1:0]]+VSCR,
                           {7'd0,    hcnt}-hscr[mlyr[1:0]]+HSCR};
    if( flip ) begin
        hpos = -hpos;
        vpos = -vpos;
    end
    // Determines the active layer
    win = 0; // Keep the line order (priority):
    if( mask[1][7] ) win = 1;
    if( mask[2][7] ) win = 2;
    if( mask[3][7] ) win = 3;
    if( mask[4][7] ) win = 4;
    if( mask[5][7] ) win = 5;
    if( mask[6][7] ) win = 6;
    if( mask[7][7] ) win = 7;
end

always @* begin // Mask reload - keep in its own always block
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

// reg [2:0] hos, vos, vmos;

// always @* begin
//     hos = hos+debug_bus[2:0];
//     vos = vos+debug_bus[2:0];
//     if( mlyr>=4 ) begin
//         hos=
//     end
// end

// Pixel drawing
always @(posedge clk, posedge rst) begin
    if( rst ) begin
        mask_cs   <= 0;
        mask_addr <= 0;
        bpxl      <= 0;
        bprio     <= 0;
        attr      <= 0;
        mreq      <= 0;
        mst       <= 0;
    end else if(vrender<9'h1f0 && vrender>'h10e) begin
        if( mlyr!=7 ) mst <= mst+3'd1;

        case( mst )
            0: // Tile map RAM address
            case( mlyr )
                0: tmap_addr <= { 2'd0, vpos[3+:6], hpos[3+:6] };
                1: tmap_addr <= { 2'd1, vpos[3+:6], hpos[3+:6] };
                2: tmap_addr <= { 2'd2, vpos[3+:6], hpos[3+:6] };
                3: tmap_addr <= { 3'd6, vpos[3+:5], hpos[3+:6] };
                // fixed tile maps are packed in memory and do not fit into a H-V binary split
                4: tmap_addr <= { 4'b1110, linear };
                5: tmap_addr <= { 4'b1111, linear };
                default:;
            endcase
            3: begin
                mask_addr <= { tmap_data[13:0], mlyr>3 ? vpos[2:0]+3'd1 : vpos[2:0] }; // 17 bits
                mask_cs   <= 1;
            end
            5: if(mask_ok) begin
                mask[cfg_prio[mlyr]] <= mask_data;
                info[cfg_prio[mlyr]] <= {cfg_pal[mlyr], tmap_data[13:0], mlyr>3 ? vpos[2:0]+3'd1 : vpos[2:0], ~tcnt+3'd1};
                mreq[mlyr] <= 0;
                mask_cs    <= 0;
                mst        <= 0;
            end else mst <= 5;
            default:;
        endcase
        if( alt_cen ) begin
            linear <= lin_row + {4'd0,hcnt[3+:6]};
            if( hcnt0==7 && !cfg_enb[0] ) mreq[0] <= 1; // do not request disabled layers
            if( hcnt1==7 && !cfg_enb[1] ) mreq[1] <= 1;
            if( hcnt2==7 && !cfg_enb[2] ) mreq[2] <= 1;
            if( hcnt3==7 && !cfg_enb[3] ) mreq[3] <= 1;
            if( hcnt[2:0]==7 ) begin
                if( !cfg_enb[4] ) mreq[4] <= 1;
                if( !cfg_enb[5] ) mreq[5] <= 1;
            end
            // next pixel information
            { attr, scr_addr } <= { win, info[win][3+:20], info[win][2:0]+tcnt };
            for( i=0; i<8; i=i+1 ) mask[i] <= mask[i] << 1;
            buf_a <= hcnt;
            // current pixel
            { bprio, bpxl } <= { attr, scr_data };
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
    .wr_addr    ( buf_a     ),
    .wr_data    ({bpxl,bprio}),
    .we         ( buf_we    ),
    .rd_addr    ( hdump     ),
    .rd_data    ({pxl,prio} ),
    .rd_gated   (           )
);

jtshouse_scr_mmr u_mmr(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cs         ( cs            ),
    .addr       ( addr          ),
    .rnw        ( rnw           ),
    .din        ( din           ),
    .dout       ( dout          ),
    .hscr       ( hscr          ),
    .vscr       ( vscr          ),
    .pal        ( cfg_pal       ),
    .prio       ( cfg_prio      ),
    .enb        ( cfg_enb       ),
    .ioctl_addr ( ioctl_addr    ),
    .ioctl_din  ( ioctl_din     ),
    .debug_bus  ( debug_bus     ),
    .st_dout    ( st_dout       )
);

integer aux;

always @(posedge clk) begin
    vs_l <= vs;
    if( vs & ~vs_l ) aux <= aux+1;
end

`ifdef SIMULATION
/* verilator tracing_off */
int reported=0;

always @(posedge miss) begin
    if(reported==1 ) $display("Scroll line missed");
    reported<=reported+1;
end
`endif

endmodule