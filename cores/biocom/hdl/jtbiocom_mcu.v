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
    Date: 14-9-2019 */


// Interface with sound CPU:
// The sound CPU can read and write to the MCU at a fixed
// address. The MCU only knows when data has been written to it
// The MCU responds by writting an answer. The MCU cannot
// know whether the sound CPU has read the value

// Interface with main CPU:
// The MCU takes control of the bus directly, including the bus decoder
// Because it doesn't drive AB[19:17], which will remain high, the MCU
// cannot access the PROM, OBJRAM, IO, scroll positions or char RAM
// It can drive both scrolls, palette and work RAM because it drives
// AB[16:14]. However, it doesn't have any bus arbitrion with the video
// components, so it wouldn't be able to access video components
// successfully. Thus, I am assuming that it only interacts with the
// work RAM

module jtbiocom_mcu(
    input                rst,
    input                rst_cpu,
    input                clk_rom,
    input                clk_cpu,
    input                clk,
    input                cen6a,       //  6   MHz
    // Main CPU interface
    (*keep*) input       DMAONn,
    output       [ 7:0]  mcu_dout,
    input        [ 7:0]  mcu_din,
    output               mcu_wr,   // always write to low bytes
    output       [16:1]  mcu_addr,
    (*keep*) output      mcu_brn,   // RQBSQn
    (*keep*) output      DMAn,
    // Sound CPU interface
    input        [ 7:0]  snd_dout,
    output reg   [ 7:0]  snd_din,
    input                snd_mcu_wr,
    input                snd_mcu_rd,
    // ROM programming
    input        [11:0]  prog_addr,
    input        [ 7:0]  prom_din,
    input                prom_we
);

parameter SINC_XDATA=1;
parameter ROMBIN="../../../../rom/biocom/ts.2f";
`ifndef NOMCU
wire [15:0] ext_addr;
wire [ 6:0] ram_addr;
wire [ 7:0] ram_data;
wire        ram_we;
wire [ 7:0] ram_q, rom_data;

wire [ 7:0] p0_o, p1_o, p2_o, p3_o;
reg         int0n, int1n;

// interface with main CPU
wire [7:0] p3_os;
assign mcu_addr[13:9] = ~5'b0;
assign { mcu_addr[16:14], mcu_addr[8:1] } = ext_addr[10:0];
assign mcu_brn  = int0n;
assign DMAn     = p3_os[5];
reg    last_DMAONn;

jtframe_sync #(.W(8)) u_p3sync(
    .clk_in ( 1'b0      ),
    .clk_out( clk_cpu   ),
    .raw    ( p3_o      ),
    .sync   ( p3_os     )
);

wire int0n_mcu;

jtframe_sync #(.W(1)) u_intsync(
    .clk_in ( 1'b0      ),
    .clk_out( clk       ),
    .raw    ( int0n     ),
    .sync   ( int0n_mcu )
);

always @(posedge clk_cpu, posedge rst_cpu) begin
    if( rst_cpu ) begin
        int0n <= 1;
        last_DMAONn <= 1;
    end else begin
        last_DMAONn <= DMAONn;
        if(!p3_os[0]) // CLR
            int0n <= 1;
        else if(!p3_os[1])
            int0n <= 0; // PR
        else if( DMAONn && !last_DMAONn )
            int0n <= 0;
    end
end

// interface with sound CPU
wire      int1_clrn = p3_o[4];

reg [7:0] snd_dout_latch;
reg       last_snd_mcu_wr, last_p3_6, last_snd_mcu_rd;
wire      posedge_snd    = snd_mcu_wr && !last_snd_mcu_wr;
wire      posedge_snd_rd = snd_mcu_rd && !last_snd_mcu_rd;
wire      posedge_p3_6 = p3_o[6] && !last_p3_6;
wire      snd_blank = p1_o == 8'hff;
reg       snd_done;

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        snd_dout_latch  <= 8'd0;
        int1n           <= 1;
        last_snd_mcu_wr <= 1'b0;
        snd_done        <= 1'b1;
    end else begin
        last_snd_mcu_wr <= snd_mcu_wr;
        last_snd_mcu_rd <= snd_mcu_rd;
        last_p3_6       <= p3_o[6];
        if( posedge_snd )
            snd_dout_latch <= snd_dout;
        // interrupt line
        if( !int1_clrn )
            int1n <= 1;
        else if( posedge_snd ) int1n <= 0;
        // latch sound data
        if( posedge_snd_rd ) snd_done <= 1'b1;
        if( posedge_p3_6 && (snd_done || !snd_blank) ) begin
            snd_done <= snd_blank;
            snd_din  <= p1_o;
        end
    end
end

wire [7:0] mcu_din_s, x_dout;
wire       x_wr;

assign mcu_wr = x_wr | ~p3_o[6]; // wr pin
assign mcu_dout = x_wr ? x_dout : p0_o;

jtframe_sync #(.W(8)) u_sync(
    .clk_in ( clk_cpu   ),
    .clk_out( clk       ),
    .raw    ( mcu_din   ),
    .sync   ( mcu_din_s )
);

jtframe_8751mcu #(
    .ROMBIN(ROMBIN),
    .SYNC_XDATA(SINC_XDATA)
) u_mcu(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cen        ( cen6a     ),
    // external memory: connected to main CPU
    .x_din      ( mcu_din_s ),
    .x_dout     ( x_dout    ),
    .x_addr     ( ext_addr  ),
    .x_wr       ( x_wr      ),
    .x_acc      (           ),
    // interrupts
    .int0n      ( int0n_mcu ),
    .int1n      ( int1n     ),
    // Ports
    .p0_i       ( 8'hff     ),
    .p0_o       ( p0_o      ),

    .p1_i       ( snd_dout_latch   ),
    .p1_o       ( p1_o      ),

    .p2_i       ( 8'hff     ),
    .p2_o       ( p2_o      ),

    .p3_i       ( 8'hff     ),
    .p3_o       ( p3_o      ),

    .clk_rom    ( clk_rom   ),
    .prog_addr  ( prog_addr ),
    .prom_din   ( prom_din  ),
    .prom_we    ( prom_we   )
);

`ifdef SIMULATION
always @(negedge int0n)
    $display ("MCU: int0n edge - main CPU");

always @(negedge int1n)
    $display ("MCU: int1n edge - sound CPU");
`endif
`else // NOMCU
    assign mcu_dout=0;
    assign mcu_wr=0;
    assign mcu_addr=0;
    assign mcu_brn=1;
    assign DMAn=1;
    initial snd_din=0;
`endif
endmodule