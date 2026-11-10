// SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
// SPDX-License-Identifier: GPL-3.0-only
// Date: 2026-11-08
// CPU-side interfaces for the Nemesis color and graphics RAMs.
// Storage and synchronous read latency are supplied by JTFRAME's generated
// dual-port BRAM wrapper.

`default_nettype none

module jtnemsis_video_bram_if(
    input      [15:1] cpu_addr,
    input      [15:0] cpu_din,
    input             uds_n,
    input             lds_n,
    input             rnw,
    input             chacs_n,
    input             objram_n,
    input             vcs1,
    input             vcs2,
    input             vzcs,

    output     [10:0] scroll_cpu_addr,
    output     [ 7:0] scroll_cpu_din,
    output            scroll_cpu_we,
    input      [ 7:0] scroll_cpu_dout,

    output     [10:0] obj_cpu_addr,
    output     [ 7:0] obj_cpu_din,
    output            obj_cpu_we,
    input      [ 7:0] obj_cpu_dout,

    output     [12:1] vram1_cpu_addr,
    output     [15:0] vram1_cpu_din,
    output     [ 1:0] vram1_cpu_we,
    input      [15:0] vram1_cpu_dout,

    output     [11:0] vram2_cpu_addr,
    output     [ 7:0] vram2_cpu_din,
    output            vram2_cpu_we,
    input      [ 7:0] vram2_cpu_dout,

    output     [15:2] char_cpu_addr,
    output     [31:0] char_cpu_din,
    output     [ 3:0] char_cpu_we,
    input      [31:0] char_cpu_dout,

    output reg [15:0] cpu_dout
);

wire chacs1, chacs2;

assign chacs1 = |{ cpu_addr[1], chacs_n };
assign chacs2 = |{ ~cpu_addr[1], chacs_n };

assign scroll_cpu_addr = cpu_addr[11:1];
assign scroll_cpu_din  = cpu_din[7:0];
assign scroll_cpu_we   = &{ ~vzcs, ~rnw, ~lds_n };

assign obj_cpu_addr = cpu_addr[11:1];
assign obj_cpu_din  = cpu_din[7:0];
assign obj_cpu_we   = &{ ~objram_n, ~rnw, ~lds_n };

assign vram1_cpu_addr = cpu_addr[12:1];
assign vram1_cpu_din  = cpu_din;
assign vram1_cpu_we   = { &{ ~vcs1, ~rnw, ~uds_n },
                          &{ ~vcs1, ~rnw, ~lds_n } };

assign vram2_cpu_addr = cpu_addr[12:1];
assign vram2_cpu_din  = cpu_din[7:0];
assign vram2_cpu_we   = &{ ~vcs2, ~rnw, ~lds_n };

assign char_cpu_addr = cpu_addr[15:2];
assign char_cpu_din  = { 2{cpu_din} };
assign char_cpu_we   = { &{ ~chacs2, ~rnw, ~uds_n },
                         &{ ~chacs2, ~rnw, ~lds_n },
                         &{ ~chacs1, ~rnw, ~uds_n },
                         &{ ~chacs1, ~rnw, ~lds_n } };

always @* begin
    case( 1'b0 )
        vzcs:     cpu_dout = { 8'h00, scroll_cpu_dout };
        objram_n: cpu_dout = { 8'h00, obj_cpu_dout };
        vcs1:     cpu_dout = vram1_cpu_dout;
        vcs2:     cpu_dout = { 8'h00, vram2_cpu_dout };
        chacs1:   cpu_dout = char_cpu_dout[15:0];
        chacs2:   cpu_dout = char_cpu_dout[31:16];
        default:  cpu_dout = 16'hffff;
    endcase
end

endmodule

`default_nettype wire
