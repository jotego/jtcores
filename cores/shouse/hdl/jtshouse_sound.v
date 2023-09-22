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
    Date: 21-9-2023 */

module jtshouse_sound(
    input               srst_n,
    input               clk,
    input        [ 1:0] cpu_cen,
    input               cen_fm,
    input               cen_fm2,
    input               lvbl,

    output reg          rom_cs,
    output       [16:0] rom_addr,
    input        [ 7:0] rom_data,
    input               rom_ok,
    output              bus_busy,

    output signed[15:0] left, right,
    output              sample,
    output              peak
);

wire [15:0] A;
wire [ 7:0] cpu_dout, ram_dout, fm_dout;
reg  [ 7:0] cpu_din;
reg  [ 2:0] bank;
reg         irq_n, lvbl_l, VMA;
wire        AVMA, RnW, ram_cs, fm_cs, firq_n;
wire signed [15:0] fm_l, fm_r;

assign rom_addr = { bank, A[13:0] };
assign bus_busy = rom_cs & ~rom_ok;
assign peak     = 0;

always @(posedge clk) begin
    rom_cs   <= 0;
    fm_cs    <= 0;
    cus30_cs <= 0;
    tri_cs   <= 0;
    ram_cs   <= 0;
    reg_cs   <= 0;
    if( VMA ) casez(A[15:12])
        4'b00??: rom_cs   <= 1;
        4'b0100: fm_cs    <= 1;
        4'b0101: cus30_cs <= 1;
        4'b0111: tri_cs   <= 1;
        4'b100?: ram_cs   <= 1;
        4'b11??: reg_cs   <= 1;
    endcase
end

always @* begin
    cpu_din = rom_cs ? rom_data :
              ram_cs ? ram_dout :
              fm_cs  ? fm_dout  :
              8'd0;
end

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        bank  <= 0;
        irq_n <= 1;
        lvbl_l <= 0;
        VMA   <= 0;
    end else begin
        if( cpu_cen[1] ) VMA <= AVMA;
        lvbl_l <= lvbl;
        if( !lvbl && lvbl_l ) irq_n <= 0;
        if( reg_cs && !RnW ) begin
            if( A[13:12]==0 ) banck <=cpu_dout[6:4];
            if( A[13:12]==2 ) irq_n <= 1;
        end
    end
end

jt51 u_jt51(
    .rst        ( ~srst_n   ), // reset
    .clk        ( clk       ), // main clock
    .cen        ( cen_fm    ),
    .cen_p1     ( cen_fm2   ),
    .cs_n       ( ~fm_cs    ), // chip select
    .wr_n       ( RnW       ), // write
    .a0         ( A[0]      ),
    .din        ( dout      ), // data in
    .dout       ( fm_dout   ), // data out
    .ct1        (           ),
    .ct2        (           ),
    .irq_n      ( firq_n    ),
    // Low resolution output (same as real chip)
    .sample     ( sample    ), // marks new output sample
    .left       (           ),
    .right      (           ),
    // Full resolution output
    .xleft      ( fm_l      ),
    .xright     ( fm_r      )
);

mc6809i u_cpu(
    .nRESET     ( srst_n    ),
    .clk        ( clk       ),
    .cen_E      ( cpu_cen[1]),
    .cen_Q      ( cpu_cen[0]),
    .D          ( cpu_din   ),
    .DOut       ( cpu_dout  ),
    .ADDR       ( A         ),
    .RnW        ( RnW       ),
    .AVMA       ( AVMA      ),
    // Interrupts
    .nIRQ       ( irq_n     ),
    .nFIRQ      ( firq_n    ),
    .nNMI       ( 1'b1      ),
    .nHALT      ( 1'b1      ),
    // unused
    .BS         (           ),
    .BA         (           ),
    .BUSY       (           ),
    .LIC        (           ),
    .nDMABREQ   ( 1'b1      ),
    .OP         (           ),
    .RegData    (           )
);

endmodule