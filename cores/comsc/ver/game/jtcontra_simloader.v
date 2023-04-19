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
    Date: 03-06-2020 */

// Sim loader for Combat School

module jtcontra_simloader(
    input               rst,
    input               clk,
    output              cpu_cen,
    // GFX
    output reg  [15:0]  cpu_addr,
    output reg          cpu_rnw,
    output reg  [ 7:0]  cpu_dout,
    output reg          pal_cs,
    output reg          gfx1_cs,
    output reg          gfx2_cs,
    output      [ 7:0]  video_bank,
    output              prio_latch
);

reg [7:0] gfx_snap[0:16383];
reg [7:0] pal_snap[0:255  ];
reg [7:0] gfx_cfg [0:127  ];
reg [7:0] other   [0:1    ];

assign video_bank = other[0];
assign prio_latch = ~other[1][0];

assign cpu_cen = 1;

integer file, cnt, dump_cnt, pal_cnt, cfg_cnt;

initial begin
    file=$fopen("scene/gfx1.bin","rb");
    cnt=$fread(gfx_snap,file,0,8192);
    $display("%d bytes loaded as GFX1 snapshot",cnt);
    $fclose(file);

    file=$fopen("scene/gfx2.bin","rb");
    cnt=$fread(gfx_snap,file,8192,8192);
    $display("%d bytes loaded as GFX2 snapshot",cnt);
    $fclose(file);

    file=$fopen("scene/pal.bin","rb");
    cnt=$fread(pal_snap,file);
    $display("%d bytes loaded as PAL snapshot",cnt);
    $fclose(file);

    file=$fopen("scene/gfx_cfg1.bin","rb");
    cnt=$fread(gfx_cfg,file,0,64);
    $fclose(file);
    file=$fopen("scene/gfx_cfg2.bin","rb");
    cnt=$fread(gfx_cfg,file,64,64);
    $fclose(file);

    $readmemh("scene/other.hex",other);
end

wire gfx_low = dump_cnt < 8*1024-1;
wire cfg_low = dump_cnt < 64-1;

always @(posedge clk) begin
    if( rst ) begin
        dump_cnt  <= 0;
        pal_cnt   <= 0;
        cfg_cnt   <= 0;
        cpu_addr  <= 16'h1FFF;
        cpu_rnw   <= 1;
        cpu_dout  <= 8'd0;
        pal_cs    <= 0;
        gfx1_cs   <= 1;
        gfx2_cs   <= 0;
    end else begin
        if( dump_cnt < 16*1024 ) begin
            dump_cnt     <= dump_cnt + 1;
            cpu_addr     <= { 3'b001, dump_cnt[12:0] };
            cpu_rnw      <= 0;
            cpu_dout     <= gfx_snap[ dump_cnt ];
            gfx1_cs      <= gfx_low;
            gfx2_cs      <= ~gfx_low;
        end else if( pal_cnt < 256 ) begin            
            pal_cnt      <= pal_cnt + 1;
            cpu_addr     <= { 8'h06, pal_cnt[7:0] };
            cpu_rnw      <= 0;
            cpu_dout     <= pal_snap[ pal_cnt ];
            pal_cs       <= 1;
            gfx1_cs      <= 0;
            gfx2_cs      <= 0;
        end else begin
            pal_cs         <= 0;
            cpu_addr[15:6] <= 'd0;
            if( cfg_cnt < 128 ) begin
                gfx1_cs       <= ~cfg_cnt[6];
                gfx2_cs       <=  cfg_cnt[6];
                cpu_addr[5:0] <= cfg_cnt[5:0];
                cpu_rnw       <= 0;
                cpu_dout      <= gfx_cfg[ cfg_cnt ];
                cfg_cnt       <= cfg_cnt+1;
            end else begin
                gfx1_cs       <= 0;
                gfx2_cs       <= 0;
                cpu_rnw       <= 1;
            end
        end
    end
end

endmodule