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
    Date: 15-3-2025 */

module jtrthunder_sound(
    input               rst,
    input               clk, cen_fm, cen_fm2,
    input        [15:0] dipsw,

    // PROM programming
    input      [11:0]  prog_addr,
    input      [ 7:0]  prog_data,
    input              prog_we,

    output reg          rom_cs,
    output       [14:0] rom_addr,
    input        [ 7:0] rom_data,
    input               rom_ok,
    output              bus_busy,
);

wire [11:0] internal_addr;
wire [ 7:0] internal_data, mcu_dout;
reg  [ 7:0] mcu_din;

assign bus_busy = rom_cs & ~rom_ok;

// Address decoder
always @(*) begin
    pcm_cs  = vma && ^A[15:14];                    // 4000~bfff
    swio_cs = vma &&  A[15:12]==4'h1;
    // the init_done mechanism mimics MAME's hack to prevent a lock up during the boot sequence
    // see https://github.com/jotego/jtcores/issues/410
    ram_cs  = vma &&  A[15:12]==4'hc && !A[11] /*&& (A[10:0]!=0 || rnw || !init_done)*/;    // c000~c7ff
    epr_cs  = vma &&  A[15:12]==4'hc &&  A[11];    // c800~cfff
    reg_cs  = vma &&  A[15:12]==4'hd && wr;
    dip_cs  = vma && swio_cs && A[11:10]==0;
    cab_cs  = vma && swio_cs && A[11:10]==1;
end

always @* begin
    mcu_din =   pcm_cs  ? pcm_data   :
                ram_cs  ? ram_dout   :
                epr_cs  ? eerom_dout :
                cab_cs  ? cab_dout   :
                dip_cs  ? { 4'hf, dipmx[0], dipmx[1], dipmx[2], dipmx[3] } :
                8'd0;
end

/* verilator tracing_on */
jtframe_6801mcu #(.ROMW(12),.SLOW_FRC(2),.MODEL("HD63701V")) u_63701(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cen        ( cen           ),

    // Bus
    .wr         ( wr            ),
    .x_cs       ( vma           ),
    .addr       ( A             ),
    .xdin       ( mcu_din       ),
    .dout       ( mcu_dout      ),
    .ba         ( halted        ),

    // interrupts
    .irq        ( irq           ),
    .nmi        ( 1'b0          ),
    // ports
    .p1_din     ( p1_din        ),
    .p2_din     ( 5'd0          ),
    .p3_din     ( 8'd0          ),
    .p4_din     ( 8'd0          ),

    .p1_dout    (               ),  // coin lock & counters
    .p2_dout    ( p2_dout       ),
    .p3_dout    (               ),
    .p4_dout    (               ),
    // ROM
    .rom_cs     (               ),
    .rom_addr   ( internal_addr ),
    .rom_data   ( rom_data      )
);

jtframe_prom #(.AW(12)) u_prom(
    .clk    ( clk           ),
    .cen    ( 1'b1          ),
    .data   ( prog_data     ),
    .we     ( prog_we       ),
    .wr_addr( prog_addr     ),
    .rd_addr( internal_addr ),
    .q      ( internal_data )
);

jtcus30 u_wav(
    .rst    ( rst       ),  // original does not have a reset pin
    .clk    ( clk       ),
    .bsel   ( bsel      ),
    .cen    ( cen_E     ),

    .xdin   ( c30_dout  ),
    // main/sub bus
    .bcs    ( bc30_cs   ),
    .brnw   ( brnw      ),
    .baddr  ( baddr     ),
    .bdout  ( bdout     ),

    // sound CPU
    .scs    ( cus30_cs  ),
    .srnw   ( rnw       ),
    .saddr  ( A         ),
    .sdout  ( cpu_dout  ),

    // sound output
    .snd_l  ( cus30_l   ),
    .snd_r  ( cus30_r   ),
    .sample (           ),
    .debug_bus(debug_bus)
);

jt51 u_jt51(
    .rst        ( ~srst_n   ), // reset
    .clk        ( clk       ), // main clock
    .cen        ( cen_fm    ),
    .cen_p1     ( cen_fm2   ),
    .cs_n       ( ~fm_cs    ), // chip select
    .wr_n       ( rnw       ), // write
    .a0         ( A[0]      ),
    .din        ( cpu_dout  ), // data in
    .dout       ( fm_dout   ), // data out
    .ct1        (           ),
    .ct2        (           ),
    .irq_n      ( firq_n    ),
    // Low resolution output (same as real chip)
    .sample     (           ),
    .left       (           ),
    .right      (           ),
    // Full resolution output
    .xleft      ( fm_l      ),
    .xright     ( fm_r      )
);

endmodule