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
    Date: 2-12-2019 */

// Port 4 configured as output --> use as address bus
// Port 6 configured as output

module jtdd_mcu(
    input              clk,
    input              mcu_rstb,
    input              mcu_cen,
    // CPU bus
    input      [ 8:0]  cpu_AB,
    input              cpu_wrn,
    input      [ 7:0]  cpu_dout,
    output     [ 7:0]  shared_dout,
    // CPU Interface
    input              com_cs,
    output             mcu_ban,
    input              mcu_nmi_set,
    input              mcu_halt,
    output             mcu_irqmain,
    // PROM
    output     [13:0]  rom_addr,
    input      [ 7:0]  rom_data,
    output reg         rom_cs,
    input              rom_ok

);

wire        vma;
reg         port_cs, ram_cs, shared_cs;

wire        rnw;
wire [15:0] A;
wire [ 7:0] mcu_dout;
reg  [ 7:0] mcu_din;

assign  mcu_ban = vma;

reg  [7:0] p6_dout;
wire       nmi;
wire       nmi_clr = ~p6_dout[0];

assign mcu_irqmain =  p6_dout[1];

jtframe_ff u_nmi(
    .clk     (   clk          ),
    .rst     (   ~mcu_rstb    ),
    .cen     (   1'b1         ),
    .sigedge (   mcu_nmi_set  ),
    .din     (   1'b1         ),
    .clr     (   nmi_clr      ),
    .set     (   1'b0         ),
    .q       (   nmi          ),
    .qn      (                )
);

wire [7:0] ram_dout;
assign rom_addr = A[13:0];

// Address decoder
always @(*) begin
    rom_cs    = 1'b0;
    ram_cs    = 1'b0;
    shared_cs = 1'b0;
    port_cs   = 1'b0;
    if( vma ) begin
        if( A[15:14]==2'b11 )        rom_cs    = 1'b1; // Cxxx
        if( A>=16'h40 && A<16'h140 ) ram_cs    = 1'b1;
        if( A[15:12]==4'h8  )        shared_cs = 1'b1; // 8xxx
        if( A<16'h28 )               port_cs   = 1'b1;
    end
end

// Ports
reg [7:0] port_map[0:31];
always @(posedge clk ) begin
    if( !mcu_rstb ) begin
        p6_dout <= 8'd0;
    end else begin
        port_map[A[4:0]] <= mcu_dout;
        if( port_cs && A[5:0]==6'h17 ) p6_dout <= mcu_dout;
    end
end

`ifdef SIMULATION
always @(posedge port_cs) begin
    if( A[5:0] !=6'h17 && vma ) begin
        if( rnw )
            $display("WARNING: Access to non-supported MCU port %X", A );
        else
            $display("WARNING: Write to non-supported MCU port %X, data = %X", A, mcu_dout );
    end
end
`endif

// Input multiplexer
wire [7:0] sh2mcu_dout;

always @(*) begin
    case(1'b1)
        default:   mcu_din = rom_data;
        ram_cs:    mcu_din = ram_dout;
        shared_cs: mcu_din = sh2mcu_dout;
        port_cs:   mcu_din = port_map[A[4:0]];
    endcase
end

// Clock enable
reg  waitn;
wire cpu_cen = mcu_cen & (waitn | ~mcu_rstb);

always @(posedge clk) begin : cpu_clockenable
    if( !mcu_rstb ) begin
        waitn   <= 1'b1;
    end else begin
        if( rom_cs && !rom_ok ) waitn <= 1'b0;
        else if( rom_ok) waitn <= 1'b1;
    end
end

wire halted;

m6801 u_6801(
    .rst        ( ~mcu_rstb     ),
    .clk        ( clk           ),
    .cen        ( cpu_cen       ),
    .rw         ( rnw           ),
    .vma        ( vma           ),
    .address    ( A             ),
    .data_in    ( mcu_din       ),
    .data_out   ( mcu_dout      ),
    .halt       ( mcu_halt      ),
    .halted     ( halted        ),
    .irq        ( 1'b0          ),
    .nmi        ( nmi           ),
    .irq_icf    ( 1'b0          ),
    .irq_ocf    ( 1'b0          ),
    .irq_tof    ( 1'b0          ),
    .irq_sci    ( 1'b0          )
);

jtframe_dual_ram #(.AW(9)) u_shared(
    .clk0   ( clk         ),
    .clk1   ( clk         ),

    .data0  ( mcu_dout    ),
    .addr0  ( A[8:0]      ),
    .we0    ( ~rnw & shared_cs  ),
    .q0     ( sh2mcu_dout ),

    .data1  ( cpu_dout    ),
    .addr1  ( cpu_AB[8:0] ),
    .we1    ( ~cpu_wrn & com_cs & halted),
    .q1     ( shared_dout )
);

wire intram_we = ram_cs & ~rnw;

jtframe_ram #(.AW(8)) u_intram(
    .clk    ( clk         ),
    .cen    ( cpu_cen     ),
    .data   ( mcu_dout    ),
    .addr   ( A[7:0]      ),
    .we     ( intram_we   ),
    .q      ( ram_dout    )
);

// `ifdef SIMULATION
// always @(posedge mcu_halt)   $display("MCU_HALT rose");
// always @(negedge mcu_halt)   $display("MCU_HALT fell");
// always @(posedge mcu_nmi_set) $display("MCU NMI set");
// `endif
endmodule
