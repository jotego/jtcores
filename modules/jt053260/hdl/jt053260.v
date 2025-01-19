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

module jt053260(
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

    // external YM2151 or YM3012-compatible devices
    input      signed [15:0] aux_l, aux_r,
    output reg signed [15:0] snd_l,
    output reg signed [15:0] snd_r,
    output                   sample,
    // debug
    input             [ 4:0] ch_en
    // unsupported pins
    // input               st1,
    // input               st2,
    // input               aux2,
    // output              rdnwp,
    // output              tim2,
    // output              cen_e,    // M6809 clock
    // output              cen_q     // M6809 clock
);
wire signed [15:0] pre_l, pre_r;
reg    [ 7:0] pm2s[0:1];
reg    [ 7:0] ps2m[0:1];

reg    [ 3:0] keyon, mode;
wire   [ 3:0] bsy, mmr_we;
reg    [ 3:0] adpcm_en, loop;
reg    [ 2:0] ch0_pan, ch1_pan, ch2_pan, ch3_pan;

wire          ch0_sample, ch1_sample, ch2_sample, ch3_sample;
wire signed [15:0] ch0_snd_l, ch1_snd_l, ch2_snd_l, ch3_snd_l,
                   ch0_snd_r, ch1_snd_r, ch2_snd_r, ch3_snd_r;

reg    [ 6:0] pan0_l, pan0_r, pan1_l, pan1_r,
              pan2_l, pan2_r, pan3_l, pan3_r;
reg           tst_rd, tst_rdl;
wire          mmr_en, tst_nx;

assign sample = |{ch0_sample,ch1_sample,ch2_sample,ch3_sample};
assign mmr_en = addr[5:3]>=1 && addr[5:3]<=4;
assign mmr_we = {4{ cs & ~wr_n & mmr_en }} &
                { addr[5:3]==4, addr[5:3]==3, addr[5:3]==2, addr[5:3]==1 };
assign tst_nx = tst_rd & ~tst_rdl;

jtframe_limsum u_suml(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .cen    ( cen       ),
    .parts  ( {aux_l, ch3_snd_l, ch2_snd_l, ch1_snd_l, ch0_snd_l} ),
    .en     ( ch_en     ),
    .sum    ( pre_l     ),
    .peak   (           )
);

jtframe_limsum u_sumr(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .cen    ( cen       ),
    .parts  ( {aux_r, ch3_snd_r, ch2_snd_r, ch1_snd_r, ch0_snd_r} ),
    .en     ( ch_en     ),
    .sum    ( pre_r     ),
    .peak   (           )
);

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        snd_l   <= 0;
        snd_r   <= 0;
    end else begin
        if( mode[1] ) begin
            snd_l <= pre_l;
            snd_r <= pre_r;
        end else if(cen) begin // fade out
            snd_l <= snd_l >>> 1;
            snd_r <= snd_r >>> 1;
        end
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
        ps2m[0] <= 0; ps2m[1] <= 0;
        ch0_pan <= 0; ch1_pan <= 0; ch2_pan <= 0; ch3_pan <= 0;
        keyon   <= 4'hF; loop <= 0; mode    <= 0; adpcm_en <=0;
        dout    <= 0;
        tst_rd  <= 0;
        tst_rdl <= 0;
    end else begin
        tst_rdl <= tst_rd;
        if( cs ) begin
            if ( !wr_n ) begin
                case ( addr )
                    2,3:   ps2m[addr[0]] <= din;
                    6'h28: keyon <= din[3:0];
                    6'h2A: { adpcm_en, loop } <= din;
                    6'h2C: { ch1_pan, ch0_pan } <= din[5:0];
                    6'h2D: { ch3_pan, ch2_pan } <= din[5:0];
                    6'h2F: mode <= din[3:0];
                    default: ;
                endcase
            end
            if (!rd_n) case ( addr )
                0,1:     dout <= pm2s[addr[0]];
                6'h29:   dout <= {4'd0,bsy};
                6'h2E:   begin
                    if( !tst_rd ) dout <= mode[0] ? roma_data : 8'd0;
                    tst_rd <= 1;
                end
                default: dout <= 0;
            endcase
        end else begin
            tst_rd <= 0;
        end
    end
end

function [6:0] pan_dec_l( input [2:0] code );
    case ( code )
        3'b001:  pan_dec_l = 7'b1111111; // 127 /   0
        3'b010:  pan_dec_l = 7'b1110100; // 116 /  52
        3'b011:  pan_dec_l = 7'b1101000; // 104 /  73
        3'b100:  pan_dec_l = 7'b1011010; //  90 /  90
        3'b101:  pan_dec_l = 7'b1001001; //  73 / 104
        3'b110:  pan_dec_l = 7'b0110100; //  52 / 116
        3'b111:  pan_dec_l = 7'b0000000; //   0 / 127
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

jt053260_channel u_ch0(
    .rst      ( rst         ),
    .clk      ( clk         ),
    .cen      ( cen         ),

    // MMR
    .addr     ( addr[2:0]   ),
    .din      ( din         ),
    .we       ( mmr_we[0]   ),

    .tst_en   ( mode[0]     ),
    .tst_nx   ( tst_nx      ),
    .pan_l    ( pan0_l      ),
    .pan_r    ( pan0_r      ),
    .keyon    ( keyon[0]    ),
    .loop     ( loop[0]     ),
    .sample   ( ch0_sample  ),
    .bsy      ( bsy[0]      ),

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
    .cen      ( cen         ),

    // MMR
    .addr     ( addr[2:0]   ),
    .din      ( din         ),
    .we       ( mmr_we[1]   ),

    .tst_en   ( 1'b0        ),
    .tst_nx   ( 1'b0        ),
    .pan_l    ( pan1_l      ),
    .pan_r    ( pan1_r      ),
    .keyon    ( keyon[1]    ),
    .loop     ( loop[1]     ),
    .sample   ( ch1_sample  ),
    .bsy      ( bsy[1]      ),

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
    .cen      ( cen         ),

    // MMR
    .addr     ( addr[2:0]   ),
    .din      ( din         ),
    .we       ( mmr_we[2]   ),

    .tst_en   ( 1'b0        ),
    .tst_nx   ( 1'b0        ),
    .pan_l    ( pan2_l      ),
    .pan_r    ( pan2_r      ),
    .keyon    ( keyon[2]    ),
    .loop     ( loop[2]     ),
    .sample   ( ch2_sample  ),
    .bsy      ( bsy[2]      ),

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
    .cen      ( cen         ),

    // MMR
    .addr     ( addr[2:0]   ),
    .din      ( din         ),
    .we       ( mmr_we[3]   ),

    .tst_en   ( 1'b0        ),
    .tst_nx   ( 1'b0        ),
    .pan_l    ( pan3_l      ),
    .pan_r    ( pan3_r      ),
    .keyon    ( keyon[3]    ),
    .loop     ( loop[3]     ),
    .sample   ( ch3_sample  ),
    .bsy      ( bsy[3]      ),

    .rom_addr ( romd_addr   ),
    .rom_data ( romd_data   ),
    .rom_cs   ( romd_cs     ),
    .adpcm_en ( adpcm_en[3] ),
    .snd_l    ( ch3_snd_l   ),
    .snd_r    ( ch3_snd_r   )
);

endmodule
