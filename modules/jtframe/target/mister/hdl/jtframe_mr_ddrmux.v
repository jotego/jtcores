/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 28-2-2021 */

module jtframe_mr_ddrmux(
    input          rst,
    input          clk,
    input          ioctl_rom,
    // Fast DDR load
    input   [ 7:0] ddrld_burstcnt,
    input   [28:0] ddrld_addr,
    input          ddrld_rd,
    output         ddrld_busy,
    // Video DDR client: rotation or line-frame buffer
    input          rot_clk,
    input   [ 7:0] rot_burstcnt,
    input   [28:0] rot_addr,
    input          rot_rd,
    input          rot_we,
    input          rot_lock, // the video client has a burst open
    input   [ 7:0] rot_be,
    input   [63:0] rot_din,
    output         rot_busy,
    // DDR Signals
    output         ddr_clk,
    input          ddr_busy,
    output  [ 7:0] ddr_burstcnt,
    output  [28:0] ddr_addr,
    output         ddr_rd,
    output  [ 7:0] ddr_be,
    output         ddr_we,
    output  [63:0] ddr_din
);

`ifdef JTFRAME_MR_DDRLOAD
    localparam DDRLOAD=1;
`else
    localparam DDRLOAD=0;
`endif

`ifdef JTFRAME_VERTICAL
    localparam VERTICAL=1;
`else
    localparam VERTICAL=0;
`endif

`ifdef JTFRAME_LF_BUFFER
    localparam LFBUF=1;
`else
    localparam LFBUF=0;
`endif

reg ddrld_en;

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        ddrld_en <= 0;
    // Keep the owner while the video client has a burst open on the bus.
    // A client burst that opens while the loader owns the port has not
    // reached the bus yet: it waits on busy and does not hold the switch.
    end else if(!ddr_busy && !(rot_lock && !ddrld_en)) begin
        case( {DDRLOAD[0], VERTICAL[0] || LFBUF[0]} )
            2'b00: ddrld_en <= 0; // don't care
            // the video DDR client may be the regression capture writer
            2'b10: ddrld_en <= ioctl_rom;
            2'b01: ddrld_en <= 0;
            2'b11: ddrld_en <= ioctl_rom;
        endcase
    end
end

assign ddr_clk = ddrld_en ? clk : rot_clk;

// This simple mux allows for bad data transfers when switching from ROM download
// to the frame buffer, but it shouldn't be a problem

assign ddr_burstcnt = ddrld_en ? ddrld_burstcnt : rot_burstcnt;
assign ddr_addr     = ddrld_en ? ddrld_addr     : rot_addr;
assign ddr_rd       = ddrld_en ? ddrld_rd       : rot_rd;
assign ddr_be       = ddrld_en ? 8'hff          : rot_be;
assign ddr_we       = ddrld_en ? 1'b0           : rot_we;
assign ddr_din      = ddrld_en ? 64'd0          : rot_din;

assign ddrld_busy   = ~ddrld_en | ddr_busy;
assign rot_busy     =  ddrld_en | ddr_busy;

endmodule