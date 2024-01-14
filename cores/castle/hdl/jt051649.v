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
    Date: 9-4-2023 */

// Mostly equivalent to the SCC chip in MSX cartridges

module jt051649(
    input                rst,
    input                clk,
    input                cen4,  // set to 4x the frequency on schematics
    input                cs,
    input                wrn,
    input         [15:0] addr,
    input         [ 7:0] din,
    output        [ 7:0] dout,
    output reg signed [11:0] snd
);

wire [ 8:0] cfg_dout, pre_dout;
wire        cs2;
reg  [ 7:0] test, cfg_addr, wr_addr;
reg  [ 4:0] kon;
reg         cpu_we, cfg_we, sinc;

// Current channel data
reg  [ 2:0] st; // 8 states x 8 ch = 64, cen4 / 128 = cen/16
reg  [ 2:0] ch;
reg  [ 1:0] ch45;   // ch>4 ignored
reg  [11:0] freq, cnt, nx_cnt;
reg  [ 3:0] vol;
reg  [ 4:0] scnt;
reg  [ 8:0] cfg_din;

wire signed [ 7:0] wav;
wire signed [ 4:0] vol_sex;
reg  signed [11:0] acc;
reg  signed [11:0] acc_nx;
reg  signed [12:0] chsnd;
reg                ov;

`ifdef SIMULATION
reg cenl=0;
always @(posedge clk) begin
    cenl <= cen4;
    if( cenl && cen4 ) begin
        $display("jt051649: ERROR cen4 input cannot be high for 2-clock cycles");
        $finish;
    end
end
`endif

assign wav  = cfg_dout[7:0];
assign cs2  = addr[15:12]==9 && addr[11];
assign vol_sex = { 1'b0, vol };
assign dout = addr[7] ? 8'hff : pre_dout[7:0];

always @* begin
    wr_addr = addr[7:0];
    cpu_we  = cs & cs2 & ~wrn;
    if( addr[7] ) wr_addr[4]=0;     // converts 90-9F to 80-8F
    if( addr[7:4]>9 ) cpu_we = 0;
end

// RAM map
// 00 ~ 1F waveform 0
// 20 ~ 3F waveform 1
// 40 ~ 5F waveform 2
// 60 ~ 7F waveform 3 and waveform 4
// 80 ~ 89 frequency data, 16-bit values, little endian
// 8A ~ 8E volume, 4-bit values
// A0 ~ A9 channel freq counters
//         even address: low byte
//         odd  address: sample counter, freq. cnt high nibble
jtframe_dual_ram #(.DW(9),.AW(8)) u_ram(
    // Port 0
    .clk0   ( clk        ),
    .data0  ( {1'd0, din}),
    .addr0  ( wr_addr    ),
    .we0    ( cpu_we     ),
    .q0     ( pre_dout   ),
    // Port 1
    .clk1   ( clk        ),
    .data1  ( cfg_din    ),
    .addr1  ( cfg_addr   ),
    .we1    ( cfg_we     ),
    .q1     ( cfg_dout   )
);

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        test <= 0;
        kon  <= 0;
    end else if( cs && cs2 && !wrn ) begin
        if( &addr[7:5] ) test <= din;
        if(  addr[7:0]==8'h8F ) kon <= din[4:0];
    end
end

always @(posedge clk) begin
    chsnd = wav * vol_sex;
end

always @* begin
    acc_nx =  acc + {chsnd[12],chsnd[12:2]};
    ov = &{acc[11],chsnd[12],~acc_nx[11]} | &{~acc[11],~chsnd[12],acc_nx[11]};
    nx_cnt = {cfg_dout[3:0],cnt[7:0]}+12'd5;
    if( nx_cnt >= freq ) begin
        sinc = 1;
        nx_cnt = nx_cnt - freq;
    end else begin
        sinc = 0;
    end
end

always @* begin
    ch45    = ch[2] ? 2'd3 : ch[1:0];
    cfg_we  = 0;
    cfg_din = {1'd0, cnt[7:0]};
    case( st )
        0: cfg_addr = {4'h8, ch, 1'd0 }; // frequency
        1: cfg_addr = {4'h8, ch, 1'd1 };
        2: cfg_addr = {4'h8, 4'hA + {1'd0,ch} };  // volume
        3: cfg_addr = {4'hA, ch, 1'd0 }; // freq counter low
        4: cfg_addr = {4'hA, ch, 1'd1 }; // freq cnt high and sample counter
        5: begin
            cfg_addr = {4'hA, ch, 1'd0 }; // freq counter (low)
            cfg_din = {1'd0, cnt[7:0]};
            cfg_we  = 1;
        end
        6: begin
            cfg_addr = {4'hA, ch, 1'd1 };  // freq cnt hi, sample cnt
            cfg_din = {scnt,cnt[11:8]};
            cfg_we  = 1;
        end
        7: cfg_addr = { 1'd0, ch45, scnt }; // new sample
    endcase
    if( ch>4 ) cfg_we = 0;
end

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        ch   <= 0;
        vol  <= 0;
        cnt  <= 0;
        scnt <= 0;
        freq <= 0;
        st   <= 0;
        snd  <= 0;
    end else if(cen4) begin
        st <= st+1'd1;
        case( st )
            0: freq[ 7:0] <= cfg_dout[7:0];
            1: freq[11:8] <= cfg_dout[3:0];
            2:  vol       <= cfg_dout[3:0];
            3:  cnt[ 7:0] <= cfg_dout[7:0];
            4: begin
                if( !kon[ch] || freq<9 ) begin
                    cnt  <= 0;
                    scnt <= 0;
                end else begin
                    cnt <= nx_cnt;
                    scnt<= sinc ? cfg_dout[8:4]+1'd1 : cfg_dout[8:4];
                end
            // 5 - write cnt low
            // 6 - write scnt, cnt high
            end
            7: begin
                ch <= ch==4 ? 3'd0 : ch+1'd1;
                if( ch==0 ) begin
                    acc <= { chsnd[12], chsnd[12:2] };
                    snd <= acc;
                end else if(ch<5) begin
                    acc <= ov ? { acc[11], {11{~acc[11]}}} : acc_nx;
                end
            end
        endcase
    end
end


endmodule