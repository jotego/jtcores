/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 24-10-2026 */

module jtroundu_txram(
    input             rst,
    input             clk,
    input      [16:0] cpu_addr,
    input       [7:0] cpu_din,
    output reg  [7:0] cpu_dout,
    input             cpu_cs,
    input             cpu_we,
    output reg        cpu_ok,
    input      [16:0] gfx_addr,
    input             gfx_cs,
    output reg  [7:0] gfx_data,
    output reg        gfx_ok,
    output reg [16:1] ram_addr,
    output reg [15:0] ram_din,
    input      [15:0] ram_data,
    output reg        ram_cs,
    output reg        ram_we,
    output reg  [1:0] ram_dsn,
    input             ram_ok
);

reg owner, odd;
wire [7:0] selected = odd ? ram_data[15:8] : ram_data[7:0];

always @(posedge clk) begin
    if (rst) begin
        cpu_dout <= 0;
        cpu_ok <= 0;
        gfx_data <= 0;
        gfx_ok <= 0;
        ram_addr <= 0;
        ram_din <= 0;
        ram_cs <= 0;
        ram_we <= 0;
        // The RW slot uses this mask during reset-time erasure.
        ram_dsn <= 2'b00;
        owner <= 0;
        odd <= 0;
    end else begin
        if (!cpu_cs) cpu_ok <= 0;
        if (!gfx_cs) gfx_ok <= 0;
        if (ram_cs) begin
            if (ram_ok) begin
                ram_cs <= 0;
                if (owner) begin
                    gfx_data <= selected;
                    gfx_ok <= 1;
                end else begin
                    cpu_dout <= selected;
                    cpu_ok <= 1;
                end
            end
        end else if (gfx_cs && !gfx_ok) begin
            ram_addr <= gfx_addr[16:1];
            ram_din <= 0;
            ram_cs <= 1;
            ram_we <= 0;
            ram_dsn <= 2'b11;
            owner <= 1;
            odd <= gfx_addr[0];
        end else if (cpu_cs && !cpu_ok) begin
            ram_addr <= cpu_addr[16:1];
            ram_din <= {2{cpu_din}};
            ram_cs <= 1;
            ram_we <= cpu_we;
            ram_dsn <= {~cpu_addr[0],cpu_addr[0]};
            owner <= 0;
            odd <= cpu_addr[0];
        end
    end
end

endmodule
