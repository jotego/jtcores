// SPDX-License-Identifier: GPL-3.0-or-later

module jtmzone_video(
    input               rst,
    input               clk,
    input               clk24,
    input               pxl_cen,

    input        [ 9:0] main_tile_addr,
    input        [ 7:0] vram_din,
    input               main_cpu_rnw,
    input               vram0_cs,
    input               vram1_cs,
    input               cram0_cs,
    input               cram1_cs,
    output       [ 7:0] vram0_dout,
    output       [ 7:0] vram1_dout,
    output       [ 7:0] cram0_dout,
    output       [ 7:0] cram1_dout,

    input        [ 9:0] objram_addr,
    input        [ 7:0] objram_din,
    input               objram_cs,
    output       [ 7:0] objram_dout,

    input        [ 7:0] scrolly,
    input        [ 7:0] scrollx,
    input               flip,
    input               dip_orig_hactive,
    input        [ 3:0] gfx_en,

    input        [ 7:0] prog_data,
    input        [21:0] prog_addr,
    input               prom_we,

    output       [11:0] fixrom_addr,
    output              fixrom_cs,
    input        [31:0] fixrom_data,
    input               fixrom_ok,

    output       [11:0] scrrom_addr,
    output              scrrom_cs,
    input        [31:0] scrrom_data,
    input               scrrom_ok,

    output       [12:0] obj_addr,
    output              obj_cs,
    input        [31:0] obj_data,
    input               obj_ok,

    output              HS,
    output              VS,
    output              LHBL,
    output              LVBL,
    output       [ 3:0] red,
    output       [ 3:0] green,
    output       [ 3:0] blue,

    output       [ 8:0] hdump,
    output       [ 8:0] vdump,
    output       [ 8:0] vrender
`ifdef MZONE_FETCH_DIAG
    ,input       [ 7:0] debug_bus
    ,output reg  [ 7:0] fetch_debug
`endif
);

// Default to 288 active pixels. Original non-flipped PCB timing blanks the
// last pixel below, without changing the counter or sync timing.
localparam [8:0] HVISIBLE = 9'd288;
localparam [8:0] HTOTAL   = 9'd384;
localparam [8:0] HB_END   = HTOTAL-9'd1;
localparam [8:0] HB_START = HVISIBLE-9'd1;
localparam [8:0] HS_START = 9'd319;
localparam [8:0] HS_END   = 9'd351;
localparam [8:0] H_VB     = H_VNEXT;
localparam [8:0] H_VNEXT  = HS_START;
localparam [8:0] VB_START = 9'd239;
localparam [8:0] VB_END   = 9'd015;
localparam [8:0] VVISIBLE = 9'd016;
localparam [8:0] VS_START = 9'd256;
localparam [8:0] VS_END   = 9'd000;
localparam [8:0] VCNT_END = 9'd263;
localparam [21:0] OBJ_OFFSET = `ifdef JTFRAME_PROM_START `JTFRAME_PROM_START + 22'h020 `else 22'h020 `endif;
localparam [21:0] CHR_OFFSET = `ifdef JTFRAME_PROM_START `JTFRAME_PROM_START + 22'h120 `else 22'h120 `endif;

wire        pre_lhbl, pre_lvbl;
// The PCB-visible color-mixer window is 288 pixels when flipped and 287 when
// not flipped. Default to a symmetric 288-pixel window for display systems.
// pre_lhbl remains high at HB_START and falls on the following counter value.
// Mask the final active pixel, without a one-pixel gap before it.
wire        orig_last_pixel = dip_orig_hactive && !flip && hdump == HB_START;
wire        colmix_pre_lhbl = pre_lhbl && !orig_last_pixel;
wire [ 3:0] scr_pxl;
wire [ 3:0] fix_pxl;
wire [ 3:0] obj_pxl;
wire        fix_src, fix_en;
`ifdef MZONE_FETCH_DIAG
wire        scr_fetch_late;
reg         diag_armed;
reg  [ 7:0] diag_count, diag_last, diag_peak, diag_frames;
// Count visible deadline misses, excluding the first partial frame.
// JTFRAME debug selector: 1 = last frame, 3 = affected frames, otherwise peak.
always @(posedge clk) begin
    if( rst ) begin
        diag_armed <= 1'b0;
        diag_count <= 8'd0;
        diag_last  <= 8'd0;
        diag_peak  <= 8'd0;
        diag_frames<= 8'd0;
    end else begin
        if( pxl_cen && vdump == 9'd239 && hdump == 9'd383 ) begin
            diag_armed <= 1'b1;
            diag_last  <= diag_count;
            diag_count <= 8'd0;
            if( diag_count > diag_peak ) diag_peak <= diag_count;
            if( diag_count != 0 && diag_frames != 8'hff )
                diag_frames <= diag_frames + 8'd1;
        end
        if( diag_armed && scr_fetch_late && diag_count != 8'hff &&
            vdump >= 9'd16 && vdump < 9'd240 &&
            (flip ? hdump >= 9'd8 && hdump < 9'd232 :
                    hdump >= 9'd56 && hdump < 9'd280) )
            diag_count <= diag_count + 8'd1;
    end
end
always @* begin
    case( debug_bus[1:0] )
        2'd1: fetch_debug = diag_last;
        2'd3: fetch_debug = diag_frames;
        default: fetch_debug = diag_peak; // Stable default; no keyboard needed.
    endcase
end
`endif
wire        obj_lut_we, char_lut_we;

assign obj_lut_we = prom_we && prog_addr >= OBJ_OFFSET && prog_addr < OBJ_OFFSET+22'h100;
assign char_lut_we = prom_we && prog_addr >= CHR_OFFSET && prog_addr < CHR_OFFSET+22'h100;


jtmzone_scroll u_scroll(
    .rst              ( rst                              ),
    .clk              ( clk                              ),
    .clk24            ( clk24                            ),
    .pxl_cen          ( pxl_cen                          ),
    .cpu_addr         ( main_tile_addr                   ),
    .cpu_dout         ( vram_din                         ),
    .cpu_rnw          ( main_cpu_rnw                     ),
    .vram_cs          ( vram0_cs                         ),
    .cram_cs          ( cram0_cs                         ),
    .vram_dout        ( vram0_dout                       ),
    .cram_dout        ( cram0_dout                       ),
    .hdump            ( hdump                            ),
    .vdump            ( vdump                            ),
    .scrollx          ( scrollx                          ),
    .scrolly          ( scrolly                          ),
    .flip             ( flip                             ),
    .prog_data        ( prog_data[3:0]                   ),
    .prog_addr        ( prog_addr[7:0] - CHR_OFFSET[7:0] ),
    .prog_en          ( char_lut_we                      ),
    .rom_data         ( scrrom_data                      ),
    .rom_ok           ( scrrom_ok                        ),
    .rom_addr         ( scrrom_addr                      ),
    .rom_cs           ( scrrom_cs                        ),
    .pxl              ( scr_pxl                          )
`ifdef MZONE_FETCH_DIAG
    ,.fetch_late       ( scr_fetch_late                   )
`endif
);

jtmzone_fix u_fix(
    .rst              ( rst                              ),
    .clk              ( clk                              ),
    .clk24            ( clk24                            ),
    .pxl_cen          ( pxl_cen                          ),
    .cpu_addr         ( main_tile_addr                   ),
    .cpu_dout         ( vram_din                         ),
    .cpu_rnw          ( main_cpu_rnw                     ),
    .vram_cs          ( vram1_cs                         ),
    .cram_cs          ( cram1_cs                         ),
    .vram_dout        ( vram1_dout                       ),
    .cram_dout        ( cram1_dout                       ),
    .hdump            ( hdump                            ),
    .vdump            ( vdump                            ),
    .flip             ( flip                             ),
    .dip_orig_hactive ( dip_orig_hactive                 ),
    .prog_data        ( prog_data[3:0]                   ),
    .prog_addr        ( prog_addr[7:0] - CHR_OFFSET[7:0] ),
    .prog_en          ( char_lut_we                      ),
    .rom_data         ( fixrom_data                      ),
    .rom_ok           ( fixrom_ok                        ),
    .rom_addr         ( fixrom_addr                      ),
    .rom_cs           ( fixrom_cs                        ),
    .pxl              ( fix_pxl                          ),
    .fix_src          ( fix_src                          ),
    .fix_en           ( fix_en                           )
);

jtmzone_obj u_obj(
    .rst              ( rst                              ),
    .clk              ( clk                              ),
    .clk24            ( clk24                            ),
    .pxl_cen          ( pxl_cen                          ),
    .objram_addr      ( objram_addr                      ),
    .objram_din       ( objram_din                       ),
    .objram_cs        ( objram_cs                        ),
    .cpu_rnw          ( main_cpu_rnw                     ),
    .objram_dout      ( objram_dout                      ),
    .LVBL             ( LVBL                             ),
    .HS               ( HS                               ),
    .hdump            ( hdump                            ),
    .vdump            ( vdump                            ),
    .flip             ( flip                             ),
    .rom_addr         ( obj_addr                         ),
    .rom_cs           ( obj_cs                           ),
    .rom_data         ( obj_data                         ),
    .rom_ok           ( obj_ok                           ),
    .prog_data        ( prog_data[3:0]                   ),
    .prog_addr        ( prog_addr[7:0] - OBJ_OFFSET[7:0] ),
    .prog_en          ( obj_lut_we                       ),
    .pxl              ( obj_pxl                          )
);

jtmzone_colmix u_colmix(
    .rst              ( rst                              ),
    .clk              ( clk                              ),
    .pxl_cen          ( pxl_cen                          ),
    .scr_pxl          ( scr_pxl                          ),
    .fix_pxl          ( fix_pxl                          ),
    .obj_pxl          ( obj_pxl                          ),
    .gfx_en           ( gfx_en                           ),
    .fix_src          ( fix_src                          ),
    .fix_prio         ( fix_en                           ),
    .preLHBL          ( colmix_pre_lhbl                  ),
    .preLVBL          ( pre_lvbl                         ),
    .prog_data        ( prog_data                        ),
    .prog_addr        ( prog_addr                        ),
    .prom_we          ( prom_we                          ),
    .red              ( red                              ),
    .green            ( green                            ),
    .blue             ( blue                             ),
    .LHBL             ( LHBL                             ),
    .LVBL             ( LVBL                             ),
    .preLBL           (                                  )
);

`ifdef SIMULATION
// Check the mixer-facing horizontal active width after all palette and
// blanking delays. Ignore the partial line present when reset is released,
// then validate every complete line at pixel-clock granularity.
wire [9:0] hactive_expected = dip_orig_hactive && !flip ? 10'd287 : 10'd288;
reg        hactive_lhbl_l;
reg        hactive_armed;
reg [ 9:0] hactive_count;
always @(posedge clk) begin
    if( rst ) begin
        hactive_lhbl_l <= LHBL;
        hactive_armed  <= 1'b0;
        hactive_count  <= 10'd0;
    end else if( pxl_cen ) begin
        hactive_lhbl_l <= LHBL;
        if( !hactive_lhbl_l && LHBL ) begin
            hactive_armed <= 1'b1;
            hactive_count <= 10'd1;
        end else if( LHBL ) begin
            hactive_count <= hactive_count + 10'd1;
        end
        if( hactive_lhbl_l && !LHBL ) begin
            if( hactive_armed && hactive_count != hactive_expected )
                $error("MZONE_HACTIVE width=%0d expected=%0d vdump=%0d hdump=%0d",
                    hactive_count, hactive_expected, vdump, hdump);
            if( hactive_armed && vdump == VVISIBLE )
                $display("MZONE_HACTIVE width=%0d expected=%0d vdump=%0d hdump=%0d",
                    hactive_count, hactive_expected, vdump, hdump);
            hactive_count <= 10'd0;
        end
    end
end
`endif


jtframe_vtimer #(
    .VB_START         ( VB_START                         ),
    .VB_END           ( VB_END                           ),
    .VCNT_END         ( VCNT_END                         ),
    .VS_START         ( VS_START                         ),
    .VS_END           ( VS_END                           ),
    .HB_END           ( HB_END                           ),
    .HB_START         ( HB_START                         ),
    .HCNT_END         ( HB_END                           ),
    .HS_START         ( HS_START                         ),
    .HS_END           ( HS_END                           ),
    .H_VB             ( H_VB                             ),
    .H_VNEXT          ( H_VNEXT                          )
) u_vtimer(
    .clk              ( clk                              ),
    .pxl_cen          ( pxl_cen                          ),
    .vdump            ( vdump                            ),
    .vrender          ( vrender                          ),
    .vrender1         (                                  ),
    .H                ( hdump                            ),
    .Hinit            (                                  ),
    .Vinit            (                                  ),
    .LHBL             ( pre_lhbl                         ),
    .LVBL             ( pre_lvbl                         ),
    .HS               ( HS                               ),
    .VS               ( VS                               )
);

endmodule
