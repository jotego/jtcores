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
    Date: 20-1-2019 */

// 1942 Sound
// Schematics page 3/8


module jt1942_sound(
    input           rst,
    input           clk,    // 24   MHz
    input           cen3   /* synthesis direct_enable = 1 */,   //  3   MHz
    input           cen1p5, //  1.5 MHz
    input   [ 1:0]  game_id,
    // Higemaru: AY chips are controlled by the main CPU
    input           main_ay0_cs, main_ay1_cs,
    // Interface with main CPU
    input           sres_b,
    input   [ 7:0]  main_dout,
    input           main_wr_n,
    input           main_a0,
    input           main_latch0_cs,
    input           main_latch1_cs, // Vulgus PCB also has two latches. MAME ignores one of them.
    input           snd_int,
    // ROM access
    output  reg     rom_cs,
    output  [14:0]  rom_addr,
    input   [ 7:0]  rom_data,
    input           rom_ok,
    // Sound output
    output  [ 9:0]  psg0, psg1
);

`ifndef NOSOUND
`include "1942.vh"
wire mreq_n, rd_n, wr_n;
reg  ay1_cs, ay0_cs, latch_cs, ram_cs, hige;

reg [7:0] AH;

wire [7:0] ram_dout, cpu_dout, ay_din, ay0_dout, ay1_dout;
wire [9:0] sound0, sound1;

// posedge of snd_int
reg snd_int_last;
wire snd_int_edge = !snd_int_last && snd_int;
always @(posedge clk) if(cen3) begin
    snd_int_last <= snd_int;
end

// interrupt latch
reg int_n;
wire iorq_n;
always @(posedge clk, posedge rst) begin
    if( rst ) int_n <= 1'b1;
    else if(cen3) begin
        if(!iorq_n) int_n <= 1'b1;
        else if( snd_int_edge ) int_n <= 1'b0;
    end
end

wire [15:0] A;
assign rom_addr = A[14:0];
assign ay_din   = !hige ? cpu_dout : main_dout;

reg reset_n=0, ay_rstn=0;

always @(posedge clk) hige <= game_id == HIGEMARU;

always @(posedge clk) if(cen3) begin
    reset_n <= ~rst & sres_b;
    ay_rstn <= ~rst & (sres_b | hige); // AY always on when running Higemaru
end

always @(*) begin
    rom_cs   = 1'b0;
    ram_cs   = 1'b0;
    latch_cs = 1'b0;
    ay0_cs   = 1'b0;
    ay1_cs   = 1'b0;
    if( !mreq_n ) casez(A[15:13])
        3'b00?: rom_cs   = 1'b1;
        3'b010: ram_cs   = 1'b1;
        3'b011: latch_cs = 1'b1;
        3'b100: ay0_cs   = 1'b1;
        3'b110: ay1_cs   = 1'b1;
        default:;
    endcase
    if( hige ) begin
        ay0_cs = main_ay0_cs;
        ay1_cs = main_ay1_cs;
    end
end

reg [7:0] latch0, latch1;

always @(posedge clk)
if( rst ) begin
    latch1 <= 8'd0;
    latch0 <= 8'd0;
end else if(cen3) begin
    if( main_latch1_cs ) latch1 <= main_dout;
    if( main_latch0_cs ) latch0 <= main_dout;
end

reg [7:0] din;

always @(*) begin
    case( 1'b1 )
        ay1_cs:   din = ay1_dout;
        ay0_cs:   din = ay0_dout;
        latch_cs: din = A[0] ? latch1 : latch0;
        rom_cs:   din = rom_data;
        ram_cs:   din = ram_dout;
        default:  din = 8'hff;
    endcase
end

jtframe_sysz80 #(.RAM_AW(11)) u_cpu(
    .rst_n      ( reset_n     ),
    .clk        ( clk         ),
    .cen        ( cen3        ),
    .cpu_cen    (             ),
    .int_n      ( int_n       ),
    .nmi_n      ( 1'b1        ),
    .busrq_n    ( 1'b1        ),
    .m1_n       (             ),
    .mreq_n     ( mreq_n      ),
    .iorq_n     ( iorq_n      ),
    .rd_n       ( rd_n        ),
    .wr_n       ( wr_n        ),
    .rfsh_n     (             ),
    .halt_n     (             ),
    .busak_n    (             ),
    .A          ( A           ),
    .cpu_din    ( din         ),
    .cpu_dout   ( cpu_dout    ),
    .ram_dout   ( ram_dout    ),
    // ROM access
    .ram_cs     ( ram_cs      ),
    .rom_cs     ( rom_cs      ),
    .rom_ok     ( rom_ok      )
);

function [1:0] bcdir( input cs );
begin
    bcdir[0] = cs       & ~(hige ? main_wr_n : wr_n); // bdir pin
    bcdir[1] = bcdir[0] &  (hige ? main_a0   :~A[0]); // bc pin
end
endfunction

wire bdir0, bc0;

assign {bc0, bdir0} = bcdir(ay0_cs);

jt49_bus #(.COMP(3'b10)) u_ay0( // note that input ports are not multiplexed
    .rst_n  ( ay_rstn   ),
    .clk    ( clk       ),
    .clk_en ( cen1p5    ),
    .bdir   ( bdir0     ),
    .bc1    ( bc0       ),
    .din    ( ay_din    ),
    .sel    ( 1'b1      ),
    .dout   ( ay0_dout  ),
    .sound  ( psg0      ),
    .sample (           ),
    // unused
    .IOA_in ( 8'h0      ),
    .IOA_out(           ),
    .IOA_oe (           ),
    .IOB_in ( 8'h0      ),
    .IOB_out(           ),
    .IOB_oe (           ),
    .A(), .B(), .C() // unused outputs
);

wire bdir1, bc1;
assign {bc1, bdir1} = bcdir(ay1_cs);

jt49_bus #(.COMP(3'b10)) u_ay1( // note that input ports are not multiplexed
    .rst_n  ( ay_rstn   ),
    .clk    ( clk       ),
    .clk_en ( cen1p5    ),
    .bdir   ( bdir1     ),
    .bc1    ( bc1       ),
    .din    ( ay_din    ),
    .sel    ( 1'b1      ),
    .dout   ( ay1_dout  ),
    .sound  ( psg1      ),
    // unused
    .IOA_in ( 8'h0      ),
    .IOA_out(           ),
    .IOA_oe (           ),
    .IOB_in ( 8'h0      ),
    .IOB_out(           ),
    .IOB_oe (           ),
    .sample (           ),
    .A(), .B(), .C()
);
`else
    initial rom_cs   = 0;
    assign  rom_addr = 0;
    assign  psg0     = 0;
    assign  psg1     = 0;
`endif
endmodule