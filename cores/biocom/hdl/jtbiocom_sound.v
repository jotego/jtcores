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
    output reg [14:0]  rom_addr,
    output  reg     rom_cs,
    input   [ 7:0]  rom_data,
    input           rom_ok,

    // Sound output
    output  signed [15:0] fm_l,
    output  signed [15:0] fm_r
);

parameter LAYOUT  = 3, // 9 for SF
          RECOVERY= 0;
`ifndef NOSOUND

wire [15:0] A;
reg         fm_cs, latch_cs, ram_cs, mcu_cs;
wire        mreq_n, rfsh_n, int_n, iorq_n, m1_n, nmiff_n;
wire        WRn, rd_n, wr_n, fm_csn, RAM_we;
wire [ 7:0] ram_dout, dout, fm_dout;
reg  [ 7:0] din;
reg         rom2_ok;

assign fm_csn     = ~fm_cs;
assign RAM_we     = ram_cs && !WRn;
assign snd_mcu_wr = mcu_cs && !WRn;
assign snd_mcu_rd = mcu_cs &&  WRn;

always @(posedge clk) begin
    rom_cs   <= 1'b0;
    ram_cs   <= 1'b0;
    latch_cs <= 1'b0;
    fm_cs    <= 1'b0;
    mcu_cs   <= 1'b0;
    rom2_ok  <= rom_ok;
    if(!mreq_n) begin
        if( LAYOUT==9 ) begin // Stret Fighter
             casez( A[15:13] )
                3'b0??: begin
                    rom_cs <= 1;
                    rom_addr <= A[14:0];
                end
                3'b110: begin
                    ram_cs   <= !A[11];
                    latch_cs <=  A[11];
                end
                3'b111: fm_cs <= 1;
                default:;
            endcase
        end else begin // Bionic Commando
             casez( A[15:13] )
                3'b0??: begin
                    rom_cs   <= 1'b1;
                    rom_addr <= A[14:0];
                end
                3'b100: fm_cs    <= 1'b1;
                3'b101: mcu_cs   <= 1'b1;
                3'b110: ram_cs   <= 1'b1;
                3'b111: latch_cs <= 1'b1;
            endcase
        end
    end
end

assign WRn      = wr_n | mreq_n;
assign snd_dout = dout;

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        din <= 8'hff;
    end else begin
        din <= rom_cs   ? rom_data : (
               fm_cs    ? fm_dout   : (
               latch_cs ? (LAYOUT==9 ? snd_latch : snd_din) : (
               mcu_cs   ? snd_din   : (
               ram_cs   ? ram_dout  :
               8'hff ))));
    end
end

jtframe_ram #(.AW(11)) u_ram(
    .clk    ( clk      ),
    .cen    ( 1'b1     ),
    .data   ( dout     ),
    .addr   ( A[10:0]  ),
    .we     ( RAM_we   ),
    .q      ( ram_dout )
);


jtframe_z80_romwait #(.RECOVERY(RECOVERY)) u_cpu(
    .rst_n      ( ~rst        ),
    .clk        ( clk         ),
    .cen        ( cen_fm      ),
    .int_n      ( int_n       ),
    .nmi_n      ( nmi_n       ),
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
    .dout       ( dout        ),
    // manage access to ROM data from SDRAM
    .rom_cs     ( rom_cs      ),
    .rom_ok     ( rom2_ok     ),
    // unused
    .cpu_cen    (             )
);

jt51 u_jt51(
    .rst        ( rst       ), // reset
    .clk        ( clk       ), // main clock
    .cen        ( cen_fm    ),
    .cen_p1     ( cen_fm2   ),
    .cs_n       ( fm_csn    ), // chip select
    .wr_n       ( WRn       ), // write
    .a0         ( A[0]      ),
    .din        ( dout      ), // data in
    .dout       ( fm_dout   ), // data out
    .ct1        (           ),
    .ct2        (           ),
    .irq_n      ( int_n     ),
    // Low resolution output (same as real chip)
    .sample     (           ),
    .left       (           ),
    .right      (           ),
    // Full resolution output
    .xleft      ( fm_l      ),
    .xright     ( fm_r      )
);

`else // NOSOUND
    assign snd_dout   = 0;
    assign snd_mcu_wr = 0;
    assign snd_mcu_rd = 0;
    assign fm_l       = 0;
    assign fm_r       = 0;
    assign sample     = 0;
    initial begin
        rom_addr = 0;
        rom_cs = 0;
    end
`endif

endmodule