/*  This file is part of JTKCPU.
    JTKCPU program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTKCPU program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTKCPU.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 14-4-2023 */

module jt053260 (
    input                       rst,
    input                       clk,
    input                       cen,
    input                [ 5:0] addr,
    input                       ma0,
    input                       mr_wn,
    input                [ 7:0] mdin,
    output reg           [ 7:0] mdout,
    input                       mcs,
    input                       r_wn,  // 1 = read, 0 = write
    input                       cs,
    input                [ 7:0] din,
    // output               [ 7:0] dout,
    output reg           [20:0] rom_addr,
    input                [ 7:0] rom_data,
    output reg                  rom_cs,
    input                       rom_ok,
    output reg    signed [11:0] snd_l,
    output reg    signed [11:0] snd_r,
    output                      sample
);

wire        [ 1:0] ch;
reg         [ 3:0] st;
reg         [ 7:0] ch_mmr[0:31];
reg         [ 7:0] portdata[0:3];
reg         [ 3:0] key_on, mode;
reg         [ 3:0] ch_st, adpcm, loop;
reg         [ 2:0] ch0_pan, ch1_pan, ch2_pan, ch3_pan, pan;
reg                dly_cen;

// channel data
reg         [11:0] pitch;
reg         [15:0] length;
reg         [20:0] start;
reg         [ 6:0] volume;
reg         [ 6:0] pan_l, pan_r;
reg         [ 3:0] keyon_l;
reg                keyon;
reg                loop_en;
reg                adpcm_en;
reg         [20:0] cur_addr[0:3];
reg         [16:0] cur_cnt[0:3];
reg  signed [ 9:0] cur_snd[0:3];
reg         [11:0] pitch_cnt[0:3];
reg         [ 3:0] adpcm_cnt, up;

reg                cen16, cen64;
reg         [ 5:0] cen_cnt = 0;
reg         [ 5:0] m_addr;

reg         [ 7:0] kadpcm;
wire signed [17:0] mul_l;
wire signed [17:0] mul_r;

reg  signed [11:0] acc_l;
reg  signed [11:0] acc_r;
reg  signed [ 9:0] ch_snd_l;
reg  signed [ 9:0] ch_snd_r;

wire        [12:0] nx_pitch_cnt;
wire signed [ 7:0] svl, svr;
wire        [ 6:0] vol_l, vol_r;
wire        [ 3:0] nibble;
wire        [ 7:0] reg2e;


assign reg2e        = mode[0] ? rom_data : portdata[addr[1:0]];
assign nx_pitch_cnt = {1'd0, pitch_cnt[ch] } + { 1'd0, pitch };
assign nibble       = adpcm_cnt[ch] ? rom_data[7:4] : rom_data[3:0];
assign sample       = cen64;
assign vol_l        = volume | pan_l;
assign vol_r        = volume | pan_r;
assign svl          = {1'b0, vol_l};
assign svr          = {1'b0, vol_r};
assign mul_l        = cur_snd[ch] * svl;
assign mul_r        = cur_snd[ch] * svr;
assign ch           = cen_cnt[5:4];

always @* begin
    case ( nibble )
        4'h0: kadpcm =  8'd0;
        4'h1: kadpcm =  8'd1;
        4'h2: kadpcm =  8'd2;
        4'h3: kadpcm =  8'd4;
        4'h4: kadpcm =  8'd8;
        4'h5: kadpcm =  8'd16;
        4'h6: kadpcm =  8'd32;
        4'h7: kadpcm =  8'd64;
        4'h8: kadpcm = -8'd128;
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
    if( cen ) cen_cnt <= cen_cnt + 1'd1;
    dly_cen <= cen;
    cen64 <= cen_cnt == 0 && cen;
    cen16 <= cen_cnt[3:0] == 0 && cen;
end

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        ch_mmr[0] <= 0; ch_mmr[ 8] <= 0; ch_mmr[16] <= 0; ch_mmr[24] <= 0;
        ch_mmr[1] <= 0; ch_mmr[ 9] <= 0; ch_mmr[17] <= 0; ch_mmr[25] <= 0;
        ch_mmr[2] <= 0; ch_mmr[10] <= 0; ch_mmr[18] <= 0; ch_mmr[26] <= 0;
        ch_mmr[3] <= 0; ch_mmr[11] <= 0; ch_mmr[19] <= 0; ch_mmr[27] <= 0;
        ch_mmr[4] <= 0; ch_mmr[12] <= 0; ch_mmr[20] <= 0; ch_mmr[28] <= 0;
        ch_mmr[5] <= 0; ch_mmr[13] <= 0; ch_mmr[21] <= 0; ch_mmr[29] <= 0;
        ch_mmr[6] <= 0; ch_mmr[14] <= 0; ch_mmr[22] <= 0; ch_mmr[30] <= 0;
        ch_mmr[7] <= 0; ch_mmr[15] <= 0; ch_mmr[23] <= 0; ch_mmr[31] <= 0;
        portdata[0]  <= 0; portdata[1]   <= 0;
        portdata[2]  <= 0; portdata[3]   <= 0;
        mdout   <= 0;
        ch0_pan <= 0; ch1_pan <= 0; ch2_pan <= 0; ch3_pan <= 0;
        key_on  <= 4'hF; loop <= 0; mode    <= 0; ch_st   <= 0; adpcm <= 0;
    end else begin
        if ( mcs && !mr_wn ) begin
            portdata[addr[1:0]] <= mdin;
        end
        mdout <= portdata[addr[1:0]];
        if ( cs && !r_wn ) begin
            if (addr >= 6'h08 && addr <= 6'h27) begin
                m_addr = addr - 8;
                ch_mmr[ m_addr[4:0] ] <= din;
            end
            case ( addr )
                6'h28: key_on <= din[3:0];
                6'h2A: { adpcm, loop } <= din;
                6'h2C: { ch1_pan, ch0_pan } <= din[5:0];
                6'h2D: { ch3_pan, ch2_pan } <= din[5:0];
                6'h2F: mode <= din[3:0];
                default: ;
            endcase
        end else begin
            case ( addr )
                6'h29: ch_st <= key_on[3:0];
                default: ;
            endcase
        end
    end
end

always @* begin
    case ( pan )
        3'b001:  pan_l = 7'b1111111;
        3'b010:  pan_l = 7'b1110100;
        3'b011:  pan_l = 7'b1101000;
        3'b100:  pan_l = 7'b1011010;
        3'b101:  pan_l = 7'b1001001;
        3'b110:  pan_l = 7'b0110100;
        3'b111:  pan_l = 7'b0000000;
        default: pan_l = 0;
    endcase
    case ( pan )
        3'b001:  pan_r = 7'b0000000;
        3'b010:  pan_r = 7'b0110100;
        3'b011:  pan_r = 7'b1001001;
        3'b100:  pan_r = 7'b1011010;
        3'b101:  pan_r = 7'b1101000;
        3'b110:  pan_r = 7'b1110100;
        3'b111:  pan_r = 7'b1111111;
        default: pan_r = 0;
    endcase
end

always @* begin
    casez ( ch )
        0: begin
                pitch    = { ch_mmr[1][3:0], ch_mmr[0] };
                length   = { ch_mmr[3], ch_mmr[2] };
                start    = { ch_mmr[6][4:0], ch_mmr[5], ch_mmr[4] };
                volume   = { ch_mmr[7][6:0] };
                keyon    = key_on[0];
                adpcm_en = adpcm[0];
                loop_en  = loop[0];
                pan      = ch0_pan;
            end
        1: begin
                pitch    = { ch_mmr[9][3:0], ch_mmr[8] };
                length   = { ch_mmr[11], ch_mmr[10] };
                start    = { ch_mmr[14][4:0], ch_mmr[13], ch_mmr[12] };
                volume   = { ch_mmr[15][6:0] };
                keyon    = key_on[1];
                adpcm_en = adpcm[1];
                loop_en  = loop[1];
                pan      = ch1_pan;
            end
        2: begin
                pitch    = { ch_mmr[17][3:0], ch_mmr[16] };
                length   = { ch_mmr[19], ch_mmr[18] };
                start    = { ch_mmr[22][4:0], ch_mmr[21], ch_mmr[20] };
                volume   = { ch_mmr[23][6:0] };
                keyon    = key_on[2];
                adpcm_en = adpcm[2];
                loop_en  = loop[2];
                pan      = ch2_pan;
            end
        3: begin
                pitch    = { ch_mmr[25][3:0], ch_mmr[24] };
                length   = { ch_mmr[27], ch_mmr[26] };
                start    = { ch_mmr[30][4:0], ch_mmr[29], ch_mmr[28] };
                volume   = { ch_mmr[31][6:0] };
                keyon    = key_on[3];
                adpcm_en = adpcm[3];
                loop_en  = loop[3];
                pan      = ch3_pan;
            end
        default: ;
    endcase
end

function [11:0] sign_ext( input [9:0] a );
    sign_ext = { {2{a[9]}}, a };
endfunction

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        acc_l    <= 0;
        acc_r    <= 0;
        snd_l    <= 0;
        snd_r    <= 0;
    end else if( cen16 ) begin
        if( cen64 ) begin
            snd_l <= acc_l;
            snd_r <= acc_r;
        end
        acc_l <= (cen64 ? 12'd0 : acc_l) + sign_ext(ch_snd_l);
        acc_r <= (cen64 ? 12'd0 : acc_r) + sign_ext(ch_snd_r);
    end
end

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        st       <= 0;
        up[0]    <= 0; up[1] <= 0; up[2] <= 0; up[3] <= 0;
        keyon_l  <= 0;
        rom_cs   <= 0;
        ch_snd_l <= 0;
        ch_snd_r <= 0;
        pitch_cnt[0] <= 0; pitch_cnt[1] <= 0; pitch_cnt[2] <= 0; pitch_cnt[3] <= 0;
        adpcm_cnt[0] <= 0; adpcm_cnt[1] <= 0; adpcm_cnt[2] <= 0; adpcm_cnt[3] <= 0;
         cur_addr[0] <= 0;  cur_addr[1] <= 0;  cur_addr[2] <= 0;  cur_addr[3] <= 0;
          cur_snd[0] <= 0;   cur_snd[1] <= 0;   cur_snd[2] <= 0;   cur_snd[3] <= 0;
          cur_cnt[0] <= 0;   cur_cnt[1] <= 0;   cur_cnt[2] <= 0;   cur_cnt[3] <= 0;
    end else if( dly_cen ) begin
        st <= cen16 ? 4'd0 : st + 1'd1;
        case( st )
            0: begin
                keyon_l[ch] <= keyon;
                if( !keyon && keyon_l[ch] ) begin
                    rom_cs   <= 1;
                    up[ch]   <= 1;
                    adpcm_cnt[ch] <= 0;
                    pitch_cnt[ch] <= 0;
                    cur_addr[ch]  <= start;
                    cur_snd[ch]   <= 0;
                    cur_cnt[ch]   <= {1'd0, length};
                end else if( !keyon && !cur_cnt[ch][16] )begin
                    rom_cs <= 1;
                    rom_addr <= cur_addr[ch];
                end else begin
                    rom_cs <= 0;
                    cur_cnt[ch][16] <= 1;
                end
            end
            14: begin
                if( cur_cnt[ch][16] ) begin
                    cur_snd[ch] <= cur_snd[ch] >>> 1;
                end else if( up[ch] && rom_cs && rom_ok ) begin
                    if( adpcm_en ) begin
                        cur_snd[ch] <= cur_snd[ch] + {1'd0, kadpcm };
                    end else begin
                        cur_snd[ch] <= { rom_data, 2'd0 };
                    end
                end
            end
            15: begin
                rom_cs <= 0;
                ch_snd_l <= mul_l[17-:10];
                ch_snd_r <= mul_r[17-:10];
                if( rom_cs ) begin
                    // update counters for next sample
                    pitch_cnt[ch] <= nx_pitch_cnt[11:0];
                    up[ch] <= 0;
                    if( !cur_cnt[ch][16] && nx_pitch_cnt[12] ) begin
                        up[ch] <= 1;
                        // addr start increment and cnt decrement
                        if( adpcm_en ) begin
                            { cur_addr[ch], adpcm_cnt[ch] } <= { cur_addr[ch], adpcm_cnt[ch] } + 1'd1;
                        end else begin
                            cur_addr[ch] <= cur_addr[ch] + 1'd1;
                        end
                        if( !adpcm_en || adpcm_cnt[ch] ) cur_cnt[ch] <= cur_cnt[ch] - 1'd1;
                        if( cur_cnt[ch]==0 && (!adpcm_en || adpcm_cnt[ch]) ) begin
                            if( loop_en ) begin
                                cur_addr[ch]  <= start;
                                cur_cnt[ch]   <= {1'd0, length};
                            end
                        end
                    end
                end
            end
            default: ;
        endcase
    end
end

endmodule
