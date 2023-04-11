/*  This file is part of JTCONTRA.
    JTCONTRA program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTCONTRA program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTCONTRA.  If not, see <http://www.gnu.org/licenses/>.

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
    output reg signed [14:0] snd    // Do not clamp at this level
);

localparam SW=8+5, OW=15;

wire [ 7:0] cfg_dout, pre_dout;
wire        cs2;
reg  [ 7:0] test, cfg_addr, wr_addr;
reg  [ 4:0] kon;
reg         cpu_we, cfg_we;

// Current channel data
reg  [ 3:0] st; // 16 states x 8 ch = 128, cen4 / 128 = cen/32
reg  [ 2:0] ch;
reg  [ 1:0] ch45;   // ch>4 ignored
reg  [11:0] freq, cnt;
reg  [ 3:0] vol;
reg  [ 4:0] scnt;
reg  [ 7:0] cfg_din;

reg  signed [ 7:0] wav;
wire signed [ 4:0] vol_sex;
reg  signed [14:0] acc, acc_nx;
wire signed [14:0] chsnd_sex;
reg  signed [SW-1:0] chsnd;

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

assign cs2  = addr[15:12]==9 && addr[11];
assign chsnd_sex = kon[ch] ? { {OW-SW{chsnd[SW-1]}}, chsnd } : 15'd0;
assign vol_sex = { 1'b0, vol };
assign dout = addr[7] ? 8'hff : pre_dout;

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
// AA ~ AE channel sample counters
jtframe_dual_ram #(.AW(8)) u_ram(
    // Port 0
    .clk0   ( clk        ),
    .data0  ( din        ),
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
        if(  addr[7:0]==8'h8F ) kon <= {4'd0,din[0]};//din[4:0];
    end
end

always @(posedge clk) begin
    chsnd = wav * vol_sex;
end

always @* begin
    acc_nx  = acc + chsnd_sex;
    ch45    = ch[2] ? 2'd3 : ch[1:0];
    cfg_we  = 0;
    cfg_din = cnt[7:0];
    case( st )
        0: cfg_addr = {4'h8, ch, 1'd0 }; // frequency
        1: cfg_addr = {4'h8, ch, 1'd1 };
        2: cfg_addr = {4'hA, ch, 1'd0 }; // freq counter
        3: cfg_addr = {4'hA, ch, 1'd1 };
        4: cfg_addr = {4'h8, 4'hA + {1'd0,ch} };  // volume
        5: cfg_addr = {4'hA, 4'hA + {1'd0,ch} };  // sample counter
        6: begin
            cfg_addr = {4'hA, 4'hA + {1'd0,ch} };  // sample counter
            cfg_din = {3'd0, scnt};
            cfg_we  = 1;
        end
        7: begin
            cfg_addr = {4'hA, ch, 1'd0 }; // freq counter (low)
            cfg_din = cnt[7:0];
            cfg_we  = 1;
        end
        8: begin
            cfg_addr = {4'hA, ch, 1'd1 }; // freq counter (high)
            cfg_din = {4'd0,cnt[11:8]};
            cfg_we  = 1;
        end
        default: cfg_addr = { 1'd0, ch45, scnt }; // new sample
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
        wav  <= 0;
    end else if(cen4) begin
        st <= st+1'd1;
        case( st )
            0: freq[ 7:0] <= cfg_dout;
            1: freq[11:8] <= cfg_dout[3:0];
            2:  cnt[ 7:0] <= cfg_dout;
            3:  cnt[11:8] <= cfg_dout[3:0];
            4:  vol       <= cfg_dout[3:0];
            5: begin
                if( !kon[ch] || freq<9 ) begin
                    cnt  <= 0;
                    scnt <= 0;
                end else begin
                    cnt <= cnt==freq ? 12'd0 : cnt+1'd1;
                    scnt<= cnt==freq ? cfg_dout[4:0]+1'd1 : cfg_dout[4:0];
                end
            // 6 - write scnt
            // 7 - write cnt low
            // 8 - write cnt high
            end
            9: wav <= cfg_dout;
            10: begin
                if( ch==0 ) begin
                    acc <= chsnd_sex;
                    snd <= acc;
                end else if(ch<5) begin
                    acc <= acc_nx;
                end
            end
            15: ch <= ch+1'd1;
            default:;
        endcase
    end
end


endmodule