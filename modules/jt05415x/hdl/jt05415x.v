/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 2-9-2026 */

// K054156: CPU registers, tile RAM and addressing. K054157: pixel pipelines, see jt054157.v
// Tile RAM: RAM0 attribute (even word D[7:0]), RAM1/RAM2 tile code (odd word). Four 64x32 pages

module jt05415x(
    input             rst,
    input             clk,
    input             pxl_cen,

    input             cs_156,
    input             cs_157,
    input             cram_cs,  // tile RAM window
    input             rmrd_cs,  // graphics ROM read-back window
    input       [5:1] addr,
    input      [12:1] cpu_addr,
    input             rnw,
    input      [15:0] din,
    output     [15:0] dout,
    input       [1:0] dsn,

    // Scan side
    input       [8:0] hdump,
    input       [8:0] vdump,
    input             blankn,

    output            flip,     // global screen flip (H or V)

    output     [18:0] lyrf_addr, lyra_addr, lyrb_addr, lyrc_addr,
    output            lyrf_cs,   lyra_cs,   lyrb_cs,   lyrc_cs,
    input      [31:0] lyrf_data, lyra_data, lyrb_data, lyrc_data,
    input             lyrf_ok,   lyra_ok,   lyrb_ok,   lyrc_ok,
    output     [11:0] lyrf_pxl,  lyra_pxl,  lyrb_pxl,  lyrc_pxl,

    // IOCTL dump
    input      [14:0] ioctl_addr,
    input             ioctl_ram,
    output      [7:0] ioctl_din,
    output      [7:0] mmr_dump,
    // Debug
    input       [3:0] gfx_en,
    input       [7:0] debug_bus,
    output      [7:0] st_156_dout,
    output      [7:0] st_157_dout
);

parameter SIMFILE156 = "rest.bin",
          SIMFILE157 = "rest.bin";

// Per-layer horizontal offsets. These add to the source x, so they are the
// negation of MAME's set_layer_offs for moomesa (moo.cpp:301-304 = -1/3/5/7)
localparam signed [12:0] HOFSA =  13'sd1,
                         HOFSB = -13'sd3,
                         HOFSC = -13'sd5,
                         HOFSD = -13'sd7;
// jtframe_tilemap requests a tile one group before it is displayed
localparam [12:0] PREFETCH = 13'd8;
// screen column c is bitmap x c+40 (moo.cpp set_visarea); hdump's first visible
// pixel is 56, jtframe_tilemap adds 9 pixels of latency and the mixer 3
localparam signed [12:0] HBASE = 13'sd40 - 13'sd56 + 13'sd9 + 13'sd3;

wire [15:0] dout_156, dout_157, dout_mmr, romrd_dout, vram_dout;
wire [ 7:0] ioctl_156_din, ioctl_157_din;
wire [ 7:0] vram0_scan, vram1_scan, vram2_scan;
wire [ 7:0] glob_ctrl, flip_en, attr_ctrl, irq_attr, addr_ctrl, lnscr_ctrl;
wire [ 5:0] vram_ctrl, a_vgrid, b_vgrid, c_vgrid, d_vgrid;
wire [ 5:0] a_hgrid, b_hgrid, c_hgrid, d_hgrid;
wire [10:0] a_scry, b_scry, c_scry, d_scry;
wire [11:0] a_scrx, b_scrx, c_scrx, d_scrx;
wire [ 5:0] lnscr_bank, cpu_bank;
wire [ 7:0] rom_bank, rom_col;
wire [ 1:0] rom_vrc;
wire [15:0] tile_lut;
wire [11:0] hflip_corr;
wire [10:0] vflip_corr;
wire        hofs_phase, clk_fanout, ram_clkph;
wire        a_hofs_flip, b_hofs_flip, c_hofs_flip, d_hofs_flip;
wire        ramout_mux, dbout_mux, vc_dir, crom_decode;
wire        db_lane, col_src0, col_src1;

reg  [ 1:0] dout_sel;

assign dout      = dout_sel==2'd3 ? romrd_dout :
                   dout_sel==2'd2 ? vram_dout  : dout_mmr;
assign dout_mmr  = dout_sel[0] ? dout_157 : dout_156;
assign mmr_dump  = ioctl_addr[6]  ? ioctl_157_din : ioctl_156_din;
assign ioctl_din = ioctl_addr[14] ? vram2_scan :
                   ioctl_addr[13] ? vram1_scan : vram0_scan;
assign flip      = glob_ctrl[4] | glob_ctrl[5];

always @(posedge clk) begin
    if( rst ) begin
        dout_sel <= 0;
    end else if( cs_156 | cs_157 | cram_cs | rmrd_cs ) begin
        dout_sel <= rmrd_cs ? 2'd3 :
                    cram_cs ? 2'd2 :
                    cs_157  ? 2'd1 : 2'd0;
    end
end

jt054156_mmr #(
    .SIMFILE ( SIMFILE156 )
) u_054156_mmr(
    .rst        ( rst           ),
    .clk        ( clk           ),

    .cs         ( cs_156        ),
    .addr       ( addr          ),
    .rnw        ( rnw           ),
    .din        ( din           ),
    .dout       ( dout_156      ),
    .dsn        ( dsn           ),

    .glob_ctrl  ( glob_ctrl     ),
    .flip_en    ( flip_en       ),
    .attr_ctrl  ( attr_ctrl     ),
    .irq_attr   ( irq_attr      ),
    .addr_ctrl  ( addr_ctrl     ),
    .lnscr_ctrl ( lnscr_ctrl    ),
    .vram_ctrl  ( vram_ctrl     ),
    .a_vgrid    ( a_vgrid       ),
    .b_vgrid    ( b_vgrid       ),
    .c_vgrid    ( c_vgrid       ),
    .d_vgrid    ( d_vgrid       ),
    .a_hgrid    ( a_hgrid       ),
    .b_hgrid    ( b_hgrid       ),
    .c_hgrid    ( c_hgrid       ),
    .d_hgrid    ( d_hgrid       ),
    .a_scry     ( a_scry        ),
    .b_scry     ( b_scry        ),
    .c_scry     ( c_scry        ),
    .d_scry     ( d_scry        ),
    .a_scrx     ( a_scrx        ),
    .b_scrx     ( b_scrx        ),
    .c_scrx     ( c_scrx        ),
    .d_scrx     ( d_scrx        ),
    .lnscr_bank ( lnscr_bank    ),
    .cpu_bank   ( cpu_bank      ),
    .rom_bank   ( rom_bank      ),
    .rom_col    ( rom_col       ),
    .rom_vrc    ( rom_vrc       ),
    .tile_lut   ( tile_lut      ),
    .hflip_corr ( hflip_corr    ),
    .vflip_corr ( vflip_corr    ),

    // IOCTL dump
    .ioctl_addr ( ioctl_addr[5:0] ),
    .ioctl_din  ( ioctl_156_din ),
    // Debug
    .debug_bus  ( debug_bus     ),
    .st_dout    ( st_156_dout   )
);

// db_lane/col_src0/col_src1 (K054157 second-bank register 0x06, bits 5/6/7)
// are decoded here and then only sunk into unused_157 below. This is not a
// dropped wire: MAME's k056832_device::b_word_w (the second-bank register
// write handler these bits belong to) is a bare COMBINE_DATA store into
// m_regsb[]; m_regsb[] is read back only for CPU register reads and, in
// mw_rom_word_r (a Mystic Warriors-only ROM-readback special case Moo/Bucky
// never call), m_regsb[2] bit3 (our ramout_mux). get_tile_info()'s own
// colour/attribute select (`fbits`) reads first-bank m_regs[3] bits 6:7
// instead - already wired here as `fbits = irq_attr[7:6]` (see `tcolor`
// below) - not this second-bank register. So MAME's reference model never
// gives col_src0/col_src1/db_lane any rendering effect either; leaving them
// unconsumed matches the emulated hardware behaviour we are differential-
// testing against, not a gap. (evidence: modules/jt05415x/doc/mame/
// k054156_k054157_k056832.cpp:823,1179-1183,1980, 617-627; register map:
// modules/jt05415x/doc/register_map.md "Second Bank, K054157" 0x06 row)
jt054157_mmr #(
    .SIMFILE ( SIMFILE157 )
) u_054157_mmr(
    .rst         ( rst            ),
    .clk         ( clk            ),

    .cs          ( cs_157         ),
    .addr        ( addr[2:1]      ),
    .rnw         ( rnw            ),
    .din         ( din            ),
    .dout        ( dout_157       ),
    .dsn         ( dsn            ),

    .hofs_phase  ( hofs_phase     ),
    .clk_fanout  ( clk_fanout     ),
    .ram_clkph   ( ram_clkph      ),
    .a_hofs_flip ( a_hofs_flip    ),
    .b_hofs_flip ( b_hofs_flip    ),
    .c_hofs_flip ( c_hofs_flip    ),
    .d_hofs_flip ( d_hofs_flip    ),
    .ramout_mux  ( ramout_mux     ),
    .dbout_mux   ( dbout_mux      ),
    .vc_dir      ( vc_dir         ),
    .crom_decode ( crom_decode    ),
    .db_lane     ( db_lane        ),
    .col_src0    ( col_src0       ),
    .col_src1    ( col_src1       ),

    // IOCTL dump
    .ioctl_addr  ( ioctl_addr[2:0]),
    .ioctl_din   ( ioctl_157_din  ),
    // Debug
    .debug_bus   ( debug_bus      ),
    .st_dout     ( st_157_dout    )
);

// Tile RAM
wire [12:0] vaddr, cpu_vaddr;
wire [ 7:0] cpu_ram0, cpu_ram1, cpu_ram2;
wire        cpu_attr, cpu_wr;
wire [ 1:0] cpu_page;
wire [ 2:0] ram_we;

// cpu_bank picks the visible page like MAME's change_rambank does, but this
// board only has four pages so a single row/column bit reaches the RAM
assign cpu_page  = { cpu_bank[3], cpu_bank[0] };
assign cpu_vaddr = { cpu_page, cpu_addr[12:2] };
assign cpu_attr  = ~cpu_addr[1];
assign cpu_wr    = cram_cs & ~rnw;
assign ram_we[0] = cpu_wr &  cpu_attr & ~dsn[0];
assign ram_we[1] = cpu_wr & ~cpu_attr & ~dsn[1];
assign ram_we[2] = cpu_wr & ~cpu_attr & ~dsn[0];
assign vram_dout = cpu_attr ? { 8'd0, cpu_ram0 } : { cpu_ram1, cpu_ram2 };

// Board correspondence (scroll.kicad_sch, MB8464A SRAMs L10/M10/N10; see
// D:\evidence\moo\audit\sch\scroll.md GAP-6, independently re-checked
// against the raw VD* net labels this session): u_vram0 (attribute byte,
// standalone write-enable pattern below) is board M10 (VD16..23, ~CS1 tied
// to VSS so always selected, own ~ROE3/~RWE3). u_vram1/u_vram2 (the tile
// code byte pair, independently chip-selected via dsn[1]/dsn[0]) are boards
// L10 (VD0..7) and N10 (VD8..15) - which of the two is which is not
// established by the schematic evidence gathered so far, so it is left
// unclaimed here rather than guessed. This naming only matters for a future
// raw-VRAM-vs-MAME diff tool; MAME's own k056832 videoram is a flat 16-bit
// attr/code array (see get_tile_info in doc/mame/...cpp) unrelated to this
// physical VD bus order, and the RTL's plane semantics (attribute vs code
// hi/lo) are already unambiguous from cpu_attr/ram_we below, so the IOCTL
// dump address order (ioctl_addr[14:13] select) is left unchanged.
jtframe_dual_nvram #(
    .AW      ( 13         ),
    .SIMFILE ( "scr0.bin" )
) u_vram0(
    .clk0   ( clk             ),
    .data0  ( din[7:0]        ),
    .addr0  ( cpu_vaddr       ),
    .we0    ( ram_we[0]       ),
    .q0     ( cpu_ram0        ),
    .clk1   ( clk             ),
    .addr1a ( vaddr           ),
    .addr1b ( ioctl_addr[12:0]),
    .sel_b  ( ioctl_ram       ),
    .we_b   ( 1'b0            ),
    .data1  ( 8'd0            ),
    .q1     ( vram0_scan      )
);

jtframe_dual_nvram #(
    .AW      ( 13         ),
    .SIMFILE ( "scr1.bin" )
) u_vram1(
    .clk0   ( clk             ),
    .data0  ( din[15:8]       ),
    .addr0  ( cpu_vaddr       ),
    .we0    ( ram_we[1]       ),
    .q0     ( cpu_ram1        ),
    .clk1   ( clk             ),
    .addr1a ( vaddr           ),
    .addr1b ( ioctl_addr[12:0]),
    .sel_b  ( ioctl_ram       ),
    .we_b   ( 1'b0            ),
    .data1  ( 8'd0            ),
    .q1     ( vram1_scan      )
);

jtframe_dual_nvram #(
    .AW      ( 13         ),
    .SIMFILE ( "scr2.bin" )
) u_vram2(
    .clk0   ( clk             ),
    .data0  ( din[7:0]        ),
    .addr0  ( cpu_vaddr       ),
    .we0    ( ram_we[2]       ),
    .q0     ( cpu_ram2        ),
    .clk1   ( clk             ),
    .addr1a ( vaddr           ),
    .addr1b ( ioctl_addr[12:0]),
    .sel_b  ( ioctl_ram       ),
    .we_b   ( 1'b0            ),
    .data1  ( 8'd0            ),
    .q1     ( vram2_scan      )
);

// Per-layer effective coordinates
// The map is a whole number of 512x256 pages, global flip inverts the low bits
reg  [11:0] lyrf_lnscr, lyra_lnscr, lyrb_lnscr, lyrc_lnscr;
wire [12:0] hflip_corr_ext;
wire [11:0] vflip_corr_ext;

assign hflip_corr_ext = { hflip_corr[11], hflip_corr };
assign vflip_corr_ext = { vflip_corr[10], vflip_corr };

wire [12:0] f_xsum, a_xsum, b_xsum, c_xsum;
wire [11:0] f_ysum, a_ysum, b_ysum, c_ysum;
wire [ 8:0] f_heff, a_heff, b_heff, c_heff;
wire [ 8:0] f_veff, a_veff, b_veff, c_veff;

assign f_xsum = {4'd0,hdump} + HBASE + HOFSA + {1'b0,lnscr_ctrl[0] ? a_scrx : lyrf_lnscr} +
                (glob_ctrl[4] ? hflip_corr_ext : 13'd0);
assign a_xsum = {4'd0,hdump} + HBASE + HOFSB + {1'b0,lnscr_ctrl[2] ? b_scrx : lyra_lnscr} +
                (glob_ctrl[4] ? hflip_corr_ext : 13'd0);
assign b_xsum = {4'd0,hdump} + HBASE + HOFSC + {1'b0,lnscr_ctrl[4] ? c_scrx : lyrb_lnscr} +
                (glob_ctrl[4] ? hflip_corr_ext : 13'd0);
assign c_xsum = {4'd0,hdump} + HBASE + HOFSD + {1'b0,lnscr_ctrl[6] ? d_scrx : lyrc_lnscr} +
                (glob_ctrl[4] ? hflip_corr_ext : 13'd0);

// first visible line is vdump 0x110 = tilemap row 16 (moo.cpp set_visarea)
wire [ 8:0] vscr = vdump - 9'h100;

assign f_ysum = {3'd0,vscr} + {1'b0,a_scry} + (glob_ctrl[5] ? vflip_corr_ext : 12'd0);
assign a_ysum = {3'd0,vscr} + {1'b0,b_scry} + (glob_ctrl[5] ? vflip_corr_ext : 12'd0);
assign b_ysum = {3'd0,vscr} + {1'b0,c_scry} + (glob_ctrl[5] ? vflip_corr_ext : 12'd0);
assign c_ysum = {3'd0,vscr} + {1'b0,d_scry} + (glob_ctrl[5] ? vflip_corr_ext : 12'd0);

assign f_heff = glob_ctrl[4] ? ~f_xsum[8:0] : f_xsum[8:0];
assign a_heff = glob_ctrl[4] ? ~a_xsum[8:0] : a_xsum[8:0];
assign b_heff = glob_ctrl[4] ? ~b_xsum[8:0] : b_xsum[8:0];
assign c_heff = glob_ctrl[4] ? ~c_xsum[8:0] : c_xsum[8:0];

assign f_veff = { 1'b0, glob_ctrl[5] ? ~f_ysum[7:0] : f_ysum[7:0] };
assign a_veff = { 1'b0, glob_ctrl[5] ? ~a_ysum[7:0] : a_ysum[7:0] };
assign b_veff = { 1'b0, glob_ctrl[5] ? ~b_ysum[7:0] : b_ysum[7:0] };
assign c_veff = { 1'b0, glob_ctrl[5] ? ~c_ysum[7:0] : c_ysum[7:0] };

// VRAM scan slots
wire [ 5:0] layer_vgrid, layer_hgrid;
wire [11:0] layer_scrx_e;
wire [ 1:0] layer_scroll, layer_x, layer_y, layer_w, layer_h;
wire [ 2:0] layer_span_x, layer_span_y;
wire [12:0] layer_width, hofs, x_sum;
wire [11:0] layer_height, y_sum;
wire [ 1:0] src_page_x, src_page_y, slot_lyr;
wire [ 1:0] a_x, b_x, c_x, d_x, a_y, b_y, c_y, d_y,
            a_w, b_w, c_w, d_w, a_h, b_h, c_h, d_h;
wire        b_covers, c_covers, d_covers;
wire        assoc_disable, active_nx, tile_slot;
wire [12:0] tile_ram_addr, line_ram_addr;
wire [10:0] line_pair_off;

reg  [12:0] x_mod, x_nx;
reg  [11:0] y_mod;
reg  [10:0] y_nx;
integer     mod_i;

assign slot_lyr  = hdump[1:0];
assign tile_slot = ~hdump[2];

assign layer_vgrid  = slot_lyr==2'd0 ? a_vgrid : slot_lyr==2'd1 ? b_vgrid :
                      slot_lyr==2'd2 ? c_vgrid : d_vgrid;
assign layer_hgrid  = slot_lyr==2'd0 ? a_hgrid : slot_lyr==2'd1 ? b_hgrid :
                      slot_lyr==2'd2 ? c_hgrid : d_hgrid;
assign layer_scroll = slot_lyr==2'd0 ? lnscr_ctrl[1:0] : slot_lyr==2'd1 ? lnscr_ctrl[3:2] :
                      slot_lyr==2'd2 ? lnscr_ctrl[5:4] : lnscr_ctrl[7:6];
assign x_sum        = (slot_lyr==2'd0 ? f_xsum : slot_lyr==2'd1 ? a_xsum :
                       slot_lyr==2'd2 ? b_xsum : c_xsum) + PREFETCH;
assign y_sum        =  slot_lyr==2'd0 ? f_ysum : slot_lyr==2'd1 ? a_ysum :
                       slot_lyr==2'd2 ? b_ysum : c_ysum;

assign a_x = a_hgrid[4:3], b_x = b_hgrid[4:3], c_x = c_hgrid[4:3], d_x = d_hgrid[4:3],
       a_y = a_vgrid[4:3], b_y = b_vgrid[4:3], c_y = c_vgrid[4:3], d_y = d_vgrid[4:3],
       a_w = a_hgrid[1:0], b_w = b_hgrid[1:0], c_w = c_hgrid[1:0], d_w = d_hgrid[1:0],
       a_h = a_vgrid[1:0], b_h = b_vgrid[1:0], c_h = c_vgrid[1:0], d_h = d_vgrid[1:0];

assign layer_x      = layer_hgrid[4:3];
assign layer_y      = layer_vgrid[4:3];
assign layer_w      = layer_hgrid[1:0];
assign layer_h      = layer_vgrid[1:0];
assign layer_span_x = { 1'b0, layer_w } + 3'd1;
assign layer_span_y = { 1'b0, layer_h } + 3'd1;
assign layer_width  = { 1'b0, layer_span_x, 9'd0 };
assign layer_height = { 1'b0, layer_span_y, 8'd0 };

assign src_page_x = layer_x + x_nx[10:9];
assign src_page_y = layer_y + y_nx[9:8];
assign tile_ram_addr = { src_page_y[0], src_page_x[0], y_nx[7:3], x_nx[8:3] };

// Source oriented line scroll: 0x400 entries per layer, one every two words
assign line_pair_off = layer_scroll==2'd2 ? { slot_lyr, y_nx[8:3], 3'd0 } :
                                            { slot_lyr, y_nx[8:0]        };
assign line_ram_addr = { lnscr_bank[0], line_pair_off, 1'b0 };
assign vaddr         = tile_slot ? tile_ram_addr : line_ram_addr;

// A layer covering the whole 4x4 grid disables page association
assign assoc_disable = (a_x==0 && a_y==0 && a_w==3 && a_h==3) ||
                       (b_x==0 && b_y==0 && b_w==3 && b_h==3) ||
                       (c_x==0 && c_y==0 && c_w==3 && c_h==3) ||
                       (d_x==0 && d_y==0 && d_w==3 && d_h==3);
assign b_covers = (src_page_y - b_y) <= b_h && (src_page_x - b_x) <= b_w;
assign c_covers = (src_page_y - c_y) <= c_h && (src_page_x - c_x) <= c_w;
assign d_covers = (src_page_y - d_y) <= d_h && (src_page_x - d_x) <= d_w;
assign active_nx = slot_lyr==2'd0 ? assoc_disable || !(b_covers || c_covers || d_covers) :
                   slot_lyr==2'd1 ? assoc_disable || !(c_covers || d_covers)             :
                   slot_lyr==2'd2 ? assoc_disable || !d_covers                           : 1'b1;

always @* begin
    y_mod = y_sum;
    for( mod_i=0; mod_i<4; mod_i=mod_i+1 ) begin
        if( y_mod >= layer_height ) y_mod = y_mod - layer_height;
    end
    y_nx = glob_ctrl[5] ? layer_height[10:0] - 11'd1 - y_mod[10:0] : y_mod[10:0];

    x_mod = x_sum;
    for( mod_i=0; mod_i<4; mod_i=mod_i+1 ) begin
        if( x_mod >= layer_width ) x_mod = x_mod - layer_width;
    end
    x_nx = glob_ctrl[4] ? layer_width - 13'd1 - x_mod : x_mod;
end

// Tile attribute decode - see MAME k056832_device::get_tile_info
wire [ 2:0] slot_l;
wire [ 1:0] fbits, attr_flip, flip_msk;
reg  [ 5:0] tcolor;
reg  [ 1:0] tflip;

// the scan RAM answers within the pixel period, registering the slot handed each layer the next layer's tile
assign slot_l    = hdump[2:0];
assign fbits     = irq_attr[7:6];
assign attr_flip = fbits==2'd0 ? vram0_scan[7:6] :
                   fbits==2'd1 ? vram0_scan[5:4] :
                   fbits==2'd2 ? vram0_scan[3:2] : vram0_scan[1:0];
assign flip_msk  = slot_l[1:0]==2'd0 ? flip_en[1:0] : slot_l[1:0]==2'd1 ? flip_en[3:2] :
                   slot_l[1:0]==2'd2 ? flip_en[5:4] : flip_en[7:6];

always @* begin
    case( fbits )
        2'd0: tcolor =   vram0_scan[5:0];
        2'd1: tcolor = { vram0_scan[7:6], vram0_scan[3:0] };
        2'd2: tcolor = { vram0_scan[7:4], vram0_scan[1:0] };
        default: tcolor = vram0_scan[7:2];
    endcase
    tflip = flip_msk & attr_flip;
end

reg  [15:0] f_code, a_code, b_code, c_code;
reg  [ 7:0] f_pal,  a_pal,  b_pal,  c_pal;
reg         f_hf,   a_hf,   b_hf,   c_hf;
reg         f_vf,   a_vf,   b_vf,   c_vf;
reg         f_en,   a_en,   b_en,   c_en;

// The RAM answers within the pixel period, so at every pxl_cen the scan
// outputs belong to the slot hdump shows at that edge (slot_l above)
always @(posedge clk) begin
    if( rst ) begin
        { f_code, a_code, b_code, c_code } <= 0;
        { f_pal,  a_pal,  b_pal,  c_pal  } <= 0;
        { f_hf,   a_hf,   b_hf,   c_hf   } <= 0;
        { f_vf,   a_vf,   b_vf,   c_vf   } <= 0;
        { f_en,   a_en,   b_en,   c_en   } <= 0;
        lyrf_lnscr <= 0; lyra_lnscr <= 0;
        lyrb_lnscr <= 0; lyrc_lnscr <= 0;
    end else if( pxl_cen ) begin
        if( slot_l[2] ) begin  // line/row scroll word
            case( slot_l[1:0] )
                2'd0: lyrf_lnscr <= { vram1_scan[3:0], vram2_scan };
                2'd1: lyra_lnscr <= { vram1_scan[3:0], vram2_scan };
                2'd2: lyrb_lnscr <= { vram1_scan[3:0], vram2_scan };
                default: lyrc_lnscr <= { vram1_scan[3:0], vram2_scan };
            endcase
        end else case( slot_l[1:0] )
            2'd0: begin
                f_code<={vram1_scan,vram2_scan}; f_pal<={4'd0,tcolor[5:2]};
                f_hf  <=tflip[0] & a_hofs_flip; f_vf<=tflip[1]; f_en<=active_nx;
            end
            2'd1: begin
                a_code<={vram1_scan,vram2_scan};
                // tcolor[0] reaches K053251 CI28 through FPAL4, the K054338 blend enable
                a_pal <={3'd0,tcolor[0],tcolor[5:2]};
                a_hf  <=tflip[0] & b_hofs_flip; a_vf<=tflip[1]; a_en<=active_nx;
            end
            2'd2: begin
                b_code<={vram1_scan,vram2_scan}; b_pal<={4'd0,tcolor[5:2]};
                b_hf  <=tflip[0] & c_hofs_flip; b_vf<=tflip[1]; b_en<=active_nx;
            end
            default: begin
                c_code<={vram1_scan,vram2_scan}; c_pal<={4'd0,tcolor[5:2]};
                c_hf  <=tflip[0] & d_hofs_flip; c_vf<=tflip[1]; c_en<=active_nx;
            end
        endcase
    end
end

// Pixel pipelines
wire [18:0] f_rom_addr, a_rom_addr, b_rom_addr, c_rom_addr;
wire        f_rom_cs, a_rom_cs, b_rom_cs, c_rom_cs;

jt054157 u_054157(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .blankn     ( blankn    ),

    .a_heff( f_heff ), .b_heff( a_heff ), .c_heff( b_heff ), .d_heff( c_heff ),
    .a_veff( f_veff ), .b_veff( a_veff ), .c_veff( b_veff ), .d_veff( c_veff ),
    .a_code( f_code ), .b_code( a_code ), .c_code( b_code ), .d_code( c_code ),
    .a_pal ( f_pal  ), .b_pal ( a_pal  ), .c_pal ( b_pal  ), .d_pal ( c_pal  ),
    .a_hflip(f_hf   ), .b_hflip(a_hf   ), .c_hflip(b_hf   ), .d_hflip(c_hf   ),
    .a_vflip(f_vf   ), .b_vflip(a_vf   ), .c_vflip(b_vf   ), .d_vflip(c_vf   ),
    .a_assoc(f_en   ), .b_assoc(a_en   ), .c_assoc(b_en   ), .d_assoc(c_en   ),

    .a_rom_addr(f_rom_addr), .b_rom_addr(a_rom_addr),
    .c_rom_addr(b_rom_addr), .d_rom_addr(c_rom_addr),
    .a_rom_data(lyrf_data ), .b_rom_data(lyra_data ),
    .c_rom_data(lyrb_data ), .d_rom_data(lyrc_data ),
    .a_rom_cs  (f_rom_cs  ), .b_rom_cs  (a_rom_cs  ),
    .c_rom_cs  (b_rom_cs  ), .d_rom_cs  (c_rom_cs  ),
    .a_rom_ok  (lyrf_ok   ), .b_rom_ok  (lyra_ok   ),
    .c_rom_ok  (lyrb_ok   ), .d_rom_ok  (lyrc_ok   ),

    .a_pxl( lyrf_pxl ), .b_pxl( lyra_pxl ),
    .c_pxl( lyrb_pxl ), .d_pxl( lyrc_pxl ),

    .gfx_en( gfx_en )
);

// Graphics ROM read-back window
// MAME: addr = 0x2000*bank + 2*offset. The read-back steals the first pipeline while active
assign lyrf_addr = rmrd_cs ? { rom_bank, cpu_addr[12:2] } : f_rom_addr;
assign lyrf_cs   = rmrd_cs | f_rom_cs;
assign lyra_addr = a_rom_addr;
assign lyra_cs   = a_rom_cs;
assign lyrb_addr = b_rom_addr;
assign lyrb_cs   = b_rom_cs;
assign lyrc_addr = c_rom_addr;
assign lyrc_cs   = c_rom_cs;
assign romrd_dout= cpu_addr[1] ? { lyrf_data[23:16], lyrf_data[31:24] } :
                                 { lyrf_data[ 7: 0], lyrf_data[15: 8] };

`ifdef SIMULATION
wire unused_156 = &{ 1'b0, attr_ctrl, addr_ctrl, vram_ctrl, rom_col, rom_vrc,
                     tile_lut, cpu_bank[5:4], cpu_bank[2:1], lnscr_bank[5:1] };
wire unused_157 = &{ 1'b0, hofs_phase, clk_fanout, ram_clkph, ramout_mux,
                     dbout_mux, vc_dir, crom_decode, db_lane, col_src0, col_src1 };

// vram_ctrl (K054156 first-bank register 0x0C, bits 5:0 - "CPU/VRAM DB output
// selection, VRAM strobe selection, RAM address high-bit shift, and
// active-page/address timing", register_map.md) is decoded above but not
// modelled: this core always runs one fixed VRAM/CPU access timing rather
// than switching it per this register. Surface it as a simulation-only
// warning instead of silently folding it into unused_156, so a game that
// actually writes non-zero VRAM-timing control bits is flagged instead of
// silently mismatched.
reg [5:0] vram_ctrl_l;
always @(posedge clk) begin
    if( rst ) vram_ctrl_l <= 0;
    else begin
        if( vram_ctrl!=6'd0 && vram_ctrl!=vram_ctrl_l )
            $display("%m WARNING: unsupported K054156 VRAM timing/strobe control bits written (vram_ctrl=%02x, reg 0x0C) - not modelled by this core",vram_ctrl);
        vram_ctrl_l <= vram_ctrl;
    end
end
`endif

endmodule
