/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 24-10-2026 */

module jtroundu_txram_model #(
    parameter SIMFILE="", ERASE=0
)(
    input             rst,
    input             clk,
    input      [16:0] cpu_addr,
    input       [7:0] cpu_din,
    output      [7:0] cpu_dout,
    input             cpu_cs,
    input             cpu_we,
    output            cpu_ok,
    input      [16:0] gfx_addr,
    input             gfx_cs,
    output      [7:0] gfx_data,
    output            gfx_ok,
    input      [31:0] waits
);

wire [15:0] ram_addr, ram_din, ram_data;
wire ram_cs, ram_we, ram_ok;
wire [1:0] ram_dsn;
wire [21:0] sdram_addr;
wire rd, wr, hold_rst;
wire [15:0] sdram_din;
wire [1:0] sdram_dsn;
reg ack=0, dst=0, rdy=0;
reg [15:0] data=0;
reg [15:0] mem [0:65535];
reg [7:0] raw [0:131071];
reg pending=0, seen=0, write_pending;
reg [15:0] address, value;
reg [1:0] mask;
integer delay_count=0, transactions=0, reads=0, writes=0, i, fd, count;

jtroundu_txram u_arb (
    .rst      ( rst || hold_rst ),
    .clk      ( clk             ),
    .cpu_addr ( cpu_addr        ),
    .cpu_din  ( cpu_din         ),
    .cpu_dout ( cpu_dout        ),
    .cpu_cs   ( cpu_cs          ),
    .cpu_we   ( cpu_we          ),
    .cpu_ok   ( cpu_ok          ),
    .gfx_addr ( gfx_addr        ),
    .gfx_cs   ( gfx_cs          ),
    .gfx_data ( gfx_data        ),
    .gfx_ok   ( gfx_ok          ),
    .ram_addr ( ram_addr        ),
    .ram_din  ( ram_din         ),
    .ram_data ( ram_data        ),
    .ram_cs   ( ram_cs          ),
    .ram_we   ( ram_we          ),
    .ram_dsn  ( ram_dsn         ),
    .ram_ok   ( ram_ok          )
);

jtframe_ram1_1slot #(
    .SDRAMW      ( 22    ),
    .SLOT0_AW    ( 16    ),
    .SLOT0_DW    ( 16    ),
    .SLOT0_ERASE ( ERASE )
) u_bank (
    .rst          ( rst          ),
    .clk          ( clk          ),
    .slot0_addr   ( ram_addr     ),
    .slot0_dout   ( ram_data     ),
    .slot0_din    ( ram_din      ),
    .slot0_offset ( 22'd0        ),
    .slot0_cs     ( ram_cs       ),
    .slot0_ok     ( ram_ok       ),
    .slot0_wen    ( ram_we       ),
    .slot0_wrmask ( ram_dsn      ),
    .hold_rst     ( hold_rst     ),
    .sdram_ack    ( ack          ),
    .sdram_rd     ( rd           ),
    .sdram_wr     ( wr           ),
    .sdram_addr   ( sdram_addr   ),
    .data_rdy     ( rdy          ),
    .data_dst     ( dst          ),
    .data_read    ( data         ),
    .data_write   ( sdram_din    ),
    .sdram_wrmask ( sdram_dsn    )
);

always @(posedge clk) begin
    ack <= 0;
    dst <= 0;
    rdy <= 0;
    if (rst) begin
        pending <= 0;
        seen <= 0;
    end else begin
        if (!rd && !wr) seen <= 0;
        if (!pending && !seen && (rd || wr)) begin
            if (sdram_addr >= 65536) $fatal(1,"text SDRAM address exceeds 128KiB");
            transactions <= transactions+1;
            reads <= reads + (rd ? 1 : 0);
            writes <= writes + (wr ? 1 : 0);
            pending <= 1;
            seen <= 1;
            ack <= 1;
            address <= sdram_addr[15:0];
            value <= sdram_din;
            mask <= sdram_dsn;
            write_pending <= wr;
            delay_count <= waits + sdram_addr % 3;
        end else if (pending) begin
            if (delay_count != 0) delay_count <= delay_count-1;
            else begin
                if (write_pending) begin
                    if (!mask[0]) mem[address][7:0] <= value[7:0];
                    if (!mask[1]) mem[address][15:8] <= value[15:8];
                end
                data <= mem[address];
                dst <= 1;
                rdy <= 1;
                pending <= 0;
            end
        end
    end
end

initial begin
    for (i=0;i<131072;i=i+1) raw[i]=(i*37+(i>>8))&255;
    if (SIMFILE != "") begin
        fd=$fopen(SIMFILE,"rb"); count=$fread(raw,fd); $fclose(fd);
        if (count != 131072) $fatal(1,"incomplete text RAM capture");
    end
    for (i=0;i<65536;i=i+1) mem[i]={raw[2*i+1],raw[2*i]};
end

endmodule
