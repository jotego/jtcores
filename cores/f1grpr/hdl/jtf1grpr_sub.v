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
    Date: 27-8-2026 */

// Sub 68000 at 10MHz, IRQ1 on vblank. It drives the road and the opponents
// and talks to the main CPU only through the shared RAM.
//
//   000000-01ffff  ROM
//   ff8000-ffbfff  work RAM
//   ffc000-ffcfff  RAM shared with the main 68000
//   fff030-fff033  ACIA 6850, for the cabinet-link cable
//
// The ACIA is stubbed: MAME ties CTS and DCD low, and with no cable there is
// never a character to read. The status register must still answer or the
// boot code waits on it - TDRE (bit 1) reads high so a transmit completes
// immediately, RDRF (bit 0) stays low so the link is simply always idle.
// IRQ3 is never raised.

module jtf1grpr_sub(
    input                rst,
    input                clk,
    input                LVBL,
    input                dip_pause,

    output        [16:1] sub_addr,
    output        [15:0] sub_dout,
    output               sub_rnw,
    output        [ 1:0] sub_dsn,
    output               rom_cs,
    input         [15:0] rom_data,
    input                rom_ok,

    output        [ 1:0] ram_we, shared_we,
    input         [15:0] ram_dout, shared_dout
);

`ifndef NOMAIN
localparam [6:0] CEN_NUM = 7'd11;
localparam [7:0] CEN_DEN = 8'd63;    // 57.272720 * 11/63 = 9.999999MHz

wire [23:1] A;
reg  [15:0] cpu_din;
wire [ 2:0] cpu_fc;
wire        cpu_as_n, cpu_uds_n, cpu_lds_n, cpu_rnw;
wire        cen10, cen10b, dtack_n, inta_n, irq_n;
wire        cpu_bus, lo_we, hi_we, ffblk;
wire        ram_cs, shared_cs, acia_cs;
wire        rom_ok_dly;

assign sub_addr = A[16:1];
assign sub_rnw  = cpu_rnw;
assign sub_dsn  = { cpu_uds_n, cpu_lds_n };

assign cpu_bus  = ~cpu_as_n && (cpu_rnw || sub_dsn!=2'b11);
assign hi_we    = ~cpu_rnw & ~cpu_uds_n;
assign lo_we    = ~cpu_rnw & ~cpu_lds_n;

assign ffblk    = &A[23:16];
assign rom_cs   = cpu_bus & ~|A[23:17];
assign ram_cs   = cpu_bus & ffblk & A[15:14]==2'b10;    // ff8000-ffbfff
assign shared_cs= cpu_bus & ffblk & A[15:12]==4'hc;
assign acia_cs  = cpu_bus & ffblk & A[15:8]==8'hf0 & A[7:2]==6'b0011_00; // fff030-fff033

assign ram_we   = { ram_cs    & hi_we, ram_cs    & lo_we };
assign shared_we= { shared_cs & hi_we, shared_cs & lo_we };

always @(posedge clk) begin
    cpu_din <= rom_cs    ? rom_data    :
               ram_cs    ? ram_dout    :
               shared_cs ? shared_dout :
               // ACIA: A[1]=0 status, A[1]=1 receive data. TDRE high, RDRF low
               acia_cs   ? (A[1] ? 16'h0000 : 16'h0002) : 16'hffff;
end

jtframe_okdly #(.W(1)) u_romok(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .cs     ( rom_cs    ),
    .ok     ( rom_ok    ),
    .ok_dly ( rom_ok_dly)
);

fx68k u_cpu(
    .clk        ( clk       ),
    .enPhi1     ( cen10     ),
    .enPhi2     ( cen10b    ),
    .extReset   ( rst       ),
    .pwrUp      ( rst       ),
    .HALTn      ( dip_pause ),
    .BERRn      ( 1'b1      ),
    .oRESETn    (           ),
    .oHALTEDn   (           ),
    .eab        ( A         ),
    .iEdb       ( cpu_din   ),
    .oEdb       ( sub_dout  ),
    .ASn        ( cpu_as_n  ),
    .eRWn       ( cpu_rnw   ),
    .UDSn       ( cpu_uds_n ),
    .LDSn       ( cpu_lds_n ),
    .DTACKn     ( dtack_n   ),
    .BRn        ( 1'b1      ),
    .BGn        (           ),
    .BGACKn     ( 1'b1      ),
    .E          (           ),
    .VMAn       (           ),
    .VPAn       ( inta_n    ),
    .FC0        ( cpu_fc[0] ),
    .FC1        ( cpu_fc[1] ),
    .FC2        ( cpu_fc[2] ),
    .IPL0n      ( irq_n     ),
    .IPL1n      ( 1'b1      ),
    .IPL2n      ( 1'b1      )
);

assign inta_n = ~&{ cpu_fc, ~cpu_as_n };

jtframe_virq u_virq(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .LVBL       ( LVBL      ),
    .dip_pause  ( dip_pause ),
    .skip_en    ( 1'b0      ),
    .skip_but   ( 1'b0      ),
    .clr        ( ~inta_n   ),
    .custom_in  ( 1'b0      ),
    .blin_n     ( irq_n     ),
    .blout_n    (           ),
    .custom_n   (           )
);

jtframe_68kdtack_cen #(.W(8),.MFREQ(`JTFRAME_MCLK/2000)) u_dtack(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cpu_cen    ( cen10     ),
    .cpu_cenb   ( cen10b    ),
    .bus_cs     ( rom_cs    ),
    .bus_busy   ( rom_cs & ~rom_ok_dly ),
    .bus_legit  ( 1'b0      ),
    .bus_ack    ( 1'b0      ),
    .ASn        ( cpu_as_n  ),
    .DSn        ( sub_dsn   ),
    .num        ( CEN_NUM   ),
    .den        ( CEN_DEN   ),
    .DTACKn     ( dtack_n   ),
    .wait2      ( 1'b0      ),
    .wait3      ( 1'b0      ),
    .fave       (           ),
    .fworst     (           )
);

`else
assign sub_addr  = 0;
assign sub_dout  = 0;
assign sub_rnw   = 1;
assign sub_dsn   = 2'b11;
assign rom_cs    = 0;
assign ram_we    = 0;
assign shared_we = 0;
`endif

endmodule
