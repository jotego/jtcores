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
    input        [ 6:0] joystick1, joystick2,

    output       [11:0] embd_addr,
    input        [ 7:0] embd_data,
    output       [11:0] ram_addr,
    input        [ 7:0] ram_data,

    output reg          rom_cs,
    output       [14:0] rom_addr,
    input        [ 7:0] rom_data,
    input               rom_ok,
    output              bus_busy,
);

wire [ 7:0] mcu_dout;
reg  [ 7:0] mcu_din, cab_dout;
reg         bc30_cs, fm_cs, cab_cs, dip_cs;

assign bus_busy = rom_cs & ~rom_ok;
assign ram_addr = A[11:0];

// Address decoder
always @(*) begin
    bc30_cs = vma && A[15:12]==1 && A[11:10]==0;    // 1000~13FF
    ram_cs  = vma && A[15:12]==1 && A[11:10]!=0;    // 1400~1FFF -> 4kB
    fm_cs   = vma && A[15:12]==2 && A[ 7: 4]==0;    // 2000~200F
    cab_cs  = vma && A[15:12]==2 && A[ 7: 4]==2;    // 2020~202F
    dip_cs  = vma && A[15:12]==2 && A[ 7: 4]==3;    // 2030~203F
    rom_cs  = vma && A[15:12]>=4 && A[15:12]<=4'hb; // 4000~BFFF
end

always @* begin
    mcu_din = rom_cs  ? rom_data :
              ram_cs  ? ram_dout :
              cab_cs  ? cab_dout :
              dip_cs  ? dip_mux  :
              8'd0;
end

always @(posedge clk) begin
    case
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
    .rom_addr   ( embd_addr     ),
    .rom_data   ( embd_data     )
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