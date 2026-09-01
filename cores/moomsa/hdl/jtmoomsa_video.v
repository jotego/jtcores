/* SPDX-License-Identifier: GPL-3.0-or-later */

// Moo Mesa video boundary.  The live GX151 scroll owner is the
// K054156/K054157 tilemap; the former K056832 renderer is retained only as
// an isolated diagnostic source in the project, not instantiated here.
module jtmoomsa_video(
    input             rst, clk, pxl_cen, pxl2_cen,
    input             raster_lhbl, raster_lvbl, raster_hs, raster_vs,
    input      [8:0]  raster_hdump, raster_vdump,
    input      [8:0]  raster_vrender, raster_vrender1, raster_vmax,
    output            lhbl, lvbl, hs, vs,
    input      [16:1] cpu_addr,
    input      [15:0] cpu_dout,
    input      [1:0]  cpu_dsn,
    input             cpu_we, cpu_active,
    input      [13:1] oram_addr,
    input      [1:0]  oram_we,
    input             objsys_cs, objreg_cs, objcha_n, pcu_cs,
    output            vdtac,
    output     [7:0]  tilesys_dout,
    output     [15:0] pal_dout,
    input      [8:0]  object_pxl,
    input      [15:0] palette_cpu_din,
    output     [10:0] palette_addr,
    input      [23:0] color_rgb,
    output     [10:0] color_cout,
    output            color_brit,
    output            color_n,
    output     [1:0]  color_shadow,
    input      [4:0]  object_prio,
    input      [1:0]  object_shd,

    // Software-derived CPU windows.  Their P6 equations remain documented
    // open evidence; the tilemap consumes only the already-decoded selects.
    input             k056_reg_cs, k056_b_cs, k056_vram_cs, k056_rom_cs,
    input      [4:0]  k056_reg_addr,
    input      [1:0]  k056_b_addr,
    input      [13:1] k056_vram_addr,
    input      [12:1] k056_rom_addr,
    output     [15:0] k056_cpu_dout,
    output            k056_cpu_dout_valid,
    output     [15:0] k056_rom_dout,
    output            k056_rom_ok,
    output            k056_rom_busy,

    output     [20:2] lyrf_addr, lyra_addr, lyrb_addr,
    output            lyrf_cs, lyra_cs, lyrb_cs,
    input      [31:0] lyrf_data,
    input             lyrf_ok,
    output     [7:0]  red, green, blue,
    input      [3:0]  ioctl_addr,
    input             ioctl_ram,
    input      [2:0]  gfx_en,
    input      [3:0]  debug_bus,
    output     [7:0]  st_dout
);

wire cpu_write = cpu_we && cpu_active;
wire [7:0] direct_pxl;
reg  [7:0] direct_pxl_q1, direct_pxl_q2;
wire [8:0] lyrf_pxl;
wire [7:0] lyra_pxl, lyrb_pxl;
wire [15:0] tile_cpu_dout;
wire tile_cpu_dout_valid;
wire [15:0] tile_rom_dout;
wire tile_rom_ok, tile_rom_busy;

wire [1:0] shd_out;
wire [10:0] pal_addr;
wire [10:0] colmix_addr, direct_palette;
wire [2:0] colmix_winner;
wire [8:0] k1_ci0, k1_ci1, k1_ci2;
wire [7:0] k1_ci3, k1_ci4;
wire direct_opaque;
wire [4:0] object_prio_latched;
wire [1:0] object_shd_latched;
wire col_n_int, brit_int;
/* Legacy raster aliases have no downstream schematic sink in Moo. */
/* verilator lint_off UNUSEDSIGNAL */
wire [8:0] tile_hdump, tile_vdump, tile_vrender, tile_vrender1;
wire [7:0] k053251_ioctl_din;
wire        pxl2_cen_diag = pxl2_cen;
wire [8:0]  raster_vmax_diag = raster_vmax;
wire [11:0] cpu_addr_hi_diag = cpu_addr[16:5];
wire [13:1] oram_addr_diag = oram_addr;
wire [1:0]  oram_we_diag = oram_we;
wire        objsys_cs_diag = objsys_cs;
wire        objreg_cs_diag = objreg_cs;
wire        objcha_n_diag = objcha_n;
/* verilator lint_on UNUSEDSIGNAL */
wire k056_bus_cs = k056_reg_cs || k056_b_cs || k056_vram_cs;
reg tile_wait_seen;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        direct_pxl_q1 <= 8'd0;
        direct_pxl_q2 <= 8'd0;
    end else if (pxl_cen) begin
        direct_pxl_q1 <= direct_pxl;
        direct_pxl_q2 <= direct_pxl_q1;
    end
end

assign k056_cpu_dout       = tile_cpu_dout;
assign k056_cpu_dout_valid = tile_cpu_dout_valid;
assign k056_rom_dout       = tile_rom_dout;
assign k056_rom_ok         = tile_rom_ok;
assign k056_rom_busy       = tile_rom_busy;

assign tilesys_dout = tile_cpu_dout[7:0];
// The palette CPU window is owned by jtmoomsa_palette_rgb.  Keep this
// compatibility return path tied to that owner instead of manufacturing an
// all-white value when the wrapper is addressed through the video boundary.
assign pal_dout = palette_cpu_din;
assign st_dout = 8'd0;
assign lyra_addr = 19'd0;
assign lyrb_addr = 19'd0;
assign lyra_cs = 1'b0;
assign lyrb_cs = 1'b0;

assign palette_addr = pal_addr;
assign color_cout = pal_addr;
assign color_brit = direct_opaque ? 1'b0 : brit_int;
assign color_n = direct_opaque ? 1'b0 : col_n_int;
assign color_shadow = direct_opaque ? 2'b0 : shd_out;
assign red = (lhbl && lvbl) ? color_rgb[23:16] : 8'd0;
assign green = (lhbl && lvbl) ? color_rgb[15:8] : 8'd0;
assign blue = (lhbl && lvbl) ? color_rgb[7:0] : 8'd0;

// Keep the historical instance label for existing observation-only probes;
// the instantiated module is the live K054156/K054157 owner.
jtmoomsa_tilemap u_k056832(
    .rst(rst), .clk(clk), .pxl_cen(pxl_cen),
    .raster_lhbl(raster_lhbl), .raster_lvbl(raster_lvbl),
    .raster_hs(raster_hs), .raster_vs(raster_vs),
    .raster_hdump(raster_hdump), .raster_vdump(raster_vdump),
    .raster_vrender(raster_vrender), .raster_vrender1(raster_vrender1),
    .k056_reg_cs(k056_reg_cs), .k056_b_cs(k056_b_cs),
    .k056_vram_cs(k056_vram_cs), .k056_rom_cs(k056_rom_cs),
    .k056_reg_addr(k056_reg_addr), .k056_b_addr(k056_b_addr),
    .k056_vram_addr(k056_vram_addr), .k056_rom_addr(k056_rom_addr),
    .cpu_active(cpu_active), .cpu_we(cpu_write),
    .cpu_din(cpu_dout), .cpu_dsn(cpu_dsn),
    .cpu_dout(tile_cpu_dout), .cpu_dout_valid(tile_cpu_dout_valid),
    .rom_dout(tile_rom_dout), .rom_ok(tile_rom_ok), .rom_busy(tile_rom_busy),
    .lhbl(lhbl), .lvbl(lvbl), .hs(hs), .vs(vs),
    .hdump(tile_hdump), .vdump(tile_vdump),
    .vrender(tile_vrender), .vrender1(tile_vrender1),
    .lyrf_addr(lyrf_addr), .lyrf_cs(lyrf_cs),
    .lyrf_data(lyrf_data), .lyrf_ok(lyrf_ok),
    .gfx_en(gfx_en[2:0]), .direct_pxl(direct_pxl), .f_pxl(lyrf_pxl),
    .a_pxl(lyra_pxl), .b_pxl(lyrb_pxl)
);

jtmoomsa_k053251_map u_k053251_map(
    .direct_pxl(direct_pxl_q2), .f_pxl(lyrf_pxl), .a_pxl(lyra_pxl),
    .b_pxl(lyrb_pxl), .object_pxl(object_pxl),
    .ci0(k1_ci0), .ci1(k1_ci1), .ci2(k1_ci2),
    .ci3(k1_ci3), .ci4(k1_ci4),
    .direct_palette(direct_palette), .direct_opaque(direct_opaque)
);

jtmoomsa_obj_meta_latch u_obj_meta_latch(
    .clk(clk), .rst(rst), .cen(pxl_cen),
    .prio_in(object_prio), .shd_in(object_shd),
    .prio_out(object_prio_latched), .shd_out(object_shd_latched)
);

assign pal_addr = direct_opaque ? direct_palette : colmix_addr;

assign vdtac = !k056_bus_cs || tile_wait_seen;
always @(posedge clk) begin
    if (rst)
        tile_wait_seen <= 1'b0;
    else if (!k056_bus_cs)
        tile_wait_seen <= 1'b0;
    else
        tile_wait_seen <= 1'b1;
end

jtcolmix_053251 u_k053251(
    .rst(rst), .clk(clk), .pxl_cen(pxl_cen),
    .cs(pcu_cs && cpu_write && !cpu_dsn[0]),
    .addr(cpu_addr[4:1]), .din(cpu_dout[5:0]), .sel(1'b0),
    .pri0({object_prio_latched,1'b1}), .pri1(6'd0), .pri2(6'd0),
    .ci0(k1_ci0), .ci1(k1_ci1), .ci2(k1_ci2),
    .ci3(k1_ci3), .ci4(k1_ci4),
    .shd_in(object_shd_latched), .shd_out(shd_out),
    .ioctl_addr(ioctl_ram ? ioctl_addr : debug_bus[3:0]),
    .ioctl_din(k053251_ioctl_din), .cout(colmix_addr), .winner(colmix_winner),
    .brit(brit_int), .col_n(col_n_int)
);

endmodule
