// SPDX-License-Identifier: GPL-3.0-or-later

module jtmzone_mcu(
    input               rst,
    input               clk,
    input               cen,

    input       [ 7:0]  din,
    input               latch_cs,
    input               irq_cs,

    output      [ 7:0]  status,

    output      [11:0]  rom_addr,
    output              rom_cs,
    input       [ 7:0]  rom_data,
    input               rom_ok,

    output      [ 7:0]  dac
);

wire        xtal3, ram_we;
wire [ 7:0] ram_addr, ram_din, ram_dout;
wire [ 7:0] p2_out;
reg  [ 7:0] latch;
reg  [14:0] timer;
reg         irq_pending, irq_last, rstn_t48;
wire        irq_clear = rst | ~p2_out[7];

assign rom_cs = 1'b1;
// B_A12/B_B11/B_B10 divide the 14.318 MHz crystal by 4096 before
// B_B9 counts the four AY port-A timer bits. cen is crystal / 2, so
// advance the visible counter every 2048 enables (MAME: AY clock / 512).
assign status = { timer[14:11], 1'b0, p2_out[6:4] };

// P27 asynchronously clears the /INT latch. Only a new /START
// assertion may set it again; clear has priority over that assertion.
always @(posedge clk or posedge irq_clear) begin
    if( irq_clear ) irq_pending <= 1'b0;
    else if( irq_cs && !irq_last ) irq_pending <= 1'b1;
end

always @(posedge clk) begin
    rstn_t48 <= ~rst;
    if( rst ) begin
        irq_last    <= 1'b0;
        latch       <= 8'd0;
        timer       <= 15'd0;
    end else begin
        irq_last <= irq_cs;
        if( cen ) timer <= timer + 15'd1;
        if( latch_cs ) latch <= din;
    end
end

t48_core u_mcu(
    .reset_i        ( rstn_t48           ),
    .xtal_i         ( clk                ),
    .xtal_en_i      ( cen & (~rstn_t48 | rom_ok) ),
    .clk_i          ( clk                ),
    .en_clk_i       ( xtal3              ),
    .xtal3_o        ( xtal3              ),
    .t0_i           ( 1'b0               ),
    .t1_i           ( 1'b0               ),
    .t0_o           (                    ),
    .t0_dir_o       (                    ),
    .int_n_i        ( ~irq_pending       ),
    .ea_i           ( 1'b0               ),
    .rd_n_o         (                    ),
    .wr_n_o         (                    ),
    .psen_n_o       (                    ),
    .ale_o          (                    ),
    .db_i           ( latch              ),
    .db_o           (                    ),
    .db_dir_o       (                    ),
    .p2_i           ( 8'hff              ),
    .p2_o           ( p2_out             ),
    .p2l_low_imp_o  (                    ),
    .p2h_low_imp_o  (                    ),
    .p1_i           ( 8'd0               ),
    .p1_o           ( dac                ),
    .p1_low_imp_o   (                    ),
    .prog_n_o       (                    ),
    .pmem_addr_o    ( rom_addr           ),
    .pmem_data_i    ( rom_data           ),
    .dmem_addr_o    ( ram_addr           ),
    .dmem_we_o      ( ram_we             ),
    .dmem_data_i    ( ram_dout           ),
    .dmem_data_o    ( ram_din            )
);

jtframe_ram #(.AW(8)) u_ram(
    .clk    ( clk       ),
    .cen    ( 1'b1      ),
    .data   ( ram_din   ),
    .addr   ( ram_addr  ),
    .we     ( ram_we    ),
    .q      ( ram_dout  )
);

endmodule
