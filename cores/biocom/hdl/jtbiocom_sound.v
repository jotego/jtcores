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
    input           cen_fm,   // 14.31318/4   MHz ~ 3.5  MHz => 10/134 of 48MHz clock
    input           cen_fm2,  // 14.31318/4/8 MHz ~ 1.75 MHz =>  5/134 of 48MHz clock
    // Interface with main CPU
    input   [7:0]   snd_latch,
    input           nmi_n,
    // Interface with MCU
    input   [7:0]   snd_din,
    output  [7:0]   snd_dout,
    output          snd_mcu_wr,
    output          snd_mcu_rd,
    // ROM
    output  [14:0]  rom_addr,
    output  reg     rom_cs,
    input   [ 7:0]  rom_data,
    input           rom_ok,

    // Sound output
    output  signed [15:0] left,
    output  signed [15:0] right,
    output                sample
);

wire [15:0] A;
reg  fm_cs, latch_cs, ram_cs, mcu_cs;
wire mreq_n, rfsh_n, int_n;
wire WRn;

assign snd_mcu_wr = mcu_cs && !WRn;
assign snd_mcu_rd = mcu_cs &&  WRn;

always @(*) begin
    rom_cs   = 1'b0;
    ram_cs   = 1'b0;
    latch_cs = 1'b0;
    fm_cs    = 1'b0;
    mcu_cs   = 1'b0;
    if(!mreq_n) casez( A[15:13] )
        3'b0??: rom_cs   = 1'b1;
        3'b100: fm_cs    = 1'b1;
        3'b101: mcu_cs   = 1'b1;
        3'b110: ram_cs   = 1'b1;
        3'b111: latch_cs = 1'b1;
    endcase
end

wire rd_n;
wire wr_n;

wire RAM_we = ram_cs && !WRn;
wire [7:0] ram_dout, dout, fm_dout;

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
        latch_cs: din = snd_din; //snd_latch;
        ram_cs:   din = ram_dout;
        mcu_cs:   din = snd_din;
        default:  din = rom_data;
    endcase // {latch_cs,rom_cs,ram_cs}

reg reset_n=1'b0;

// local reset
reg [3:0] rst_cnt;

always @(negedge clk)
    if( rst ) begin
        rst_cnt <= 'd0;
        reset_n <= 1'b0;
    end else begin
        if( rst_cnt != ~4'b0 ) begin
            reset_n <= 1'b0;
            rst_cnt <= rst_cnt + 4'd1;
        end else reset_n <= 1'b1;
    end

wire wait_n = !(rom_cs && !rom_ok);

jtframe_z80 u_cpu(
    .rst_n      ( reset_n     ),
    .clk        ( clk         ),
    .cen        ( cen_fm      ),
    .wait_n     ( wait_n      ),
    .int_n      ( int_n       ),
    .nmi_n      ( nmi_n       ),
    .busrq_n    ( 1'b1        ),
    .m1_n       (             ),
    .mreq_n     ( mreq_n      ),
    .iorq_n     (             ),
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
    .rst        ( rst       ), // reset
    .clk        ( clk       ), // main clock
    .cen        ( cen_fm    ),
    .cen_p1     ( cen_fm2   ),
    .cs_n       ( !fm_cs    ), // chip select
    .wr_n       ( WRn       ), // write
    .a0         ( A[0]      ),
    .din        ( dout      ), // data in
    .dout       ( fm_dout   ), // data out
    .ct1        (           ),
    .ct2        (           ),
    .irq_n      ( int_n     ),  // I do not synchronize this signal
    // Low resolution output (same as real chip)
    .sample     ( sample    ), // marks new output sample
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