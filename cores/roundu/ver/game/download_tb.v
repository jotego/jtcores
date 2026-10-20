/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 18-10-2026 */

`timescale 1ns/1ps

module download_tb;

reg         clk = 0;
reg         ioctl_rom = 1;
reg  [26:0] ioctl_addr = 0;
reg  [ 7:0] ioctl_dout = 0;
reg         ioctl_wr = 0;
reg         ack = 1;
wire [21:0] prog_addr;
wire [15:0] raw_data;
wire [ 1:0] prog_mask, prog_ba;
wire        prog_we;
wire [ 7:0] post_data;
integer     checked = 0;
integer     k;

always #5 clk = ~clk;

jtframe_dwnld #(
    .SDRAMW    ( 23                   ),
    .BA1_START ( `JTFRAME_BA1_START    ),
    .BA2_START ( `JTFRAME_BA2_START    ),
    .BA3_START ( `JTFRAME_BA3_START    ),
    .SWAB      ( 1                    )
) u_download (
    .clk          ( clk               ),
    .ioctl_rom    ( ioctl_rom         ),
    .ioctl_addr   ( ioctl_addr        ),
    .ioctl_dout   ( ioctl_dout        ),
    .ioctl_wr     ( ioctl_wr          ),
    .prog_addr    ( prog_addr         ),
    .prog_data    ( raw_data          ),
    .prog_mask    ( prog_mask         ),
    .prog_we      ( prog_we           ),
    .prog_rd      (                   ),
    .prog_ba      ( prog_ba           ),
    .gfx4_en      ( 1'b0              ),
    .gfx8_en      ( 1'b0              ),
    .gfx16_en     ( 1'b0              ),
    .gfx16b_en    ( 1'b0              ),
    .gfx16c_en    ( 1'b0              ),
    .prom_we      (                   ),
    .header       (                   ),
    .sdram_ack    ( ack               )
);

jtroundu_download u_adapter (
    .prog_addr ( prog_addr           ),
    .prog_data ( raw_data[7:0]        ),
    .prog_ba   ( prog_ba             ),
    .post_data ( post_data           )
);

task send_one;
    input [26:0] address;
    input [ 7:0] value;
    input integer wait_cycles;
    reg   [26:0] base;
    reg   [ 1:0] bank, mask;
    reg   [ 7:0] expected;
    integer n;
    begin
        if (address < 27'h100000) begin
            bank = 0;
            base = 0;
        end else if (address < 27'h1c0000) begin
            bank = 1;
            base = 27'h100000;
        end else if (address < 27'h280000) begin
            bank = 2;
            base = 27'h1c0000;
        end else begin
            bank = 3;
            base = 27'h280000;
        end
        expected = address >= 27'h2c0000 && address < 27'h2d0000 ? 8'h00 : value;
        mask = address[0] ? 2'b01 : 2'b10;
        @(negedge clk);
        ack = 0;
        ioctl_addr = address;
        ioctl_dout = value;
        ioctl_wr = 1;
        @(negedge clk);
        ioctl_addr = address ^ 27'h3fffff;
        ioctl_dout = ~value;
        ioctl_wr = 0;
        repeat (3) @(negedge clk);
        for (n = 0; n <= wait_cycles; n = n + 1) begin
            if (prog_we !== 1'b1 || prog_ba !== bank ||
                prog_addr !== ((address-base) >> 1) ||
                prog_mask !== mask || raw_data !== {2{value}} ||
                post_data !== expected)
                $fatal(1, "download mismatch at %h: bank=%d addr=%h mask=%b raw=%h data=%h expected=%h",
                       address, prog_ba, prog_addr, prog_mask, raw_data, post_data, expected);
            @(negedge clk);
        end
        ack = 1;
        repeat (3) @(negedge clk);
        if (prog_we !== 1'b0) $fatal(1, "write did not finish at %h", address);
        checked = checked + 1;
    end
endtask

initial begin
    repeat (3) @(negedge clk);
    send_one(27'h000000, 8'h12, 0);
    send_one(27'h07ffff, 8'h34, 1);
    send_one(27'h080000, 8'h56, 2);
    send_one(27'h0fffff, 8'h78, 3);
    send_one(27'h100000, 8'h9a, 1);
    send_one(27'h1bffff, 8'hbc, 2);
    send_one(27'h1c0000, 8'hde, 3);
    send_one(27'h27ffff, 8'hf0, 0);
    send_one(27'h280000, 8'h12, 1);
    send_one(27'h28ffff, 8'h34, 2);
    send_one(27'h290000, 8'h56, 3);
    send_one(27'h2bffff, 8'h78, 2);
    send_one(27'h2d0000, 8'h9a, 1);
    for (k = 0; k < 16; k = k + 1) begin
        send_one(27'h040000+k, k[7:0], k % 4);
        send_one(27'h140000+k, k[7:0], k % 4);
        send_one(27'h200000+k, k[7:0], k % 4);
    end
    for (k = 0; k < 65536; k = k + 1)
        send_one(27'h2c0000+k, 8'hff, k % 4);
    $display("PASS: %0d download bytes, all 65536 OKI padding bytes, bank boundaries, byte lanes and SDRAM waits", checked);
    $finish;
end

initial begin
    #20000000;
    $fatal(1, "download timeout");
end

endmodule
