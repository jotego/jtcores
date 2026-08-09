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

    Author: Andrea Bogazzi <andreabogazzi79@gmail.com>
    Version: 1.0
    Date: 9-8-2026 */

// Tricky Doc main board. Single Z80 at 5MHz (20MHz/4) with everything
// memory mapped, including the YM3812 and the LS259 addressable latch.
//
//  0000-dfff   ROM
//  e000-e7ff   work RAM (battery backed)
//  e800-ebff   sprite RAM (mirrored up to efff)
//  f000-f3ff   tile code
//  f400-f7ff   tile attributes
//  f800-f83f   I/O, decoded on a[5:3]

module jttrcdoc_main(
    input               rst,
    input               clk,        // 24 MHz
    input               cen,        // 5 MHz, gated by the ROM wait

    output      [15:0]  cpu_addr,
    output              cpu_rnw,
    output      [ 7:0]  cpu_dout,

    output reg          wram_cs,
    output reg          oram_cs,
    output reg          vram_cs,
    output reg          cram_cs,
    input       [ 7:0]  wram_dout,
    input       [ 7:0]  oram_dout,
    input       [ 7:0]  vram_dout,
    input       [ 7:0]  cram_dout,

    // YM3812
    output reg          fm_cs,

    // video configuration
    output      [ 7:0]  scrx,
    output              flip,

    input               LVBL,
    // cabinet I/O
    input       [ 1:0]  cab_1p,
    input       [ 1:0]  coin,
    input       [ 5:0]  joystick1,
    input       [ 5:0]  joystick2,
    input               service,
    input               dip_pause,
    input       [ 7:0]  dipsw_a,
    input       [ 7:0]  dipsw_b,

    output      [15:0]  rom_addr,
    output reg          rom_cs,
    input       [ 7:0]  rom_data,
    input               rom_ok
);

`ifndef NOMAIN

wire [15:0] A;
wire        mreq_n, rfsh_n, wr_n, rd_n, iorq_n, m1_n, int_n;
reg  [ 7:0] cpu_din, cabinet;
reg  [ 7:0] latch;     // LS259 addressable latch
reg  [ 7:0] scrx_reg;
reg         io_cs, cab_cs, scrx_cs, latch_cs;

// bare address bits, aliased against the memory map
wire a15 = A[15], a14 = A[14], a13 = A[13],
     a12 = A[12], a11 = A[11], a10 = A[10];

assign cpu_addr = A;
assign cpu_rnw  = wr_n;
assign rom_addr = A;
assign scrx     = scrx_reg;
assign flip     = latch[1];

always @* begin
    rom_cs   = 0;
    wram_cs  = 0;
    oram_cs  = 0;
    vram_cs  = 0;
    cram_cs  = 0;
    io_cs    = 0;
    if( !mreq_n && rfsh_n ) begin
        if( a15 & a14 & a13 ) begin
            wram_cs =  ~a12 & ~a11;
            oram_cs =  ~a12 &  a11;
            vram_cs =   a12 & ~a11 & ~a10;
            cram_cs =   a12 & ~a11 &  a10;
            io_cs   =   a12 &  a11;
        end else begin
            rom_cs  = 1;
        end
    end
end

// I/O block decoder, an LS138 on a[5:3]
always @* begin
    cab_cs   = io_cs & ~A[5];                  // f800/f808/f810/f818
    fm_cs    = io_cs &  A[5] & ~A[4] & ~A[3];  // f820-f821
    scrx_cs  = io_cs &  A[5] &  A[4] & ~A[3];  // f830
    latch_cs = io_cs &  A[5] &  A[4] &  A[3];  // f838-f83f
    // f828: watchdog reset, read only
end

// Inputs are active high on this PCB, JTFRAME delivers them active low
always @(posedge clk) begin
    case( A[4:3] )
        0: cabinet <= { dipsw_a[7:1], dipsw_a[0] | ~service };
        1: cabinet <= dipsw_b;
        2: cabinet <= ~{ joystick1[2], joystick1[3], joystick1[0], joystick1[1],
                         coin[1], coin[0], joystick1[5], joystick1[4] };
        3: cabinet <= ~{ joystick2[2], joystick2[3], joystick2[0], joystick2[1],
                         cab_1p[1], cab_1p[0], joystick2[5], joystick2[4] };
    endcase
    cpu_din <= rom_cs  ? rom_data  :
               wram_cs ? wram_dout :
               oram_cs ? oram_dout :
               vram_cs ? vram_dout :
               cram_cs ? cram_dout :
               cab_cs  ? cabinet   : 8'hff;
end

always @(posedge clk) begin
    if( rst ) begin
        latch    <= 0;
        scrx_reg <= 0;
    end else begin
        if( scrx_cs  && !wr_n ) scrx_reg <= cpu_dout;
        if( latch_cs && !wr_n ) latch[A[2:0]] <= cpu_dout[0];
    end
end

// The IRQ flip flop is clocked by VBLANK and held cleared while latch
// bit 4 is high. The acknowledge is a 1 followed by a 0
jtframe_ff u_irq(
    .rst      ( rst               ),
    .clk      ( clk               ),
    .cen      ( 1'b1              ),
    .din      ( 1'b1              ),
    .q        (                   ),
    .qn       ( int_n             ),
    .set      ( 1'b0              ),
    .clr      ( latch[4]          ),
    .sigedge  ( ~LVBL & dip_pause )
);

/* verilator tracing_off */
jtframe_z80 u_cpu(
    .rst_n      ( ~rst        ),
    .clk        ( clk         ),
    .cen        ( cen         ),
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
    .din        ( cpu_din     ),
    .dout       ( cpu_dout    )
);

`else
assign cpu_addr = 16'd0;
assign cpu_rnw  = 1'b1;
assign cpu_dout = 8'd0;
assign rom_addr = 16'd0;
assign scrx     = 8'd0;
assign flip     = 1'b0;
initial begin
    rom_cs=0; wram_cs=0; oram_cs=0; vram_cs=0; cram_cs=0; fm_cs=0;
end
`endif

endmodule
