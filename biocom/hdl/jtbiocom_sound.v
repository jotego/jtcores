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

// This module is equivalent to the function
// of CAPCOM's 85H001 package found in GunSmoke, GnG, etc.

module jtbiocom_sound(
    input           rst,
    input           clk,    
    input           cenfm,  // 14.31318/4 MHz
    // Interface with main CPU
    input           sres_b, // Z80 reset
    input   [7:0]   snd_latch,
    input           snd_int,
    // Interface with MCU
    input   [7:0]   snd_din,
    output  [7:0]   snd_dout,
    output          RDn,
    output          WRn,
    // ROM
    output  [14:0]  rom_addr,
    output  reg     rom_cs,
    input   [ 7:0]  rom_data,
    input           rom_ok,

    // Sound output
    output  signed [15:0] left,
    output  signed [15:0] right,
    output  sample
);

wire [15:0] A;
reg fm_cs, latch_cs, ram_cs, mcu_cs;
wire mreq_n, rfsh_n, int_n;

always @(*) begin
    rom_cs   = 1'b0;
    ram_cs   = 1'b0;
    latch_cs = 1'b0;
    fm_cs    = 1'b0;
    mcu_cs   = 1'b0;
    casez( A[15:13] )
        3'b1??: rom_cs   = 1'b1;
        3'b000: fm_cs    = 1'b1;
        3'b001: mcu_cs   = 1'b1;
        3'b010: ram_cs   = 1'b1;
        3'b011: latch_cs = 1'b1;
    endcase
end

wire rd_n;
wire wr_n;

wire RAM_we = ram_cs && !WRn;
wire [7:0] ram_dout, dout, fm_dout;

assign RDn = rd_n | mreq_n;
assign WRn = wr_n | mreq_n;
assign snd_dout = dout;
assign rom_addr = A[14:0];


jtgng_ram #(.aw(11)) u_ram(
    .clk    ( clk      ),
    .cen    ( 1'b1     ),
    .data   ( dout     ),
    .addr   ( A[10:0]  ),
    .we     ( RAM_we   ),
    .q      ( ram_dout )
);

reg [7:0] din;

always @(*)
    case( 1'b1 )
        fm_cs:    din = fm_dout;
        latch_cs: din = snd_latch;
        ram_cs:   din = ram_dout;
        mcu_cs:   din = snd_din;
        default:  din = rom_data;
    endcase // {latch_cs,rom_cs,ram_cs}

reg reset_n=1'b0;

// local reset
reg [3:0] rst_cnt;

always @(negedge clk)
    if( rst | ~sres_b ) begin
        rst_cnt <= 'd0;
        reset_n <= 1'b0;
    end else begin
        if( rst_cnt != ~4'b0 ) begin
            reset_n <= 1'b0;
            rst_cnt <= rst_cnt + 4'd1;
        end else reset_n <= 1'b1;
    end

jtframe_z80 u_cpu(
    .rst_n      ( reset_n     ),
    .clk        ( clk         ),
    .cen        ( cenfm       ),
    .wait_n     ( 1'b1        ),
    .int_n      ( int_n       ),
    .nmi_n      ( 1'b1        ),
    .busrq_n    ( 1'b1        ),
    .m1_n       ( m1_n        ),
    .mreq_n     ( mreq_n      ),
    .iorq_n     ( iorq_n      ),
    .rd_n       ( rd_n        ),
    .wr_n       ( wr_n        ),
    .rfsh_n     ( rfsh_n      ),
    .halt_n     (             ),
    .busak_n    (             ),
    .A          ( A           ),
    .din        ( din         ),
    .dout       ( dout        )
);

jt51 u_jt51(
    .clk        ( clk       ), // main clock
    .cen        ( cenfm     ),
    .rst        ( rst       ), // reset
    .cs_n       ( !fm_cs    ), // chip select
    .wr_n       ( WRn       ), // write
    .a0         ( A[0]      ),
    .d_in       ( dout      ), // data in
    .d_out      ( fm_dout   ), // data out
    .ct1        (           ),
    .ct2        (           ),
    .irq_n      ( int_n     ),  // I do not synchronize this signal
    .p1         (           ),
    // Low resolution output (same as real chip)
    .sample     (           ), // marks new output sample
    .left       (           ),
    .right      (           ),
    // Full resolution output
    .xleft      ( left      ),
    .xright     ( right     ),
    // unsigned outputs for sigma delta converters, full resolution
    .dacleft    (           ),
    .dacright   (           )
);

endmodule // jtgng_sound