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
    Date: 14-4-2023 */

module jt053260_channel#(parameter TESTRD=0)(
    input                    rst,
    input                    clk,
    input                    cen,
    input                    swap,
    // MMR interface
    input             [ 2:0] addr,
    input             [ 7:0] din,
    input                    we,

    input                    keyon,
    input                    tst_en,
    input                    tst_nx,
    input                    loop,
    input                    adpcm_en,
    input             [ 6:0] pan_l, pan_r,
    input             [ 7:0] rom_data,

    output reg        [20:0] rom_addr,
    output reg               rom_cs,
    output reg signed [15:0] snd_l,
    output reg signed [15:0] snd_r,
    output reg               bsy,
    output                   match, sample
);

// MMR
reg         [ 7:0] mmr[0:7];
wire        [20:0] start, neg_cnt;
wire        [15:0] length;
wire        [11:0] pitch;
wire        [ 6:0] volume;

reg         [15:0] cnt, inc;
reg         [11:0] pitch_cnt;
reg  signed [ 7:0] pre_snd;
reg  signed [ 7:0] kadpcm, adpcm_sat, adpcm_lim;
reg  signed [ 8:0] adpcm_full;
reg                adpcm_cnt, keyon_l, adpcm_over;

wire        [12:0] nx_pitch_cnt;
wire signed [15:0] mul_l, mul_r;
wire signed [ 7:0] svl, svr;
reg         [13:0] vol_l, vol_r;
wire        [ 3:0] nibble;
wire               tst_mode;

assign start    = { mmr[6][4:0], mmr[5], mmr[4] };
assign length   = { mmr[3], mmr[2] };
assign pitch    = { mmr[1][3:0], mmr[0] };
assign volume   = { mmr[7][6:0] };
assign tst_mode = tst_en && TESTRD==1;

assign nx_pitch_cnt = {1'd0, pitch_cnt } + 13'd1;
assign nibble       = adpcm_cnt^swap ? rom_data[7:4] : rom_data[3:0];
assign sample       = nx_pitch_cnt[12] & cen;
assign svl          = {1'b0, vol_l[13-:7]};
assign svr          = {1'b0, vol_r[13-:7]};
assign mul_l        = pre_snd * svl;
assign mul_r        = pre_snd * svr;
assign match        = cnt == length;
assign neg_cnt      = -{5'd0,cnt};

always @* begin
    case ( nibble )
        4'h0: kadpcm =  0;
        4'h1: kadpcm =  1;
        4'h2: kadpcm =  2;
        4'h3: kadpcm =  4;
        4'h4: kadpcm =  8;
        4'h5: kadpcm =  16;
        4'h6: kadpcm =  32;
        4'h7: kadpcm =  64;
        4'h8: kadpcm = -8'd128; // 8'd explicit to prevent warning in Quartus
        4'h9: kadpcm = -8'd64;
        4'hA: kadpcm = -8'd32;
        4'hB: kadpcm = -8'd16;
        4'hC: kadpcm = -8'd8;
        4'hD: kadpcm = -8'd4;
        4'hE: kadpcm = -8'd2;
        4'hF: kadpcm = -8'd1;
    endcase
end

always @(posedge clk) begin
    if( rst ) begin
        mmr[0] <= 0; mmr[1] <= 0; mmr[2] <= 0; mmr[3] <= 0;
        mmr[4] <= 0; mmr[5] <= 0; mmr[6] <= 0; mmr[7] <= 0;
    end else begin
        if( we ) mmr[addr] <= din;
    end
end

always @(posedge clk) begin
    vol_l <= volume * pan_l;
    vol_r <= volume * pan_r;
    snd_l <= mul_l;
    snd_r <= mul_r;
    if( !bsy ) begin
        snd_l <= snd_l >>> 1;
        snd_r <= snd_r >>> 1;
    end
end

always @(posedge clk) begin
    rom_addr <= start + (swap ? neg_cnt : {5'd0,cnt});
end

always @* begin
    adpcm_full = {pre_snd[7], pre_snd} + {kadpcm[7],kadpcm};
    adpcm_sat  = {adpcm_full[8],{7{~adpcm_full[8]}}};
    adpcm_over = adpcm_full[8]!=adpcm_full[7];
    adpcm_lim  = adpcm_over ? adpcm_sat : adpcm_full[7:0];
end

always @(posedge clk) begin
    if( rst ) begin
        cnt       <= 0;
        adpcm_cnt <= 0;
        pitch_cnt <= 0;
        rom_cs    <= 0;
        bsy       <= 0;
        keyon_l   <= 0;
    end else begin
        if( cen ) begin
            rom_cs  <= 1;
            keyon_l <= keyon;
            if( !keyon_l && keyon ) begin
                bsy       <= 1;
                cnt       <= 0;
                adpcm_cnt <= 1;
                pitch_cnt <= pitch;
            end
            if( !keyon ) begin
                pre_snd <= 0;
                rom_cs  <= 0;
                bsy     <= 0;
            end else if( bsy ) begin
                pitch_cnt <= nx_pitch_cnt[12] ? pitch : nx_pitch_cnt[11:0];
                if( nx_pitch_cnt[12] ) begin
                    // ROM address increment and sample cnt increment
                    adpcm_cnt <= ~adpcm_cnt;
                    if( !adpcm_cnt || !adpcm_en ) begin
                        cnt <= cnt + 1'd1;
                        if( match ) begin
                            if( loop ) begin
                                cnt      <= 0;
                            end else begin
                                bsy <= 0;
                            end
                        end
                    end
                    pre_snd <= adpcm_en ? adpcm_lim : rom_data;
                end
            end
        end
        // not under cen control
        if( tst_mode ) begin
            rom_cs <= 1;
            if( tst_nx ) cnt <= cnt+1'd1;
        end
    end
end

endmodule