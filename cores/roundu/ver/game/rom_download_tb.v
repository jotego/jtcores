/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 18-10-2026 */

`timescale 1ns/1ps

module rom_download_tb;

reg         clk = 0;
reg         ioctl_rom = 1;
reg  [26:0] ioctl_addr = 0;
reg  [ 7:0] ioctl_dout = 0;
reg         ioctl_wr = 0;
reg  [ 2:0] phase = 0;
wire        ack = phase != 0 && phase != 1;
wire [21:0] prog_addr;
wire [15:0] raw_data;
wire [ 1:0] prog_mask, prog_ba;
wire        prog_we;
wire [ 7:0] post_data;
reg  [ 7:0] payload [0:2949119];
reg  [15:0] bank0 [0:524287];
reg  [15:0] bank1 [0:393215];
reg  [15:0] bank2 [0:393215];
reg  [15:0] bank3 [0:163839];
string      rom_path;
integer     fd, bytes_read, writes = 0;
integer     i;

always #5 clk = ~clk;
always @(posedge clk) phase <= phase + 1'd1;

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

always @(posedge clk) begin
    if (prog_we && ack) begin
        case (prog_ba)
            0: begin
                if (prog_addr >= 524288) $fatal(1, "bank 0 overflow");
                if (!prog_mask[0]) bank0[prog_addr][ 7:0] <= post_data;
                if (!prog_mask[1]) bank0[prog_addr][15:8] <= post_data;
            end
            1: begin
                if (prog_addr >= 393216) $fatal(1, "bank 1 overflow");
                if (!prog_mask[0]) bank1[prog_addr][ 7:0] <= post_data;
                if (!prog_mask[1]) bank1[prog_addr][15:8] <= post_data;
            end
            2: begin
                if (prog_addr >= 393216) $fatal(1, "bank 2 overflow");
                if (!prog_mask[0]) bank2[prog_addr][ 7:0] <= post_data;
                if (!prog_mask[1]) bank2[prog_addr][15:8] <= post_data;
            end
            3: begin
                if (prog_addr >= 163840) $fatal(1, "bank 3 overflow");
                if (!prog_mask[0]) bank3[prog_addr][ 7:0] <= post_data;
                if (!prog_mask[1]) bank3[prog_addr][15:8] <= post_data;
            end
        endcase
        writes = writes + 1;
    end
end

initial begin
    if (!$value$plusargs("ROM=%s", rom_path)) $fatal(1, "missing ROM argument");
    fd = $fopen(rom_path, "rb");
    if (!fd) $fatal(1, "cannot open ROM");
    bytes_read = $fread(payload, fd);
    $fclose(fd);
    if (bytes_read != 2949120) $fatal(1, "incorrect ROM size %d", bytes_read);
    repeat (3) @(negedge clk);
    for (i = 0; i < bytes_read; i = i + 1) begin
        while (prog_we) @(negedge clk);
        ioctl_addr = i;
        ioctl_dout = payload[i];
        ioctl_wr = 1;
        @(negedge clk);
        ioctl_wr = 0;
        repeat (3) @(negedge clk);
        if ((i & 20'hfffff) == 20'hfffff) $display("Downloaded %0d bytes", i+1);
    end
    while (prog_we) @(negedge clk);
    repeat (4) @(negedge clk);
    if (writes != bytes_read) $fatal(1, "%d accepted writes for %d bytes", writes, bytes_read);
    fd = $fopen("sdram_bank0.bin", "wb");
    for (i = 0; i < 524288; i = i + 1) $fwrite(fd, "%c%c", bank0[i][15:8], bank0[i][7:0]);
    $fclose(fd);
    fd = $fopen("sdram_bank1.bin", "wb");
    for (i = 0; i < 393216; i = i + 1) $fwrite(fd, "%c%c", bank1[i][15:8], bank1[i][7:0]);
    $fclose(fd);
    fd = $fopen("sdram_bank2.bin", "wb");
    for (i = 0; i < 393216; i = i + 1) $fwrite(fd, "%c%c", bank2[i][15:8], bank2[i][7:0]);
    $fclose(fd);
    fd = $fopen("sdram_bank3.bin", "wb");
    for (i = 0; i < 163840; i = i + 1) $fwrite(fd, "%c%c", bank3[i][15:8], bank3[i][7:0]);
    $fclose(fd);
    $display("PASS: all %0d real-ROM bytes downloaded with SDRAM waits", writes);
    $finish;
end

initial begin
    #1000000000;
    $fatal(1, "ROM download timeout");
end

endmodule
