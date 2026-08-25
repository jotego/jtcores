/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 14-9-2019 */


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

parameter ROMBIN="../../../../rom/biocom/ts.2f";
`ifndef NOMCU
wire [15:0] ext_addr;

wire [ 7:0] p0_o, p1_o, p2_o, p3_o;
reg         int0n, int1n;

// interface with main CPU
assign mcu_addr[13:9] = ~5'b0;
assign { mcu_addr[16:14], mcu_addr[8:1] } = ext_addr[10:0];
assign mcu_brn  = int0n;
assign DMAn     = p3_o[5];
reg    last_DMAONn;

always @(posedge clk_cpu, posedge rst_cpu) begin
    if( rst_cpu ) begin
        int0n <= 1;
        last_DMAONn <= 1;
    end else begin
        last_DMAONn <= DMAONn;
        if(!p3_o[0]) // CLR
            int0n <= 1;
        else if(!p3_o[1])
            int0n <= 0; // PR
        else if( DMAONn && !last_DMAONn )
            int0n <= 0;
    end
end

// interface with sound CPU
wire      int1_clrn = p3_o[4];
wire [7:0] x_dout;
wire       x_wr;

reg [7:0] snd_dout_latch;
reg       last_snd_mcu_wr, last_p3_6, last_snd_mcu_rd;
wire      posedge_snd    = snd_mcu_wr && !last_snd_mcu_wr;
wire      posedge_snd_rd = snd_mcu_rd && !last_snd_mcu_rd;
// P3.6 is the physical /WR pin during MOVX, otherwise it is GPIO.  Current
// MAME models the MCU-to-sound transfer on the 1-to-0 transition of P3.6.
wire      p3_6_pin = p3_o[6] & ~x_wr;
wire      negedge_p3_6 = last_p3_6 && !p3_6_pin;
wire      snd_blank = p1_o == 8'hff;
reg       snd_done;

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        snd_dout_latch  <= 8'd0;
        int1n           <= 1;
        last_snd_mcu_wr <= 1'b0;
        last_p3_6        <= 1'b1;
        last_snd_mcu_rd <= 1'b0;
        snd_done        <= 1'b1;
    end else begin
        last_snd_mcu_wr <= snd_mcu_wr;
        last_snd_mcu_rd <= snd_mcu_rd;
        last_p3_6        <= p3_6_pin;
        if( posedge_snd )
            snd_dout_latch <= snd_dout;
        // interrupt line
        if( !int1_clrn )
            int1n <= 1;
        else if( posedge_snd ) int1n <= 0;
        // latch sound data
        if( posedge_snd_rd ) snd_done <= 1'b1;
        if( negedge_p3_6 && (snd_done || !snd_blank) ) begin
            snd_done <= snd_blank;
            snd_din  <= p1_o;
        end
    end
end

// The shared main bus is accessed through MOVX.  P3.5 is the DMA ownership
// output; reads float high and writes are ignored while the MCU does not own
// the bus.
wire [7:0] x_din = p3_o[5] ? 8'hff : mcu_din;
assign mcu_wr   = x_wr & ~p3_o[5];
assign mcu_dout = x_dout;

jtframe_8751mcu #(
    .ROMBIN     ( ROMBIN ),
    .SYNC_XDATA ( 1      ) // used to hold the data, rather than synchronization
) u_mcu(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cen        ( cen6a     ),
    // external memory: connected to main CPU
    .x_din      ( x_din     ),
    .x_dout     ( x_dout    ),
    .x_addr     ( ext_addr  ),
    .x_wr       ( x_wr      ),
    .x_acc      (           ),
    // interrupts
    .int0n      ( int0n     ),
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
`else // NOMCU
    assign mcu_dout=0;
    assign mcu_wr=0;
    assign mcu_addr=0;
    assign mcu_brn=1;
    assign DMAn=1;
    initial snd_din=0;
`endif
endmodule
