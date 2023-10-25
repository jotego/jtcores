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
/* verilator tracing_on */
module jtcus30(
    input               rst,
    input               clk,
    input               bsel,
    input               cen,    // 1.5 MHz

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
    output reg   [10:0] snd_l,
    output reg   [10:0] snd_r
);

localparam CW=21,
           A0=CW-5;

wire [ 7:0] xdout = bsel ? bdout : sdout;
wire [15:0] xaddr = bsel ? {6'd0, baddr } : saddr;
wire        xcs   = (bsel ? bcs  : scs) && xaddr[9:8]==0;
wire        xwe   = xcs & ~(bsel ? brnw : srnw);
wire        mmr_cs= (bsel ? bcs  : scs) && xaddr[9:6]==4'b0100;
wire        mmr_wn= ~mmr_cs | (bsel ? brnw : srnw);

wire        cen120;
// channel configuration data
wire [7:0][ 3:0] lvol;
wire [7:0][ 3:0] rvol;
wire [7:0]       no_en;
wire [7:0][ 3:0] wsel;
wire [7:0][19:0] freq;
reg  [7:0][CW-1:0] cnt;

// sound synthesis
reg  [ 2:0] ch, ch_l;
reg  [10:0] lacc, racc;
wire [ 7:0] wdata;
reg  [ 7:0] lamp, ramp;
wire [ 9:0] rd_addr = {1'b0, wsel[ch], cnt[ch][A0+:5] };

// LFSR polynomial
reg  [17:0] lfsr;
reg         noise;
reg  [7:0][CW-1:A0] cnt_no; // old value of counter when noise was last produced

always @(posedge clk, posedge rst ) begin
    if( rst ) begin
        ch    <= 0;
        lamp  <= 0;
        ramp  <= 0;
        lacc  <= 0;
        racc  <= 0;
        snd_l <= 0;
        snd_r <= 0;
        lfsr  <= 18'h1;
        noise <= 0;
        cnt_no<= 0;
    end else if(cen120) begin
        ch   <= ch+3'd1;
        ch_l <= ch;
        cnt[ch] <= cnt[ch]+{1'd0,freq[ch]};

        if( no_en[ch_l] && cnt[ch_l][CW-1:A0]!=cnt_no[ch_l]) begin
            lamp <= 4'd7*({1'b0,lvol[ch_l][3:1]});
            ramp <= 4'd7*({1'b0,rvol[ch_l][3:1]});
            cnt_no[ch_l] <= cnt[ch_l][CW-1:A0];
        end else begin
            lamp <= wdata*lvol[ch_l];
            ramp <= wdata*rvol[ch_l];
        end

        // accumulator and output
        lacc <= ch==0 ? {3'd0,lamp} : lacc+{3'd0,lamp};
        racc <= ch==0 ? {3'd0,ramp} : racc+{3'd0,ramp};
        if( ch==0 ) begin
            snd_l <= lacc;
            snd_r <= racc;
        end
        // LFSR
        noise <= noise^(^lfsr[1:0]);
        lfsr <= { lfsr[0], lfsr[17]^lfsr[0], lfsr[16], lfsr[15]^{lfsr[0]}, lfsr[14:1] }; // MAME's polynomial, is it verified?
    end
end

jtframe_cendiv #(.MDIV(12)) u_cendiv(
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
    .q1     ( wdata      )
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