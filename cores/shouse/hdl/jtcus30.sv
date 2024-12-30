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
    Date: 24-9-2023 */

// Implementation of Namco's CUS30 - 8-channel stereo DAC
// Based on MAME's namco_snd.cpp information and Atari's schematics

// The frequency number is the step added to the channel counter
// each waveform is 32-byte long
// MAME reports 12kHz as sampling frequency
// 15 kHz * 8 = 120 kHz
// 1536 kHz / 120 kHz = 12

module jtcus30(
    input               rst,
    input               clk,
    input               bsel,
    input               cen,    // 1.5 MHz (16 times slower than original input clk at 24MHz)

    output       [ 7:0] xdin,
    // main/sub bus
    input               bcs,
    input               brnw,
    input        [ 9:0] baddr,
    input        [ 7:0] bdout,

    // sound CPU
    input               scs,
    input               srnw,
    input        [15:0] saddr,
    input        [ 7:0] sdout,

    // sound output
    output               sample,
    output signed [12:0] snd_l,
    output signed [12:0] snd_r,

    input         [ 7:0] debug_bus
);

localparam CW=21,
           A0=CW-5;

wire [ 7:0] xdout = bsel ? bdout : sdout;
wire [15:0] xaddr = bsel ? {6'd0, baddr } : saddr;
wire        xcs   = bsel ? bcs  : scs;
wire        xwe   = xcs & ~(bsel ? brnw : srnw);
wire        mmr_cs= (bsel ? bcs  : scs) && xaddr[9:6]==4'b0100;
wire        mmr_wn= ~mmr_cs | (bsel ? brnw : srnw);

wire        cen120, zero;
// channel configuration data
wire [7:0][ 3:0] lvol;
wire [7:0][ 3:0] rvol;
wire [7:0]       no_en;
wire [7:0][ 3:0] wsel;
wire [7:0][19:0] freq;
reg  [7:0][CW-1:0] cnt;

// sound synthesis
reg  [ 2:0] ch, ch_l;
reg  [12:0] lacc, racc, raw_l, raw_r;
wire [ 7:0] wdata8;
reg  signed [ 9:0] lamp, ramp;
wire [ 9:0] rd_addr = {2'b0, wsel[ch_l], cnt[ch_l][(A0+1)+:4] };
wire signed [ 3:0] wdata;

// LFSR polynomial
reg  [17:0] lfsr;
reg         noise;
reg  [ 7:0] zero_l;

assign sample = ch==0 && cen120;
assign wdata  = cnt[ch][A0] ? wdata8[3:0] : wdata8[7:4];
assign zero   = cnt[ch_l][CW-1:A0]==0;

`ifdef DUMP
reg [7:0][3:0] wav;
wire [ 3:0] wav0,  wav1,  wav2,  wav3,  wav4,  wav5,  wav6,  wav7;
wire [19:0] freq0, freq1, freq2, freq3, freq4, freq5, freq6, freq7;
wire [ 3:0] lvol0, lvol1, lvol2, lvol3, lvol4, lvol5, lvol6, lvol7;
wire [CW-1:0] wcnt0, wcnt1, wcnt2, wcnt3, wcnt4, wcnt5, wcnt6, wcnt7;

assign  freq0 = freq[0], freq1 = freq[1], freq2 = freq[2], freq3 = freq[3],
        freq4 = freq[4], freq5 = freq[5], freq6 = freq[6], freq7 = freq[7];
assign  wav0 = wav[0], wav1 = wav[1], wav2 = wav[2], wav3 = wav[3],
        wav4 = wav[4], wav5 = wav[5], wav6 = wav[6], wav7 = wav[7];
assign  lvol0 = lvol[0], lvol1 = lvol[1], lvol2 = lvol[2], lvol3 = lvol[3],
        lvol4 = lvol[4], lvol5 = lvol[5], lvol6 = lvol[6], lvol7 = lvol[7];
assign  wcnt0 = cnt[0], wcnt1 = cnt[1], wcnt2 = cnt[2], wcnt3 = cnt[3],
        wcnt4 = cnt[4], wcnt5 = cnt[5], wcnt6 = cnt[6], wcnt7 = cnt[7];
always @(posedge clk) if(cen120) wav[ch]<=wdata;
`endif

always @(posedge clk, posedge rst ) begin
    if( rst ) begin
        ch    <= 0;
        lamp  <= 0;
        ramp  <= 0;
        lacc  <= 0;
        racc  <= 0;
        raw_l <= 0;
        raw_r <= 0;
        lfsr  <= 18'h1;
        noise <= 0;
        zero_l<= 0;
    end else if(cen120) begin
        ch   <= ch+3'd1;
        ch_l <= ch;
        cnt[ch] <= cnt[ch]+{1'd0,freq[ch]};
        zero_l[ch_l] <= zero;

        if( !no_en[ch_l] ) begin
            lamp <= { 1'b0, wdata } * { 1'b0, lvol[ch_l] };
            ramp <= { 1'b0, wdata } * { 1'b0, rvol[ch_l] };
        end else if( zero && !zero_l[ch_l]) begin
            lamp <= 5'd7*({1'b0,lvol[ch_l]});
            ramp <= 5'd7*({1'b0,rvol[ch_l]});
            if(!noise) {lamp,ramp} <= 0;
        end

        // accumulator and output
        lacc <= ch==0 ? {3'd0,lamp} : lacc+{3'd0,lamp};
        racc <= ch==0 ? {3'd0,ramp} : racc+{3'd0,ramp};
        if( ch==0 ) begin
            raw_l <= lacc;
            raw_r <= racc;
        end
        // LFSR
        noise <= noise^(^lfsr[1:0]);
        lfsr <= { lfsr[0], lfsr[17]^lfsr[0], lfsr[16], lfsr[15]^{lfsr[0]}, lfsr[14:1] }; // MAME's polynomial, is it verified?
    end
end

jtframe_dcrm #(.SW(13),.SIGNED_INPUT(0)) u_dcrm_left(
    .rst    ( rst           ),
    .clk    ( clk           ),
    .sample ( sample        ),
    .din    ( raw_l         ),
    .dout   ( snd_l         )
);

jtframe_dcrm #(.SW(13),.SIGNED_INPUT(0)) u_dcrm_right(
    .rst    ( rst           ),
    .clk    ( clk           ),
    .sample ( sample        ),
    .din    ( raw_r         ),
    .dout   ( snd_r         )
);

jtframe_cendiv #(.MDIV(8)) u_cendiv(
    .clk        ( clk       ),
    .cen_in     ( cen       ),
    .cen_div    ( cen120    ),
    .cen_da     (           )
);

jtframe_dual_ram u_wave( // 4 (waves) + 5 (wave length) = 9 bits, 10th bit must be used as regular RAM
    // Port 0 - CPUs
    .clk0   ( clk        ),
    .data0  ( xdout      ),
    .addr0  ( xaddr[9:0] ),
    .we0    ( xwe        ),
    .q0     ( xdin       ),
    // Port 1 - Waveform reading
    .clk1   ( clk        ),
    .data1  (  8'd0      ),
    .addr1  ( rd_addr    ),
    .we1    (  1'b0      ),
    .q1     ( wdata8     )
);

jtshouse_cus30_mmr u_mmr(
    .rst    ( rst       ),
    .clk    ( clk       ),

    .cs     ( mmr_cs    ),
    .addr   ( xaddr[5:0]),
    .rnw    ( mmr_wn    ),
    .din    (  xdout    ),

    .lvol   ( lvol      ),
    .rvol   ( rvol      ),
    .no_en  ( no_en     ),
    .wsel   ( wsel      ),
    .freq   ( freq      ),

    // IOCTL dump
    .ioctl_addr( 6'd0   ),
    .ioctl_din (        ),
    // Debug
    .debug_bus ( 8'd0   ),
    .st_dout   (        )
);

endmodule