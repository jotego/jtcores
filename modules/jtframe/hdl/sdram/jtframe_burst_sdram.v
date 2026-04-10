/*  This file is part of JTFRAME.
    JTFRAME program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTFRAME program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTFRAME.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Date: 20-3-2026 */

// Programming mode matches jtframe_sdram64.
// Burst mode switches the SDRAM to full-page sequential bursts and exposes
// a single consumer port that can stop the transfer by lowering rd/wr.
/* verilator lint_off TIMESCALEMOD */
/* verilator coverage_off */
module jtframe_burst_sdram #(
    parameter AW       = 22,
              HF       = 1,
              MISTER   = 1,
              RFSHCNT  = 9,
              PROG_LEN = 64
)(
    input               rst,
    input               clk,
    output              init,

    input      [AW-1:0] addr,
    input        [ 1:0] ba,
    input               rd,
    input               wr,
    input       [15:0]  din,
    output      [15:0]  dout,
    output              ack,
    output              dst,
    output              dok,
    output              rdy,

    input               prog_en,
    input      [AW-1:0] prog_addr,
    input               prog_rd,
    input               prog_wr,
    input       [15:0]  prog_din,
    input        [ 1:0] prog_dsn,
    input        [ 1:0] prog_ba,
    output              prog_dst,
    output              prog_dok,
    output              prog_rdy,
    output              prog_ack,

    input               rfsh,

    inout      [15:0]   sdram_dq,
`ifdef VERILATOR
    output     [15:0]   sdram_din,
`endif
    output     [12:0]   sdram_a,
    output              sdram_dqml,
    output              sdram_dqmh,
    output      [ 1:0]  sdram_ba,
    output              sdram_nwe,
    output              sdram_ncas,
    output              sdram_nras,
    output              sdram_ncs,
    output              sdram_cke
);

wire        pre_dst, pre_dok, pre_ack, pre_rdy;
wire        pre_br, pre_idle;
wire [12:0] pre_a;
wire [ 3:0] pre_cmd;
wire        rfsh_br, rfshing, help;
wire [12:0] rfsh_a, init_a;
wire [ 3:0] rfsh_cmd, init_cmd;

wire        prog_rst, rfsh_rst;
wire [ 3:0] mode_cmd;
wire [12:0] mode_a;
wire        mode_busy;

wire        prog_noreq = !(prog_rd | prog_wr);
wire        burst_noreq = !(rd | wr);
wire        burst_idle;
wire        noreq = prog_en ? prog_noreq : burst_noreq;
wire        rfsh_bg = !mode_busy && (prog_en ? (pre_idle && (noreq | help)) :
                                     (burst_idle && (noreq | help))) && rfsh_br;
wire        prog_bg = pre_br & !rfshing & !mode_busy;

wire [ 3:0] burst_cmd;
wire [12:0] burst_a;
wire [ 1:0] burst_ba;
wire [ 1:0] burst_dqm;
wire        burst_dq_oe;
wire [15:0] burst_dq_out;
wire        burst_ack;
wire        burst_dst;
wire        burst_dok;
wire        burst_rdy;

wire        next_dq_oe;
wire [15:0] next_dq;
wire [ 3:0] sel_cmd;
wire [12:0] sel_a;
wire [ 1:0] sel_ba;
wire [ 1:0] sel_dqm;
wire        sel_ack;
wire        sel_dst;
wire        sel_dok;
wire        sel_rdy;
wire        sel_prog_ack;
wire        sel_prog_dst;
wire        sel_prog_dok;
wire        sel_prog_rdy;

jtframe_sdram64_init #(
    .HF      ( HF       ),
    .BURSTLEN( PROG_LEN )
) u_init(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .init       ( init      ),
    .cmd        ( init_cmd  ),
    .sdram_a    ( init_a    )
);

jtframe_burst_mode #(
    .PROG_LEN( PROG_LEN )
) u_mode(
    .rst            ( rst            ),
    .clk            ( clk            ),
    .init           ( init           ),
    .prog_en        ( prog_en        ),
    .rfshing        ( rfshing        ),
    .pre_idle       ( pre_idle       ),
    .burst_idle     ( burst_idle     ),
    .prog_rst       ( prog_rst       ),
    .rfsh_rst       ( rfsh_rst       ),
    .mode_busy      ( mode_busy      ),
    .mode_cmd       ( mode_cmd       ),
    .mode_a         ( mode_a         )
);

jtframe_sdram64_rfsh #(
    .HF      ( HF       ),
    .RFSHCNT ( RFSHCNT  )
) u_rfsh(
    .rst        ( rfsh_rst  ),
    .clk        ( clk       ),
    .start      ( rfsh      ),
    .br         ( rfsh_br   ),
    .bg         ( rfsh_bg   ),
    .noreq      ( noreq     ),
    .rfshing    ( rfshing   ),
    .cmd        ( rfsh_cmd  ),
    .help       ( help      ),
    .sdram_a    ( rfsh_a    )
);

jtframe_sdram64_bank #(
    .AW            ( AW       ),
    .HF            ( HF       ),
    .SHIFTED       ( 0        ),
    .BALEN         ( PROG_LEN ),
    .BURSTLEN      ( PROG_LEN ),
    .AUTOPRECH     ( 1        ),
    .PRECHARGE_ALL ( 1        )
) u_prog(
    .rst        ( prog_rst   ),
    .clk        ( clk        ),
    .help       ( 1'b0       ),
    .addr       ( prog_addr  ),
    .rd         ( prog_rd    ),
    .wr         ( prog_wr    ),
    .ack        ( pre_ack    ),
    .dst        ( pre_dst    ),
    .dbusy      (            ),
    .all_dbusy  ( 1'b0       ),
    .idle       ( pre_idle   ),
    .dbusy64    (            ),
    .all_dbusy64( 1'b0       ),
    .post_act   (            ),
    .all_act    ( 1'b0       ),
    .dqm_busy   (            ),
    .all_dqm    ( 1'b0       ),
    .wr_busy    (            ),
    .row        (            ),
    .match      ( 1'b0       ),
    .dok        ( pre_dok    ),
    .rdy        ( pre_rdy    ),
    .set_prech  ( 1'b0       ),
    .br         ( pre_br     ),
    .bg         ( prog_bg    ),
    .sdram_a    ( pre_a      ),
    .cmd        ( pre_cmd    )
);

jtframe_burst_ctrl #(
    .AW( AW )
) u_burst(
    .rst                ( rst                  ),
    .clk                ( clk                  ),
    .prog_en            ( prog_en              ),
    .mode_busy          ( mode_busy            ),
    .rfshing            ( rfshing              ),
    .addr               ( addr                 ),
    .ba                 ( ba                   ),
    .rd                 ( rd                   ),
    .wr                 ( wr                   ),
    .din                ( din                  ),
    .burst_idle         ( burst_idle           ),
    .burst_cmd          ( burst_cmd            ),
    .burst_a            ( burst_a              ),
    .burst_ba           ( burst_ba             ),
    .burst_dqm          ( burst_dqm            ),
    .burst_dq_oe        ( burst_dq_oe          ),
    .burst_dq_out       ( burst_dq_out         ),
    .burst_ack          ( burst_ack            ),
    .burst_dst          ( burst_dst            ),
    .burst_dok          ( burst_dok            ),
    .burst_rdy          ( burst_rdy            )
);

jtframe_burst_mux u_mux(
    .init           ( init           ),
    .mode_busy      ( mode_busy      ),
    .rfshing        ( rfshing        ),
    .prog_en        ( prog_en        ),
    .prog_wr        ( prog_wr        ),
    .prog_din       ( prog_din       ),
    .prog_dsn       ( prog_dsn       ),
    .prog_ba        ( prog_ba        ),
    .pre_cmd        ( pre_cmd        ),
    .pre_a          ( pre_a          ),
    .pre_ack        ( pre_ack        ),
    .pre_dst        ( pre_dst        ),
    .pre_dok        ( pre_dok        ),
    .pre_rdy        ( pre_rdy        ),
    .init_cmd       ( init_cmd       ),
    .init_a         ( init_a         ),
    .rfsh_cmd       ( rfsh_cmd       ),
    .rfsh_a         ( rfsh_a         ),
    .mode_cmd       ( mode_cmd       ),
    .mode_a         ( mode_a         ),
    .burst_cmd      ( burst_cmd      ),
    .burst_a        ( burst_a        ),
    .burst_ba       ( burst_ba       ),
    .burst_dqm      ( burst_dqm      ),
    .burst_dq_oe    ( burst_dq_oe    ),
    .burst_dq_out   ( burst_dq_out   ),
    .burst_ack      ( burst_ack      ),
    .burst_dst      ( burst_dst      ),
    .burst_dok      ( burst_dok      ),
    .burst_rdy      ( burst_rdy      ),
    .next_dq_oe     ( next_dq_oe     ),
    .next_dq        ( next_dq        ),
    .sel_cmd        ( sel_cmd        ),
    .sel_a          ( sel_a          ),
    .sel_ba         ( sel_ba         ),
    .sel_dqm        ( sel_dqm        ),
    .sel_ack        ( sel_ack        ),
    .sel_dst        ( sel_dst        ),
    .sel_dok        ( sel_dok        ),
    .sel_rdy        ( sel_rdy        ),
    .sel_prog_ack   ( sel_prog_ack   ),
    .sel_prog_dst   ( sel_prog_dst   ),
    .sel_prog_dok   ( sel_prog_dok   ),
    .sel_prog_rdy   ( sel_prog_rdy   )
);

jtframe_burst_io #(
    .MISTER( MISTER )
) u_io(
    .rst            ( rst            ),
    .clk            ( clk            ),
    .sdram_dq       ( sdram_dq       ),
`ifdef VERILATOR
    .sdram_din      ( sdram_din      ),
`endif
    .sdram_a        ( sdram_a        ),
    .sdram_ba       ( sdram_ba       ),
    .sdram_dqml     ( sdram_dqml     ),
    .sdram_dqmh     ( sdram_dqmh     ),
    .sdram_nwe      ( sdram_nwe      ),
    .sdram_ncas     ( sdram_ncas     ),
    .sdram_nras     ( sdram_nras     ),
    .sdram_ncs      ( sdram_ncs      ),
    .sdram_cke      ( sdram_cke      ),
    .dout           ( dout           ),
    .ack            ( ack            ),
    .dst            ( dst            ),
    .dok            ( dok            ),
    .rdy            ( rdy            ),
    .prog_ack       ( prog_ack       ),
    .prog_dst       ( prog_dst       ),
    .prog_dok       ( prog_dok       ),
    .prog_rdy       ( prog_rdy       ),
    .next_dq_oe     ( next_dq_oe     ),
    .next_dq        ( next_dq        ),
    .sel_cmd        ( sel_cmd        ),
    .sel_a          ( sel_a          ),
    .sel_ba         ( sel_ba         ),
    .sel_dqm        ( sel_dqm        ),
    .sel_ack        ( sel_ack        ),
    .sel_dst        ( sel_dst        ),
    .sel_dok        ( sel_dok        ),
    .sel_rdy        ( sel_rdy        ),
    .sel_prog_ack   ( sel_prog_ack   ),
    .sel_prog_dst   ( sel_prog_dst   ),
    .sel_prog_dok   ( sel_prog_dok   ),
    .sel_prog_rdy   ( sel_prog_rdy   )
);

endmodule
