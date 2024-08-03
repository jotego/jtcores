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
    input       [8:0] vdump,
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
    output     [16:0] mask_addr,
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
    input      [ 3:0] gfx_en,
    output     [ 7:0] st_dout
);

parameter  [ 8:0] VB_END = 9'h120;
localparam [ 8:0] HMARGIN=9'h8,
                  HSTART=9'h40-HMARGIN,
                  HEND=9'd288+HSTART+(HMARGIN<<1); // hdump is non blank from 'h40 to 'h160

wire [15:0] hoff0 = flip ? 16'h71 : -16'h0f;
wire [15:0] hoff1 = flip ? hoff0 + 16'h2 : hoff0 - 16'h2;
wire [15:0] hoff2 = flip ? hoff0 + 16'h3 : hoff0 - 16'h3;
wire [15:0] hoff3 = flip ? hoff0 + 16'h4 : hoff0 - 16'h4;

reg  [15:0] hoff, hpos, vpos;
reg  [ 2:0] mlyr, mask_asub, mst;
reg  [ 5:0] mreq, attr;
wire [ 2:0] hsub;
reg  [ 7:0] mask[0:5];
reg  [22:0] info[0:5];
reg  [ 8:0] hcnt, buf_a;
reg  [10:0] bpxl;
reg  [ 9:0] lin_row;   // linear "row" count (does not count during blanks)
reg  [ 9:0] linear;    // linear position ("row"+col)
reg  [ 2:0] bprio, cprio, win, hcnt0, hcnt1, hcnt2, hcnt3;
reg         hs_l, done, alt_cen, vs_l, opaque;
wire        buf_we, rom_ok, hs_edge;

// Layer configuration
wire [3:0][15:0] hscr, vscr;
wire [5:0][ 2:0] cfg_pal, cfg_prio;
wire [5:0]       cfg_enb;

integer     i, j;
`ifdef SIMULATION
    reg       miss;
`endif

assign scr_cs    = 1;
assign hsub      = hcnt[2:0];
assign buf_we    = alt_cen & ~done;
assign rom_ok    = scr_ok & mlyr==7;
assign hs_edge   = hs & ~hs_l;
assign mask_addr = { tmap_data[13:0], mask_asub };

`ifdef SIMULATION
wire [15:0] hscr0=hscr[0], hscr1=hscr[1], hscr2 = hscr[2], hscr3 = hscr[3],
            vscr0=vscr[0], vscr1=vscr[1], vscr2 = vscr[2], vscr3 = vscr[3];
wire [ 2:0] cfg_prio0 = cfg_prio[0], cfg_prio3 = cfg_prio[3],
            cfg_prio1 = cfg_prio[1], cfg_prio4 = cfg_prio[4],
            cfg_prio2 = cfg_prio[2], cfg_prio5 = cfg_prio[5];
`endif

// Horizontal counter that waits for SDRAM
always @(posedge clk, posedge rst) begin
    if( rst ) begin
        hs_l <= 0;
        hcnt <= 0;
        done <= 0;
        lin_row <= 0;
        alt_cen <= 1;
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
            hcnt0 <= (-hscr[0][2:0] ^ {3{~flip}})+hoff0[2:0];
            hcnt1 <= (-hscr[1][2:0] ^ {3{~flip}})+hoff1[2:0];
            hcnt2 <= (-hscr[2][2:0] ^ {3{~flip}})+hoff2[2:0];
            hcnt3 <= (-hscr[3][2:0] ^ {3{~flip}})+hoff3[2:0];

            if(vdump[2:0]==0)
                if (flip)
                    lin_row <= vdump[8:3]==6'h24 ? 10'd973 : lin_row-10'd36;
                else
                    lin_row <= vdump[8:3]==6'h24 ? 10'd1 : lin_row+10'd36;
            // if(vrender[2:0]==7) lin_row <= vrender[8:3]==6'h24 ? 10'd1 : lin_row+10'd36;
            // if(vrender==9'h120 ) lin_row <= 1;
        end
        done <= hcnt==HEND;
    end
end

always @* begin
    case( mlyr[1:0] )
        0: hoff = hoff0;
        1: hoff = hoff1;
        2: hoff = hoff2;
        3: hoff = hoff3;
    endcase

    if( mlyr>3 )
        { vpos, hpos } = { 7'd0, vdump, 7'd0, hcnt };
    else
        { vpos, hpos } = { {7'd0, vdump}+vscr[mlyr[1:0]] + 16'd248,
                           {7'd0,  hcnt}-(hscr[mlyr[1:0]] ^ {16{~flip}}) + hoff};

    if ( flip ) vpos = ~vpos;

    // Determines the active layer
    win    = 5;
    cprio  = 0;
    opaque = 0;
    for( j=5; j>=0; j=j-1 )
        if( !opaque || (cfg_prio[j]>cprio && mask[j][7])) { opaque, win, cprio } = { mask[j][7], j[2:0], cfg_prio[j] };
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

// Pixel drawing
always @(posedge clk, posedge rst) begin
    if( rst ) begin
        mask_asub <= 0;
        bpxl      <= 0;
        bprio     <= 0;
        attr      <= 0;
        mreq      <= 0;
        mst       <= 0;
    end else begin
        // Reads mask data for the layer set in mlyr
        mst <= mlyr==7 ? 3'd0 : mst+3'd1;
        case( mst )
            0: begin // Tile map RAM address
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
            end
            // vpos for the fixed layers has a relationship with the linear counter
            // changing the octal LSB of the linear start requires an adjustment here
            1: mask_asub <= vpos[2:0];
            4: begin
                mask[mlyr] <= mask_data;
                info[mlyr] <= {cfg_pal[mlyr], tmap_data[13:0], mask_asub, ~hsub+3'd1};
                mreq[mlyr] <= 0;
                mst        <= 0;
            end
            default:;
        endcase
        if( alt_cen ) begin
            linear <= lin_row + {4'd0,hcnt[3+:6]};
            if( hcnt0==7 && !cfg_enb[0] && gfx_en[1] ) mreq[0] <= 1; // do not request disabled layers
            if( hcnt1==7 && !cfg_enb[1] && gfx_en[1] ) mreq[1] <= 1;
            if( hcnt2==7 && !cfg_enb[2] && gfx_en[1] ) mreq[2] <= 1;
            if( hcnt3==7 && !cfg_enb[3] && gfx_en[1] ) mreq[3] <= 1;
            if( hcnt[2:0]==7 && gfx_en[2] ) begin
                if( !cfg_enb[4] ) mreq[4] <= 1;
                if( !cfg_enb[5] ) mreq[5] <= 1;
            end
            // next pixel information
            { attr, scr_addr } <= { cprio, info[win][3+:20], info[win][2:0]+hsub };
            for( i=0; i<6; i=i+1 ) mask[i] <= mask[i] << 1;
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
    .rd_addr    ( flip ? ~hdump - 9'h5e : hdump ),
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
