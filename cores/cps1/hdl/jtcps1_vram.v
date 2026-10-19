/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */

// 192 KiB shared CPU/video RAM, implemented as three 64 KiB BRAM banks.
module jtcps1_vram(
    input           rst,
    input           clk_cpu,
    input           clk_gfx,
    output reg      hold_rst,

    input           cpu_cs,
    input           cpu_rnw,
    input   [17:1]  cpu_addr,
    input   [15:0]  cpu_din,
    input   [ 1:0]  cpu_dsn,
    output  [15:0]  cpu_dout,
    output reg      cpu_ok,

    input           gfx_cs,
    input   [17:1]  gfx_addr,
    output  [15:0]  gfx_dout,
    output reg      gfx_ok
);

wire [15:0] cpu_data[0:2], gfx_data[0:2], ram_din;
wire [15:1] ram_addr;
reg  [15:1] erase_addr;
reg  [ 1:0] cpu_bank, gfx_bank;
genvar      bank;

assign cpu_dout = cpu_bank==3 ? 16'hffff : cpu_data[cpu_bank];
assign gfx_dout = gfx_bank==3 ? 16'hffff : gfx_data[gfx_bank];
assign ram_addr = hold_rst ? erase_addr : cpu_addr[15:1];
assign ram_din  = hold_rst ? 16'd0 : cpu_din;

// Clear all three banks in parallel before releasing the CPU, just as the
// SDRAM path clears VRAM at reset. Each port acknowledges its synchronous read.
always @(posedge clk_cpu) begin
    cpu_bank <= cpu_addr[17:16];
    if(rst) begin
        erase_addr <= 0;
        hold_rst <= 1;
        cpu_ok <= 0;
    end else begin
        if(hold_rst) begin
            erase_addr <= erase_addr+1'b1;
            if(&erase_addr) hold_rst <= 0;
        end
        cpu_ok <= cpu_cs && !hold_rst;
    end
end

always @(posedge clk_gfx) begin
    gfx_bank <= gfx_addr[17:16];
    gfx_ok <= !rst && gfx_cs;
end

generate
    for(bank=0; bank<3; bank=bank+1) begin : gen_vram
        wire [1:0] we;
        assign we = hold_rst ? 2'b11 :
                    {2{cpu_cs && !cpu_rnw && cpu_addr[17:16]==bank}} & ~cpu_dsn;
        jtframe_dual_ram16 #(.AW(15)) u_ram(
            .clk0   ( clk_cpu        ),
            .addr0  ( ram_addr       ),
            .data0  ( ram_din        ),
            .we0    ( we             ),
            .q0     ( cpu_data[bank] ),
            .clk1   ( clk_gfx        ),
            .addr1  ( gfx_addr[15:1] ),
            .data1  ( 16'd0          ),
            .we1    ( 2'b00          ),
            .q1     ( gfx_data[bank] )
        );
    end
endgenerate

endmodule
