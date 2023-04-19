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
    Date: 04-05-2020 */

module jtcontra_simloader(
    input               rst,
    input               clk,
    output              cpu_cen,
    // GFX
    output reg  [15:0]  cpu_addr,
    output reg          cpu_rnw,
    output reg  [ 7:0]  cpu_dout,
    output reg          pal_cs,
    input               gfx1_cs,
    input               gfx2_cs,
    output      [ 7:0]  video_bank,
    output              prio_latch
);

reg [7:0] gfx_snap[0:16383];
reg [7:0] pal_snap [0:255 ];
reg [7:0] gfx_cfg[0:15];

assign cpu_cen = 1;

integer file, cnt, dump_cnt, pal_cnt, cfg_cnt;

// These values are not used in Contra
assign video_bank = 8'h0;
assign prio_latch = 0;

initial begin
    file=$fopen("gfx1.bin","rb");
    cnt=$fread(gfx_snap,file,0,8192);
    $display("%d bytes loaded as GFX1 snapshot",cnt);
    $fclose(file);

    file=$fopen("gfx2.bin","rb");
    cnt=$fread(gfx_snap,file,8192,8192);
    $display("%d bytes loaded as GFX2 snapshot",cnt);
    $fclose(file);

    file=$fopen("pal.bin","rb");
    cnt=$fread(pal_snap,file);
    $display("%d bytes loaded as PAL snapshot",cnt);
    $fclose(file);

    $readmemh("gfx_cfg.hex",gfx_cfg);
end

wire gfx_low = dump_cnt < 8*1024;

always @(posedge clk) begin
    if( rst ) begin
        dump_cnt  <= 0;
        pal_cnt   <= 0;
        cfg_cnt   <= 0;
        cpu_addr  <= 16'h1FFF;
        cpu_rnw   <= 1;
        cpu_dout  <= 8'd0;
        pal_cs    <= 0;
    end else begin
        if( dump_cnt < 16*1024 ) begin
            dump_cnt     <= dump_cnt + 1;
            cpu_addr     <= { gfx_low ? 3'b01 : 3'b10, dump_cnt[12:0] };
            cpu_rnw      <= 0;
            cpu_dout     <= gfx_snap[ dump_cnt ];
        end else if( pal_cnt < 256 ) begin            
            pal_cnt      <= pal_cnt + 1;
            cpu_addr     <= { 8'h0c, pal_cnt[7:0] };
            cpu_rnw      <= 0;
            cpu_dout     <= pal_snap[ pal_cnt ];
            pal_cs       <= 1;
        end else begin
            pal_cs         <= 0;
            cpu_addr[15:3] <= 'd0;
            if( cfg_cnt < 16 ) begin
                cpu_addr[6:5] <= {2{cfg_cnt[3]}};
                cpu_addr[2:0] <= cfg_cnt[2:0];
                cpu_rnw       <= 0;
                cpu_dout      <= gfx_cfg[ cfg_cnt ];
                cfg_cnt       <= cfg_cnt+1;
            end else begin
                cpu_rnw       <= 1;
            end
        end
    end
end

endmodule