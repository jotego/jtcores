/* SPDX-FileCopyrightText: 2026 Chris Watson
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 31-8-2026 */

// Road RAM CPU-port arbiter, CPU sheet 3/6.
//
// The board puts road RAM on the SUB bus and decodes no ROAD select for the
// main, so the sub owns this port and the road engine reads the other side of
// the dual-port. The main's writes are merged in on free cycles anyway, because
// the firmware writes 256 words at every title/attract transition.
//
// One pending write is enough: a 68000 write is ~19 clk against a sub access
// that holds sub_cs for at most one, so the latch cannot back up.

module jtharier_roadarb(
    input             rst,
    input             clk,

    // Main CPU bus
    input             main_cs,
    input             main_rnw,
    input      [ 1:0] main_dsn,
    input      [11:1] main_addr,
    input      [15:0] main_dout,

    // Sub CPU bus, which owns the port
    input             sub_cs,
    input             sub_rnw,
    input      [ 1:0] sub_dsn,
    input      [11:1] sub_addr,
    input      [15:0] sub_dout,

    // Road RAM port 0
    output     [11:1] ram_addr,
    output     [15:0] ram_din,
    output     [ 1:0] ram_we
);

reg  [11:1] pend_addr;
reg  [15:0] pend_din;
reg  [ 1:0] pend_we;
reg         pend, main_wr_l;

wire [ 1:0] main_road_we = main_cs & ~main_rnw ? ~main_dsn : 2'b00;
wire        main_wr      = |main_road_we;

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        pend_addr <= 0;
        pend_din  <= 0;
        pend_we   <= 0;
        pend      <= 0;
        main_wr_l <= 0;
    end else begin
        main_wr_l <= main_wr;
        if( main_wr & ~main_wr_l ) begin
            pend_addr <= main_addr;
            pend_din  <= main_dout;
            pend_we   <= main_road_we;
            pend      <= 1;
        end else if( pend & ~sub_cs ) begin
            pend <= 0;      // served on this cycle by the mux below
        end
    end
end

assign ram_addr = sub_cs ? sub_addr : pend_addr;
assign ram_din  = sub_cs ? sub_dout : pend_din;
assign ram_we   = sub_cs ? (~sub_rnw ? ~sub_dsn : 2'b00) :
                  pend   ? pend_we : 2'b00;

endmodule
