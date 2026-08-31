/* SPDX-License-Identifier: GPL-3.0-or-later */

module jtmoomsa_eeprom_io(
    input            clk,
    input            rst,
    input            lds_n,
    input            reg_write,
    input      [3:0]  cpu_dout,
    input            cpu_dout5,
    output            eeprom_do,
    output            eeprom_rdy,
    output            k51550_si,
    output            irq_set
`ifdef JTFRAME_SAVEGAME
    ,output reg       sav_change,
    output reg        sav_wait,
    output            sav_done,
    input      [1:0]  sav_wr,
    input             sav_ack,
    output     [15:0] sav_din,
    input      [15:0] sav_dout,
    input      [15:0] sav_addr
`endif
`ifdef JTFRAME_IOCTL_RD
    ,input      [15:0] ioctl_addr,
    input             ioctl_ram,
    input             ioctl_wr,
    input      [7:0]  ioctl_dout,
    output     [7:0]  ioctl_din
`endif
);

reg [3:0] q;
reg q5;
reg q4_clk_d;
wire q4_clk = lds_n | ~reg_write;
wire [6:0] mem8_addr;
wire [7:0] mem8_din, mem8_dout;
wire mem8_we;
wire eeprom8_do, eeprom8_rdy;
reg [7:0] nvram8 [0:127];

`ifdef JTFRAME_SAVEGAME
wire       save_addr_valid = (sav_addr[15:7] == 9'd0);
wire [6:0] save_word_addr = {sav_addr[6:1],1'b0};
`endif

always @(posedge clk or posedge rst) begin
    if (rst) begin
        q <= 4'd0;
        q5 <= 1'b0;
        q4_clk_d <= 1'b1;
    end else begin
        q4_clk_d <= q4_clk;
        if (q4_clk && !q4_clk_d) begin
            q <= cpu_dout[3:0];
            q5 <= cpu_dout5;
        end
    end
end

always @(posedge clk or posedge rst) begin
    if (rst) begin
`ifdef JTFRAME_SAVEGAME
        sav_change <= 1'b0;
        sav_wait   <= 1'b0;
`endif
    end else begin
`ifdef JTFRAME_IOCTL_RD
        // NVRAM download uses the same byte-addressed stream that the dump
        // side reads. It is distinct from normal ROM programming because
        // ioctl_ram qualifies the write.
        if (ioctl_wr && ioctl_ram && (ioctl_addr[15:7] == 9'd0)) begin
            nvram8[ioctl_addr[6:0]] <= ioctl_dout;
`ifdef JTFRAME_SAVEGAME
            sav_change <= 1'b0;
`endif
        end else
`endif
        if (mem8_we) begin
            nvram8[mem8_addr] <= mem8_din;
`ifdef JTFRAME_SAVEGAME
            sav_change <= 1'b1;
`endif
        end
`ifdef JTFRAME_SAVEGAME
        // JTFRAME presents one 16-bit save word at a time. The ER5911 is
        // 128x8, so two adjacent EEPROM bytes occupy one save word.
        // Hold the core busy for one cycle after accepting an access. The
        // controller keeps sav_ack asserted until sav_wait is released.
        if (sav_ack && !sav_wait) begin
            sav_wait <= 1'b1;
            if (save_addr_valid && sav_wr[0])
                nvram8[save_word_addr] <= sav_dout[7:0];
            if (save_addr_valid && sav_wr[1])
                nvram8[save_word_addr + 7'd1] <= sav_dout[15:8];
            if (save_addr_valid && sav_done)
                sav_change <= 1'b0;
        end else if (sav_wait) begin
            sav_wait <= 1'b0;
        end
`endif
    end
end

assign k51550_si = q[3];
assign irq_set    = q5;

assign mem8_dout  = nvram8[mem8_addr];
assign eeprom_do  = eeprom8_do;
assign eeprom_rdy = eeprom8_rdy;

`ifdef JTFRAME_SAVEGAME
assign sav_din  = save_addr_valid
                ? {nvram8[save_word_addr + 7'd1],nvram8[save_word_addr]}
                : 16'h0000;
assign sav_done = save_addr_valid && (sav_addr[6:0] == 7'h7f);
`endif

`ifdef JTFRAME_IOCTL_RD
// JTFRAME uses the same ioctl_ram indication for the NVRAM load and dump.
// Keep the read window bounded to the physical 128-byte ER5911 organization.
assign ioctl_din = (ioctl_ram && (ioctl_addr[15:7] == 9'd0))
                 ? nvram8[ioctl_addr[6:0]] : 8'h00;
`endif

// Direct KiCad source: 15A1 ER5911 ORG is tied to VSS, so the live device is
// the fixed 128x8 organization. 16A1 EVQQ5911 is a separate passive switch;
// Q4's fourth output is not promoted into the EEPROM path.
/* JT5911 dump status has no PCB connection. */
/* verilator lint_off PINMISSING */
jt5911 #(.PROG(0)) u_eeprom8(
    .rst        ( rst        ),
    .clk        ( clk        ),
    // PCB Q-latch connectivity: Q0=DI, Q1=CS, Q2=serial clock.
    .sclk       ( q[2]       ),
    .sdi        ( q[0]       ),
    .sdo        ( eeprom8_do ),
    .rdy        ( eeprom8_rdy ),
    .scs        ( q[1]       ),
    .mem_addr   ( mem8_addr  ),
    .mem_din    ( mem8_din   ),
    .mem_we     ( mem8_we    ),
    .mem_dout   ( mem8_dout  ),
    .dump_clr   ( 1'b0       )
);
/* verilator lint_on PINMISSING */

endmodule
