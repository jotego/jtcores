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
    Date: 27-10-2017 */

`timescale 1ns/1ps

module jtgng_sound(
    input   clk,    // 6   MHz
    input   rst,
    input   soft_rst,
    // Interface with main CPU
    input           sres_b, // Z80 reset
    input   [7:0]   snd_latch,
    input           V32,    
    // ROM access
    output  [14:0]  rom_addr,
    output          rom_cs,
    input   [ 7:0]  rom_dout,
    input           snd_wait_n,
    // Sound output
    output  signed [15:0] ym_snd
);

wire [15:0] A;
assign rom_addr = A[14:0];

reg reset_n;

always @(negedge clk)
    reset_n <= ~( rst | soft_rst /*| ~sres_b*/ );

reg clk_en, cen_z80;

always @(negedge clk)
    if( rst ) begin
        clk_en  <= 1'b1;
        cen_z80 <= 1'b1;
    end else begin
        clk_en  <= ~clk_en;
        cen_z80 <= snd_wait_n & ~clk_en;
    end

wire fm1_cs,fm0_cs, latch_cs, ram_cs;
reg [4:0] map_cs;

assign { rom_cs, fm1_cs, fm0_cs, latch_cs, ram_cs } = map_cs;

reg [7:0] AH;

always @(*)
    casez(A[15:11])
        5'b0???_?: map_cs = 5'h10; // 0000-7FFF, ROM
        5'b1100_0: map_cs = 5'h1; // C000-C7FF, RAM
        5'b1100_1: map_cs = 5'h2; // C800-C8FF, Sound latch
        5'b1110_0: 
            if( !A[1] ) map_cs = 5'h4; // E000-E0FF, Yamaha
                else    map_cs = 5'h8;
        default: map_cs = 5'h0;
    endcase


// RAM, 8kB
wire rd_n;
wire wr_n;

wire RAM_we = ram_cs && !wr_n;
wire [7:0] ram_dout, dout;

jtgng_chram RAM(    // 2 kB, just like CHARs
    .address    ( A[10:0]   ),
    .clock      ( clk       ),  // 6 MHz
    .data       ( dout      ),
    .wren       ( RAM_we    ),
    .q          ( ram_dout  )
);

reg [7:0] din;

always @(*)
    case( {latch_cs, rom_cs,ram_cs, fm1_cs,fm0_cs} )
        5'b1_00_00:  din = snd_latch;
        5'b0_10_00:  din = rom_dout;
        5'b0_01_00:  din = ram_dout;
        // 5'b0_00_10:  din = fm1_dout;
        // 5'b0_00_01:  din = fm0_dout;
        default: din = 8'd0;
    endcase // {latch_cs,rom_cs,ram_cs}

    reg int_n;
    wire m1_n;
    wire mreq_n;
    wire iorq_n;
    wire rfsh_n;
    wire halt_n;
    wire busak_n;

    wire wait_n = snd_wait_n;

reg lastV32;
reg [4:0] int_n2;

always @(posedge clk) begin
    lastV32 <= V32;
    if ( !V32 && lastV32 ) begin
        { int_n, int_n2 } <= 6'b0;
    end
    else begin
        if( ~&int_n2 ) 
            int_n2 <= int_n2+5'd1;
        else
            int_n <= 1'b1;
    end
end

tv80s Z80 (
    .reset_n(reset_n ),
    .clk    (clk     ), // 3 MHz, clock gated
    .cen    (cen_z80 ),
    .wait_n (1'b1    ),
    .int_n  (int_n   ),
    .nmi_n  (1'b1    ),
    .busrq_n(1'b1    ),
    .m1_n   (m1_n    ),
    .mreq_n (mreq_n  ),
    .iorq_n (iorq_n  ),
    .rd_n   (rd_n    ),
    .wr_n   (wr_n    ),
    .rfsh_n (rfsh_n  ),
    .halt_n (halt_n  ),
    .busak_n(busak_n ),
    .A      (A       ),
    .di     (din     ),
    .dout   (dout    )
);

wire [7:0] fm0_dout, fm1_dout;
wire signed [15:0] fm0_snd, fm1_snd;
assign ym_snd = fm0_snd + fm1_snd;

jt03 fm0(
    .rst    ( ~reset_n  ),
    // CPU interface
    .clk    ( clk       ),
    .cen    ( clk_en    ),
    .din    ( dout      ),
    .addr   ( A[0]      ),
    .cs_n   ( ~fm0_cs   ),
    .wr_n   ( wr_n      ),
    .dout   ( fm0_dout  ),
    //output            irq_n,
    // combined output
    .snd    ( fm0_snd   ),
    .irq_n()
);

jt03 fm1(
    .rst    ( ~reset_n  ),
    // CPU interface
    .clk    ( clk       ),
    .cen    ( clk_en    ),
    .din    ( dout      ),
    .addr   ( A[0]      ),
    .cs_n   ( ~fm1_cs   ),
    .wr_n   ( wr_n      ),
    .dout   ( fm1_dout  ),
    //output            irq_n,
    // combined output
    .snd    ( fm1_snd   ),
    .irq_n() 
);

endmodule // jtgng_sound