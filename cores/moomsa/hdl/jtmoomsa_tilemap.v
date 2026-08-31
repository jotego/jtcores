/* SPDX-License-Identifier: GPL-3.0-or-later */
`timescale 1ns/1ps

// GX151 scroll path: G4 K054156 and J1 K054157.
//
// The board has one T8/T10 graphics bus.  This block therefore owns the
// four logical tile clients and arbitrates them onto one request/response
// stream.  The three MB8464A devices are represented by the existing
// three-lane scroll-RAM boundary.  Their address pins are deliberately kept
// at the proven 13-bit physical boundary; the higher K054156 bank semantics
// remain diagnostic until the board PAL/page equations are recovered.
//
// Tile-map address generation follows the pinned JTFRAME 8x8 tile cadence:
// map entries are prefetched for the next pixel, and the JTFRAME engines
// consume the latched code/attribute word at the following pixel edge.
// The schematic fixes the external F/A/B widths and connected K1 bits, but
// not K054157's internal DFI/DSA/DSB generation or field permutation.  The
// attribute split below is therefore an explicit default profile, not a
// claimed silicon-equivalence result.
module jtmoomsa_tilemap(
    input             rst,
    input             clk,
    input             pxl_cen,

    input             raster_lhbl,
    input             raster_lvbl,
    input             raster_hs,
    input             raster_vs,
    input      [8:0]  raster_hdump,
    input      [8:0]  raster_vdump,
    input      [8:0]  raster_vrender,
    input      [8:0]  raster_vrender1,

    input             k056_reg_cs,
    input             k056_b_cs,
    input             k056_vram_cs,
    input             k056_rom_cs,
    input      [4:0]  k056_reg_addr,
    input      [1:0]  k056_b_addr,
    input      [13:1] k056_vram_addr,
    input      [12:1] k056_rom_addr,
    input             cpu_active,
    input             cpu_we,
    input      [15:0] cpu_din,
    input      [1:0]  cpu_dsn,
    output reg [15:0] cpu_dout,
    output reg        cpu_dout_valid,

    output     [15:0] rom_dout,
    output            rom_ok,
    output            rom_busy,

    output            lhbl,
    output            lvbl,
    output            hs,
    output            vs,
    output     [8:0]  hdump,
    output     [8:0]  vdump,
    output     [8:0]  vrender,
    output     [8:0]  vrender1,

    // One physical graphics request is exported.  The A/B names remain at
    // the video wrapper as inactive compatibility aliases because the
    // schematic has one T8/T10 bus, not three independent ROM buses.
    output     [20:2] lyrf_addr,
    output            lyrf_cs,
    input      [31:0] lyrf_data,
    input             lyrf_ok,

    input      [2:0]  gfx_en,
    output     [7:0]  direct_pxl,
    output     [8:0]  f_pxl,
    output     [7:0]  a_pxl,
    output     [7:0]  b_pxl
);

assign lhbl    = raster_lhbl;
assign lvbl    = raster_lvbl;
assign hs      = raster_hs;
assign vs      = raster_vs;
assign hdump   = raster_hdump;
assign vdump   = raster_vdump;
assign vrender = raster_vrender;
assign vrender1= raster_vrender1;

wire blankn = raster_lvbl && (raster_lhbl || raster_hdump >= 9'd496);

// The CPU window is the software-derived 0x0c0000 register aperture.  The
// low address bits are expanded back to the K054156 byte-register address.
wire [13:1] ctrl_ab = {6'd0,2'b00,k056_reg_addr};
wire reg_cs, reg_rd, reg_wr, reg_wr_hi, reg_wr_lo;
wire reg_wr_ctrl = reg_wr && (reg_wr_hi || reg_wr_lo);
wire [15:0] ctrl_dout;
wire ctrl_dout_valid;
// G4 D0..D15 connect directly to MAIN_D0..MAIN_D15.  Keep the 68000
// {UDS,LDS} byte enables and data lanes in CPU order at this boundary.
wire [1:0] ctrl_dsn = cpu_dsn;
wire [15:0] ctrl_din = cpu_din;
wire [15:0] ctrl_dout_cpu = ctrl_dout;
// Stable diagnostic names retained for existing headless probes.  They are
// not additional implementations of the CPU decoder.
wire reg_write = k056_reg_cs && cpu_we;
wire b_write = k056_b_cs && cpu_we;
wire vram_write = k056_vram_cs && cpu_we;

jtmoomsa_054156_decode u_054156_decode(
    .nrcs    (~k056_reg_cs),
    .ab      (ctrl_ab[7:4]),
    .rw      (!cpu_we),
    .uds_n   (cpu_dsn[1]),
    .lds_n   (cpu_dsn[0]),
    .reg_cs  (reg_cs),
    .reg_rd  (reg_rd),
    .reg_wr  (reg_wr),
    .reg_wr_hi(reg_wr_hi),
    .reg_wr_lo(reg_wr_lo)
);

wire [10:0] scroll_y0, scroll_y1, scroll_y2, scroll_y3;
wire [11:0] scroll_x0, scroll_x1, scroll_x2, scroll_x3;
wire [5:0] linescroll_bank, vram_bank;
wire [15:0] rom_bank, tile_bank_lut;
wire [1:0] rom_bank_hi;
wire [10:0] x_flip_offset, y_flip_offset;
wire [7:0] reg00, reg02, reg04, reg06, reg08, reg0a, reg0c;
wire [2:0] y_grid0, y_grid1, y_grid2, y_grid3;
wire [2:0] y_pages0, y_pages1, y_pages2, y_pages3;
wire [2:0] x_grid0, x_grid1, x_grid2, x_grid3;
wire [2:0] x_pages0, x_pages1, x_pages2, x_pages3;
wire flip_x, flip_y;

jtmoomsa_054156_ctrl u_054156_ctrl(
    .clk(clk), .rst(rst), .ab(ctrl_ab), .db_in(ctrl_din), .dsn(ctrl_dsn),
    .cs(reg_cs), .we(reg_wr_ctrl), .rd(reg_rd),
    .db_out(ctrl_dout), .db_valid(ctrl_dout_valid),
    .scroll_y0(scroll_y0), .scroll_y1(scroll_y1),
    .scroll_y2(scroll_y2), .scroll_y3(scroll_y3),
    .scroll_x0(scroll_x0), .scroll_x1(scroll_x1),
    .scroll_x2(scroll_x2), .scroll_x3(scroll_x3),
    .linescroll_bank(linescroll_bank), .vram_bank(vram_bank),
    .rom_bank(rom_bank), .rom_bank_hi(rom_bank_hi),
    .tile_bank_lut(tile_bank_lut),
    .x_flip_offset(x_flip_offset), .y_flip_offset(y_flip_offset),
    .reg00(reg00), .reg02(reg02), .reg04(reg04), .reg06(reg06),
    .reg08(reg08), .reg0a(reg0a), .reg0c(reg0c),
    .y_grid0(y_grid0), .y_grid1(y_grid1),
    .y_grid2(y_grid2), .y_grid3(y_grid3),
    .y_pages0(y_pages0), .y_pages1(y_pages1),
    .y_pages2(y_pages2), .y_pages3(y_pages3),
    .x_grid0(x_grid0), .x_grid1(x_grid1),
    .x_grid2(x_grid2), .x_grid3(x_grid3),
    .x_pages0(x_pages0), .x_pages1(x_pages1),
    .x_pages2(x_pages2), .x_pages3(x_pages3),
    .flip_x(flip_x), .flip_y(flip_y)
);

// J1's second register bank is visible through the existing 0x0d8000
// compatibility window.  It is kept separate from the G4 register file.
reg [15:0] bregs [0:3];
reg [15:0] b_dout;
reg        b_dout_valid;
integer bi;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        b_dout       <= 16'h0000;
        b_dout_valid <= 1'b0;
        for (bi = 0; bi < 4; bi = bi + 1)
            bregs[bi] <= 16'h0000;
    end else begin
        b_dout_valid <= 1'b0;
        if (k056_b_cs && !cpu_we) begin
            b_dout       <= bregs[k056_b_addr];
            b_dout_valid <= 1'b1;
        end
        if (k056_b_cs && cpu_we) begin
            if (!cpu_dsn[1])
                bregs[k056_b_addr][15:8] <= cpu_din[15:8];
            if (!cpu_dsn[0])
                bregs[k056_b_addr][7:0] <= cpu_din[7:0];
        end
    end
end

// The direct scroll sheet exposes three 8-bit SRAM lanes behind one RA bus.
// CPU byte lanes are mapped to VD0..7 and VD8..15; VD16..23 is display data.
// This is the bounded physical interface, not a claim that the unresolved
// P6/PAL address expansion has been recovered.
reg [2:0]  scan_slot;
reg [1:0]  scan_read_slot_q;
reg        scan_read_valid_q;
reg [12:0] scan_read_addr_q;
reg [12:0] scan_addr0_q, scan_addr1_q, scan_addr2_q, scan_addr3_q;
reg [12:0] map_addr0_q, map_addr1_q, map_addr2_q, map_addr3_q;
reg [23:0] map_word0, map_word1, map_word2, map_word3;
reg [12:0] scan_addr_selected;
reg [1:0]  scan_issue_slot;
reg        scan_issue_valid;
wire [16:0] vram_cpu_phys;
wire [12:0] cpu_vram_phys;
wire [12:0] vram_phys_addr = k056_vram_cs ? cpu_vram_phys :
    scan_addr_selected;
wire [23:0] cpu_vram_din;
wire [2:0] vram_rwe_n;
wire [23:0] vram_dout;
/* The inactive capture output remains explicit for diagnostics. */
/* verilator lint_off UNUSEDSIGNAL */
wire [23:0] cpu_vd_latch;
wire [16:0] scan_va_diag;
wire [12:0] scan_scrama_diag;
wire [3:0]  reg04_hi_diag = reg04[7:4];
wire [1:0]  scroll_y0_hi_diag = scroll_y0[10:9];
wire [1:0]  scroll_y1_hi_diag = scroll_y1[10:9];
wire [1:0]  scroll_y2_hi_diag = scroll_y2[10:9];
wire [1:0]  scroll_y3_hi_diag = scroll_y3[10:9];
wire [2:0]  scroll_x0_hi_diag = scroll_x0[11:9];
wire [2:0]  scroll_x1_hi_diag = scroll_x1[11:9];
wire [2:0]  scroll_x2_hi_diag = scroll_x2[11:9];
wire [2:0]  scroll_x3_hi_diag = scroll_x3[11:9];
wire [5:0]  linescroll_bank_diag = linescroll_bank;
wire [15:0] tile_bank_lut_diag = tile_bank_lut;
wire [1:0]  rom_bank_hi_diag = rom_bank_hi;
wire [10:0] x_flip_offset_diag = x_flip_offset;
wire [10:0] y_flip_offset_diag = y_flip_offset;
wire [7:0]  reg00_diag = reg00;
wire [7:0]  reg02_diag = reg02;
wire [5:0]  reg06_lo_diag = reg06[5:0];
wire [7:0]  reg08_diag = reg08;
wire [7:0]  reg0a_diag = reg0a;
wire [7:0]  reg0c_diag = reg0c;
wire [1:0]  y_grid0_hi_diag = y_grid0[2:1];
wire [1:0]  y_grid1_hi_diag = y_grid1[2:1];
wire [1:0]  y_grid2_hi_diag = y_grid2[2:1];
wire [1:0]  y_grid3_hi_diag = y_grid3[2:1];
wire [1:0]  x_grid0_hi_diag = x_grid0[2:1];
wire [1:0]  x_grid1_hi_diag = x_grid1[2:1];
wire [1:0]  x_grid2_hi_diag = x_grid2[2:1];
wire [1:0]  x_grid3_hi_diag = x_grid3[2:1];
/* verilator lint_on UNUSEDSIGNAL */

jtmoomsa_054156_vram_data u_cpu_vram_data(
    .clk(clk), .capture(1'b0), .vd_in(24'd0), .vd_latch(cpu_vd_latch),
    .cpu_vram_cs(k056_vram_cs), .cpu_active(cpu_active), .cpu_we(cpu_we),
    .cpu_a1(k056_vram_addr[1]), .cpu_dsn(cpu_dsn), .cpu_din(cpu_din),
    .cpu_vd_out(cpu_vram_din), .cpu_rwe_n(vram_rwe_n)
);

jtmoomsa_054156_vram_addr u_cpu_vram_addr(
    // Decap F32: AB_RAM0..10 latch package AB2..AB12.  AB1 selects the
    // attribute/code CPU word and is handled by the three-lane data path.
    .cpu_ab_ram(k056_vram_addr[12:2]),
    .cpu_ab_mux_ram(k056_vram_addr[12:2]),
    .scan_low(11'd0), .scan_page(6'd0),
    .cpu_bank(vram_bank), .scan_bank(6'd0),
    .cpu_addr_mode(reg04[3]), .scan_bank_mode(1'b0),
    .cpu_va(vram_cpu_phys), .scan_va(scan_va_diag),
    .cpu_scrama(cpu_vram_phys), .scan_scrama(scan_scrama_diag)
);

jtmoomsa_scroll_vram_lanes u_scroll_vram(
    .clk(clk),
    .scrama(vram_phys_addr),
    .vd_in(cpu_vram_din),
    .rwe_n(vram_rwe_n),
    .roe_n(3'b000),
    .vd_out(vram_dout)
);

// The populated scroll SRAM is addressed as four 64x32 tile pages:
// {page_y,page_x,tile_row[4:0],tile_col[5:0]}.  The two page bits are the
// only display-side projection available at SCRAMA[12:0].  Grid selects set
// the page base; a nonzero page count enables the corresponding wrapped
// coordinate bit.  Higher undocumented PAL expansion remains outside this
// bounded profile.
wire [9:0] f_xsum = {1'b0,raster_hdump} + {1'b0,scroll_x0[8:0]} + 10'd1;
/* verilator lint_off UNUSEDSIGNAL */
wire [2:0] f_xsum_lo_diag = f_xsum[2:0];
/* verilator lint_on UNUSEDSIGNAL */
wire [9:0] a_xsum = {1'b0,raster_hdump} + {1'b0,scroll_x1[8:0]} + 10'd1;
/* verilator lint_off UNUSEDSIGNAL */
wire [2:0] a_xsum_lo_diag = a_xsum[2:0];
/* verilator lint_on UNUSEDSIGNAL */
wire [9:0] b_xsum = {1'b0,raster_hdump} + {1'b0,scroll_x2[8:0]} + 10'd48;
/* verilator lint_off UNUSEDSIGNAL */
wire [2:0] b_xsum_lo_diag = b_xsum[2:0];
/* verilator lint_on UNUSEDSIGNAL */
wire [9:0] c_xsum = {1'b0,raster_hdump} + {1'b0,scroll_x3[8:0]} + 10'd46;
/* verilator lint_off UNUSEDSIGNAL */
wire [2:0] c_xsum_lo_diag = c_xsum[2:0];
/* verilator lint_on UNUSEDSIGNAL */
wire [9:0] f_ysum = {1'b0,raster_vdump} + {1'b0,scroll_y0[8:0]};
/* verilator lint_off UNUSEDSIGNAL */
wire f_ysum_hi_diag = f_ysum[9];
/* verilator lint_on UNUSEDSIGNAL */
wire [9:0] a_ysum = {1'b0,raster_vdump} + {1'b0,scroll_y1[8:0]};
/* verilator lint_off UNUSEDSIGNAL */
wire a_ysum_hi_diag = a_ysum[9];
/* verilator lint_on UNUSEDSIGNAL */
wire [9:0] b_ysum = {1'b0,raster_vdump} + {1'b0,scroll_y2[8:0]};
/* verilator lint_off UNUSEDSIGNAL */
wire b_ysum_hi_diag = b_ysum[9];
/* verilator lint_on UNUSEDSIGNAL */
wire [9:0] c_ysum = {1'b0,raster_vdump} + {1'b0,scroll_y3[8:0]};
/* verilator lint_off UNUSEDSIGNAL */
wire c_ysum_hi_diag = c_ysum[9];
/* verilator lint_on UNUSEDSIGNAL */
wire [8:0] f_vmap_next = {f_ysum[8],f_ysum[7:0] ^ {8{flip_y}}};
/* verilator lint_off UNUSEDSIGNAL */
wire [2:0] f_vmap_lo_diag = f_vmap_next[2:0];
/* verilator lint_on UNUSEDSIGNAL */
wire [8:0] a_vmap_next = {a_ysum[8],a_ysum[7:0] ^ {8{flip_y}}};
/* verilator lint_off UNUSEDSIGNAL */
wire [2:0] a_vmap_lo_diag = a_vmap_next[2:0];
/* verilator lint_on UNUSEDSIGNAL */
wire [8:0] b_vmap_next = {b_ysum[8],b_ysum[7:0] ^ {8{flip_y}}};
/* verilator lint_off UNUSEDSIGNAL */
wire [2:0] b_vmap_lo_diag = b_vmap_next[2:0];
/* verilator lint_on UNUSEDSIGNAL */
wire [8:0] c_vmap_next = {c_ysum[8],c_ysum[7:0] ^ {8{flip_y}}};
/* verilator lint_off UNUSEDSIGNAL */
wire [2:0] c_vmap_lo_diag = c_vmap_next[2:0];
/* verilator lint_on UNUSEDSIGNAL */
wire [10:0] f_tile_index_next = {f_vmap_next[7:3],f_xsum[8:3]};
wire [10:0] a_tile_index_next = {a_vmap_next[7:3],a_xsum[8:3]};
wire [10:0] b_tile_index_next = {b_vmap_next[7:3],b_xsum[8:3]};
wire [10:0] c_tile_index_next = {c_vmap_next[7:3],c_xsum[8:3]};
wire f_page_x = x_grid0[0] ^ ((|x_pages0) && f_xsum[9]);
wire f_page_y = y_grid0[0] ^ ((|y_pages0) && f_vmap_next[8]);
wire a_page_x = x_grid1[0] ^ ((|x_pages1) && a_xsum[9]);
wire a_page_y = y_grid1[0] ^ ((|y_pages1) && a_vmap_next[8]);
wire b_page_x = x_grid2[0] ^ ((|x_pages2) && b_xsum[9]);
wire b_page_y = y_grid2[0] ^ ((|y_pages2) && b_vmap_next[8]);
wire c_page_x = x_grid3[0] ^ ((|x_pages3) && c_xsum[9]);
wire c_page_y = y_grid3[0] ^ ((|y_pages3) && c_vmap_next[8]);
wire [12:0] f_map_addr_next = {f_page_y,f_page_x,f_tile_index_next};
wire [12:0] a_map_addr_next = {a_page_y,a_page_x,a_tile_index_next};
wire [12:0] b_map_addr_next = {b_page_y,b_page_x,b_tile_index_next};
wire [12:0] c_map_addr_next = {c_page_y,c_page_x,c_tile_index_next};

always @* begin
    scan_issue_valid = 1'b0;
    scan_issue_slot = scan_slot[1:0];
    scan_addr_selected = scan_addr0_q;
    if (!k056_vram_cs) begin
        if (pxl_cen) begin
            scan_issue_valid = 1'b1;
            scan_issue_slot = 2'd0;
            scan_addr_selected = f_map_addr_next;
        end else if (scan_slot < 3'd4) begin
            scan_issue_valid = 1'b1;
            case (scan_slot[1:0])
                2'd0: scan_addr_selected = scan_addr0_q;
                2'd1: scan_addr_selected = scan_addr1_q;
                2'd2: scan_addr_selected = scan_addr2_q;
                default: scan_addr_selected = scan_addr3_q;
            endcase
        end
    end
end

always @(posedge clk or posedge rst) begin
    if (rst) begin
        scan_slot  <= 3'd4;
        scan_read_slot_q <= 2'd0;
        scan_read_valid_q <= 1'b0;
        scan_read_addr_q <= 13'd0;
        scan_addr0_q <= 13'd0;
        scan_addr1_q <= 13'd0;
        scan_addr2_q <= 13'd0;
        scan_addr3_q <= 13'd0;
        map_addr0_q <= 13'd0;
        map_addr1_q <= 13'd0;
        map_addr2_q <= 13'd0;
        map_addr3_q <= 13'd0;
        map_word0 <= 24'd0;
        map_word1 <= 24'd0;
        map_word2 <= 24'd0;
        map_word3 <= 24'd0;
    end else begin
        scan_read_valid_q <= scan_issue_valid;
        if (scan_issue_valid) begin
            scan_read_slot_q <= scan_issue_slot;
            scan_read_addr_q <= scan_addr_selected;
        end

        if (scan_read_valid_q) begin
            case (scan_read_slot_q)
                2'd0: begin map_word0 <= vram_dout; map_addr0_q <= scan_read_addr_q; end
                2'd1: begin map_word1 <= vram_dout; map_addr1_q <= scan_read_addr_q; end
                2'd2: begin map_word2 <= vram_dout; map_addr2_q <= scan_read_addr_q; end
                default: begin map_word3 <= vram_dout; map_addr3_q <= scan_read_addr_q; end
            endcase
        end

        if (pxl_cen) begin
            scan_addr0_q <= f_map_addr_next;
            scan_addr1_q <= a_map_addr_next;
            scan_addr2_q <= b_map_addr_next;
            scan_addr3_q <= c_map_addr_next;
            scan_slot <= scan_issue_valid ? 3'd1 : 3'd0;
        end else if (scan_issue_valid) begin
            if (scan_issue_slot == 2'd3)
                scan_slot <= 3'd4;
            else
                scan_slot <= {1'b0,scan_issue_slot} + 3'd1;
        end
    end
end

reg [15:0] vram_cpu_dout;
reg        vram_cpu_dout_valid;
reg        vram_cpu_read_q;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        vram_cpu_dout       <= 16'h0000;
        vram_cpu_dout_valid <= 1'b0;
        vram_cpu_read_q     <= 1'b0;
    end else begin
        vram_cpu_read_q <= k056_vram_cs && cpu_active && !cpu_we;
        vram_cpu_dout_valid <= vram_cpu_read_q;
        if (vram_cpu_read_q)
            vram_cpu_dout <= {vram_dout[15:8],vram_dout[7:0]};
    end
end

always @* begin
    cpu_dout       = 16'h0000;
    cpu_dout_valid = 1'b0;
    if (ctrl_dout_valid) begin
        cpu_dout       = ctrl_dout_cpu;
        cpu_dout_valid = 1'b1;
    end else if (b_dout_valid) begin
        cpu_dout       = b_dout;
        cpu_dout_valid = 1'b1;
    end else if (vram_cpu_dout_valid) begin
        cpu_dout       = vram_cpu_dout;
        cpu_dout_valid = 1'b1;
    end
end

function [1:0] attr_flip;
    input [7:0] attr;
    input [1:0] sel;
    begin
        case (sel)
            2'd0: attr_flip = attr[7:6];
            2'd1: attr_flip = attr[5:4];
            2'd2: attr_flip = attr[3:2];
            default: attr_flip = attr[1:0];
        endcase
    end
endfunction

// The K054156 RE evidence identifies the 24-bit attribute byte and the
// three-bit tile-bank field.  The exact J1 output packing is still open; the
// default profile keeps the lower 16 bits as {bank[2:0],code[12:0]} and uses
// the selected attribute pair for tile flips.
wire [1:0] direct_attr_flip = attr_flip(map_word0[23:16],reg06[7:6]);
wire [1:0] f_attr_flip = attr_flip(map_word1[23:16],reg06[7:6]);
wire [1:0] a_attr_flip = attr_flip(map_word2[23:16],reg06[7:6]);
wire [1:0] b_attr_flip = attr_flip(map_word3[23:16],reg06[7:6]);
wire [2:0] direct_bank = map_word0[15:13];
wire [2:0] f_bank = map_word1[15:13];
wire [2:0] a_bank = map_word2[15:13];
wire [2:0] b_bank = map_word3[15:13];
wire [12:0] direct_code_low = map_word0[12:0];
wire [12:0] f_code_low = map_word1[12:0];
wire [12:0] a_code_low = map_word2[12:0];
wire [12:0] b_code_low = map_word3[12:0];
wire [15:0] direct_code = {direct_bank,direct_code_low};
wire [15:0] f_code = {f_bank,f_code_low};
wire [15:0] a_code = {a_bank,a_code_low};
wire [15:0] b_code = {b_bank,b_code_low};
wire [3:0] direct_pal = map_word0[19:16];
wire [3:0] f_attr_pal, a_attr_pal, b_attr_pal;
wire [4:0] f_pal = {1'b0,f_attr_pal};
wire [3:0] a_pal = a_attr_pal;
wire [3:0] b_pal = b_attr_pal;
wire [1:0] j1_attr_sel = bregs[3][7:6];

jtmoomsa_054157_palette_bits u_f_palette_bits(
    .attr(map_word1[23:18]), .fbits(j1_attr_sel), .pal(f_attr_pal)
);

jtmoomsa_054157_palette_bits u_a_palette_bits(
    .attr(map_word2[23:18]), .fbits(j1_attr_sel), .pal(a_attr_pal)
);

jtmoomsa_054157_palette_bits u_b_palette_bits(
    .attr(map_word3[23:18]), .fbits(j1_attr_sel), .pal(b_attr_pal)
);

wire [8:0] direct_draw_h = raster_hdump + scroll_x0[8:0];
wire [8:0] f_draw_h = raster_hdump + scroll_x1[8:0];
wire [8:0] a_draw_h = raster_hdump + scroll_x2[8:0] + 9'd47;
wire [8:0] b_draw_h = raster_hdump + scroll_x3[8:0] + 9'd45;
wire [8:0] direct_draw_v = raster_vdump + scroll_y0[8:0];
wire [8:0] f_draw_v = raster_vdump + scroll_y1[8:0];
wire [8:0] a_draw_v = raster_vdump + scroll_y2[8:0];
wire [8:0] b_draw_v = raster_vdump + scroll_y3[8:0];

wire [11:0] direct_vram_addr_unused, f_vram_addr_unused;
wire [11:0] a_vram_addr_unused, b_vram_addr_unused;
wire [18:0] direct_rom_addr_raw, f_rom_addr_raw;
wire [18:0] a_rom_addr_raw, b_rom_addr_raw;
wire direct_rom_cs, f_rom_cs, a_rom_cs, b_rom_cs;
wire [31:0] direct_rom_data_q, f_rom_data_q;
wire [31:0] a_rom_data_q, b_rom_data_q;
wire direct_rom_ok, f_rom_ok, a_rom_ok, b_rom_ok;
wire [7:0] direct_tile_pxl;
wire [8:0] f_pxl9;
wire [7:0] a_tile_pxl;
wire [7:0] b_tile_pxl;

jtframe_tilemap #(
    .SIZE(8), .VA(12), .CW(16), .PW(8), .MAP_HW(9), .MAP_VW(9),
    .HDUMPW(9), .VDUMPW(9), .XOR_HFLIP(1), .XOR_VFLIP(1)
) u_direct(
    .rst(rst), .clk(clk), .pxl_cen(pxl_cen),
    .vdump(direct_draw_v), .hdump(direct_draw_h),
    .blankn(blankn), .flip(flip_y),
    .vram_addr(direct_vram_addr_unused), .code(direct_code), .pal(direct_pal),
    .hflip(direct_attr_flip[0] ^ flip_x ^ flip_y),
    .vflip(direct_attr_flip[1]),
    .rom_addr(direct_rom_addr_raw), .rom_data(direct_rom_data_q),
    .rom_cs(direct_rom_cs), .rom_ok(direct_rom_ok), .pxl(direct_tile_pxl)
);

jtframe_tilemap #(
    .SIZE(8), .VA(12), .CW(16), .PW(9), .MAP_HW(9), .MAP_VW(9),
    .HDUMPW(9), .VDUMPW(9), .XOR_HFLIP(1), .XOR_VFLIP(1)
) u_f(
    .rst(rst), .clk(clk), .pxl_cen(pxl_cen),
    .vdump(f_draw_v), .hdump(f_draw_h),
    .blankn(blankn && gfx_en[0]), .flip(flip_y),
    .vram_addr(f_vram_addr_unused), .code(f_code), .pal(f_pal),
    .hflip(f_attr_flip[0] ^ flip_x ^ flip_y),
    .vflip(f_attr_flip[1]),
    .rom_addr(f_rom_addr_raw), .rom_data(f_rom_data_q),
    .rom_cs(f_rom_cs), .rom_ok(f_rom_ok), .pxl(f_pxl9)
);

jtframe_tilemap #(
    .SIZE(8), .VA(12), .CW(16), .PW(8), .MAP_HW(9), .MAP_VW(9),
    .HDUMPW(9), .VDUMPW(9), .XOR_HFLIP(1), .XOR_VFLIP(1)
) u_a(
    .rst(rst), .clk(clk), .pxl_cen(pxl_cen),
    .vdump(a_draw_v), .hdump(a_draw_h),
    .blankn(blankn && gfx_en[1]), .flip(flip_y),
    .vram_addr(a_vram_addr_unused), .code(a_code), .pal(a_pal),
    .hflip(a_attr_flip[0] ^ flip_x ^ flip_y),
    .vflip(a_attr_flip[1]),
    .rom_addr(a_rom_addr_raw), .rom_data(a_rom_data_q),
    .rom_cs(a_rom_cs), .rom_ok(a_rom_ok), .pxl(a_tile_pxl)
);

jtframe_tilemap #(
    .SIZE(8), .VA(12), .CW(16), .PW(8), .MAP_HW(9), .MAP_VW(9),
    .HDUMPW(9), .VDUMPW(9), .XOR_HFLIP(1), .XOR_VFLIP(1)
) u_b(
    .rst(rst), .clk(clk), .pxl_cen(pxl_cen),
    .vdump(b_draw_v), .hdump(b_draw_h),
    .blankn(blankn && gfx_en[2]), .flip(flip_y),
    .vram_addr(b_vram_addr_unused), .code(b_code), .pal(b_pal),
    .hflip(b_attr_flip[0] ^ flip_x ^ flip_y),
    .vflip(b_attr_flip[1]),
    .rom_addr(b_rom_addr_raw), .rom_data(b_rom_data_q),
    .rom_cs(b_rom_cs), .rom_ok(b_rom_ok), .pxl(b_tile_pxl)
);

assign direct_pxl = direct_tile_pxl;
assign f_pxl = gfx_en[0] ? f_pxl9 : 9'd0;
assign a_pxl = gfx_en[1] ? a_tile_pxl : 8'd0;
assign b_pxl = gfx_en[2] ? b_tile_pxl : 8'd0;

// One physical T8/T10 request arbitrates the four JTFRAME tile clients.
// The client result is held until the next pixel edge, which is the explicit
// response contract expected by jtframe_tilemap's registered fetch stage.
reg [3:0]  vis_pending, vis_ready, vis_seen;
reg [18:0] vis_req0, vis_req1, vis_req2, vis_req3;
reg [31:0] vis_data0, vis_data1, vis_data2, vis_data3;
reg [1:0]  vis_client, vis_rr;
reg        vis_wait;
reg [18:0] vis_addr_q;
wire [31:0] direct_rom_data_sorted, f_rom_data_sorted;
wire [31:0] a_rom_data_sorted, b_rom_data_sorted;

localparam CPU_ROM_IDLE = 2'd0, CPU_ROM_WAIT = 2'd1,
           CPU_ROM_DONE = 2'd2;
reg [1:0] cpu_rom_state;
reg [12:1] cpu_rom_addr_q;
reg [15:0] cpu_rom_bank_q;
reg [15:0] cpu_rom_data_q;

/* verilator lint_off UNUSEDSIGNAL */
wire [7:0] cpu_rom_bank_hi_diag = cpu_rom_bank_q[15:8];
/* verilator lint_on UNUSEDSIGNAL */
wire [18:0] cpu_rom_phys = {cpu_rom_bank_q[7:0],cpu_rom_addr_q[12:2]};
wire cpu_rom_bus = (cpu_rom_state == CPU_ROM_WAIT) && !vis_wait;
wire [18:0] selected_rom_addr = vis_wait ? vis_addr_q :
                                 cpu_rom_bus ? cpu_rom_phys : 19'd0;

assign lyrf_addr = selected_rom_addr;
assign lyrf_cs = vis_wait || cpu_rom_bus;

jtframe_8x8x4_packed_msb u_direct_packed(
    .raw(vis_data0), .sorted(direct_rom_data_sorted)
);

jtframe_8x8x4_packed_msb u_f_packed(
    .raw(vis_data1), .sorted(f_rom_data_sorted)
);

jtframe_8x8x4_packed_msb u_a_packed(
    .raw(vis_data2), .sorted(a_rom_data_sorted)
);

jtframe_8x8x4_packed_msb u_b_packed(
    .raw(vis_data3), .sorted(b_rom_data_sorted)
);

assign direct_rom_data_q = direct_rom_data_sorted;
assign f_rom_data_q = f_rom_data_sorted;
assign a_rom_data_q = a_rom_data_sorted;
assign b_rom_data_q = b_rom_data_sorted;
assign direct_rom_ok = direct_rom_cs && vis_ready[0] &&
                       (vis_req0 == direct_rom_addr_raw);
assign f_rom_ok = f_rom_cs && vis_ready[1] && (vis_req1 == f_rom_addr_raw);
assign a_rom_ok = a_rom_cs && vis_ready[2] && (vis_req2 == a_rom_addr_raw);
assign b_rom_ok = b_rom_cs && vis_ready[3] && (vis_req3 == b_rom_addr_raw);

always @(posedge clk or posedge rst) begin
    if (rst) begin
        vis_pending <= 4'b0000;
        vis_ready   <= 4'b0000;
        vis_seen    <= 4'b0000;
        vis_req0    <= 19'd0;
        vis_req1    <= 19'd0;
        vis_req2    <= 19'd0;
        vis_req3    <= 19'd0;
        vis_data0   <= 32'd0;
        vis_data1   <= 32'd0;
        vis_data2   <= 32'd0;
        vis_data3   <= 32'd0;
        vis_client  <= 2'd0;
        vis_rr      <= 2'd0;
        vis_wait    <= 1'b0;
        vis_addr_q  <= 19'd0;
    end else begin
        if (!direct_rom_cs) begin
            vis_seen[0]    <= 1'b0;
            vis_pending[0] <= 1'b0;
            vis_ready[0]   <= 1'b0;
        end else if (!vis_seen[0] || (vis_req0 != direct_rom_addr_raw)) begin
            vis_seen[0]    <= 1'b1;
            vis_pending[0] <= 1'b1;
            vis_ready[0]   <= 1'b0;
            vis_req0       <= direct_rom_addr_raw;
        end
        if (!f_rom_cs) begin
            vis_seen[1]    <= 1'b0;
            vis_pending[1] <= 1'b0;
            vis_ready[1]   <= 1'b0;
        end else if (!vis_seen[1] || (vis_req1 != f_rom_addr_raw)) begin
            vis_seen[1]    <= 1'b1;
            vis_pending[1] <= 1'b1;
            vis_ready[1]   <= 1'b0;
            vis_req1       <= f_rom_addr_raw;
        end
        if (!a_rom_cs) begin
            vis_seen[2]    <= 1'b0;
            vis_pending[2] <= 1'b0;
            vis_ready[2]   <= 1'b0;
        end else if (!vis_seen[2] || (vis_req2 != a_rom_addr_raw)) begin
            vis_seen[2]    <= 1'b1;
            vis_pending[2] <= 1'b1;
            vis_ready[2]   <= 1'b0;
            vis_req2       <= a_rom_addr_raw;
        end
        if (!b_rom_cs) begin
            vis_seen[3]    <= 1'b0;
            vis_pending[3] <= 1'b0;
            vis_ready[3]   <= 1'b0;
        end else if (!vis_seen[3] || (vis_req3 != b_rom_addr_raw)) begin
            vis_seen[3]    <= 1'b1;
            vis_pending[3] <= 1'b1;
            vis_ready[3]   <= 1'b0;
            vis_req3       <= b_rom_addr_raw;
        end

        if (!pxl_cen && !vis_wait && !k056_rom_cs &&
                (cpu_rom_state == CPU_ROM_IDLE)) begin
            case (vis_rr)
                2'd0: begin
                    if (vis_pending[0] && direct_rom_cs &&
                            (vis_req0 == direct_rom_addr_raw)) begin
                        vis_client <= 2'd0; vis_addr_q <= vis_req0;
                        vis_pending[0] <= 1'b0; vis_wait <= 1'b1;
                    end else if (vis_pending[1] && f_rom_cs &&
                            (vis_req1 == f_rom_addr_raw)) begin
                        vis_client <= 2'd1; vis_addr_q <= vis_req1;
                        vis_pending[1] <= 1'b0; vis_wait <= 1'b1;
                    end else if (vis_pending[2] && a_rom_cs &&
                            (vis_req2 == a_rom_addr_raw)) begin
                        vis_client <= 2'd2; vis_addr_q <= vis_req2;
                        vis_pending[2] <= 1'b0; vis_wait <= 1'b1;
                    end else if (vis_pending[3] && b_rom_cs &&
                            (vis_req3 == b_rom_addr_raw)) begin
                        vis_client <= 2'd3; vis_addr_q <= vis_req3;
                        vis_pending[3] <= 1'b0; vis_wait <= 1'b1;
                    end
                end
                2'd1: begin
                    if (vis_pending[1] && f_rom_cs &&
                            (vis_req1 == f_rom_addr_raw)) begin
                        vis_client <= 2'd1; vis_addr_q <= vis_req1;
                        vis_pending[1] <= 1'b0; vis_wait <= 1'b1;
                    end else if (vis_pending[2] && a_rom_cs &&
                            (vis_req2 == a_rom_addr_raw)) begin
                        vis_client <= 2'd2; vis_addr_q <= vis_req2;
                        vis_pending[2] <= 1'b0; vis_wait <= 1'b1;
                    end else if (vis_pending[3] && b_rom_cs &&
                            (vis_req3 == b_rom_addr_raw)) begin
                        vis_client <= 2'd3; vis_addr_q <= vis_req3;
                        vis_pending[3] <= 1'b0; vis_wait <= 1'b1;
                    end else if (vis_pending[0] && direct_rom_cs &&
                            (vis_req0 == direct_rom_addr_raw)) begin
                        vis_client <= 2'd0; vis_addr_q <= vis_req0;
                        vis_pending[0] <= 1'b0; vis_wait <= 1'b1;
                    end
                end
                2'd2: begin
                    if (vis_pending[2] && a_rom_cs &&
                            (vis_req2 == a_rom_addr_raw)) begin
                        vis_client <= 2'd2; vis_addr_q <= vis_req2;
                        vis_pending[2] <= 1'b0; vis_wait <= 1'b1;
                    end else if (vis_pending[3] && b_rom_cs &&
                            (vis_req3 == b_rom_addr_raw)) begin
                        vis_client <= 2'd3; vis_addr_q <= vis_req3;
                        vis_pending[3] <= 1'b0; vis_wait <= 1'b1;
                    end else if (vis_pending[0] && direct_rom_cs &&
                            (vis_req0 == direct_rom_addr_raw)) begin
                        vis_client <= 2'd0; vis_addr_q <= vis_req0;
                        vis_pending[0] <= 1'b0; vis_wait <= 1'b1;
                    end else if (vis_pending[1] && f_rom_cs &&
                            (vis_req1 == f_rom_addr_raw)) begin
                        vis_client <= 2'd1; vis_addr_q <= vis_req1;
                        vis_pending[1] <= 1'b0; vis_wait <= 1'b1;
                    end
                end
                default: begin
                    if (vis_pending[3] && b_rom_cs &&
                            (vis_req3 == b_rom_addr_raw)) begin
                        vis_client <= 2'd3; vis_addr_q <= vis_req3;
                        vis_pending[3] <= 1'b0; vis_wait <= 1'b1;
                    end else if (vis_pending[0] && direct_rom_cs &&
                            (vis_req0 == direct_rom_addr_raw)) begin
                        vis_client <= 2'd0; vis_addr_q <= vis_req0;
                        vis_pending[0] <= 1'b0; vis_wait <= 1'b1;
                    end else if (vis_pending[1] && f_rom_cs &&
                            (vis_req1 == f_rom_addr_raw)) begin
                        vis_client <= 2'd1; vis_addr_q <= vis_req1;
                        vis_pending[1] <= 1'b0; vis_wait <= 1'b1;
                    end else if (vis_pending[2] && a_rom_cs &&
                            (vis_req2 == a_rom_addr_raw)) begin
                        vis_client <= 2'd2; vis_addr_q <= vis_req2;
                        vis_pending[2] <= 1'b0; vis_wait <= 1'b1;
                    end
                end
            endcase
        end

        if (vis_wait && lyrf_ok) begin
            case (vis_client)
                2'd0: if (direct_rom_cs &&
                        (direct_rom_addr_raw == vis_addr_q)) begin
                    vis_data0 <= lyrf_data;
                    vis_ready[0] <= 1'b1;
                end
                2'd1: if (f_rom_cs && (f_rom_addr_raw == vis_addr_q)) begin
                    vis_data1 <= lyrf_data;
                    vis_ready[1] <= 1'b1;
                end
                2'd2: if (a_rom_cs && (a_rom_addr_raw == vis_addr_q)) begin
                    vis_data2 <= lyrf_data;
                    vis_ready[2] <= 1'b1;
                end
                default: if (b_rom_cs && (b_rom_addr_raw == vis_addr_q)) begin
                    vis_data3 <= lyrf_data;
                    vis_ready[3] <= 1'b1;
                end
            endcase
            vis_wait <= 1'b0;
            vis_rr <= vis_client + 1'b1;
        end
    end
end

always @(posedge clk or posedge rst) begin
    if (rst) begin
        cpu_rom_state  <= CPU_ROM_IDLE;
        cpu_rom_addr_q <= 12'd0;
        cpu_rom_bank_q <= 16'd0;
        cpu_rom_data_q <= 16'd0;
    end else begin
        case (cpu_rom_state)
            CPU_ROM_IDLE: if (k056_rom_cs) begin
                cpu_rom_addr_q <= k056_rom_addr;
                cpu_rom_bank_q <= rom_bank;
                cpu_rom_state  <= CPU_ROM_WAIT;
            end
            CPU_ROM_WAIT: begin
                if (!k056_rom_cs)
                    cpu_rom_state <= CPU_ROM_IDLE;
                else if (!vis_wait && lyrf_ok) begin
                    cpu_rom_data_q <= cpu_rom_addr_q[1] ?
                        lyrf_data[31:16] : lyrf_data[15:0];
                    cpu_rom_state <= CPU_ROM_DONE;
                end
            end
            CPU_ROM_DONE: if (!k056_rom_cs)
                cpu_rom_state <= CPU_ROM_IDLE;
            default: cpu_rom_state <= CPU_ROM_IDLE;
        endcase
    end
end

assign rom_dout = cpu_rom_data_q;
assign rom_ok = k056_rom_cs && (cpu_rom_state == CPU_ROM_DONE);
assign rom_busy = k056_rom_cs && (cpu_rom_state != CPU_ROM_DONE);

endmodule
