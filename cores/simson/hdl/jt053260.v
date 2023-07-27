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
    input                    rst,
    input                    clk,
    input                    cen,
    // Main CPU interface
    input                    ma0,
    input                    mrdnw,
    input                    mcs,
    input             [ 7:0] mdout,
    output reg        [ 7:0] mdin,
    // Sound CPU control
    input             [ 5:0] addr,
    input                    wr_n,
    input                    rd_n,
    input                    cs,
    input             [ 7:0] din,
    output reg        [ 7:0] dout,
    // input YM2151
    // input                    stb1,
    // input                    aux1,
    // ROM access for channel A
    output            [20:0] roma_addr,
    input             [ 7:0] roma_data,
    output                   roma_cs,

    output            [20:0] romb_addr,
    input             [ 7:0] romb_data,
    output                   romb_cs,

    output            [20:0] romc_addr,
    input             [ 7:0] romc_data,
    output                   romc_cs,

    output            [20:0] romd_addr,
    input             [ 7:0] romd_data,
    output                   romd_cs,

    output reg signed [11:0] snd_l,
    output reg signed [11:0] snd_r,
    output                   sample
    // slots unconnected
    // input               st1,
    // input               st2,
    // input               aux2,
    // output              rdnwp,
    // output              tim2,
    // output              cen_e,    // M6809 clock
    // output              cen_q     // M6809 clock
);
    reg    [ 7:0] ch_mmr[0:31];
    reg    [ 7:0] pm2s[0:1], ps2m[0:1];

    reg    [ 3:0] key_on, mode;
    wire   [ 3:0] over;
    reg    [ 3:0] adpcm_en, loop;

    // 4 channels for register of 8 bit
    wire   [11:0] ch0_pitch  = { ch_mmr[1][3:0], ch_mmr[0] };
    wire   [15:0] ch0_length = { ch_mmr[3], ch_mmr[2] };
    wire   [20:0] ch0_start  = { ch_mmr[6][4:0], ch_mmr[5], ch_mmr[4] };
    wire   [ 6:0] ch0_volume = { ch_mmr[7][6:0] };
    reg    [ 2:0] ch0_pan;
    wire          ch0_key  = key_on[0];
    wire          ch0_loop = loop[0];

    wire   [11:0] ch1_pitch  = { ch_mmr[9][3:0], ch_mmr[8] };
    wire   [15:0] ch1_length = { ch_mmr[11], ch_mmr[10] };
    wire   [20:0] ch1_start  = { ch_mmr[14][4:0], ch_mmr[13], ch_mmr[12] };
    wire   [ 6:0] ch1_volume = { ch_mmr[15][6:0] };
    reg    [ 2:0] ch1_pan;
    wire          ch1_key  = key_on[1];
    wire          ch1_loop = loop[1];

    wire   [11:0] ch2_pitch  = { ch_mmr[17][3:0], ch_mmr[16] };
    wire   [15:0] ch2_length = { ch_mmr[19], ch_mmr[18] };
    wire   [20:0] ch2_start  = { ch_mmr[22][4:0], ch_mmr[21], ch_mmr[20] };
    wire   [ 6:0] ch2_volume = { ch_mmr[23][6:0] };
    reg    [ 2:0] ch2_pan;
    wire          ch2_key  = key_on[2];
    wire          ch2_loop = loop[2];

    wire   [11:0] ch3_pitch  = { ch_mmr[25][3:0], ch_mmr[24] };
    wire   [15:0] ch3_length = { ch_mmr[27], ch_mmr[26] };
    wire   [20:0] ch3_start  = { ch_mmr[30][4:0], ch_mmr[29], ch_mmr[28] };
    wire   [ 6:0] ch3_volume = { ch_mmr[31][6:0] };
    reg    [ 2:0] ch3_pan;
    wire          ch3_key  = key_on[3];
    wire          ch3_loop = loop[3];

    wire          ch0_sample, ch1_sample, ch2_sample, ch3_sample;
    wire signed [9:0] ch0_snd_l, ch1_snd_l, ch2_snd_l, ch3_snd_l,
                      ch0_snd_r, ch1_snd_r, ch2_snd_r, ch3_snd_r;

    reg    [ 6:0] pan0_l, pan0_r;
    reg    [ 6:0] pan1_l, pan1_r;
    reg    [ 6:0] pan2_l, pan2_r;
    reg    [ 6:0] pan3_l, pan3_r;
    wire   [ 5:0] addr8;

    assign sample   = |{ch0_sample,ch1_sample,ch2_sample,ch3_sample};
    assign addr8    = addr - 6'd8;

    always @(posedge clk, posedge rst) begin
        if( rst ) begin
            snd_l   <= 0;
            snd_r   <= 0;
        end else begin
            snd_l <= { {2{ch0_snd_l[9]}}, ch0_snd_l } + { {2{ch1_snd_l[9]}}, ch1_snd_l } + { {2{ch2_snd_l[9]}}, ch2_snd_l } + { {2{ch3_snd_l[9]}}, ch3_snd_l };
            snd_r <= { {2{ch0_snd_r[9]}}, ch0_snd_r } + { {2{ch1_snd_r[9]}}, ch1_snd_r } + { {2{ch2_snd_r[9]}}, ch2_snd_r } + { {2{ch3_snd_r[9]}}, ch3_snd_r };
        end
    end

    // Interface with main CPU
    always @(posedge clk, posedge rst) begin
        if( rst ) begin
            pm2s[0] <= 0;
            pm2s[1] <= 0;
        end else if(mcs) begin
            mdin <= ps2m[ma0];
            if ( !mrdnw ) pm2s[ma0] <= mdout;
        end
    end

    // Interface with sound CPU
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
            ch0_pan <= 0; ch1_pan <= 0; ch2_pan <= 0; ch3_pan <= 0;
            key_on  <= 4'hF; loop <= 0; mode    <= 0; adpcm_en <=0;
            dout <= 0;
        end else begin
            if( cs ) begin
                if ( !wr_n ) begin
                    if (addr >= 6'h08 && addr <= 6'h27) begin
                        ch_mmr[ addr8[4:0] ] <= din;
                    end
                    case ( addr )
                        2,3:   ps2m[addr[0]] <= din;
                        6'h28: key_on <= din[3:0];
                        6'h2A: { adpcm_en, loop } <= din;
                        6'h2C: { ch1_pan, ch0_pan } <= din[5:0];
                        6'h2D: { ch3_pan, ch2_pan } <= din[5:0];
                        6'h2F: mode <= din[3:0];
                        default: ;
                    endcase
                end
                if (!rd_n) case ( addr )
                    0,1:     dout <= pm2s[addr[0]];
                    6'h29:   dout <= {4'd0,~over};
                    6'h2E:   dout <= mode ? roma_data : 8'd0;
                    default: dout <= 0;
                endcase
            end
        end
    end

    function [6:0] pan_dec_l( input [2:0] code );
        case ( code )
            3'b001:  pan_dec_l = 7'b1111111;
            3'b010:  pan_dec_l = 7'b1110100;
            3'b011:  pan_dec_l = 7'b1101000;
            3'b100:  pan_dec_l = 7'b1011010;
            3'b101:  pan_dec_l = 7'b1001001;
            3'b110:  pan_dec_l = 7'b0110100;
            3'b111:  pan_dec_l = 7'b0000000;
            default: pan_dec_l = 0;
        endcase
    endfunction

    function [6:0] pan_dec_r( input [2:0] code);
        case ( code )
            3'b001:  pan_dec_r = 7'b0000000;
            3'b010:  pan_dec_r = 7'b0110100;
            3'b011:  pan_dec_r = 7'b1001001;
            3'b100:  pan_dec_r = 7'b1011010;
            3'b101:  pan_dec_r = 7'b1101000;
            3'b110:  pan_dec_r = 7'b1110100;
            3'b111:  pan_dec_r = 7'b1111111;
            default: pan_dec_r = 0;
        endcase
    endfunction

    always @* begin
        pan0_l = pan_dec_l( ch0_pan );
        pan0_r = pan_dec_r( ch0_pan );
        pan1_l = pan_dec_l( ch1_pan );
        pan1_r = pan_dec_r( ch1_pan );
        pan2_l = pan_dec_l( ch2_pan );
        pan2_r = pan_dec_r( ch2_pan );
        pan3_l = pan_dec_l( ch3_pan );
        pan3_r = pan_dec_r( ch3_pan );
    end

    reg        cen64;
    reg  [5:0] cen_cnt = 0;

    always @(posedge clk) begin
        if( cen ) cen_cnt <= cen_cnt + 1'd1;
        cen64 <= cen_cnt==0 && cen;
    end


    jt053260_channel u_ch0(
        .rst      ( rst         ),
        .clk      ( clk         ),
        .cen64    ( cen64       ),

        .pitch    ( ch0_pitch   ),
        .length   ( ch0_length  ),
        .start    ( ch0_start   ),
        .volume   ( ch0_volume  ),
        .pan_l    ( pan0_l      ),
        .pan_r    ( pan0_r      ),
        .keyon    ( ch0_key     ),
        .loop     ( ch0_loop    ),
        .sample   ( ch0_sample  ),
        .over     ( over[0]     ),

        .rom_addr ( roma_addr   ),
        .rom_data ( roma_data   ),
        .rom_cs   ( roma_cs     ),
        .adpcm_en ( adpcm_en[0] ),
        .snd_l    ( ch0_snd_l   ),
        .snd_r    ( ch0_snd_r   )
    );

    jt053260_channel u_ch1(
        .rst      ( rst         ),
        .clk      ( clk         ),
        .cen64    ( cen64       ),

        .pitch    ( ch1_pitch   ),
        .length   ( ch1_length  ),
        .start    ( ch1_start   ),
        .volume   ( ch1_volume  ),
        .pan_l    ( pan1_l      ),
        .pan_r    ( pan1_r      ),
        .keyon    ( ch1_key     ),
        .loop     ( ch1_loop    ),
        .sample   ( ch1_sample  ),
        .over     ( over[1]     ),

        .rom_addr ( romb_addr   ),
        .rom_data ( romb_data   ),
        .rom_cs   ( romb_cs     ),
        .adpcm_en ( adpcm_en[1] ),
        .snd_l    ( ch1_snd_l   ),
        .snd_r    ( ch1_snd_r   )
    );

    jt053260_channel u_ch2(
        .rst      ( rst         ),
        .clk      ( clk         ),
        .cen64    ( cen64       ),

        .pitch    ( ch2_pitch   ),
        .length   ( ch2_length  ),
        .start    ( ch2_start   ),
        .volume   ( ch2_volume  ),
        .pan_l    ( pan2_l      ),
        .pan_r    ( pan2_r      ),
        .keyon    ( ch2_key     ),
        .loop     ( ch2_loop    ),
        .sample   ( ch2_sample  ),
        .over     ( over[2]     ),

        .rom_addr ( romc_addr   ),
        .rom_data ( romc_data   ),
        .rom_cs   ( romc_cs     ),
        .adpcm_en ( adpcm_en[2] ),
        .snd_l    ( ch2_snd_l   ),
        .snd_r    ( ch2_snd_r   )
    );

    jt053260_channel u_ch3(
        .rst      ( rst         ),
        .clk      ( clk         ),
        .cen64    ( cen64       ),

        .pitch    ( ch3_pitch   ),
        .length   ( ch3_length  ),
        .start    ( ch3_start   ),
        .volume   ( ch3_volume  ),
        .pan_l    ( pan3_l      ),
        .pan_r    ( pan3_r      ),
        .keyon    ( ch3_key     ),
        .loop     ( ch3_loop    ),
        .sample   ( ch3_sample  ),
        .over     ( over[3]     ),

        .rom_addr ( romd_addr   ),
        .rom_data ( romd_data   ),
        .rom_cs   ( romd_cs     ),
        .adpcm_en ( adpcm_en[3]    ),
        .snd_l    ( ch3_snd_l   ),
        .snd_r    ( ch3_snd_r   )
    );

endmodule

////////////////////////////////////////////////////////////////////////////////
module jt053260_channel(
    input                       rst,
    input                       clk,
    input                       cen64,

    input                [20:0] start,
    input                [15:0] length,
    input                [11:0] pitch,  // extra bits to slow down rom_addr needed
    input                [ 6:0] volume, // add multiplier
    input                       keyon,
    input                       loop,
    input                       adpcm_en,
    input                [ 6:0] pan_l, pan_r,
    input                [ 7:0] rom_data,

    output reg           [20:0] rom_addr,
    output reg                  rom_cs,
    output reg    signed [ 9:0] snd_l,
    output reg    signed [ 9:0] snd_r,
    output                      over,
    output                      sample
);

    reg         [16:0] cnt;
    reg         [15:0] inc;
    reg         [11:0] pitch_cnt;
    reg  signed [ 9:0] pre_snd;
    reg         [ 7:0] kadpcm;
    reg                adpcm_cnt;
    wire signed [17:0] mul_l;
    wire signed [17:0] mul_r;

    wire        [12:0] nx_pitch_cnt;
    wire signed [ 7:0] svl, svr;
    wire        [ 6:0] vol_l, vol_r;
    wire        [ 3:0] nibble;

    assign nx_pitch_cnt = {1'd0, pitch_cnt } + { 1'd0, pitch };
    assign nibble       = adpcm_cnt ? rom_data[7:4] : rom_data[3:0];
    assign sample       = nx_pitch_cnt[12] & cen64;
    assign vol_l        = volume | pan_l;
    assign vol_r        = volume | pan_r;
    assign svl          = {1'b0, vol_l};
    assign svr          = {1'b0, vol_r};
    assign mul_l        = pre_snd * svl;
    assign mul_r        = pre_snd * svr;
    assign over         = cnt[16];

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
        snd_l <= mul_l[17-:10];
        snd_r <= mul_r[17-:10];
    end

    always @(posedge clk, posedge rst) begin
        if( rst ) begin
            rom_addr  <= 0;
            cnt       <= 0;
            adpcm_cnt <= 0;
            rom_cs    <= 0;
        end else if( cen64 ) begin
            if( keyon ) begin
                rom_addr  <= start;
                cnt       <= {1'd0, length};
                adpcm_cnt <= 0;
                pre_snd   <= 0;
                rom_cs    <= 0;
                pitch_cnt <= 0;
            end else begin
                rom_cs <= 1;
                pitch_cnt <= nx_pitch_cnt[11:0];
                if( adpcm_en ) begin
                    pre_snd <= pre_snd + {1'd0, kadpcm };
                end else begin
                    pre_snd <= { rom_data, 2'd0 };
                end
                if( !cnt[16] && nx_pitch_cnt[12] ) begin
                    // addr start increment and cnt decrement
                    if( adpcm_en ) begin
                        { rom_addr[20:0], adpcm_cnt } <= { rom_addr[20:0], adpcm_cnt } + 1'd1;
                        cnt <= cnt - {15'd0, adpcm_cnt};
                    end else begin
                        rom_addr[20:0] <= rom_addr[20:0] + 1'd1;
                        cnt <=  cnt - 1'd1;
                    end
                    if( cnt==0 && loop && (adpcm_cnt || !adpcm_en) ) begin
                        rom_addr <= start;
                        cnt      <= {1'd0, length};
                    end
                end
            end
        end
    end

endmodule