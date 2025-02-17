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
    Date: 16-7-2022 */

// This module represents the 315-5218
// Clock input 16.000MHz on pin 80
// Clock outputs: pin 2 - 4.000MHz, pin 80 - 500.000kHz, pin 89 - 62.500KHz
// Sample rate = clk/4/128 = 31.25 kHz

module jtoutrun_pcm #(parameter
    WD        = 12,     // DAC bit width (AD7121) = 12 bits plus bits dropped internally
    SIMHEXFILE= ""
)(
    input              rst,
    input              clk,
    input              cen, // original clock was 16MHz

    input        [7:0] debug_bus,
    output reg   [7:0] st_dout,

    // CPU interface
    input        [7:0] cpu_addr,
    input        [7:0] cpu_dout,
    output       [7:0] cpu_din,
    input              cpu_rnw,
    input              cpu_cs,

    // ROM interface
    output reg  [18:0] rom_addr,
    input       [ 7:0] rom_data,
    input              rom_ok,
    output reg         rom_cs,

    // sound output
    output reg signed [15:0] snd_left,
    output reg signed [15:0] snd_right,
    output reg           sample
);

wire        we = cpu_cs & ~cpu_rnw;
reg  [ 3:0] st;
wire [ 2:0] bank;
wire [ 7:0] cfg_data;
reg  [ 3:0] cur_ch;
reg  [ 4:0] cfg_addr;
reg  [15:0] active;     // high for active channels, debug only
reg  [ 7:0] cfg_en;
reg  [ 7:0] delta, cfg_din;
reg         cfg_we, was_enb;

reg  [23: 0] cur_addr;
reg  [23: 8] loop_addr;
reg  [23:16] end_addr;

reg  signed [ 7:0] vol_left, vol_right, vol_mux;
wire signed [ 7:0] pcm_data;
reg  signed [15:0] mul_data;
reg  signed [15:0] acc_l, acc_r;
reg  signed [WD-1:0] mul_clip, buf_r;


assign bank     = cfg_en[6:4];
assign pcm_data = rom_data - 8'h80;

// only AW=8 is needed for the CPU. Using AW=9
// to store the scratch value for lower
// 8-bit address of the current sample
// so it does not overwrite any register the CPU has
// access too.
// That register may actually be visible by
// the CPU, using cfg_addr=4'o17 for AW=8 seems to work fine too
jtframe_dual_ram #(.AW(9),.SIMHEXFILE(SIMHEXFILE)) u_ram(
    // Port 0: CPU
    .clk0   ( clk       ),
    .data0  ( cpu_dout  ),
    .addr0  ({1'b0,cpu_addr}),
    .we0    ( we        ),
    .q0     ( cpu_din   ),
    // Port 1
    .clk1   ( clk       ),
    .data1  ( cfg_din   ),
    .addr1  ( { cfg_addr[4:3], cur_ch, cfg_addr[2:0] } ),
    .we1    ( cfg_we    ),
    .q1     ( cfg_data  )
);

always @(posedge clk) begin
    sample <= st==0 && cur_ch==0 && cen;
end

function signed [WD-1:0] clipDAC( input [15:0]s );
    clipDAC = (|s[15:WD-1] & ~&s[15:WD-1]) ? {s[15],{WD-1{~s[15]}}} : s[WD-1:0];
endfunction

function signed [15:0] clip_sum( input signed [15:0] a, input signed [WD-1:0] b );
    begin : clip_sum_func
        reg signed [16:0] full;
        full = { a[15],a } + { {17-WD{b[WD-1]}},b};
        clip_sum = full[16]==full[15] ? full[15:0] :
            full[16] ? 16'h8000 : 16'h7fff; // clip
    end
endfunction

always @* begin
    case( st )
         0: cfg_addr = 5'o16; // enable
         1: cfg_addr = 5'o20; // addr 7-0
         2: cfg_addr = 5'o14; // addr 15-8
         3: cfg_addr = 5'o15; // addr 23-16
         4: cfg_addr = 5'o07; // addr delta
         5: cfg_addr = 5'o04; // loop addr 15-8
         6: cfg_addr = 5'o05; // loop addr 23-16
         7: cfg_addr = 5'o06; // end addr
         8: cfg_addr = 5'o16; // enable (wr)
         9: cfg_addr = 5'o20; // addr  7- 0 (wr)
        10: cfg_addr = 5'o14; // addr 15- 8 (wr)
        11: cfg_addr = 5'o15; // addr 23-16 (wr)
        12: cfg_addr = 5'o02; // vol. left
        13: cfg_addr = 5'o03; // vol. right
        default: cfg_addr = 0;
    endcase

    vol_mux = st[0] ? vol_left : vol_right;
    case( st )
         8: begin cfg_we = 1;        cfg_din = cfg_en; end
         9: begin cfg_we = 1;        cfg_din = cur_addr[ 7: 0]; end
        10: begin cfg_we = !was_enb; cfg_din = cur_addr[15: 8]; end
        11: begin cfg_we = !was_enb; cfg_din = cur_addr[23:16]; end
        default: begin cfg_we = 0; cfg_din = 0; end
    endcase
end

always @(posedge clk) begin
    mul_data <= vol_mux * pcm_data;
end

// multiply by 2 and clip if needed
function signed [15:0] clip2x( input signed [15:0] s);
    clip2x = s[15]==s[14] ? {s[14:0],s[15]} : {s[15],{15{~s[15]}}};
endfunction

always @(posedge clk) begin
    st_dout <= debug_bus[0] ? active[15:8] : active[7:0];
end

always @(posedge clk) begin
    if( rst ) begin
        st        <= 0;
        cur_ch    <= 0;
        rom_cs    <= 0;
        rom_addr  <= 0;
        snd_left  <= 0;
        snd_right <= 0;
        acc_l     <= 0;
        acc_r     <= 0;
        cur_addr  <= 0;
        delta     <= 0;
        loop_addr <= 0;
        cfg_en    <= 0;
        vol_left  <= 0;
        vol_right <= 0;
        was_enb   <= 0;
    end else if(cen) begin
        st <= st + 1'd1;
        case( st )
            0: begin
                cfg_en  <= cfg_data;
                was_enb <= cfg_data[0];
                if( cur_ch==0 ) begin
                    snd_left  <= acc_l;
                    snd_right <= acc_r;
                    acc_l     <= 0;
                    acc_r     <= 0;
                end
            end
            1: cur_addr[ 7: 0]  <= was_enb ? 8'd0 : cfg_data;
            2: cur_addr[15: 8]  <= cfg_data;
            3: cur_addr[23:16]  <= cfg_data;
            4: delta            <= cfg_data;
            5: loop_addr[15: 8] <= cfg_data;
            6: loop_addr[23:16] <= cfg_data;
            7: if( cur_addr[23:16] > cfg_data ) begin
                if( cfg_en[1] ) begin
                    cfg_en[0]     <= 1; // no loop
                    cur_addr[7:0] <= 0;
                end else
                    cur_addr <= {loop_addr,8'd0}; // loop around
            end
            8: if( !cfg_en[0] ) begin
                rom_cs   <= 1;
                rom_addr <= { bank, cur_addr[23:8] };
                cur_addr <= cur_addr + { 16'd0, delta };
            end
            12: vol_left  <= {1'b0, cfg_data[6:0]};
            13: vol_right <= {1'b0, cfg_data[6:0]};
            14: begin
                rom_cs  <= 0; // ROM data must be good by now
                buf_r   <= clipDAC(mul_data);
            end
            15: begin
                active[cur_ch] <= ~was_enb;
                cur_ch <= cur_ch + 1'd1;
                if( !cfg_en[0] ) begin
                    acc_r <= clip_sum( acc_r, buf_r);
                    acc_l <= clip_sum( acc_l, clipDAC(mul_data));
                end
            end
        endcase
    end
end

endmodule