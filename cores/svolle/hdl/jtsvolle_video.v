/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 25-10-2026 */

module jtsvolle_video(
    input             rst, clk, pxl_cen,
    input      [31:0] gga_h,
    input      [23:0] gga_v,
    input      [7:0]  irq_control,
    input      [8:0]  scrx0, scry0, scrx1, scry1,
    input      [15:0] videoflags,
    input      [5:0]  obj_count, obj_pri,
    output     [12:1] scrv0_addr, scrv1_addr,
    input      [15:0] scrv0_data, scrv1_data,
    output     [11:1] objr_addr,
    input      [15:0] objr_data,
    output     [10:1] mix_addr,
    input      [15:0] mix_data,
    output     [18:2] scr0_addr, scr1_addr, obj_addr,
    output            scr0_cs, scr1_cs, obj_cs,
    input      [31:0] scr0_data, scr1_data, obj_data,
    input             scr0_ok, scr1_ok, obj_ok,
    input      [3:0]  gfx_en,
    output            LHBL, LVBL, HS, VS, irq_event,
    output     [4:0]  red, green, blue,
    output            obj_overrun
);

reg [8:0] h;
reg [7:0] v;
wire [9:0] htotal = gga_h[31:24]==0 ? 10'd432 : {gga_h[31:24],2'b00}+10'd4;
wire [9:0] hb = gga_h[7:0]==0 ? 10'd288 : {gga_h[7:0],2'b00}+10'd4;
wire [9:0] hss = gga_h[15:8]==0 ? 10'd352 : {gga_h[15:8],2'b00}+10'd4;
wire [9:0] hse = gga_h[23:16]==0 ? 10'd392 : {gga_h[23:16],2'b00}+10'd4;
wire [8:0] vb = gga_v[7:0]==0 ? 9'd216 : {gga_v[7:0],1'b0}+9'd2;
wire [8:0] vss = gga_v[15:8]==0 ? 9'd232 : {gga_v[15:8],1'b0}+9'd2;
wire [8:0] vse = gga_v[23:16]==0 ? 9'd240 : {gga_v[23:16],1'b0}+9'd2;
wire [8:0] lead = h>=hss[8:0] ? h-htotal[8:0]+9'd10 : h+9'd10;
wire [8:0] obj_h = h+9'd9;
wire [8:0] vrender = {1'b0,v+8'd1};
wire [7:0] half_irq = vb[7:0]+8'd128;
wire [7:0] scr0_pxl, scr1_pxl;
wire [8:0] obj_pxl;

assign LHBL = {1'b0,h}<hb;
assign LVBL = {1'b0,v}<vb;
assign HS = {1'b0,h}>=hss && {1'b0,h}<hse;
assign VS = {1'b0,v}>=vss && {1'b0,v}<vse;
assign irq_event = pxl_cen && h==0 && irq_control!=0 &&
                   (v==vb[7:0] || (irq_control==8'hc0 && v==half_irq));

// The GGA vertical total is provisional at 256 lines.
always @(posedge clk) begin
    if(rst) begin
        h <= 0;
        v <= 0;
    end else if(pxl_cen) begin
        if({1'b0,h}==htotal-10'd1) begin
            h <= 0;
            v <= v+8'd1;
        end else h <= h+9'd1;
    end
end

jtsvolle_scr u_scr0(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .pxl_cen    ( pxl_cen       ),
    .hs         ( HS            ),
    .en         ( gfx_en[0]     ),
    .hdump      ( lead          ),
    .vdump      ( {1'b0,v}      ),
    .scrx       ( scrx0         ),
    .scry       ( scry0         ),
    .code_bank  ( videoflags[10] ),
    .pal_bank   ( videoflags[4] ),
    .ram_addr   ( scrv0_addr    ),
    .ram_data   ( scrv0_data    ),
    .rom_addr   ( scr0_addr     ),
    .rom_cs     ( scr0_cs       ),
    .rom_data   ( scr0_data     ),
    .rom_ok     ( scr0_ok       ),
    .pxl        ( scr0_pxl      )
);

jtsvolle_scr u_scr1(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .pxl_cen    ( pxl_cen       ),
    .hs         ( HS            ),
    .en         ( gfx_en[1]     ),
    .hdump      ( lead          ),
    .vdump      ( {1'b0,v}      ),
    .scrx       ( scrx1+9'd8    ),
    .scry       ( scry1         ),
    .code_bank  ( videoflags[11] ),
    .pal_bank   ( videoflags[5] ),
    .ram_addr   ( scrv1_addr    ),
    .ram_data   ( scrv1_data    ),
    .rom_addr   ( scr1_addr     ),
    .rom_cs     ( scr1_cs       ),
    .rom_data   ( scr1_data     ),
    .rom_ok     ( scr1_ok       ),
    .pxl        ( scr1_pxl      )
);

jtsvolle_obj u_obj(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .pxl_cen    ( pxl_cen       ),
    .hs         ( HS            ),
    .en         ( gfx_en[3]     ),
    .hdump      ( obj_h         ),
    .vrender    ( vrender       ),
    .count      ( obj_count     ),
    .pri        ( obj_pri       ),
    .pal_bank   ( videoflags[6] ),
    .ram_addr   ( objr_addr     ),
    .ram_data   ( objr_data     ),
    .rom_addr   ( obj_addr      ),
    .rom_cs     ( obj_cs        ),
    .rom_data   ( obj_data      ),
    .rom_ok     ( obj_ok        ),
    .pxl        ( obj_pxl       ),
    .overrun    ( obj_overrun   )
);

jtsvolle_colmix u_colmix(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .pxl_cen    ( pxl_cen       ),
    .LHBL       ( LHBL          ),
    .LVBL       ( LVBL          ),
    .scr0       ( scr0_pxl      ),
    .scr1       ( scr1_pxl      ),
    .obj        ( obj_pxl       ),
    .gfx_en     ( gfx_en        ),
    .pal_addr   ( mix_addr      ),
    .pal_data   ( mix_data      ),
    .red        ( red           ),
    .green      ( green         ),
    .blue       ( blue          )
);

endmodule
