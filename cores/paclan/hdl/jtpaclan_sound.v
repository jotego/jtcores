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
    Date: 18-5-2025 */

module jtpaclan_sound(
    input               rst, clk,
                        cen_mcu, pxl_cen, cen_c30,
                        vs, lvbl, mcu_seln,

    input        [15:0] dipsw,
    input        [ 6:0] joystick1, joystick2,
    input        [15:0] joyana_r1,
    input        [ 1:0] cab_1p,
    input        [ 1:0] coin,
    input               service,

    input        [ 9:0] maddr,
    input        [ 7:0] mdout,
    output       [ 7:0] c30_dout,
    input               mc30_cs,
    input               mrnw,

    output       [11:0] embd_addr,
    input        [ 7:0] embd_data,
    output       [11:0] ram_addr,
    input        [ 7:0] ram_dout,
    output              ram_we,
    output       [ 7:0] ram_din,

    output reg          rom_cs,
    output       [12:0] rom_addr,
    input        [ 7:0] rom_data,
    input               rom_ok,
    output              bus_busy,

    output signed[12:0] cus30_l, cus30_r,
    input        [ 7:0] debug_bus
);
`ifndef NOMAIN // sound always needed if main is compiled
wire [15:0] A;
wire [ 7:0] mcu_dout, cab_other, fm_dout, p1_dout, cab_dout;
wire [ 4:0] p2_dout;
reg  [ 7:0] mcu_din;
reg         uc30_cs, cab_cs, ram_cs, irq_ctl, irq_ack;
wire        halted, vma, wr, irq;

assign bus_busy = rom_cs & ~rom_ok;
assign ram_addr = A[11:0];
assign ram_we   = ram_cs & wr;
assign ram_din  = mcu_dout;
assign rom_addr = A[12:0];

always @(posedge clk) if(irq_ctl) irq_ack <= A[13];
// Address decoder
always @(*) begin
    uc30_cs = vma && A[15:12]==1    && A[11:10]==0;          // 1000~13FF
    irq_ctl = vma && A[15:12]>=4'h4 && A[15:12]<=4'h7 && wr; // 4000~7FFF
    rom_cs  = vma && A[15:12]>=4'h8 && A[15:12]<=4'h9;       // 8000~9FFF
    ram_cs  = vma && A[15:12]==4'hc;                         // C000~C7FF
    cab_cs  = vma && A[15:12]==4'hd && !wr;                  // Dxxx
end

always @* begin
    mcu_din = rom_cs  ? rom_data :
              ram_cs  ? ram_dout :
              cab_cs  ? cab_dout :
              uc30_cs ? c30_dout :
              8'd0;
end

jtframe_edge u_irq(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .edgeof ( ~lvbl     ),
    .clr    ( irq_ack   ),
    .q      ( irq       )
);

jtpaclan_cab u_cab(
    .clk        ( clk           ),

    .addr       ( A[1:0]        ),

    .dipsw      ( dipsw         ),
    .joystick1  ( joystick1     ),
    .joystick2  ( joystick2     ),
    .cab_1p     ( cab_1p        ),
    .coin       ( coin          ),
    // pressing service resets the game. It does not seem to be used for credits
    .service    ( 1'b1          ),

    .cab_dout   ( cab_dout      ),
    .other      ( cab_other     )
);

/* verilator tracing_on */
jtframe_6801mcu #(.ROMW(12),.SLOW_FRC(2),.MODEL("HD63701V")) u_63701(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cen        ( cen_mcu       ),
    .cen_tmr    ( cen_mcu       ),

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
    .p1_din     ( cab_other     ),
    .p2_din     ( 5'h1f         ),
    .p3_din     ( 8'd0          ),
    .p4_din     ( 8'd0          ),

    .p1_dout    ( p1_dout       ),  // coin lock & counters
    .p2_dout    ( p2_dout       ),  // LEDs
    .p3_dout    (               ),
    .p4_dout    (               ),
    // ROM
    .rom_cs     (               ),
    .rom_addr   ( embd_addr     ),
    .rom_data   ( embd_data     )
);

jtcus30 u_wav(
    .rst        ( rst           ),  // original does not have a reset pin
    .clk        ( clk           ),
    .bsel       ( mcu_seln      ),
    .cen        ( cen_c30       ),

    .xdin       ( c30_dout      ),
    // main/sub bus
    .bcs        ( mc30_cs       ),
    .brnw       ( mrnw          ),
    .baddr      ( maddr         ),
    .bdout      ( mdout         ),

    // sound CPU
    .scs        ( uc30_cs       ),
    .srnw       ( ~wr           ),
    .saddr      ( A             ),
    .sdout      ( mcu_dout      ),

    // sound output
    .snd_l      ( cus30_l       ),
    .snd_r      ( cus30_r       ),
    .sample     (               ),
    .debug_bus  ( debug_bus     )
);
`else
    initial rom_cs=0;
    assign c30_dout=0, embd_addr=0, ram_addr=0,
    ram_we=0, ram_din=0, rom_addr=0, bus_busy=0, cus30_l=0, cus30_r=0;
`endif
endmodule