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

module jtdd2_sub(
    input              clk,
    input              rst,
    input              mcu_rstb,
    input              cen4,
    input              main_cen,
    // CPU bus
    input      [ 8:0]  main_AB,
    input              main_wrn,
    input      [ 7:0]  main_dout,
    output     [ 7:0]  shared_dout,
    // CPU Interface
(*keep*)    input              com_cs,
(*keep*)    output             mcu_ban,
(*keep*)    input              mcu_halt,
(*keep*)    input              mcu_nmi_set,
(*keep*)    output  reg        mcu_irqmain,
    // ROM interface
    output     [15:0]  rom_addr,
    input      [ 7:0]  rom_data,
    output reg         rom_cs,
    input              rom_ok

);

(*keep*) reg         shared_cs, nmi_ack;
(*keep*) wire        rnw, int_n, mreq_n, busak_n;
wire [15:0] A;
wire [ 7:0] cpu_dout;
reg  [ 7:0] cpu_din;
assign mcu_ban = busak_n;
wire halted = ~mcu_ban;
(*keep*) wire busrq_n = ~mcu_halt;

reg rstn; // combined reset
reg [3:0] rstcnt;

always @(posedge clk) begin
    if( rst || !mcu_rstb ) begin
        rstn <= 1'b0;
        rstcnt <= 4'hf;
    end else if(cen4) begin
        if( rstcnt != 4'd0 ) rstcnt <= rstcnt-4'd1;
        else rstn <= 1'b1;
    end
end

jtframe_ff u_nmi(
    .clk     (   clk          ),
    .rst     (   ~rstn        ),
    .cen     (   1'b1         ),
    .sigedge (   mcu_nmi_set  ),
    .din     (   1'b1         ),
    .clr     (   nmi_ack      ),
    .set     (   1'b0         ),
    .q       (                ),
    .qn      (   int_n        )
);

wire [7:0] ram_dout;
assign rom_addr = A;

// Address decoder
always @(*) begin
    rom_cs      = 1'b0;
    shared_cs   = 1'b0;
    mcu_irqmain = 1'b0;
    nmi_ack     = 1'b0;
    if( !mreq_n ) begin
        if( A[15:14]!=2'b11 )
            rom_cs    = 1'b1; // < Cxxx
        else begin
            case( A[13:12] )
                2'b00: if(A[11:10]==2'b0) shared_cs   = 1'b1; // C
                2'b01: nmi_ack     = !rnw; // D
                2'b10: mcu_irqmain = !rnw; // E
                default:;
            endcase
        end
    end
end

// Input multiplexer
wire [7:0] sh2mcu_dout;

always @(*) begin
    case(1'b1)
        rom_cs:    cpu_din = rom_data;
        shared_cs: cpu_din = sh2mcu_dout;
        default:   cpu_din = 8'hff;
    endcase
end

jtframe_z80_romwait #(.RECOVERY(0)) u_sub(
    .rst_n      ( rstn          ),
    .clk        ( clk           ),
    .cen        ( cen4          ),
    .cpu_cen    (               ),
    .int_n      ( 1'b1          ),
    .nmi_n      ( int_n         ),
    .busrq_n    ( busrq_n       ),
    .m1_n       (               ),
    .mreq_n     ( mreq_n        ),
    .iorq_n     (               ),
    .rd_n       (               ),
    .wr_n       ( rnw           ),
    .rfsh_n     (               ),
    .halt_n     (               ),
    .busak_n    ( busak_n       ),
    .A          ( A             ),
    .din        ( cpu_din       ),
    .dout       ( cpu_dout      ),
    // ROM access
    .rom_cs     ( rom_cs        ),
    .rom_ok     ( rom_ok        )
);

`ifdef SIMULATION
reg last_mcu_halt;
reg dump;

always @(posedge clk) begin
    last_mcu_halt <= mcu_halt;
    dump <= mcu_halt != last_mcu_halt;
end
`endif

reg [7:0] dinA, dinB;
reg [9:0] addrA, addrB;
reg       weA, weB;

always @(*) begin
    addrA = A[9:0];
    dinA  = cpu_dout;
end

reg last_rnw;

always @(posedge clk) begin
    last_rnw <= rnw;
    weA      <= ~rnw && last_rnw && shared_cs;
end

//always @(posedge clk) if(main_cen) begin
always @* begin
    addrB = {1'b0,main_AB};
    dinB  = main_dout;
    weB   = !main_wrn && com_cs && halted;
end

jtframe_dual_ram #(.AW(10),.DUMPFILE("sub.hex")) u_shared(
    .clk0   ( clk         ),
    .clk1   ( clk         ),

    .data0  ( dinA        ),
    .addr0  ( addrA       ),
    .we0    ( weA         ),
    .q0     ( sh2mcu_dout ),

    .data1  ( dinB        ),
    .addr1  ( addrB       ),
    .we1    ( weB         ),
    .q1     ( shared_dout )
    `ifdef JTFRAME_DUAL_RAM_DUMP
    ,.dump   ( dump        )
    `endif
);

// `ifdef SIMULATION
// always @(posedge mcu_halt)   $display("MCU_HALT rose");
// always @(negedge mcu_halt)   $display("MCU_HALT fell");
// always @(posedge mcu_nmi_set) $display("MCU NMI set");
// `endif
endmodule
