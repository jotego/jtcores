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
    input           cen3   /* synthesis direct_enable = 1 */,   //  3   MHz
    input           cen1p5, //  1.5 MHz
    input           rst,
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
    output reg [ 8:0]  snd
);

// posedge of snd_int
reg snd_int_last;
wire snd_int_edge = !snd_int_last && snd_int;
always @(posedge clk) if(cen3) begin
    snd_int_last <= snd_int;
end

// interrupt latch
reg int_n;
wire iorq_n;
always @(posedge clk) 
    if( rst ) int_n <= 1'b1;
    else if(cen3) begin
        if(!iorq_n) int_n <= 1'b1;
        else if( snd_int_edge ) int_n <= 1'b0;
    end

wire [15:0] A;
assign rom_addr = A[14:0];

reg reset_n=1'b0;

always @(posedge clk) if(cen3)
    reset_n <= ~( rst | ~sres_b );

reg rom_cs, ay1_cs, ay0_cs, latch_cs, ram_cs;

reg [7:0] AH;

always @(*) begin
    rom_cs   = 1'b0;
    ram_cs   = 1'b0;
    latch_cs = 1'b0;
    ay0_cs   = 1'b0;
    ay1_cs   = 1'b0;
    casez(A[15:13])
        3'b00?: rom_cs   = 1'b1;
        3'b010: ram_cs   = 1'b1;
        3'b011: latch_cs = 1'b1;
        3'b100: ay0_cs   = 1'b1;
        3'b110: ay1_cs   = 1'b1;
        default:;
    endcase
end

reg [1:0] cs_wait;
always @(posedge clk)
    if( rst )
        cs_wait <= 2'b11;
    else if(cen3) begin
        cs_wait <= { cs_wait[0], ~(ay0_cs|ay1_cs) };
    end // else if(cen3)

wire wait_n = ~cs_wait[1] | cs_wait[0];

reg [7:0] latch0, latch1;

always @(posedge clk) 
if( rst ) begin
    latch1 <= 8'd0;
    latch0 <= 8'd0;
end else if(cen3) begin
    if( main_latch1_cs ) latch1 <= main_dout;
    if( main_latch0_cs ) latch0 <= main_dout;
    `ifdef SIMULATION
        if( main_latch1_cs ) 
            $display("(%X) SND LATCH 1 = $%X", $time/1000, main_dout );
        if( main_latch0_cs ) 
            $display("(%X) SND LATCH 0 = $%X", $time/1000, main_dout );
    `endif
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
    case( 1'b1 )
        ay1_cs:   din = ay1_dout;
        ay0_cs:   din = ay0_dout;
        latch_cs: din = A[0] ? latch1 : latch0;
        rom_cs:   din = rom_data;
        ram_cs:   din = ram_dout;
        default:  din = 8'hff;
    endcase // {latch_cs,rom_cs,ram_cs}

// Select the Z80 core to use
`ifdef SIMULATION
`define Z80_ALT_CPU
`endif

// `ifdef NCVERILOG
// `undef Z80_ALT_CPU
// `endif

`ifdef VERILATOR_LINT 
`define Z80_ALT_CPU
`endif

`ifndef Z80_ALT_CPU
// This CPU is used for synthesis
T80s u_cpu(
    .RESET_n    ( reset_n     ),
    .CLK        ( clk         ),
    .CEN        ( cen3        ),
    .WAIT_n     ( wait_n      ),
    .INT_n      ( int_n       ),
    .RD_n       ( rd_n        ),
    .WR_n       ( wr_n        ),
    .A          ( A           ),
    .DI         ( din         ),
    .DO         ( dout        ),
    .IORQ_n     ( iorq_n      ),
    .NMI_n      ( 1'b1        ),
    .BUSRQ_n    ( 1'b1        ),
    .out0       ( 1'b0        )
);
`else
tv80s #(.Mode(0)) u_cpu (
    .reset_n(reset_n ),
    .clk    (clk     ), // 3 MHz, clock gated
    .cen    (cen3    ),
    .wait_n (wait_n  ),
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

wire [9:0] sound0, sound1;
wire [10:0] unlim_snd = {1'b0, sound0} + {1'b0, sound1};

// limit to 9 bits in order to get good volume
always @(posedge clk) if(cen1p5)
    snd <= unlim_snd[10:9]!=2'b0 ? 9'h1FF : unlim_snd[8:0];

wire bdir0 = ay0_cs & ~wr_n;
wire bc0   = ay0_cs & ~wr_n & ~A[0];
wire bdir1 = ay1_cs & ~wr_n;
wire bc1   = ay1_cs & ~wr_n & ~A[0];

jt49_bus u_ay0( // note that input ports are not multiplexed
    .rst_n  ( reset_n   ),
    .clk    ( clk       ),
    .clk_en ( cen1p5    ),
    .bdir   ( bdir0     ),
    .bc1    ( bc0       ),
    .din    ( dout      ),
    .sel    ( 1'b0      ),
    .dout   ( ay0_dout  ),
    .sound  ( sound0    ),
    .A(), .B(), .C() // unused outputs
);

jt49_bus u_ay1( // note that input ports are not multiplexed
    .rst_n  ( reset_n   ),
    .clk    ( clk       ),
    .clk_en ( cen1p5    ),
    .bdir   ( bdir1     ),
    .bc1    ( bc1       ),
    .din    ( dout      ),
    .sel    ( 1'b0      ),
    .dout   ( ay1_dout  ),
    .sound  ( sound1    ),
    .A(), .B(), .C() // unused outputs
);

endmodule // jtgng_sound