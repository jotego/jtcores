/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 01-11-2026 */

module jtttnose_video(
    input             rst, clk, pxl_cen, pxl2_cen,
    input             gga_cs, gga_we, gga_addr,
    input      [7:0]  gga_din,
    input             roz_we,
    input      [3:0]  roz_ctrl_addr,
    input      [7:0]  roz_ctrl_din,
    input             gfxbank_we,
    input      [7:0]  gfxbank_din,
    input      [2:0]  gfx_en,
    output     [11:1] txv_addr,
    input      [15:0] txv_data,
    output     [19:2] chars_addr,
    output            chars_cs,
    input      [31:0] chars_data,
    input             chars_ok,
    input             roz_map_cs, roz_map_we,
    input      [10:0] roz_map_addr,
    input      [7:0]  roz_map_din,
    output     [7:0]  roz_map_dout,
    output            roz_map_ok,
    input      [10:0] roz_ioctl_addr,
    input             roz_ioctl_ram,
    output     [7:0]  roz_ioctl_din, roz_mmr_dump,
    output     [16:1] rozg_addr,
    input      [15:0] rozg_data,
    output     [9:1]  objr_addr,
    input      [15:0] objr_data,
    output     [18:2] obj_addr,
    output            obj_cs,
    input      [31:0] obj_data,
    input             obj_ok,
    output     [11:1] mix_addr,
    input      [15:0] mix_data,
    output     [8:0]  hdump, vdump, vrender,
    output            LHBL, LVBL, HS, VS,
    output reg [4:0]  red, green, blue,
    output            obj_overrun
);

wire video_en, flip, txpal;
wire [1:0] txbank;
wire [6:0] roz_pxl, obj_pxl;
wire [10:0] tx_pxl;
wire hblank, vblank;
reg [2:0] blank_pipe;

jtttnose_video_mmr #(
    .SIMFILE ( "mmr.bin" ),
    .SEEK    ( 16        )
) u_control(
    .rst        ( rst         ),
    .clk        ( clk         ),
    .cs         ( gfxbank_we  ),
    .addr       ( 2'd0        ),
    .rnw        ( 1'b0        ),
    .din        ( gfxbank_din ),
    .dout       (             ),
    .txbank     ( txbank      ),
    .txpal      ( txpal       ),
    .video_en   ( video_en    ),
    .flip       ( flip        ),
    .ioctl_addr ( 2'd0        ),
    .ioctl_din  (             ),
    .debug_bus  ( 8'd0        ),
    .st_dout    (             )
);

jtpspike_gga u_gga(
    .rst      ( rst      ),
    .clk      ( clk      ),
    .pxl_cen  ( pxl_cen  ),
    .cs       ( gga_cs   ),
    .we       ( gga_we   ),
    .addr     ( gga_addr ),
    .din      ( gga_din  ),
    .h_last   (          ),
    .hsize    (          ),
    .vsize    (          ),
    .vdump    ( vdump    ),
    .vrender  ( vrender  ),
    .vrender1 (          ),
    .H        ( hdump    ),
    .Hinit    (          ),
    .Vinit    (          ),
    .LHBL     ( hblank   ),
    .LVBL     ( vblank   ),
    .HS       ( HS       ),
    .VS       ( VS       )
);

jtttnose_roz u_roz(
    .rst        ( rst            ),
    .clk        ( clk            ),
    .pxl_cen    ( pxl_cen        ),
    .pxl2_cen   ( pxl2_cen       ),
    .hs         ( HS             ),
    .vs         ( VS             ),
    .lhbl       ( hblank         ),
    .lvbl       ( vblank         ),
    .hdump      ( hdump          ),
    .vdump      ( vdump          ),
    .ctrl_we    ( roz_we         ),
    .ctrl_addr  ( roz_ctrl_addr  ),
    .ctrl_din   ( roz_ctrl_din   ),
    .map_cs     ( roz_map_cs     ),
    .map_we     ( roz_map_we     ),
    .map_addr   ( roz_map_addr   ),
    .map_din    ( roz_map_din    ),
    .map_dout   ( roz_map_dout   ),
    .map_ok     ( roz_map_ok     ),
    .ioctl_addr ( roz_ioctl_addr ),
    .ioctl_ram  ( roz_ioctl_ram  ),
    .ioctl_din  ( roz_ioctl_din  ),
    .mmr_dump   ( roz_mmr_dump   ),
    .gfx_addr   ( rozg_addr      ),
    .gfx_data   ( rozg_data      ),
    .pxl        ( roz_pxl        )
);

jtttnose_obj u_obj(
    .rst      ( rst         ),
    .clk      ( clk         ),
    .pxl_cen  ( pxl_cen     ),
    .hs       ( HS          ),
    .en       ( video_en    ),
    .flip     ( flip        ),
    .hdump    ( hdump       ),
    .vrender  ( vrender     ),
    .ram_addr ( objr_addr   ),
    .ram_data ( objr_data   ),
    .rom_addr ( obj_addr    ),
    .rom_cs   ( obj_cs      ),
    .rom_data ( obj_data    ),
    .rom_ok   ( obj_ok      ),
    .pxl      ( obj_pxl     ),
    .overrun  ( obj_overrun )
);

jtttnose_scr u_scr(
    .rst      ( rst                  ),
    .clk      ( clk                  ),
    .pxl_cen  ( pxl_cen              ),
    .hs       ( HS                   ),
    .en       ( video_en & gfx_en[2] ),
    .flip     ( flip                 ),
    .hdump    ( hdump                ),
    .vdump    ( vdump                ),
    .bank     ( txbank               ),
    .pal_bank ( txpal                ),
    .ram_addr ( txv_addr             ),
    .ram_data ( txv_data             ),
    .rom_addr ( chars_addr           ),
    .rom_cs   ( chars_cs             ),
    .rom_data ( chars_data           ),
    .rom_ok   ( chars_ok             ),
    .pxl      ( tx_pxl               )
);

jtttnose_colmix u_colmix(
    .video_en ( video_en ),
    .gfx_en   ( gfx_en   ),
    .roz_pxl  ( roz_pxl  ),
    .obj_pxl  ( obj_pxl  ),
    .tx_pxl   ( tx_pxl   ),
    .pal_addr ( mix_addr )
);

assign LHBL = hblank && hdump<9'd320;
assign LVBL = vblank;

always @(posedge clk) begin
    if(rst) begin
        blank_pipe <= 0;
        red <= 0;
        green <= 0;
        blue <= 0;
    end else begin
        blank_pipe <= {blank_pipe[1:0],LHBL & vblank & video_en};
        if(blank_pipe[2]) begin
            red <= mix_data[14:10];
            green <= mix_data[9:5];
            blue <= mix_data[4:0];
        end else begin
            red <= 0;
            green <= 0;
            blue <= 0;
        end
    end
end

endmodule
