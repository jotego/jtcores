/*  This file is part of JT_GNG.
    JT_GNG program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JT_GNG program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JT_GNG.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 20-1-2019 */

// 1942 Sound
// Schematics page 3/8

module jt1942_sound(
    input           clk,    // 24   MHz
    input           cen6   /* synthesis direct_enable = 1 */,   //  6   MHz
    input           cen3   /* synthesis direct_enable = 1 */,   //  3   MHz
    input           cen1p5 /* synthesis direct_enable = 1 */, //  1.5 MHz
    input           rst,
    input           soft_rst,    
    // Interface with main CPU
    input           sres_b,
    input   [ 7:0]  main_dout,
    input           main_latch0_cs,
    input           main_latch1_cs,
    input           snd_int,
    // ROM access
    output  [14:0]  rom_addr,
    input   [ 7:0]  rom_data,
    // Sound output
    output reg [ 8:0]  snd,
    output  sample
);

// posedge of snd_int
reg snd_int_last;
wire snd_int_edge = !snd_int_last && snd_int;
always @(posedge clk) if(cen6) begin
    snd_int_last <= snd_int;
end

// interrupt latch
reg int_n;
wire iorq_n;
always @(posedge clk) if(cen3) begin
    int_n <= !iorq_n ? 1'b0 : ~snd_int_edge;
end

wire [15:0] A;
assign rom_addr = A[14:0];

reg reset_n=1'b0;

always @(posedge clk) if(cen3)
    reset_n <= ~( rst | soft_rst | ~sres_b );

wire rom_cs, ay1_cs, ay0_cs, latch_cs, ram_cs;
reg [4:0] map_cs;

assign { rom_cs, ay1_cs, ay0_cs, latch_cs, ram_cs } = map_cs;

reg [7:0] AH;

always @(*)
    casez(A[15:13])
        3'b000: map_cs = 5'h10; // ROM
        3'b010: map_cs = 5'h1;  // RAM
        3'b011: map_cs = 5'h2;  // Sound latch
        3'b100: map_cs = 5'h4;  // AY0
        3'b110: map_cs = 5'h8;  // AY1
        default: map_cs = 5'h0;
    endcase

reg [7:0] latch0, latch1;

always @(posedge clk) if(cen6) begin
    if( main_latch1_cs ) latch1 <= main_dout;
    if( main_latch0_cs ) latch0 <= main_dout;
end

wire rd_n;
wire wr_n;

wire RAM_we = ram_cs && !wr_n;
wire [7:0] ram_dout, dout;

jtgng_ram #(.aw(11)) u_ram(
    .clk    ( clk      ),
    .cen    ( 1'b1     ),
    .data   ( dout     ),
    .addr   ( A[10:0]  ),
    .we     ( RAM_we   ),
    .q      ( ram_dout )
);

reg [7:0] din;
wire [7:0] ay1_dout, ay0_dout;

always @(*)
    case( {ay1_cs, ay0_cs, latch_cs, rom_cs,ram_cs } )
        5'b1_00_00:  din = ay1_dout;
        5'b0_10_00:  din = ay0_dout;
        5'b0_01_00:  din = A[0] ? latch1 : latch0;
        5'b0_00_10:  din = rom_data;
        5'b0_00_01:  din = ram_dout;
        default:  din = 8'd0;
    endcase // {latch_cs,rom_cs,ram_cs}


`define Z80_ALT_CPU
`ifndef SIMULATION
`ifndef VERILATOR_LINT 
`undef Z80_ALT_CPU
T80pa u_cpu(
    .RESET_n    ( reset_n ),
    .CLK        ( clk     ),
    .CEN_p      ( cen3    ),
    .CEN_n      ( 1'b1    ),
    .WAIT_n     ( 1'b1    ),
    .INT_n      ( int_n   ),
    .NMI_n      ( 1'b1    ),
    .BUSRQ_n    ( 1'b1    ),
    .RD_n       ( rd_n    ),
    .WR_n       ( wr_n    ),
    .A          ( A       ),
    .DI         ( din     ),
    .DO         ( dout    ),
    .IORQ_n     ( iorq_n  ),
    // unused
    .REG        (),
    .RFSH_n     (),
    .M1_n       (),
    .BUSAK_n    (),
    .HALT_n     (),
    .MREQ_n     (),
    .MC         (),
    .TS         (),
    .IntCycle_n (),
    .IntE       (),
    .Stop       (),
    .REG        ()
);
`endif
`endif

`ifdef Z80_ALT_CPU
tv80s #(.Mode(0)) u_cpu (
    .reset_n(reset_n ),
    .clk    (clk     ), // 3 MHz, clock gated
    .cen    (cen3    ),
    .wait_n (1'b1    ),
    .int_n  (int_n   ),
    .nmi_n  (1'b1    ),
    .busrq_n(1'b1    ),
    .rd_n   (rd_n    ),
    .wr_n   (wr_n    ),
    .A      (A       ),
    .di     (din     ),
    .dout   (dout    ),
    .iorq_n ( iorq_n ),
    // unused
    .mreq_n (),
    .m1_n   (),
    .busak_n(),
    .halt_n (),
    .rfsh_n ()
);
`endif

wire [7:0] ay0_a, ay0_b, ay0_c;
wire [7:0] ay1_a, ay1_b, ay1_c;
wire [10:0] unlim_snd = 
    {3'b0, ay0_a} +
    {3'b0, ay0_b} +
    {3'b0, ay0_c} +
    {3'b0, ay1_a} +
    {3'b0, ay1_b} +
    {3'b0, ay1_c};

// limit to 9 bits in order to get good volume
always @(posedge clk) if(cen1p5)
    snd <= unlim_snd[10:9]!=2'b0 ? 9'h1FF : unlim_snd[8:0];

wire bdir0 = ay0_cs && !wr_n;
wire bc0   = ay0_cs && !wr_n && !A[0];
wire bdir1 = ay1_cs && !wr_n;
wire bc1   = ay1_cs && !wr_n && !A[0];

ym2149 u_ay0(
    .CLK        ( clk       ),  // Global clock
    .CE         ( cen1p5    ),  // PSG Clock enable
    .RESET      ( rst       ),  // Chip RESET (set all Registers to '0', active hi)
    .BDIR       ( bdir0     ),  // Bus Direction (0 - read , 1 - write)
    .BC         ( bc0       ),  // Bus control
    .DI         ( dout      ),  // Data In
    .DO         ( ay0_dout  ),  // Data Out
    .CHANNEL_A  ( ay0_a     ),  // PSG Output channel A
    .CHANNEL_B  ( ay0_b     ),  // PSG Output channel B
    .CHANNEL_C  ( ay0_c     ),  // PSG Output channel C
    // AY mode:
    .SEL        ( 1'b1      ),
    .MODE       ( 1'b1      ),
    // unused 
    .IOA_in     ( 8'd0      ),
    .IOB_in     ( 8'd0      ),
    .ACTIVE     (           ),
    .IOA_out    (           ),
    .IOB_out    (           )
);

ym2149 u_ay1(
    .CLK        ( clk       ),  // Global clock
    .CE         ( cen1p5    ),  // PSG Clock enable
    .RESET      ( rst       ),  // Chip RESET (set all Registers to '0', active hi)
    .BDIR       ( bdir1     ),  // Bus Direction (0 - read , 1 - write)
    .BC         ( bc1       ),  // Bus control
    .DI         ( dout      ),  // Data In
    .DO         ( ay1_dout  ),  // Data Out
    .CHANNEL_A  ( ay1_a     ),  // PSG Output channel A
    .CHANNEL_B  ( ay1_b     ),  // PSG Output channel B
    .CHANNEL_C  ( ay1_c     ),  // PSG Output channel C
    // AY mode:
    .SEL        ( 1'b1      ),
    .MODE       ( 1'b1      ),
    // unused 
    .IOA_in     ( 8'd0      ),
    .IOB_in     ( 8'd0      ),
    .ACTIVE     (           ),
    .IOA_out    (           ),
    .IOB_out    (           )
);


endmodule // jtgng_sound