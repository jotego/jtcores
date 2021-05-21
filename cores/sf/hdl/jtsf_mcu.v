/*  This file is part of JT_GNG.
    JT_GNG program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JT_GNG program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JT_GNG.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 20-5-2021 */

module jtsf_mcu(
    input                rst,
    input                clk_rom,
    input                clk,       // 24MHz
    output               mcu_cen,
    // Main CPU interface
    input        [15:0]  mcu_din,
    output       [15:0]  mcu_dout,
    output               mcu_wr,
    output       [15:1]  mcu_addr,
    output               mcu_sel, // 1 for RAM, 0 for cabinet I/O
    output               mcu_brn,   // RQBSQn
    input                mcu_DMAONn,
    output               mcu_ds,
    input                ram_ok,
    // ROM programming
    input        [11:0]  prog_addr,
    input        [ 7:0]  prom_din,
    input                prom_we
);

wire [15:0] ext_addr;
wire [ 7:0] mcu_dout8;
reg  [ 7:0] mcu_din8;

wire [ 7:0] p1_o, p2_o, p3_o;
reg         int0;
assign      mcu_ds = p3_o[4];

// interface with main CPU
assign mcu_addr = ext_addr[14:0];
assign mcu_brn  = int0;
assign mcu_dout = {2{mcu_dout8}};
reg    last_mcu_DMAONn;

localparam CW=3;
reg [CW-1:0] cencnt=1;
wire cen8 = (mcu_sel & ~mcu_brn & ~ram_ok) ? 0 : cencnt[0];

assign mcu_cen = cen8;
assign mcu_sel = ext_addr[15];

// Clock enable for 8MHz, like MAME. I need to measure it on the PCB
always @(posedge clk) cencnt <= {cencnt[CW-2:0], cencnt[CW-1]};

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        int0 <= 1'b1;
        last_mcu_DMAONn <= 1'b1;
    end else begin
        last_mcu_DMAONn <= mcu_DMAONn;
        if( !p3_o[1] ) // CLR
            int0 <= ~1'b0;
        else if( mcu_DMAONn && !last_mcu_DMAONn )
            int0 <= ~1'b1;
    end
end

always @(posedge clk ) begin
    //addr_cpy <= ext_addr;
    //wr_cpy   <= mcu_wr;
    //if( addr_cpy != ext_addr || (mcu_wr && !wr_cpy) )
    if( cen8 )
        mcu_din8 <= mcu_ds ? mcu_din[15:8] : mcu_din[7:0];
end

jtframe_6801mcu u_mcu(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cen        ( cen8      ),

    .int0n      ( int0      ),
    .int1n      ( 1'b1      ),

    .p0_i       (           ),
    .p0_o       ( p0_o      ),

    .p1_i       (           ),
    .p1_o       ( p1_o      ),

    .p2_i       (           ),
    .p2_o       ( p2_o      ),

    .p3_i       (           ),
    .p3_o       ( p3_o      ),

    // external memory
    .x_din      ( mcu_din8  ),
    .x_dout     ( mcu_dout8 ),
    .x_addr     ( ext_addr  ),
    .x_wr       ( mcu_wr    ),

    // ROM programming
    .clk_rom    ( clk_rom   ),
    .prog_addr  ( prog_addr ),
    .prom_din   ( prom_din  ),
    .prom_we    ( prom_we   )
);

`ifdef SIMULATION
always @(negedge int0)
    $display ("MCU: int0 edge - main CPU");
`endif
endmodule