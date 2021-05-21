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

(*keep*) wire [15:0] rom_addr;
wire [15:0] ext_addr;
wire [ 6:0] ram_addr;
wire [ 7:0] ram_data, mcu_dout8, mcu_din8;
wire        ram_we;
wire [ 7:0] ram_q, rom_data;

wire [ 7:0] p1_o, p2_o, p3_o;
reg         int0;
assign      mcu_ds = p3_o[4];

// interface with main CPU
assign mcu_addr = ext_addr[14:0];
assign mcu_brn  = int0;
assign mcu_dout = {2{mcu_dout8}};
assign mcu_din8 = mcu_ds ? mcu_din[15:8] : mcu_din[7:0];
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

wire mcu_clk = clk & cen8;

// You need to clock gate for reading or the MCU won't work
jtframe_dual_ram #(.aw(12)) u_prom(
    .clk0   ( clk_rom   ),
    .clk1   ( mcu_clk   ),
    // Port 0
    .data0  ( prom_din  ),
    .addr0  ( prog_addr ),
    .we0    ( prom_we   ),
    .q0     (           ),
    // Port 1
    .data1  (           ),
    .addr1  ( rom_addr[11:0]  ),
    .we1    ( 1'b0      ),
    .q1     ( rom_data  )
);

jtframe_ram #(.aw(7),.cen_rd(1)) u_ramu(
    .clk        ( clk               ),
    .cen        ( cen8              ),
    .addr       ( ram_addr          ),
    .data       ( ram_data          ),
    .we         ( ram_we            ),
    .q          ( ram_q             )
);

mc8051_core u_mcu(
    .reset      ( rst       ),
    .clk        ( mcu_clk   ),
    .cen        ( 1'b1      ),  // cen implementation is wrong
    // code ROM
    .rom_data_i ( rom_data  ),
    .rom_adr_o  ( rom_addr  ),
    // internal RAM
    .ram_data_i ( ram_q     ),
    .ram_data_o ( ram_data  ),
    .ram_adr_o  ( ram_addr  ),
    .ram_wr_o   ( ram_we    ),
    .ram_en_o   (           ),
    // external memory: connected to main CPU
    .datax_i    ( mcu_din8  ),
    .datax_o    ( mcu_dout8 ),
    .adrx_o     ( ext_addr  ),
    .wrx_o      ( mcu_wr    ),
    // interrupts
    .int0_i     ( int0      ),
    .int1_i     ( 1'b1      ),
    // counters
    .all_t0_i   ( 1'b0      ),
    .all_t1_i   ( 1'b0      ),
    // serial interface
    .all_rxd_i  ( 1'b0      ),
    .all_rxd_o  (           ),
    // Ports
    .p0_i       (           ),
    .p0_o       (           ),

    .p1_i       (           ),
    .p1_o       ( p1_o      ),

    .p2_i       (           ),
    .p2_o       ( p2_o      ),

    .p3_i       (           ),
    .p3_o       ( p3_o      ),
    // Unused
    .ALL_TXD_O  (           ),
    .ALL_RXDWR_O(           )
);

`ifdef SIMULATION
always @(negedge int0)
    $display ("MCU: int0 edge - main CPU");
`endif
endmodule