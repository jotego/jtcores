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
    input               rst,
    input               clk,
    input        [ 1:0] cpu_cen,

    input               lvbl,
    input               firqn,     // input that will trigger both FIRQ outputs

    output       [21:0] baddr,  // shared by both CPUs
    output       [ 7:0] bdout,
    output              brnw,

    output              tri_cs,
    output              key_cs,
    output              cus30b_cs,
    input        [ 7:0] key_dout,
    input        [ 7:0] tri_dout,

    // Video RAMs
    output       [ 1:0] obus_we,
    output       [11:1] obus_addr,
    input        [15:0] obus_dout,

    output              vram_cs, pal_cs,
    input        [ 7:0] vram_dout, pal_dout,


    output              srst_n,

    output              mrom_cs,   srom_cs,   ram_cs,
    input               mrom_ok,   srom_ok,   ram_ok,
    input        [ 7:0] mrom_data, srom_data, ram_dout,

    output              bus_busy
);

wire [15:0] maddr, saddr;
wire [ 7:0] mdout, sdout, bdin;
wire        mrnw, mirq_n, mfirq_n, mavma,
            srnw, sirq_n, sfirq_n, savma,
            rom_cs, oram_cs, sram_cs;
wire [ 9:0] cs;
reg  [ 7:0] mdin, sdin;
reg         bsel, mvma, svma;
wire        master, sub; // current bus owner

assign master   = ~bsel;
assign sub      =  bsel;
assign mrom_cs  = rom_cs & master;
assign srom_cs  = rom_cs & sub;
assign tri_cs   = cs[9]; // /IOEN
assign cus30b_cs= cs[8]; // /SOUND
assign vram_cs  = cs[4]; // /CHAR
assign oram_cs  = cs[6]; // /OBJECT
assign key_cs   = cs[5]; // /KEY
assign pal_cs   = cs[3]; // /COLOR

// Video RAM
assign obus_we  =   {2{oram_cs&~brnw}} & { baddr[11], ~baddr[11] };
assign obus_addr= baddr[10:0];

assign bus_busy = |{mrom_cs&~mrom_ok, srom_cs&~srom_ok, ram_cs&~ram_ok};
assign bdin = mrom_cs ? mrom_data :
              srom_cs ? srom_data :
              ram_cs  ? ram_dout  :
              tri_cs  ? tri_dout  :
              key_cs  ? key_dout  :
              vram_cs ? vram_dout :
              pal_cs  ? pal_dout  :
              oram_cs ? ( baddr[11] ? obus_dout[15:8] : obus_dout[7:0] ) :
              8'd0;

always @(posedge clk) begin
    if( cpu_cen[0] ) begin bsel <= 1; mvma <= mavma; end
    if( cpu_cen[1] ) begin bsel <= 0; svma <= savma; end
    if( master )
        mdin <= bdin;
    else
        sdin <= bdin;
end

jtc117 u_mapper(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .bsel   ( bsel      ), // 0=master, 1=sub
    // interrupt triggers
    .lvbl   ( lvbl      ),
    .firqn  ( firqn     ),   // input that will trigger both FIRQ outputs
    .vma    (           ),

    // Master
    .mvma   ( mvma      ),
    .maddr  ( maddr     ),  // not all bits are used, but easier to connect as a whole
    .mdout  ( mdout     ),
    .mrnw   ( mrnw      ),
    .mirq_n ( mirq_n    ),
    .mfirq_n( mfirq_n   ),

    // Sub
    .svma   ( svma      ),
    .saddr  ( saddr     ),
    .sdout  ( sdout     ),
    .srnw   ( srnw      ),
    .sirq_n ( sirq_n    ),
    .sfirq_n( sfirq_n   ),
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
    .cen_E      ( cpu_cen[0]),
    .cen_Q      ( cpu_cen[1]),
    .D          ( mdin      ),
    .DOut       ( mdout     ),
    .ADDR       ( maddr     ),
    .RnW        ( mrnw      ),
    // Interrupts
    .nIRQ       ( mirq_n    ),
    .nFIRQ      ( mfirq_n   ),
    .nNMI       ( 1'b1      ),
    .nHALT      ( 1'b1      ),
    // unused
    .AVMA       ( mavma     ),
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
    .cen_E      ( cpu_cen[1]),
    .cen_Q      ( cpu_cen[0]),
    .D          ( sdin      ),
    .DOut       ( sdout     ),
    .ADDR       ( saddr     ),
    .RnW        ( srnw      ),
    // Interrupts
    .nIRQ       ( sirq_n    ),
    .nFIRQ      ( sfirq_n   ),
    .nNMI       ( 1'b1      ),
    .nHALT      ( 1'b1      ),
    // unused
    .AVMA       ( savma     ),
    .BS         (           ),
    .BA         (           ),
    .BUSY       (           ),
    .LIC        (           ),
    .nDMABREQ   ( 1'b1      ),
    .OP         (           ),
    .RegData    (           )
);

endmodule