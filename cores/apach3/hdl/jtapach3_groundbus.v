/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 29-10-2026 */

module jtapach3_groundbus #(
    parameter INIT = 1
)(
    input             rst,
    input             clk,
    output reg        initialized,
    input      [15:1] cpu_addr,
    input      [15:0] cpu_din,
    input       [1:0] cpu_dsn,
    input             cpu_cs,
    input             cpu_we,
    output reg [15:0] cpu_dout,
    output reg        cpu_ok,
    input      [15:1] video_addr,
    input             video_cs,
    output reg [15:0] video_dout,
    output reg        video_ok,
    output reg [15:1] ram_addr,
    output reg [15:0] ram_din,
    output reg  [1:0] ram_dsn,
    output reg        ram_cs,
    output reg        ram_we,
    input      [15:0] ram_dout,
    input             ram_ok
);

reg owner;
reg [14:0] clear_addr;

always @(posedge clk) begin
    if (rst) begin
        cpu_dout <= 0;
        cpu_ok <= 0;
        video_dout <= 0;
        video_ok <= 0;
        ram_addr <= 0;
        ram_din <= 0;
        ram_dsn <= 0;
        ram_cs <= 0;
        ram_we <= 0;
        owner <= 0;
        initialized <= !INIT;
        clear_addr <= 0;
    end else begin
        if (!initialized) begin
            if (ram_cs && ram_ok) begin
                ram_cs <= 0;
                if (&clear_addr) initialized <= 1;
                else clear_addr <= clear_addr + 1'b1;
            end else if (!ram_cs) begin
                ram_addr <= clear_addr;
                ram_din <= 0;
                ram_dsn <= 0;
                ram_we <= 1;
                ram_cs <= 1;
            end
        end else begin
        if (!cpu_cs) cpu_ok <= 0;
        if (!video_cs) video_ok <= 0;
        if (ram_cs) begin
            if (ram_ok) begin
                ram_cs <= 0;
                if (owner) begin
                    video_dout <= ram_dout;
                    video_ok <= 1;
                end else begin
                    cpu_dout <= ram_dout;
                    cpu_ok <= 1;
                end
            end
        end else if (video_cs && !video_ok) begin
            ram_addr <= video_addr;
            ram_din <= 0;
            ram_dsn <= 2'b11;
            ram_we <= 0;
            ram_cs <= 1;
            owner <= 1;
        end else if (cpu_cs && !cpu_ok) begin
            ram_addr <= cpu_addr;
            ram_din <= cpu_din;
            ram_dsn <= cpu_dsn;
            ram_we <= cpu_we;
            ram_cs <= 1;
            owner <= 0;
        end
        end
    end
end

endmodule
