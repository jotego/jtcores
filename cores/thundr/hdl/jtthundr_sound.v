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

module jtthundr_sound(
    input               rst, clk,
                        cen_fm, cen_fm2, cen_mcu, cen_pcm, pxl_cen, cen_c30,
                        vs, lvbl, mcu_seln,
                        hopmappy, genpeitd, roishtar, wndrmomo, metrocrs,

    input        [19:0] dipsw,
    input        [ 6:0] joystick1, joystick2,
    input        [15:0] joyana_r1,
    input        [ 1:0] cab_1p,
    input        [ 1:0] coin,
    input               service,

    // Sub 6809 also connects to CUS30
    input        [ 9:0] maddr,
    input        [ 7:0] mdout,
    output       [ 7:0] c30_dout,
    input               mc30_cs,
    input               mrnw,
    input               pcm_wr,
    input        [ 1:0] pcm_waddr,

    output       [11:0] embd_addr,
    input        [ 7:0] embd_data,
    output       [11:0] ram_addr,
    input        [ 7:0] ram_dout,
    output              ram_we,
    output       [ 7:0] ram_din,

    output reg          rom_cs,
    output       [14:0] rom_addr,
    input        [ 7:0] rom_data,
    input               rom_ok,
    output              bus_busy,

    // PCM
    output       [18:0] pcm0_addr,
    input        [ 7:0] pcm0_data,
    output              pcm0_cs,
    input               pcm0_ok,

    output       [18:0] pcm1_addr,
    input        [ 7:0] pcm1_data,
    output              pcm1_cs,
    input               pcm1_ok,


    output signed[15:0] fm_l, fm_r,
    output       [11:0] pcm0, pcm1,
    output signed[12:0] cus30_l, cus30_r,
    input        [ 7:0] debug_bus
);
`ifndef NOMAIN // sound always needed if main is compiled
wire [15:0] A;
wire [ 7:0] mcu_dout, cab_other, fm_dout, p1_dout, cab_dout;
wire [ 4:0] p2_dout;
reg  [ 7:0] mcu_din;
wire [ 7:0] thcab, mxcab;
reg  [ 7:0] cab;
reg         uc30_cs, fm_cs, dec7d, porta, portb, cab_cs, ram_cs, irq_aux;
wire        halted, vma, wr, irq, irq_ack;

assign bus_busy = rom_cs & ~rom_ok;
assign ram_addr = A[11:0];
assign ram_we   = ram_cs & wr;
assign ram_din  = mcu_dout;
assign rom_addr = {A[15] & ~hopmappy,A[13:0]};
assign irq_ack  = A==16'hFFF8;

// Address decoder
always @(*) begin
    uc30_cs = vma && A[15:12]==1 && A[11:10]==0;        // 1000~13FF
    ram_cs  = vma && A[15:12]==1 && A[11:10]!=0;        // 1400~1FFF -> 3kB
    if(hopmappy) begin // hopmappy & skykiddx
        dec7d   = vma && A[15: 8]==8'h20;               // 2000~2FFF
        rom_cs  = vma && A[15:12]>=8 && A[15:12]<=4'hb; // 8000~BFFF
        irq_aux = vma && A[15:12]==4'h8 && wr;          // 8000~BFFF
    end else if(roishtar) begin
        dec7d   = vma && A[15: 8]==8'h60;               // 6000~6FFF
        rom_cs  = vma && A[15:12]>=2 && A[15:12]<=4'h3||// 2000~3FFF
                  vma && A[15:12]>=8 && A[15:12]<=4'hb; // 8000~BFFF
        irq_aux = vma && A[15:12]==4'h9 && wr;          // 9000~9FFF
    end else if(genpeitd) begin
        dec7d   = vma && A[15: 8]==8'h28;               // 2800~2FFF
        rom_cs  = vma && A[15:12]>=4 && A[15:12]<=4'hb; // 4000~BFFF
        irq_aux = vma && A[15:12]==4'ha && wr;          // 9000~9FFF
    end else if(wndrmomo) begin
        dec7d   = vma && A[15: 8]==8'h38;               // 3800~38FF
        rom_cs  = vma && A[15:12]>=4 && A[15:12]<=4'hb; // 4000~BFFF
        irq_aux = vma && A[15:12]==4'hc && wr;          // C000~CFFF
    end else if (metrocrs) begin // metrocross/baraduke
        rom_cs  = vma && A[15:12]>=8    && A[15:12]<=4'hb; // 8000~BFFF
        ram_cs  = vma && A[15:12]==4'hc && !A[11];         // C000~C7FF -> 2kB
        dec7d   = 0;
        irq_aux = 0;
    end else begin // rthunder
        dec7d   = vma && A[15: 8]==8'h20;               // 2000~2FFF
        rom_cs  = vma && A[15:12]>=4 && A[15:12]<=4'hb; // 4000~BFFF
        irq_aux = vma && A[15:12]==4'hb && wr;          // B000~BFFF
    end
    fm_cs   = dec7d && A[5:4]==0;
    porta   = dec7d && A[5:4]==2 && ~wr;
    portb   = dec7d && A[5:4]==3 && ~wr;
    cab_cs  = porta | portb;
end

always @* begin
    mcu_din = rom_cs  ? rom_data :
              ram_cs  ? ram_dout :
              cab_cs  ? cab_dout :
              fm_cs   ? fm_dout  :
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

wire [6:0] joymerge1, joymerge2;

jtthundr_roishtar_joy2 u_joy2(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .vs         ( vs            ),
    .roishtar   ( roishtar      ),
    .joyana_r1  ( joyana_r1     ),
    .joystick1  ( joystick1     ),
    .joystick2  ( joystick2     ),
    .merged1    ( joymerge1     ),
    .merged2    ( joymerge2     )
);

jtthundr_cab u_thcab(
    .clk        ( clk           ),

    .a0         ( A[0]          ),
    .porta      ( porta         ),
    .portb      ( portb         ),

    .dipsw      ( dipsw[15:0]   ),
    .joystick1  ( joymerge1     ),
    .joystick2  ( joymerge2     ),
    .cab_1p     ( cab_1p        ),
    .coin       ( coin          ),
    .service    ( service       ),

    .cab_dout   ( cab_dout      ),
    .other      ( thcab         )
);

jtmetrox_cab u_mxcab(
    .clk        ( clk           ),

    .p1_dout    ( p1_dout       ),
    .dipsw      ( dipsw         ),
    .joystick1  ( joystick1     ),
    .joystick2  ( joystick2     ),
    .cab_1p     ( cab_1p        ),
    .coin       ( coin          ),
    .service    ( service       ),

    .cab        ( mxcab         )
);

always @(posedge clk) begin
    cab <= metrocrs ? mxcab : thcab;
end

jtthundr_pcm u_pcm(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cen        ( cen_pcm   ),
    .wr         ( pcm_wr    ),
    .addr       ( pcm_waddr ),
    .din        ( mdout     ),

    .rom0_addr  ( pcm0_addr ),
    .rom0_data  ( pcm0_data ),
    .rom0_cs    ( pcm0_cs   ),
    .rom0_ok    ( pcm0_ok   ),

    .rom1_addr  ( pcm1_addr ),
    .rom1_data  ( pcm1_data ),
    .rom1_cs    ( pcm1_cs   ),
    .rom1_ok    ( pcm1_ok   ),

    .pcm0       ( pcm0      ),
    .pcm1       ( pcm1      )
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
    .p1_din     ( cab           ),
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

jt51 u_jt51(
    .rst        ( rst       ), // reset
    .clk        ( clk       ), // main clock
    .cen        ( cen_fm    ),
    .cen_p1     ( cen_fm2   ),
    .cs_n       ( ~fm_cs    ), // chip select
    .wr_n       ( ~wr       ), // write
    .a0         ( A[0]      ),
    .din        ( mcu_dout  ), // data in
    .dout       ( fm_dout   ), // data out
    .ct1        (           ),
    .ct2        (           ),
    .irq_n      (           ),
    // Low resolution output (same as real chip)
    .sample     (           ),
    .left       (           ),
    .right      (           ),
    // Full resolution output
    .xleft      ( fm_l      ),
    .xright     ( fm_r      )
);
`else
assign c30_dout = 0, embd_addr = 0, ram_addr = 0, ram_we = 0,
    ram_din = 0, rom_cs = 0, rom_addr = 0, bus_busy = 0,
    fm_l = 0, fm_r = 0, cus30_l = 0, cus30_r = 0,
    pcm0_addr = 0, pcm1_addr = 0, pcm0_cs=0, pcm1_cs=0, pcm0=0, pcm1=0;
`endif
endmodule