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
    Date: 19-9-2023 */

module jtshouse_main(
    input               clk,
    input               cen3,

    input               lvbl,
    input               firqn,     // input that will trigger both FIRQ outputs

    output       [21:0] baddr,  // shared by both CPUs
    output       [ 7:0] bdout,
    output              brnw,

    output              key_cs,
    input        [ 7:0] key_dout,

    output              srst_n,

    output              mrom_cs,   srom_cs,   ram_cs,
    input               mrom_ok,   srom_ok,   ram_ok,
    input        [ 7:0] mrom_data, srom_data, ram_dout,

);

wire [15:0] maddr, saddr;
wire [ 7:0] mdout, sdout, bdin;
wire        mrnw, mirq, mfirq, mram_cs,
            srnw, sirq, sfirq, sram_cs,
            bus_busy;
wire [ 9:0] cs;
reg  [ 7:0] mdin, sdin;

reg         cen_cnt=0;

assign ram_cs   = mram_cs | sram_cs;
assign bus_busy = |{mrom_cs&~mrom_ok, srom_cs&~srom_ok, ram_cs&~ram_ok};
assign bdin = mrom_cs ? mrom_data :
              srom_cs ? srom_data :
              ram_cs  ? ram_dout  :
              key_cs  ? key_dout  :
              8'd0;

always @(posedge clk) begin
    cen_e <= 0;
    cen_q <= 0;
    if( cen3 & ~bus_busy) begin // no cycle recovery for now
       cen_cnt <= ~cen_cnt;
       cen_e <= ~cen_cnt;
       cen_q <=  cen_cnt;
    end
end

always @(posedge clk) begin
    if(  cen_cnt ) mdin <= bdin;
    if( ~cen_cnt ) sdin <= bdin;
end

jtc117 u_mapper(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .bsel   ( cen_cnt   ), // 0=master, 1=sub
    // interrupt triggers
    .lvbl   ( lvbl      ),
    .firqn  ( firqn     ),   // input that will trigger both FIRQ outputs

    // Master
    .maddr  ( maddr     ),  // not all bits are used, but easier to connect as a whole
    .mdout  ( mdout     ),
    .mrnw   ( mrnw      ),
    .mirq   ( mirq      ),
    .mfirq  ( mfirq     ),
    .mram_cs( mram_cs   ),

    // Sub
    .saddr  ( saddr     ),
    .sdout  ( sdout     ),
    .srnw   ( srnw      ),
    .sirq   ( sirq      ),
    .sfirq  ( sfirq     ),
    .sram_cs( sram_cs   ),
    .srst_n ( srst_n    ),

    .cs     ( cs        ),
    .rom_cs ( rom_cs    ),
    .ram_cs ( ram_cs    ),
    .rnw    ( brnw      ),
    .baddr  ( baddr     ),
    .bdout  ( bdout     )
);

mc6809i u_main(
    .nRESET     ( ~rst      ),
    .clk        ( clk       ),
    .cen_E      ( cen_e     ),
    .cen_Q      ( cen_q     ),
    .D          ( mdin      ),
    .DOut       ( mdout     ),
    .ADDR       ( maddr     ),
    .RnW        ( mrnw      ),
    .nIRQ       ( mirqn     ),
    .nFIRQ      ( mfirqn    ),
    .nNMI       ( 1'b1      ),
    .nHALT      ( 1'b1      ),
    // unused
    .AVMA       (           ),
    .BS         (           ),
    .BA         (           ),
    .BUSY       (           ),
    .LIC        (           ),
    .nDMABREQ   ( 1'b1      ),
    .OP         (           ),
    .RegData    (           )
);

mc6809i u_sub(
    .nRESET     ( srst_n    ),
    .clk        ( clk       ),
    .cen_E      ( cen_q     ),
    .cen_Q      ( cen_e     ),
    .D          ( sdin      ),
    .DOut       ( sdout     ),
    .ADDR       ( saddr     ),
    .RnW        ( srnw      ),
    .nIRQ       ( sirqn     ),
    .nFIRQ      ( sfirqn    ),
    .nNMI       ( 1'b1      ),
    .nHALT      ( 1'b1      ),
    // unused
    .AVMA       (           ),
    .BS         (           ),
    .BA         (           ),
    .BUSY       (           ),
    .LIC        (           ),
    .nDMABREQ   ( 1'b1      ),
    .OP         (           ),
    .RegData    (           )
);

endmodule