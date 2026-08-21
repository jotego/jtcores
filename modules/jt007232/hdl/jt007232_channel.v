/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 24-8-2021 */

// playback is delayed by one sample to ease the ROM interface
module jt007232_channel(
    input             rst,
    input             clk,
    input             cen_q,
    // control from MMR
    input      [16:0] rom_start,
    input      [11:0] pre0,
    input      [ 1:0] pre_sel,
    input             loop,
    input             play,
    input             load,

    output reg [16:0] rom_addr,
    output            rom_cs,
    input             rom_ok,
    input      [ 7:0] rom_dout,
    output reg signed [6:0] snd
);

parameter [6:0] OFFSET='h40;

reg  [11:0] cnt;
wire        over;
reg         busy, playl;

// counter length is set by an MMR
assign over = pre_sel[0] ? (&cnt[7:0]) : (pre_sel[1] ? (&cnt[11:8]) : (&cnt));
assign rom_cs = busy;

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        cnt  <= 0;
        busy <= 0;
        snd  <= 0;
        rom_addr <= 0;
    end else begin
        playl <= play;
        if( cen_q ) begin
            if( over ) begin
                cnt <= pre0;
                if( busy ) begin
                    if( pre_sel[1] ) begin
                        rom_addr[ 3: 0] <= rom_addr[ 3: 0] + 1'd1;
                        rom_addr[ 7: 4] <= rom_addr[ 7: 4] + 1'd1;
                        rom_addr[11: 8] <= rom_addr[11: 8] + 1'd1;
                        rom_addr[16:12] <= rom_addr[16:12] + 1'd1;
                    end else begin
                        rom_addr <= rom_addr + 1'd1;
                    end
                    snd <= rom_dout[6:0]-OFFSET;
                    if( rom_dout[7] ) begin
                        if( loop )
                            rom_addr <= rom_start;
                        else
                            busy <= 0;
                    end
                end
            end else begin
                if( pre_sel[1] ) begin
                    cnt[ 7:0] <= cnt[ 7:0]+1'd1;
                    cnt[11:8] <= cnt[11:8]+1'd1;
                end else begin
                    cnt <= cnt + 1'd1;
                end
            end
        end
        if( play && !playl ) begin
            busy <= 1;
            rom_addr <= rom_start;
        end
        if( load ) begin
            cnt <= pre0;
        end
        if(!busy) snd <= 0;
    end
end


endmodule