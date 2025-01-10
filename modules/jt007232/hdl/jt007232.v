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
    Date: 24-8-2021 */

// RAM-write operation is not implemented
// 2-channel PCM. The two channels connect to the same
// external ROM. The connections are separated for convenience
// in this implementation

// This chip seems to be usually hooked to a rough resistor DAC for
// channel volume. The DAC is made of four resistors which are not linear
// 24k, 40k, 100k, 200k (instead of 25, 50, 100, 200). This creates a small
// lineary error. Converting the DAC gain to an 8-bit number:
// Code Real  Ideal    Error
//  0     0       0        0
//  1     16      17       -1
//  2     31      34       -3
//  3     47      51       -4
//  4     78      68       10
//  5     94      85       9
//  6     109     102      7
//  7     125     119      6
//  8     130     136      -6
//  9     146     153      -7
//  10    161     170      -9
//  11    177     187      -10
//  12    208     204      4
//  13    224     221      3
//  14    239     238      1
//  15    255     255      0
// This is specially bad in the code 7 to 8 transition
// I am not modelling this effect as the music probably sounds better
// using the linear model rather than the *authentic* one
// It is also used with a proper R2R ladder in some games, like Haunted Castle
// so the response is linear for those ones

module jt007232(
    input             rst,
    input             clk,
    input             cen,
    input      [ 3:0] addr,
    // RAM ports not implemented
    // input             nrcs,
    // input             nrd,
    input             dacs, // active high
    input             wr_n, // not a pin on the original
    input      [ 7:0] din,
    // output            cen_2m,// equivalent to ck2m pin -- not implemented
    output reg        cen_q, // equivalent to NE pin
    output reg        cen_e, // equivalent to NQ pin
    // output     [ 7:0] dout,
    input             swap_gains,   // makes ^ with REG12A below

    // External memory - the original chip
    // only had one bus
    output     [16:0] roma_addr,
    input      [ 7:0] roma_dout,
    output            roma_cs,
    input             roma_ok,

    output     [16:0] romb_addr,
    input      [ 7:0] romb_dout,
    output            romb_cs,
    input             romb_ok,
    // sound output - scaled by register 12
    output     signed [10:0] snda,
    output     signed [10:0] sndb,
    output     signed [10:0] snd,
    // debug
    input         [ 7:0] debug_bus,
    output reg    [ 7:0] st_dout
);

parameter REG12A=1, // location of CHA gain, the gain device is external to the
                    // chip. There is normally an 8-bit latch attached. It holds
                    // the value at mmr[12], which isn't internal but just sets
                    // the SLEV pin when set.
                    // MX5000 uses the upper nibble for channel A, but
                    // aliens uses the lower.
          INVA0 =0; // invert A0? The real chip did, we don't by default

reg [7:0] mmr[0:13]; // Not all bits are used

wire signed [ 6:0] rawa, rawb;
// Channel A control
wire [11:0] cha_pres = { mmr[1][3:0], mmr[0] };
wire [16:0] cha_addr = { mmr[4][0], mmr[3], mmr[2] };
wire [ 1:0] cha_presel = mmr[1][5:4];
reg         cha_play, cha_load;
wire        peak;
wire        cha_loop = mmr[13][0];

// Channel B control
wire [11:0] chb_pres = { mmr[7][3:0], mmr[6] };
wire [16:0] chb_addr = { mmr[10][0], mmr[9], mmr[8] };
wire [ 1:0] chb_presel = mmr[7][5:4];
reg         chb_play, chb_load;
wire        chb_loop = mmr[13][1];

wire [3:0] addrj = INVA0==1 ? (addr^4'b1) : addr; // addr LSB may be inverted

jt007232_gain #(.REG12A(REG12A)) u_gain(
    .clk        ( clk         ),
    .reg12      ( mmr[12]     ),
    .swap_gains ( swap_gains  ),
    .rawa       ( rawa        ),
    .rawb       ( rawb        ),
    .snda       ( snda        ),
    .sndb       ( sndb        )
);

jtframe_limsum #(.WI(11),.K(2)) u_limsum(
    .rst    ( rst   ),
    .clk    ( clk   ),
    .cen    ( 1'b1  ),
    .en     ( 2'b11 ),
    .parts  ( {snda, sndb } ),
    .sum    ( snd   ),
    .peak   ( peak  )
);

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        mmr[ 0] <= 0; mmr[ 1] <= 0; mmr[ 2] <= 0; mmr[ 3] <= 0;
        mmr[ 4] <= 0; mmr[ 5] <= 0; mmr[ 6] <= 0; mmr[ 7] <= 0;
        mmr[ 8] <= 0; mmr[ 9] <= 0; mmr[10] <= 0; mmr[11] <= 0;
        mmr[12] <= 0; mmr[13] <= 0;
        cha_play <= 0;
        chb_play <= 0;
        st_dout  <= 0;
    end else begin
        cha_load <= 0;
        chb_load <= 0;
        if( dacs && !wr_n ) begin
            mmr[ addrj ] <= din;
            cha_load <= addrj==0 || addrj==1;
            chb_load <= addrj==6 || addrj==7;
        end
        cha_play <= dacs && addrj==5;
        chb_play <= dacs && addrj==11;
        st_dout  <= mmr[debug_bus[3:0]];
    end
end

// E/Q clocks, these are M6809 clocks, E and Q operate at 1/4 of clk
// E is 90º ahead of Q
// Here, I only generate two clock enable signals in opposite phases
// RAM access is done originally when E is low
// Here, RAM access is done when E is high

reg [1:0] cen_cnt;

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        cen_e   <= 0;
        cen_q   <= 0;
        cen_cnt <= 0;
    end else begin
        if(cen) cen_cnt <= cen_cnt+1'd1;
        cen_e    <= cen && cen_cnt==3;
        cen_q    <= cen && cen_cnt==1;
    end
end

// reg [7:0] div_cnt;
// reg       cen_div;
//
// always @(posedge clk, posedge rst) begin
//     if( rst ) begin
//         div_cnt <= 0;
//         cen_div <= 0;
//     end else begin
//         if( cen ) div_cnt <= div_cnt + 1'd1;
//         cen_div <= cen && (&div_cnt);
//     end
// end

// it looks like the clock isn't q/2 but q
// contrary to Furrtek's RE

jt007232_channel u_cha(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cen_q      ( cen_q     ),
    // control from MMR
    .rom_start  ( cha_addr  ),
    .pre0       ( cha_pres  ),
    .pre_sel    ( cha_presel),
    .loop       ( cha_loop  ),
    .play       ( cha_play  ),
    .load       ( cha_load  ),

    .rom_addr   ( roma_addr ),
    .rom_cs     ( roma_cs   ),
    .rom_ok     ( roma_ok   ),
    .rom_dout   ( roma_dout ),
    .snd        ( rawa      )
);

jt007232_channel u_chb(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cen_q      ( cen_q     ),
    // control from MMR
    .rom_start  ( chb_addr  ),
    .pre0       ( chb_pres  ),
    .pre_sel    ( chb_presel),
    .loop       ( chb_loop  ),
    .play       ( chb_play  ),
    .load       ( chb_load  ),

    .rom_addr   ( romb_addr ),
    .rom_cs     ( romb_cs   ),
    .rom_ok     ( romb_ok   ),
    .rom_dout   ( romb_dout ),
    .snd        ( rawb      )
);


endmodule

