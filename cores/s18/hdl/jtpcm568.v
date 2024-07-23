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
    Date: 19-3-2024 */

// Compatible with Ricoh RF5C68A
// Original pipeline:
// 384 ticks per sample (combining all 8 channels)
// 384/8 = 48 cycles per channel

module jtpcm568(
    input                rst,
    input                clk,
    input                cen,

    // CPU interface
    input                wr,
    input                cs,
    input         [12:0] addr, // A12 selects register (0) or memory (1)
    input         [ 7:0] din,
    output        [ 7:0] dout,

    // ADPCM RAM - ram0/ram1 represent different ports to the same memory
    // Access by PCM logic (read only)
    output reg    [15:0] ram0_addr,
    input         [ 7:0] ram0_dout,
    // Access by CPU via PCM (RW)
    output        [15:0] ram1_addr,
    output        [ 7:0] ram1_din,
    input         [ 7:0] ram1_dout,
    output               ram1_we,

    output reg    [ 9:0] snd_l, snd_r
);

reg  [  3:0] bank;
reg  [  7:0] chen_b;
wire [  7:0] chwr;
reg  [  2:0] chsel;
reg  [ 14:0] sum_l, sum_r;
reg  [ 15:0] acc_l, acc_r, envmul;
reg  [ 18:0] mul_l, mul_r;
reg  [ 26:0] sanx;
wire [ 63:0] chdout, chenv, chpan;
wire [127:0] chfd,   chls;
wire [215:0] chsa;
reg          mute_n, chenb_II, chenb_III, sign_III, loop,
             sign_IV, sign_V;
reg  [  7:0] env_II, pan_II, pan_III;
wire         regwr;
reg  [  2:0] chI, chII, chIII;
reg  [ 26:0] chsa_II;
wire [ 26:0] samx  = chsa [chI *27+:27];
wire [  7:0] enmx  = chenv[chI * 8+: 8];
wire [  7:0] panmx = chpan[chI * 8+: 8];
wire [ 15:0] fdmx  = chfd [chII*16+:16];
wire         lstop = &ram0_dout;
reg  [  5:0] cencnt=0;
reg          ch_cen;

assign ram1_addr = { bank, addr[11:0] };
assign ram1_we   = addr[12] & cs & wr;
assign ram1_din  = din;
assign dout      = addr[12] ? ram1_dout : chdout[{chsel,3'd0}+:8];
assign regwr     = cs && wr && addr[12:4]==0;

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        mute_n <= 0;
        bank   <= 0;
        chen_b <= 0;
        chsel  <= 0;
    end else begin
        if( regwr ) case(addr[3:0])
        7: begin
            mute_n <= din[7];
            if( din[6] )
                chsel <= din[2:0];
            else
                bank  <= din[3:0];
        end
        8: chen_b <= din;
        endcase
    end
end

generate
    genvar k;
    for(k=0;k<8;k=k+1) begin : channels
        assign chwr[k] = regwr && chsel==k;

        jtpcm568_ch u_ch(
            .rst        ( rst       ),
            .clk        ( clk       ),
            .cen        ( ch_cen    ),
            .wr         ( chwr[k]   ),
            .addr       ( addr[2:0] ),
            .din        ( din       ),
            .dout       ( chdout[{k[2:0],3'd0}+:8] ),
            // status
            .env        ( chenv[{k[2:0],3'd0}+:8] ),
            .pan        ( chpan[{k[2:0],3'd0}+:8] ),
            .fd         ( chfd[{k[2:0],4'd0}+:16] ),
            // sound address
            .sa         ( chsa[k[2:0]*27+:27] ),
            .sel        ( chIII==k[2:0]       ),
            .loop       ( loop                ),
            .mute       ( chenb_III           ),
            .sanx       ( sanx                )
        );
    end
endgenerate

// output rate must be 10MHz/384 = 26.041kHz
// 384/8 = 48 -> internal cen
always @(posedge clk) begin
    if(cen) cencnt <= cencnt==47 ? 6'd0 : cencnt+6'd1;
    ch_cen <= cencnt==0 && cen;
end

reg  [63:0] last;
wire [ 7:0] envmx = chenb_II ?      8'd0 : env_II;
wire [ 7:0] actmx = lstop    ? last[7:0] : ram0_dout; // repeat the last sample on loop conditions

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        chenb_II  <= 0;
        chenb_III <= 0;
        chI       <= 0;
        chII      <= 0;
        chIII     <= 0;
        chsa_II   <= 0;
        env_II    <= 0;
        envmul    <= 0;
        loop      <= 0;
        sum_l     <= 0;
        sum_r     <= 0;
        ram0_addr <= 0;
        sanx      <= 0;
        sign_III  <= 0;
        sign_IV   <= 0;
        sign_V    <= 0;
        last      <= 0;
    end else if(ch_cen) begin
        chI   <= chI+3'd1;
        chII  <= chI;
        chIII <= chII;
        // I
        ram0_addr <= samx[26-:16];
        chsa_II   <= samx;
        chenb_II  <= chen_b[chI] | ~mute_n;
        env_II    <= enmx;
        pan_II    <= panmx;
        // II
        envmul    <= {1'b0, actmx[6:0]}*envmx;
        sign_III  <= actmx[7];
        pan_III   <= pan_II;
        chenb_III <= chenb_II;
        loop      <= lstop;    // update channel counter
        sanx      <= chsa_II + {11'd0,fdmx};
        last      <= {ram0_dout,last[63:8]};
        // III
        mul_l     <= envmul*pan_III[3:0];
        mul_r     <= envmul*pan_III[7:4];
        sign_IV   <= sign_III;
        // IV
        sum_l     <= sign_IV ? -{1'b0,mul_l[18:5]} : {1'b0,mul_l[18:5]};
        sum_r     <= sign_IV ? -{1'b0,mul_r[18:5]} : {1'b0,mul_r[18:5]};
        sign_V    <= sign_IV;
    end
end

// accumulator
function [15:0] acc(input [14:0] s, input [15:0] a, input sign );
begin : acc_f
    reg ov;
    {ov, acc} = {a[15],a} + {{2{s[14]}},s};
    if (ov^acc[15]) acc = {ov,{15{~ov}}};
end
endfunction

wire [15:0] nx_accl = acc(sum_l,acc_l,sign_V);
wire [15:0] nx_accr = acc(sum_r,acc_r,sign_V);

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        acc_l     <= 0;
        acc_r     <= 0;
        snd_l     <= 0;
        snd_r     <= 0;
    end else if(ch_cen) begin
        if(&chI) begin
            acc_l <= 0;
            acc_r <= 0;
            snd_l <= nx_accl[15-:10];
            snd_r <= nx_accr[15-:10];
        end else begin
            acc_l <= nx_accl;
            acc_r <= nx_accr;
        end
    end
end

endmodule