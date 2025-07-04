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
    Date: 5-5-2023 */

module jtajax_sub(
    input               rstn,
    input               clk48,
    input               clk,
    input               cen3,

    input               irq_n, firq_trg,
    input      [7:0]    vram_dout,
    output reg          rmrd, rvo,
    output              vr_cs, io_cs, vram_cs, rvch_cs,
    output      [ 7:0]  cpu_dout,
    output              we,
    // Communication RAM
    input       [12:0]  main_addr,
    input       [ 7:0]  main_dout,
    input               main_we,
    output      [ 7:0]  mcom_dout,
    // ROM
    output      [16:0]  rom_addr,
    output              rom_cs,
    input       [ 7:0]  rom_data,
    input               rom_ok,
    // 051316 - R chip outpus
    input               psac_ok,
    input       [ 7:0]  rrom_data,
    input       [ 7:0]  rgfx_dout
);

wire [15:0] A;
wire [ 7:0] scom_dout;
reg  [ 7:0] cpu_din;
reg  [ 3:0] bank;
wire        firq_n, VMA, romlow_cs, banked_cs, scom_cs, scom_we, RnW, latch_cs;
reg         firq_clr, rom_good;

assign romlow_cs = A[15] & (bank[3]|A[14]|A[13]);
assign banked_cs = !bank[3] && A[15:13]==3'b100;
assign rom_cs    = romlow_cs | banked_cs;
assign rom_addr  = { banked_cs ? {1'b0,bank[2:0]} : {2'b10,A[14:13]}, A[12:0] };
assign latch_cs  = A[15: 9]=='b0001_100;
assign rvch_cs   = A[15:11]=='b0001_0;  // reads 051316 ROM output
assign io_cs     = A[15:11]=='b0000_1;
assign vr_cs     = A[15:11]=='b0000_0;
assign scom_cs   = A[15:13]=='b001;
assign vram_cs   = A[15:14]=='b01;
assign scom_we   = scom_cs & ~RnW;
assign we        = ~RnW;

always @(posedge clk) begin
    rom_good<=(~rom_cs  | rom_ok) & psac_ok;
    cpu_din <= rom_cs  ? rom_data  :
               rvch_cs ? rrom_data :
               vram_cs ? vram_dout :
               scom_cs ? scom_dout :
               vr_cs   ? rgfx_dout : 8'd0;
end


jtframe_edge #(.QSET(0))u_edge(
    .rst    ( ~rstn     ),
    .clk    ( clk       ),
    .edgeof ( firq_trg  ),
    .clr    ( firq_clr  ),
    .q      ( firq_n    )
);

always @(posedge clk) begin
    if(!rstn) begin
        bank     <= 0;
        firq_clr <= 1;
    end else begin
        if(latch_cs) begin
            bank     <= cpu_dout[3:0];
            firq_clr <=~cpu_dout[4];
            rvo      <= cpu_dout[5];   // OR'ed with blank output of 051316 (see J5 on sheet 2/3)
            rmrd     <= cpu_dout[6];
        end
    end
end

jtframe_dual_ram #(.AW(13)) u_com(
    // Sub
    .clk0       ( clk       ),
    .data0      ( cpu_dout  ),
    .addr0      ( A[12:0]   ),
    .we0        ( scom_we   ),
    .q0         ( scom_dout ),
    // Main
    .clk1       ( clk48     ),
    .data1      ( main_dout ),
    .addr1      ( main_addr ),
    .we1        ( main_we   ),
    .q1         ( mcom_dout )
);

jtframe_sys6809 #(.RAM_AW(0),.CENDIV(0),.IRQFF(0)) u_cpu(
    .rstn       ( rstn      ),
    .clk        ( clk       ),
    .cen        ( cen3      ),   // This is normally the input clock to the CPU
    .cpu_cen    (           ),   // 1/4th of cen -> 3MHz

    // Interrupts
    .nIRQ       ( irq_n     ),
    .nFIRQ      ( firq_n    ),
    .nNMI       ( 1'b1      ),
    .irq_ack    (           ),
    // Bus sharing
    .bus_busy   ( 1'b0      ),
    // memory interface
    .A          ( A         ),
    .RnW        ( RnW       ),
    .VMA        ( VMA       ),
    .ram_cs     ( 1'b0      ),
    .rom_cs     ( rom_cs    ),
    .rom_ok     ( rom_good  ),
    // Bus multiplexer is external
    .ram_dout   (           ),
    .cpu_dout   ( cpu_dout  ),
    .cpu_din    ( cpu_din   )
);

endmodule 