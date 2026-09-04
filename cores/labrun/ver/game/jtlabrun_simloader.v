/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 11-10-2020 */

// Sim loader for Trick Trap

module jtlabrun_simloader(
    input               rst,
    input               clk,
    output              cpu_cen,
    // GFX
    output reg  [13:0]  cpu_addr,
    output reg          cpu_rnw,
    output reg  [ 7:0]  cpu_dout,
    output reg          pal_cs,
    output reg          gfx_cs
);

reg [7:0] gfx_snap[0:8191];
reg [7:0] pal_snap[0:255 ];
reg [7:0] gfx_cfg [0:127 ];

assign cpu_cen = 1;

integer file, cnt, dump_cnt, pal_cnt, cfg_cnt;

initial begin
    file=$fopen("scene/gfx_tile.bin","rb");
    cnt=$fread(gfx_snap,file,0,4096);
    $display("%d bytes loaded as GFX tile snapshot",cnt);
    $fclose(file);

    file=$fopen("scene/gfx_obj.bin","rb");
    cnt=$fread(gfx_snap,file,4096,4096);
    $display("%d bytes loaded as GFX obj snapshot",cnt);
    $fclose(file);

    file=$fopen("scene/pal.bin","rb");
    cnt=$fread(pal_snap,file);
    $display("%d bytes loaded as PAL snapshot",cnt);
    $fclose(file);

    file=$fopen("scene/gfx_cfg.bin","rb");
    cnt=$fread(gfx_cfg,file,0,96);
    $fclose(file);
end

always @(posedge clk) begin
    if( rst ) begin
        dump_cnt  <= 0;
        pal_cnt   <= 0;
        cfg_cnt   <= 0;
        cpu_addr  <= 16'h1FFF;
        cpu_rnw   <= 1;
        cpu_dout  <= 8'd0;
        pal_cs    <= 0;
        gfx_cs    <= 0;
    end else begin
        if( dump_cnt < 8*1024 ) begin
            dump_cnt     <= dump_cnt + 1;
            cpu_addr     <= { 1'b1, dump_cnt[12:0] };
            cpu_rnw      <= 0;
            cpu_dout     <= gfx_snap[ dump_cnt ];
            gfx_cs       <= 1;
        end else if( pal_cnt < 256 ) begin
            pal_cnt      <= pal_cnt + 1;
            cpu_addr     <= { 6'h10, pal_cnt[7:0] };
            cpu_rnw      <= 0;
            cpu_dout     <= pal_snap[ pal_cnt ];
            pal_cs       <= 1;
            gfx_cs       <= 0;
        end else begin
            pal_cs         <= 0;
            cpu_addr[13:0] <= 'd0;
            if( cfg_cnt < 64 ) begin
                gfx_cs        <= 1;
                cpu_addr[5:0] <= cfg_cnt[5:0];
                cpu_rnw       <= 0;
                cpu_dout      <= gfx_cfg[ cfg_cnt ];
                cfg_cnt       <= cfg_cnt+1;
            end else begin
                gfx_cs        <= 0;
                cpu_rnw       <= 1;
            end
        end
    end
end

endmodule