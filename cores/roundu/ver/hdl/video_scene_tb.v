/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 19-10-2026 */

`timescale 1ns/1ps
`ifndef ROUNDU_SCENE_PATH
`define ROUNDU_SCENE_PATH ""
`endif
module video_scene_tb;
reg clk=0, rst=1;
reg [4:0] phase=0;
wire pxl_cen=phase==0;
wire [13:1] txmap_addr;
wire [15:0] txmap_data;
wire [16:0] tx_gfx_addr;
wire [7:0] tx_gfx_data;
wire [10:1] palette_video_addr;
wire [15:0] palette_video_data;
wire [4:0] red,green,blue;
wire LHBL,LVBL,HS,VS;
wire [9:0] text_base;
wire [7:0] text_low;
wire [15:0] control, scroll_x, scroll_y, road_yclip, road_control, object_control;
wire [15:0] vregs [0:7];
wire [15:0] observed [0:15];
reg [15:0] expected_regs [0:15];
reg [7:0] mmr_expected [0:611];
integer r;
wire [11:1] road_ctrl_addr,road_pixel_addr,road_color_addr;
wire [15:0] road_ctrl_data,road_pixel_data,road_color_data;
wire [16:0] bg_addr;
wire [7:0] bg_data;
wire [13:1] obj_addr;
wire [15:0] obj_data;
wire [8:1] ctrl_addr;
wire [19:2] rom_l_addr,rom_h_addr;
wire rom_l_cs,rom_h_cs,rom_l_ok,rom_h_ok;
wire [31:0] rom_l_data,rom_h_data;
wire overflow;
reg [7:0] rom0 [0:786431],rom1 [0:786431];
reg [17:0] pending_l,pending_h;
reg active_l=0,active_h=0;
integer delay_l,delay_h,waits=2,load_fd,n;

reg [14:0] expected [0:76799];
integer last_h=0,last_v=0,pixels=0,fd;
reg valid=0;
reg [14:0] color;

assign observed[0] = {6'd0,text_base};
assign observed[1] = {8'd0,text_low};
assign observed[2] = control;
assign observed[3] = vregs[0];
assign observed[4] = vregs[1];
assign observed[5] = vregs[2];
assign observed[6] = vregs[3];
assign observed[7] = vregs[4];
assign observed[8] = vregs[5];
assign observed[9] = vregs[6];
assign observed[10] = vregs[7];
assign observed[11] = scroll_x;
assign observed[12] = scroll_y;
assign observed[13] = road_yclip;
assign observed[14] = road_control;
assign observed[15] = object_control;

jtroundu_crtc_mmr #(
    .SIMFILE ( {`ROUNDU_SCENE_PATH,"mmr.bin"} ),
    .SEEK    ( 0                              )
) u_scene_crtc (
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cs         ( 1'b0      ),
    .addr       ( 6'd0      ),
    .rnw        ( 1'b1      ),
    .din        ( 8'd0      ),
    .dout       (           ),
    .text_base  ( text_base ),
    .text_low   ( text_low  ),
    .ioctl_addr ( 6'd0      ),
    .ioctl_din  (           ),
    .debug_bus  ( 8'd0      ),
    .st_dout    (           )
);

jtroundu_main_mmr #(
    .SIMFILE ( {`ROUNDU_SCENE_PATH,"mmr.bin"} ),
    .SEEK    ( 64                             )
) u_scene_main (
    .rst        ( rst      ),
    .clk        ( clk      ),
    .cs         ( 1'b0     ),
    .addr       ( 4'd0     ),
    .rnw        ( 1'b1     ),
    .din        ( 16'd0    ),
    .dout       (          ),
    .dsn        ( 2'b11    ),
    .control    ( control  ),
    .vreg0      ( vregs[0] ),
    .vreg1      ( vregs[1] ),
    .vreg2      ( vregs[2] ),
    .vreg3      ( vregs[3] ),
    .vreg4      ( vregs[4] ),
    .vreg5      ( vregs[5] ),
    .vreg6      ( vregs[6] ),
    .vreg7      ( vregs[7] ),
    .scroll_x   ( scroll_x ),
    .scroll_y   ( scroll_y ),
    .ioctl_addr ( 5'd0     ),
    .ioctl_din  (          ),
    .debug_bus  ( 8'd0     ),
    .st_dout    (          )
);

jtroundu_road_mmr #(
    .SIMFILE ( {`ROUNDU_SCENE_PATH,"mmr.bin"} ),
    .SEEK    ( 96                             )
) u_scene_road (
    .rst        ( rst          ),
    .clk        ( clk          ),
    .cs         ( 1'b0         ),
    .addr       ( 1'd0         ),
    .rnw        ( 1'b1         ),
    .din        ( 16'd0        ),
    .dout       (              ),
    .dsn        ( 2'b11        ),
    .yclip      ( road_yclip   ),
    .control    ( road_control ),
    .ioctl_addr ( 2'd0         ),
    .ioctl_din  (              ),
    .debug_bus  ( 8'd0         ),
    .st_dout    (              )
);

jtroundu_object_mmr #(
    .SIMFILE ( {`ROUNDU_SCENE_PATH,"mmr.bin"} ),
    .SEEK    ( 100                            )
) u_scene_object (
    .rst        ( rst            ),
    .clk        ( clk            ),
    .cs         ( 1'b0           ),
    .addr       ( 8'd0           ),
    .rnw        ( 1'b1           ),
    .din        ( 16'd0          ),
    .dout       (                ),
    .dsn        ( 2'b11          ),
    .control    ( object_control ),
    .ioctl_addr ( 9'd0           ),
    .ioctl_din  (                ),
    .debug_bus  ( 8'd0           ),
    .st_dout    (                )
);

jtroundu_video #(
    .OBJECTS   ( 1 ),
    .LANDSCAPE ( 1 )
) u_video (
    .control            ( control                     ),
    .rst                ( rst                         ),
    .clk                ( clk                         ),
    .pxl_cen            ( pxl_cen                     ),
    .text_scroll_y      ( text_base | {2'b0,text_low} ),
    .bg_back_x          ( vregs[6]                    ),
    .bg_scroll_x        ( scroll_x                    ),
    .bg_scroll_y        ( scroll_y                    ),
    .road_enable        ( vregs[1][0]                 ),
    .road_top           ( vregs[5][15:8]              ),
    .road_yclip         ( road_yclip                  ),
    .road_bank          ( road_control[4]             ),
    .road_ctrl_addr     ( road_ctrl_addr              ),
    .road_ctrl_data     ( road_ctrl_data              ),
    .road_pixel_addr    ( road_pixel_addr             ),
    .road_pixel_data    ( road_pixel_data             ),
    .road_color_addr    ( road_color_addr             ),
    .road_color_data    ( road_color_data             ),
    .bg_gfx_addr        ( bg_addr                     ),
    .bg_gfx_data        ( bg_data                     ),
    .objram_addr        ( obj_addr                    ),
    .objram_data        ( obj_data                    ),
    .obj_ctrl_addr      ( ctrl_addr                   ),
    .obj_ctrl_data      ( object_control              ),
    .sprites_l_addr     ( rom_l_addr                  ),
    .sprites_l_cs       ( rom_l_cs                    ),
    .sprites_l_data     ( rom_l_data                  ),
    .sprites_l_ok       ( rom_l_ok                    ),
    .sprites_h_addr     ( rom_h_addr                  ),
    .sprites_h_cs       ( rom_h_cs                    ),
    .sprites_h_data     ( rom_h_data                  ),
    .sprites_h_ok       ( rom_h_ok                    ),
    .obj_overflow       ( overflow                    ),
    .txmap_addr         ( txmap_addr                  ),
    .txmap_data         ( txmap_data                  ),
    .tx_gfx_addr        ( tx_gfx_addr                 ),
    .tx_gfx_data        ( tx_gfx_data                 ),
    .palette_video_addr ( palette_video_addr          ),
    .palette_video_data ( palette_video_data          ),
    .red                ( red                         ),
    .green              ( green                       ),
    .blue               ( blue                        ),
    .LHBL               ( LHBL                        ),
    .LVBL               ( LVBL                        ),
    .HS                 ( HS                          ),
    .VS                 ( VS                          )
);

jtframe_dual_ram16 #(
    .AW      ( 13                                  ),
    .SIMFILE ( {`ROUNDU_SCENE_PATH,"videoram.bin"} )
) u_map (
    .clk0  ( clk        ),
    .data0 ( 16'd0      ),
    .addr0 ( 13'd0      ),
    .we0   ( 2'd0       ),
    .q0    (            ),
    .clk1  ( clk        ),
    .data1 ( 16'd0      ),
    .addr1 ( txmap_addr ),
    .we1   ( 2'd0       ),
    .q1    ( txmap_data )
);

jtframe_dual_ram #(
    .AW      ( 17                                   ),
    .DW      ( 8                                    ),
    .SIMFILE ( {`ROUNDU_SCENE_PATH,"tx_gfxram.bin"} )
) u_gfx (
    .clk0  ( clk         ),
    .data0 ( 8'd0        ),
    .addr0 ( 17'd0       ),
    .we0   ( 1'b0        ),
    .q0    (             ),
    .clk1  ( clk         ),
    .data1 ( 8'd0        ),
    .addr1 ( tx_gfx_addr ),
    .we1   ( 1'b0        ),
    .q1    ( tx_gfx_data )
);

jtframe_dual_ram16 #(
    .AW      ( 10                                 ),
    .SIMFILE ( {`ROUNDU_SCENE_PATH,"palette.bin"} )
) u_palette (
    .clk0  ( clk                ),
    .data0 ( 16'd0              ),
    .addr0 ( 10'd0              ),
    .we0   ( 2'd0               ),
    .q0    (                    ),
    .clk1  ( clk                ),
    .data1 ( 16'd0              ),
    .addr1 ( palette_video_addr ),
    .we1   ( 2'd0               ),
    .q1    ( palette_video_data )
);

jtframe_dual_ram #(
    .AW      ( 17                                   ),
    .DW      ( 8                                    ),
    .SIMFILE ( {`ROUNDU_SCENE_PATH,"bg_gfxram.bin"} )
) u_bg (
    .clk0  ( clk     ),
    .data0 ( 8'd0    ),
    .addr0 ( 17'd0   ),
    .we0   ( 1'b0    ),
    .q0    (         ),
    .clk1  ( clk     ),
    .data1 ( 8'd0    ),
    .addr1 ( bg_addr ),
    .we1   ( 1'b0    ),
    .q1    ( bg_data )
);

jtframe_dual_ram16 #(
    .AW      ( 13                                   ),
    .SIMFILE ( {`ROUNDU_SCENE_PATH,"spriteram.bin"} )
) u_objects (
    .clk0  ( clk      ),
    .data0 ( 16'd0    ),
    .addr0 ( 13'd0    ),
    .we0   ( 2'd0     ),
    .q0    (          ),
    .clk1  ( clk      ),
    .data1 ( 16'd0    ),
    .addr1 ( obj_addr ),
    .we1   ( 2'd0     ),
    .q1    ( obj_data )
);

jtframe_dual_ram16 #(
    .AW      ( 11                                       ),
    .SIMFILE ( {`ROUNDU_SCENE_PATH,"road_ctrl_ram.bin"} )
) u_road_ctrl (
    .clk0  ( clk            ),
    .data0 ( 16'd0          ),
    .addr0 ( 11'd0          ),
    .we0   ( 2'd0           ),
    .q0    (                ),
    .clk1  ( clk            ),
    .data1 ( 16'd0          ),
    .addr1 ( road_ctrl_addr ),
    .we1   ( 2'd0           ),
    .q1    ( road_ctrl_data )
);

jtframe_dual_ram16 #(
    .AW      ( 11                                        ),
    .SIMFILE ( {`ROUNDU_SCENE_PATH,"road_pixel_ram.bin"} )
) u_road_pixel (
    .clk0  ( clk             ),
    .data0 ( 16'd0           ),
    .addr0 ( 11'd0           ),
    .we0   ( 2'd0            ),
    .q0    (                 ),
    .clk1  ( clk             ),
    .data1 ( 16'd0           ),
    .addr1 ( road_pixel_addr ),
    .we1   ( 2'd0            ),
    .q1    ( road_pixel_data )
);

jtframe_dual_ram16 #(
    .AW      ( 11                                        ),
    .SIMFILE ( {`ROUNDU_SCENE_PATH,"road_color_ram.bin"} )
) u_road_color (
    .clk0  ( clk             ),
    .data0 ( 16'd0           ),
    .addr0 ( 11'd0           ),
    .we0   ( 2'd0            ),
    .q0    (                 ),
    .clk1  ( clk             ),
    .data1 ( 16'd0           ),
    .addr1 ( road_color_addr ),
    .we1   ( 2'd0            ),
    .q1    ( road_color_data )
);

assign rom_l_ok = active_l && rom_l_cs && pending_l == rom_l_addr && delay_l == 0;
assign rom_h_ok = active_h && rom_h_cs && pending_h == rom_h_addr && delay_h == 0;
assign rom_l_data = rom_l_ok ? {rom0[{pending_l,2'd3}],rom0[{pending_l,2'd2}],rom0[{pending_l,2'd1}],rom0[{pending_l,2'd0}]} : 32'd0;
assign rom_h_data = rom_h_ok ? {rom1[{pending_h,2'd3}],rom1[{pending_h,2'd2}],rom1[{pending_h,2'd1}],rom1[{pending_h,2'd0}]} : 32'd0;

always @(posedge clk) begin
    if (!rom_l_cs) active_l <= 0;
    else if (!active_l || pending_l != rom_l_addr) begin
        active_l <= 1;
        pending_l <= rom_l_addr;
        delay_l <= waits + rom_l_addr % 3;
    end else if (delay_l > 0) delay_l <= delay_l-1;
    if (!rom_h_cs) active_h <= 0;
    else if (!active_h || pending_h != rom_h_addr) begin
        active_h <= 1;
        pending_h <= rom_h_addr;
        delay_h <= waits + rom_h_addr % 3;
    end else if (delay_h > 0) delay_h <= delay_h-1;
end

always #5 clk=~clk;
always @(posedge clk) begin
    phase<=phase+1'd1;
    if (!rst && pxl_cen) begin
        if (valid && pixels > 400*272) begin
            color=last_h<320 && last_v<240 ? expected[last_v*320+last_h] : 15'd0;
            #1;
            if ({red,green,blue} !== color)
                $fatal(1,"captured pixel h=%0d v=%0d actual=%h expected=%h",last_h,last_v,{red,green,blue},color);
            if (last_h<320 && last_v<240)
                $fwrite(fd,"%c%c%c",{red,red[4:2]},{green,green[4:2]},{blue,blue[4:2]});
        end
        if (!valid || pixels <= 400*272) #1;
        last_h=u_video.h==0 ? 399 : u_video.h-1;
        last_v=u_video.h==0 ? (u_video.v==0 ? 271 : u_video.v-1) : u_video.v;
        valid=1;
        pixels=pixels+1;
        if (pixels==400*272*2+1) begin
            $fclose(fd);
            $display("PASS: 76800 captured-state pixels through JTFRAME BRAM, scroll and sprite buffer plus core affine sprites/landscape/road");
            $finish;
        end
    end
end
initial begin
    $readmemh({`ROUNDU_SCENE_PATH,"expected-regs.hex"},expected_regs);
    load_fd=$fopen({`ROUNDU_SCENE_PATH,"mmr.bin"},"rb"); n=$fread(mmr_expected,load_fd); $fclose(load_fd);
    n=$value$plusargs("WAIT=%d",waits);
    load_fd=$fopen({`ROUNDU_SCENE_PATH,"obj-rom-0.bin"},"rb"); n=$fread(rom0,load_fd); $fclose(load_fd);
    load_fd=$fopen({`ROUNDU_SCENE_PATH,"obj-rom-1.bin"},"rb"); n=$fread(rom1,load_fd); $fclose(load_fd);
    $readmemh({`ROUNDU_SCENE_PATH,"expected.hex"},expected);
    fd=$fopen({`ROUNDU_SCENE_PATH,"rtl.ppm"},"wb");
    $fwrite(fd,"P6\n320 240\n255\n");
    repeat(16) @(negedge clk);
    rst=0;
    #1;
    for (r=0;r<64;r=r+1)
        if (u_scene_crtc.mmr[r] !== mmr_expected[0+r]) $fatal(1,"MMR crtc byte %0d",r);
    for (r=0;r<32;r=r+1)
        if (u_scene_main.mmr[r] !== mmr_expected[64+r]) $fatal(1,"MMR main byte %0d",r);
    for (r=0;r<4;r=r+1)
        if (u_scene_road.mmr[r] !== mmr_expected[96+r]) $fatal(1,"MMR road byte %0d",r);
    for (r=0;r<512;r=r+1)
        if (u_scene_object.mmr[r] !== mmr_expected[100+r]) $fatal(1,"MMR object byte %0d",r);
    for (r=0;r<16;r=r+1)
        if (observed[r] !== expected_regs[r]) $fatal(1,"MMR field %0d",r);
    $display("PASS: 612 raw MMR bytes and 16 exported fields restored");
end
endmodule
