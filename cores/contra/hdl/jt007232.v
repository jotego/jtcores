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
    // sound output - raw
    output signed [ 7:0] snda,
    output signed [ 7:0] sndb,
    output reg signed [11:0] snd       // snd_a + snd, scaled by register 12
);

parameter REG12A=1, // location of CHA gain
          INVA0 =0; // invert A0? The real chip did, we don't by default

reg [7:0] mmr[0:13]; // Not all bits are used

// Channel A control
wire [11:0] cha_pres = { mmr[1][3:0], mmr[0] };
wire [16:0] cha_addr = { mmr[4][0], mmr[3], mmr[2] };
wire [ 1:0] cha_presel = mmr[1][5:4];
reg         cha_play, cha_load;
wire        cha_loop = mmr[13][0];
wire signed [4:0] cha_gain = {1'b0, REG12A ? mmr[12][7:4] : mmr[12][3:0] };

// Channel B control
wire [11:0] chb_pres = { mmr[7][3:0], mmr[6] };
wire [16:0] chb_addr = { mmr[10][0], mmr[9], mmr[8] };
wire [ 1:0] chb_presel = mmr[7][5:4];
reg         chb_play, chb_load;
wire        chb_loop = mmr[13][1];
wire signed [4:0] chb_gain = {1'b0, !REG12A ? mmr[12][7:4] : mmr[12][3:0] };

// assign cen_2m = 0;

wire [3:0] addrj = INVA0 ? (addr^4'b1) : addr; // addr LSB may be inverted

reg signed [11:0] cha_amp, chb_amp;

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        snd     <= 0;
        cha_amp <= 0;
        chb_amp <= 0;
    end else begin
        cha_amp <= snda * cha_gain;
        chb_amp <= sndb * chb_gain;
        snd     <= cha_amp + chb_amp; // snda/b already had one filling bit
    end
end

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        mmr[ 0] <= 0; mmr[ 1] <= 0; mmr[ 2] <= 0; mmr[ 3] <= 0;
        mmr[ 4] <= 0; mmr[ 5] <= 0; mmr[ 6] <= 0; mmr[ 7] <= 0;
        mmr[ 8] <= 0; mmr[ 9] <= 0; mmr[10] <= 0; mmr[11] <= 0;
        mmr[12] <= 0; mmr[13] <= 0;
        cha_play <= 0;
        chb_play <= 0;
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
    .snd        ( snda      )
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
    .snd        ( sndb      )
);


endmodule

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
    output reg signed [7:0] snd
);

parameter [7:0] OFFSET='h40;

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
                    snd <= {1'b0, rom_dout[6:0]}-OFFSET;
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