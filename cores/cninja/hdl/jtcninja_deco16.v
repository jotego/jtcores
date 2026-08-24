/*  This file is part of JTCORES. GPLv3. See jtcninja_game.v header.

    jtcninja_deco16 - faithful single-playfield renderer for the Data East
    deco16ic tile generator (custom chips 55 / 56 / 74, 4bpp). One instance
    renders ONE playfield; a deco16ic chip has two (instantiate twice).

    Scroll modes (control1[6:5], per deco16ic.cpp deco16_pf_update /
    custom_tilemap_draw):
        00  uniform     X = scrollx                  Y = scrolly
        40  rowscroll   X = scrollx + rs[src_y>>S]   Y = scrolly            (per line)
        20  colscroll   X = scrollx                  Y = scrolly + cs[col]  (per column)
        60  row+col     per-line X AND per-column Y   (the "custom" renderer)
    Runtime 8x8 / 16x16 (control1[7]), 64x32 / 64x64 maps, screen flip, and
    per-tile X/Y flip (tile bit 0x8000 gated by control1[1:0]).

    Streaming model: the line is walked as 8-pixel SOURCE columns (the gfx-fetch
    granularity). Each 8px column picks its own colscroll Y and lands on one
    tile's left/right half -> one tile lookup + one 32-bit gfx read per column.
    Because col_type (=8<<style) is always >=8 the colscroll value is constant
    across any 8px span, so this reproduces custom_tilemap_draw exactly.

    Tile word: [11:0]=code, [15:12]=colour, [15]=per-tile-flip-enable -> when set
    control1[0]=FLIPX, control1[1]=FLIPY. rsram: X table [0,0x200), Y table
    [0x200,0x400); the single read port is time-shared (X at line top, Y per col).
*/
module jtcninja_deco16 #(
    parameter PXLW = 8       // output pixel = {colour[3:0], pixel[3:0]}
)(
    input             rst,
    input             clk,
    input             pxl_cen,        // unused (kept for interface symmetry)
    input             hs,
    input      [ 8:0] vrender,
    input      [ 8:0] hdump,
    input             flip,           // screen flip

    input             fullheight,     // 1 = 64 rows (else 32); cols always 64
    input      [15:0] scrollx,
    input      [15:0] scrolly,
    input      [ 7:0] control0,       // [7]=enable [6:3]=rowscroll style [2:0]=colscroll style
    input      [ 7:0] control1,       // [7]=8x8 [6]=rowscr [5]=colscr [1]=flipY_en [0]=flipX_en
    input      [ 2:0] bank,           // high tile-code bit(s)
    input             pswap,          // gfx plane-pair order swap
    input             rowmajor,       // 1=tiles laid out row-major (L/R 8px halves adjacent -> 64b cache hit)

    output reg [11:0] ram_addr,       // tile RAM (BRAM, 1-cyc)
    input      [15:0] ram_data,
    output reg [10:0] rsram_addr,     // row/colscroll RAM (BRAM, 1-cyc)
    input      [15:0] rsram_data,
    output reg        rom_cs,         // gfx ROM (SDRAM): 32-bit = 8px x 4 planes
    output reg [19:2] rom_addr,
    input      [31:0] rom_data,
    input             rom_ok,

    output     [PXLW-1:0] pxl
);

// ---- derived config ----
wire        tile16 = ~control1[7];
wire        en     =  control0[7];
wire        rowscr =  control1[6];
wire        colscr =  control1[5];
wire [ 3:0] rs_sh  =  control0[6:3];
wire [ 3:0] cs_sh  =  4'd3 + {1'b0,control0[2:0]};
wire        tfx_en =  control1[0];
wire        tfy_en =  control1[1];

wire [ 9:0] hmask = tile16 ? (fullheight ? 10'h3ff : 10'h1ff)
                           : (fullheight ? 10'h1ff : 10'h0ff);
wire [ 9:0] wmask = tile16 ? 10'h3ff : 10'h1ff;

wire [ 8:0] vr    = flip ? 9'd255 - vrender : vrender;
wire [ 9:0] src_y = (scrolly[9:0] + {1'b0,vr}) & hmask;

// ---- FSM ----
// XW*/CW* are wait states: the row/colscroll table is shared with the other
// playfield of the chip through a single BRAM port (see jtcninja_deco16ic), so
// rsram_addr must be held long enough for either arbiter phase to be served
// and captured. Four cycles per read covers the worst case.
localparam IDLE=0, XRD=1, XSET=2, CRD=3, CSET=4, RAMW=5, DEC=6, GFXW=7, WR=8,
           XW1=9, XW2=10, CW1=11, CW2=12;
reg  [ 3:0] st;
reg  [ 9:0] xstart, src_x;
reg  [ 8:0] scrx_pos;          // screen X of the current column's first pixel
reg  [ 5:0] colcnt;
reg  [ 9:0] mapy;
reg  [11:0] code;
reg  [ 3:0] colour;
reg         tfx, tfy;
reg  [31:0] gfx;
reg  [ 2:0] pcnt;
reg         HSl;
reg         fresh, rom_good;   // guard against sampling stale rom_ok

wire        hs_neg = HSl & ~hs;
wire [ 5:0] tcol = tile16 ? src_x[9:4] : src_x[8:3];
wire [ 5:0] trow = tile16 ? mapy[9:4]  : mapy[8:3];
wire [ 3:0] subrw_raw = tile16 ? mapy[3:0] : {1'b0,mapy[2:0]};
// rom_addr is built from the JUST-READ tile word (ram_data), NOT the `code` reg:
// `code <= ram_data` is latched this cycle, so the reg still holds the PREVIOUS
// column's tile -> using it shifts every column one 8px-column right (and the
// 16x16 half/code misalign makes even/odd columns alternate wrong). Flip also
// comes from the current tile word.
// half-bit picks the 8px column: left (src_x[3]=0) lives in the upper 16 words
// (old engine drew half=1 first, on the left) -> half = ~src_x[3].
wire        cur_tfx = ram_data[15] & tfx_en;
wire        cur_tfy = ram_data[15] & tfy_en;
wire [ 3:0] rsubrw  = cur_tfy ? ~subrw_raw : subrw_raw;
wire        rhalf   = tile16 ? ~(cur_tfx ^ src_x[3]) : 1'b0;

wire [11:0] idx16 = { trow[5], tcol[5], trow[4:0], tcol[4:0] };
wire [11:0] idx8  = { trow[5:0], tcol[5:0] };
wire [10:0] rs_a  = {1'b0, src_y >> rs_sh};
wire [10:0] cs_a  = 11'h200 + {2'b0, ((src_x[8:0] >> cs_sh) & 9'h1ff)};
wire [ 9:0] xnew  = (scrollx[9:0] + (rowscr ? rsram_data[9:0] : 10'd0)) & wmask;

always @* begin
    rsram_addr = (st==XRD||st==XW1||st==XW2||st==XSET) ? rs_a : cs_a;
    ram_addr   = tile16 ? idx16 : idx8;
end

// 16x16 word layout is half-major: word-in-tile = half*16 + subrow. Built from
// ram_data (current tile), not the `code` reg (which lags one column).
wire [17:0] roma16 = rowmajor ? { bank[0], ram_data[11:0], rsubrw, rhalf }   // row-major: L/R halves adjacent
                              : { bank[0], ram_data[11:0], rhalf, rsubrw };  // half-major (default)
wire [17:0] roma8  = { 3'd0, ram_data[11:0], rsubrw[2:0] };

// 4bpp unpack: plane p lives in byte p, bit bsel (MSB-first; per-tile X flip
// reverses the bit order within the 8). pswap exchanges the two plane pairs.
wire [2:0] bsel = tfx ? pcnt : ~pcnt;
wire [4:0] b5   = {2'b0, bsel};
wire p0 = gfx[       b5];
wire p1 = gfx[5'd8 + b5];
wire p2 = gfx[5'd16+ b5];
wire p3 = gfx[5'd24+ b5];
wire [3:0] draw_pxl = pswap ? { p1, p0, p3, p2 } : { p3, p2, p1, p0 };

// line-buffer writes are driven combinationally from the pixel counter
wire        buf_we    = (st==WR);
wire [ 8:0] buf_waddr = scrx_pos + {6'd0,pcnt};
wire [ 8:0] waflip    = flip ? 9'h100 - buf_waddr : buf_waddr;
wire [PXLW-1:0] buf_wdata = { colour, draw_pxl };

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        st<=IDLE; HSl<=0; colcnt<=0; src_x<=0; xstart<=0; scrx_pos<=0; mapy<=0;
        code<=0; colour<=0; tfx<=0; tfy<=0; gfx<=0; pcnt<=0; rom_cs<=0; rom_addr<=0;
        fresh<=0; rom_good<=0;
    end else begin
        HSl      <= hs;
        rom_good <= rom_ok;
        if( rom_cs && !rom_ok ) fresh <= 1;   // new read confirmed in flight
        case( st )
        IDLE: if( hs_neg ) begin
            colcnt <= 0;
            st     <= en ? XRD : IDLE;
        end
        XRD:  st <= XW1;                   // rsram=rs_a issued
        XW1:  st <= XW2;
        XW2:  st <= XSET;
        XSET: begin                        // rowscroll X ready
            xstart   <= xnew;
            src_x    <= xnew & ~10'd7;
            scrx_pos <= 9'd0 - {6'd0, xnew[2:0]};
            st       <= CRD;
        end
        CRD:  st <= CW1;                   // rsram=cs_a(src_x) issued
        CW1:  st <= CW2;
        CW2:  st <= CSET;
        CSET: begin                        // colscroll Y ready -> mapy
            mapy <= (src_y + (colscr ? rsram_data[9:0] : 10'd0)) & hmask;
            st   <= RAMW;                  // ram_addr now combinationally valid
        end
        RAMW: st <= DEC;                   // wait 1cyc for tile RAM data
        DEC: begin                         // tile word ready -> decode + issue gfx
            code   <= ram_data[11:0];
            // deco16ic get_pfN_tile_info: a tile that opts into per-tile flip
            // (bit 15) also drops to the low half of the palette - colour &= 7.
            // Only bites when control1[1:0] is non-zero, which cninja never sets
            // but edrandy's rowscrolled layers do.
            colour <= (ram_data[15] & (tfx_en|tfy_en)) ? {1'b0,ram_data[14:12]}
                                                       :      ram_data[15:12];
            tfx    <= ram_data[15] & tfx_en;
            tfy    <= ram_data[15] & tfy_en;
            rom_cs   <= 1;
            rom_addr <= tile16 ? roma16 : roma8;
            fresh    <= 0;
            st       <= GFXW;
        end
        GFXW: if( fresh && rom_good && rom_ok ) begin
            gfx    <= rom_data;
            rom_cs <= 0;
            fresh  <= 0;
            pcnt   <= 0;
            st     <= WR;
        end
        WR: begin                          // 8 pixels, one per cycle (combinational write)
            pcnt <= pcnt + 3'd1;
            if( pcnt==3'd7 ) begin
                colcnt   <= colcnt + 6'd1;
                src_x    <= (src_x + 10'd8) & wmask;
                scrx_pos <= scrx_pos + 9'd8;
                st       <= (colcnt>=6'd33) ? IDLE : CRD;
            end
        end
        default: st <= IDLE;
        endcase
    end
end

// jtframe_linebuf has no clear, so a disabled layer would replay its last lines
wire [PXLW-1:0] buf_pxl;
assign pxl = en ? buf_pxl : {PXLW{1'b0}};

jtframe_linebuf #(.DW(PXLW), .AW(9)) u_buf(
    .clk     ( clk       ),
    .LHBL    ( ~hs       ),
    .wr_addr ( waflip    ),
    .wr_data ( buf_wdata ),
    .we      ( buf_we    ),
    .rd_addr ( hdump     ),
    .rd_data (           ),
    .rd_gated( buf_pxl   )
);



`ifdef SIMULATION
`ifdef PFDBG
// Per-playfield activity: how many lines rendered, how long the gfx fetch
// stalled, and how many of the written pixels are non-transparent. A layer
// that should be sparse but reports nearly 100% non-zero is fetching the
// wrong gfx, not failing to run.
integer dbg_wr=0, dbg_nz=0, dbg_line=0, dbg_gfxw=0, dbg_t=0;
always @(posedge clk) begin
    if( st==IDLE && hs_neg && en ) dbg_line = dbg_line+1;
    if( st==GFXW ) dbg_gfxw = dbg_gfxw+1;
    if( st==WR ) begin
        dbg_wr = dbg_wr+1;
        if( draw_pxl!=4'd0 ) dbg_nz = dbg_nz+1;
    end
    dbg_t = dbg_t+1;
    if( dbg_t[21:0]==0 )
        $display("PFDBG %m en=%0d lines=%0d gfxw=%0d wr=%0d nonzero=%0d",
                 en, dbg_line, dbg_gfxw, dbg_wr, dbg_nz);
end
`endif
`endif

endmodule
