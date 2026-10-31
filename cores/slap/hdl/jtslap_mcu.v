/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 4-10-2026 */

module jtslap_mcu(
    input             rst,
    input             clk,
    input             cen,
    input             tigerh,
    input             host_wr, host_rd,
    input       [7:0] host_dout,
    output      [7:0] host_din,
    output reg        ibf, obf,
    output            flip,
    output      [7:0] scroll_data,
    output      [1:0] scroll_wr,
    output     [10:0] rom_addr,
    input       [7:0] rom_data
);

reg  [7:0] host_latch, mcu_latch, pb_out_l;
wire [7:0] pa_in, pa_out, pb_out;
wire [3:0] pc_in;
wire       ack, reply;

assign host_din = mcu_latch;
assign pa_in = pb_out[1] ? 8'hff : host_latch;
// The two semaphore inputs have opposite polarity on Tiger-Heli's MCU.
assign pc_in = {2'b11,~obf ^ tigerh,ibf ^ tigerh};
assign flip = ~pb_out[7];
assign scroll_data = pa_out;
assign scroll_wr = tigerh ? 2'b0 : pb_out_l[4:3] & ~pb_out[4:3];
assign ack = !pb_out_l[1] && pb_out[1];
assign reply = pb_out_l[2] && !pb_out[2];

always @(posedge clk) begin
    if(rst) begin
        ibf <= 0;
        obf <= 0;
        host_latch <= 8'hff;
        mcu_latch <= 8'hff;
        pb_out_l <= 8'hff;
    end else begin
        pb_out_l <= pb_out;
        if(ack) ibf <= 0;
        if(host_wr) begin
            host_latch <= host_dout;
            ibf <= 1;
        end
        if(reply) begin
            obf <= 1;
            mcu_latch <= pa_out;
        end
        if(host_rd) obf <= 0;
    end
end

jtframe_6805mcu u_6805mcu(
    .rst      ( rst       ),
    .clk      ( clk       ),
    .cen      ( cen       ),
    .wr       (           ),
    .addr     (           ),
    .dout     (           ),
    .irq      ( ibf       ),
    .timer    ( 1'b0      ),
    .pa_in    ( pa_in     ),
    .pa_out   ( pa_out    ),
    .pb_in    ( 8'hff     ),
    .pb_out   ( pb_out    ),
    .pc_in    ( pc_in     ),
    .pc_out   (           ),
    .rom_addr ( rom_addr  ),
    .rom_data ( rom_data  ),
    .rom_cs   (           )
);

endmodule
