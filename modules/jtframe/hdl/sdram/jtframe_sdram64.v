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
    Version: 1.0
    Date: 29-4-2021 */

// SDRAM is set to burst=2 (64 bits)

module jtframe_sdram64 #(
    parameter AW=22,
              HF=1,     // 1 for HF operation (idle cycles), 0 for LF operation
                        // HF operation starts at 66.6MHz (1/15ns)
              SHIFTED =0,
              BA0_LEN =64, // 1=16 bits, 2=32 bits, 4=64 bits
              BA1_LEN =64,
              BA2_LEN =64,
              BA3_LEN =64,
              PROG_LEN=64,

              // Selectively enable write operation in banks
              // Selecting the minimum needed set eases timing and placing
              BA0_WEN = 1,
              BA1_WEN = 0,
              BA2_WEN = 0,
              BA3_WEN = 0,

              BA0_AUTOPRECH=0,
              BA1_AUTOPRECH=0,
              BA2_AUTOPRECH=0,
              BA3_AUTOPRECH=0,

              MISTER =1,     // shorts dqm to address bus 12/11 signals
              RFSHCNT=9,     // 8192 every 64ms or 1 every 7.8us ~ 8.2 per line (15kHz)
              BAPRIO =1      // Bank requests are handled with higher priority to bank 0
                             // and lower to to bank 3
)(
    input               rst,
    input               clk,
    output              init,

    // requests
    input      [AW-1:0] ba0_addr,
    input      [AW-1:0] ba1_addr,
    input      [AW-1:0] ba2_addr,
    input      [AW-1:0] ba3_addr,
    input         [3:0] rd,
    input         [3:0] wr,
    input        [15:0] ba0_din,
    input        [ 1:0] ba0_dsn,  // write mask
    input        [15:0] ba1_din,
    input        [ 1:0] ba1_dsn,
    input        [15:0] ba2_din,
    input        [ 1:0] ba2_dsn,
    input        [15:0] ba3_din,
    input        [ 1:0] ba3_dsn,

    // programming
    input               prog_en,
    input      [AW-1:0] prog_addr,
    input               prog_rd,
    input               prog_wr,
    input        [15:0] prog_din,
    input        [ 1:0] prog_dsn,
    input        [ 1:0] prog_ba,
    output  reg         prog_dst,
    output  reg         prog_dok,
    output  reg         prog_rdy,
    output  reg         prog_ack,

    input               rfsh, // triggers a distributed cycle of RFSHCNT refresh commands
                              // This is meant to be the horizontal blanking of a 15kHz video
                              // signal. Using HB as rfsh signal also prevents having a bank
                              // active for longer than tRAS_max (120us)

    output        [3:0] ack,
    output reg    [3:0] dst,
    output reg    [3:0] dok,
    output reg    [3:0] rdy,
    output reg   [15:0] dout,

    // SDRAM interface
    // SDRAM_A[12:11] and SDRAM_DQML/H are controlled in a way
    // that can be joined together thru an OR operation at a
    // higher level. This makes it possible to short the pins
    // of the SDRAM, as done in the MiSTer 128MB module
    inout       [15:0]  sdram_dq,       // SDRAM Data bus 16 Bits
    `ifdef VERILATOR // sdram_dq is used as input-only in Verilator sims
    output reg  [15:0]  sdram_din,      // Data to be stored in SDRAM
    `endif
    output reg  [12:0]  sdram_a,        // SDRAM Address bus 13 Bits
    output              sdram_dqml,     // SDRAM Low-byte Data Mask
    output              sdram_dqmh,     // SDRAM High-byte Data Mask
    output reg  [ 1:0]  sdram_ba,       // SDRAM Bank Address
    output              sdram_nwe,      // SDRAM Write Enable
    output              sdram_ncas,     // SDRAM Column Address Strobe
    output              sdram_nras,     // SDRAM Row Address Strobe
    output              sdram_ncs,      // SDRAM Chip Select
    output              sdram_cke       // SDRAM Chip Select
);

localparam BURSTLEN=(BA0_LEN>32 || BA1_LEN>32 ||BA2_LEN>32 ||BA3_LEN>32) ? 64 :(
                    (BA0_LEN>16 || BA1_LEN>16 ||BA2_LEN>16 ||BA3_LEN>16) ? 32 : 16);

localparam LATCH = HF==1;

//                             /CS /RAS /CAS /WE
localparam CMD_LOAD_MODE   = 4'b0___0____0____0, // 0
           CMD_REFRESH     = 4'b0___0____0____1, // 1
           CMD_PRECHARGE   = 4'b0___0____1____0, // 2
           CMD_ACTIVE      = 4'b0___0____1____1, // 3
           CMD_WRITE       = 4'b0___1____0____0, // 4
           CMD_READ        = 4'b0___1____0____1, // 5
           CMD_STOP        = 4'b0___1____1____0, // 6 Burst terminate
           CMD_NOP         = 4'b0___1____1____1, // 7
           CMD_INHIBIT     = 4'b1___0____0____0; // 8

wire  [3:0] br, bx0_cmd, bx1_cmd, bx2_cmd, bx3_cmd, rfsh_cmd,
            ba_dst, ba_dbusy, ba_dbusy64, ba_rdy, ba_dok,
            init_cmd, post_act, next_cmd, dqm_busy, match;
wire        all_act, rfshing, rfsh_br, noreq, help;
reg         all_dbusy, all_dbusy64;
reg   [3:0] bg, cmd;
reg  [14:0] prio_lfsr;
wire [12:0] bx0_a, bx1_a, bx2_a, bx3_a, init_a, next_a, rfsh_a,
            ba0_row, ba1_row, ba2_row, ba3_row;
wire [ 1:0] next_ba, prio;
wire [15:0] din;

wire [AW-1:0] ba0_addr_l, ba1_addr_l, ba2_addr_l, ba3_addr_l;
wire    [3:0] rd_l, wr_aux;
reg     [3:0] wr_l;
wire    [4:0] wr_busy, idle;
wire          wr_cycle;

// prog signals
wire        pre_dst, pre_dok, pre_ack, pre_rdy;
wire [12:0] pre_a;
wire [ 3:0] pre_cmd;
reg         prog_rst, prog_bg, other_rst, rfsh_rst;

reg         rfsh_bg;
reg  [ 1:0] dqm;
wire [ 1:0] mask_mux;
wire        all_dqm, prog_busy, pre_br;

assign {sdram_ncs, sdram_nras, sdram_ncas, sdram_nwe } = cmd;
assign {sdram_dqmh, sdram_dqml} = MISTER ? sdram_a[12:11] : dqm;
assign sdram_cke = 1;
assign all_act     = |post_act;
assign all_dqm     = |dqm_busy;
assign wr_cycle    = |wr_busy;

assign {next_ba, next_cmd, next_a } =
                        init ? { 2'd0, init_cmd, init_a } : (
                      rfshing? { 2'd0, rfsh_cmd, rfsh_a } : (
                      prog_en? { prog_ba, pre_cmd, pre_a} : (
                       bg[3] ? { 2'd3, bx3_cmd, bx3_a } : (
                       bg[2] ? { 2'd2, bx2_cmd, bx2_a } : (
                       bg[1] ? { 2'd1, bx1_cmd, bx1_a } :
                               { 2'd0, bx0_cmd, bx0_a } )))));

assign prio     = prio_lfsr[1:0];
assign mask_mux = prog_en ? prog_dsn :
                  (bg[3] && BA3_WEN) ? ba3_dsn :
                  (bg[2] && BA2_WEN) ? ba2_dsn :
                  (bg[1] && BA1_WEN) ? ba1_dsn : ba0_dsn;

`ifdef SIMULATION
    always @(posedge clk) begin
        if( wr[3] & ~BA3_WEN ) begin $display("%m attempt to write to SDRAM bank 3, but it is not enable. Set JTFRAME_BA3_WEN"); $finish; end
        if( wr[2] & ~BA2_WEN ) begin $display("%m attempt to write to SDRAM bank 2, but it is not enable. Set JTFRAME_BA2_WEN"); $finish; end
        if( wr[1] & ~BA1_WEN ) begin $display("%m attempt to write to SDRAM bank 1, but it is not enable. Set JTFRAME_BA1_WEN"); $finish; end
    end
`endif

`ifndef VERILATOR
reg  [15:0] dq_pad;
assign sdram_dq = dq_pad;
`endif

always @(negedge clk) begin
    prog_rst  <= ~prog_en | init | rst;
    rfsh_rst  <= init | rst;
    other_rst <= prog_en | init | rst;
end

assign din = (bg[3] && BA3_WEN) ? ba3_din :
             (bg[2] && BA2_WEN) ? ba2_din :
             (bg[1] && BA1_WEN) ? ba1_din : ba0_din;

always @(posedge clk) begin
    dst      <= ba_dst;
    rdy      <= ba_rdy;
    all_dbusy    <= |ba_dbusy;
    all_dbusy64  <= |ba_dbusy64;
    dok      <= ba_dok;
    dout     <= sdram_dq;
    cmd      <= next_cmd;

    // prog signals
    prog_dst <= pre_dst;
    prog_dok <= pre_dok;
    prog_rdy <= pre_rdy;
    prog_ack <= pre_ack;

    sdram_ba      <= next_ba;
    sdram_a[10:0] <= next_a[10:0];

    wr_l <= wr_aux & ~ba_rdy;

`ifndef VERILATOR
    dq_pad <= wr_cycle ? (prog_en ? prog_din : din) : 16'hzzzz;
`else
    sdram_din <= prog_en ? prog_din : din;
`endif
    if( MISTER ) begin
        if( next_cmd==CMD_ACTIVE )
            sdram_a[12:11] <= next_a[12:11];
        else
            sdram_a[12:11] <= wr_cycle ? mask_mux : 2'd0;
    end else begin
        sdram_a[12:11] <= next_a[12:11];
        dqm <= wr_cycle ? mask_mux : 2'd0;
    end
end

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        prio_lfsr <= 1;
    end else begin
        prio_lfsr <= { prio_lfsr[0]^prio_lfsr[14], prio_lfsr[14:1] };
    end
end

jtframe_sdram64_latch #(.LATCH(LATCH),.AW(AW)) u_latch(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .rdy        ( ba_rdy    ),
    .ba0_addr   ( ba0_addr  ),
    .ba1_addr   ( ba1_addr  ),
    .ba2_addr   ( ba2_addr  ),
    .ba3_addr   ( ba3_addr  ),
    .ba0_addr_l ( ba0_addr_l),
    .ba1_addr_l ( ba1_addr_l),
    .ba2_addr_l ( ba2_addr_l),
    .ba3_addr_l ( ba3_addr_l),
    .ba0_row    ( ba0_row   ),
    .ba1_row    ( ba1_row   ),
    .ba2_row    ( ba2_row   ),
    .ba3_row    ( ba3_row   ),
    .match      ( match     ),
    .prog_en    ( prog_en   ),
    .prog_rd    ( prog_rd   ),
    .prog_wr    ( prog_wr   ),
    .rd         ( rd        ),
    .rd_l       ( rd_l      ),
    .wr         ( wr        ),
    .wr_l       ( wr_aux    ),
    .noreq      ( noreq     )
);

jtframe_sdram64_init #(.HF(HF),.BURSTLEN(BURSTLEN)) u_init(
    .rst        ( rst       ),
    .clk        ( clk       ),

    .init       ( init      ),
    .cmd        ( init_cmd  ),
    .sdram_a    ( init_a    )
);

jtframe_sdram64_rfsh #(.HF(HF),.RFSHCNT(RFSHCNT)) u_rfsh(
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
    .AW       ( AW      ),
    .HF       ( HF      ),
    .SHIFTED  ( SHIFTED ),
    .BALEN    ( PROG_LEN),
    .BURSTLEN ( BURSTLEN),
    // The programmer always precharges all banks
    // at the beginning of the operation
    .AUTOPRECH    ( 1   ),
    .PRECHARGE_ALL( 1   )
) u_prog(
    .rst        ( prog_rst   ),
    .clk        ( clk        ),
    .help       ( 1'b0       ),

    // requests
    .addr       ( prog_addr  ),
    .rd         ( prog_rd    ),
    .wr         ( prog_wr    ),

    .ack        ( pre_ack    ),
    .dst        ( pre_dst    ),    // data starts
    .dbusy      (            ), // prog works alone
    .all_dbusy  ( 1'd0       ),
    .idle       ( idle[4]    ),

    .dbusy64    ( prog_busy  ),
    .all_dbusy64( 1'd0       ),

    .post_act   (            ),
    .all_act    ( 1'd0       ),

    .dqm_busy   (            ),
    .all_dqm    ( 1'd0       ),
    .wr_busy    ( wr_busy[4] ),

    .row        (            ),
    .match      ( 1'b0       ),

    .dok        ( pre_dok    ),
    .rdy        ( pre_rdy    ),
    .set_prech  ( 1'd0       ),

    // SDRAM interface
    .br         ( pre_br     ), // bus request
    .bg         ( prog_bg    ), // bus grant

    .sdram_a    ( pre_a      ),
    .cmd        ( pre_cmd    )
);

jtframe_sdram64_bank #(
    .AW       ( AW            ),
    .HF       ( HF            ),
    .SHIFTED  ( SHIFTED       ),
    .BURSTLEN ( BURSTLEN      ),
    .BALEN    ( BA0_LEN       ),
    .AUTOPRECH( BA0_AUTOPRECH )
) u_bank0(
    .rst        ( other_rst  ),
    .clk        ( clk        ),
    .help       ( help       ),

    // requests
    .addr       ( ba0_addr_l ),
    .rd         ( rd_l[0]    ),
    .wr         ( wr_l[0]    ),

    .ack        ( ack[0]     ),
    .dst        ( ba_dst[0]  ),    // data starts
    .dbusy      ( ba_dbusy[0]),
    .all_dbusy  ( all_dbusy  ),
    .idle       ( idle[0]    ),

    .dbusy64    (ba_dbusy64[0]),
    .all_dbusy64( all_dbusy64),
    .wr_busy    ( wr_busy[0] ),

    .post_act   ( post_act[0]),
    .all_act    ( all_act    ),

    .dqm_busy   ( dqm_busy[0]),
    .all_dqm    ( all_dqm    ),

    .dok        ( ba_dok[0]  ),
    .rdy        ( ba_rdy[0]  ),
    .set_prech  ( rfsh_bg    ),

    .row        ( ba0_row    ),
    .match      ( match[0]   ),

    // SDRAM interface
    .br         ( br[0]      ), // bus request
    .bg         ( bg[0]      ), // bus grant

    .sdram_a    ( bx0_a      ),
    .cmd        ( bx0_cmd    )
);

jtframe_sdram64_bank #(
    .AW       ( AW            ),
    .HF       ( HF            ),
    .SHIFTED  ( SHIFTED       ),
    .BURSTLEN ( BURSTLEN      ),
    .BALEN    ( BA1_LEN       ),
    .AUTOPRECH( BA1_AUTOPRECH )
) u_bank1(
    .rst        ( other_rst  ),
    .clk        ( clk        ),
    .help       ( help       ),

    // requests
    .addr       ( ba1_addr_l ),
    .rd         ( rd_l[1]    ),
    .wr         ( wr_l[1]    ),

    .ack        ( ack[1]     ),
    .dst        ( ba_dst[1]  ),    // data starts
    .dbusy      ( ba_dbusy[1]),
    .all_dbusy  ( all_dbusy  ),
    .idle       ( idle[1]    ),

    .dbusy64    (ba_dbusy64[1]),
    .all_dbusy64( all_dbusy64),
    .wr_busy    ( wr_busy[1] ),

    .post_act   ( post_act[1]),
    .all_act    ( all_act    ),
    .dok        ( ba_dok[1]  ),
    .rdy        ( ba_rdy[1]  ),
    .set_prech  ( rfsh_bg    ),

    .dqm_busy   ( dqm_busy[1]),
    .all_dqm    ( all_dqm    ),

    .row        ( ba1_row    ),
    .match      ( match[1]   ),

    // SDRAM interface
    .br         ( br[1]      ), // bus request
    .bg         ( bg[1]      ), // bus grant

    .sdram_a    ( bx1_a      ),
    .cmd        ( bx1_cmd    )
);

jtframe_sdram64_bank #(
    .AW       ( AW            ),
    .HF       ( HF            ),
    .SHIFTED  ( SHIFTED       ),
    .BURSTLEN ( BURSTLEN      ),
    .BALEN    ( BA2_LEN       ),
    .AUTOPRECH( BA2_AUTOPRECH )
) u_bank2(
    .rst        ( other_rst  ),
    .clk        ( clk        ),
    .help       ( help       ),

    // requests
    .addr       ( ba2_addr_l ),
    .rd         ( rd_l[2]    ),
    .wr         ( wr_l[2]    ),

    .ack        ( ack[2]     ),
    .dst        ( ba_dst[2]  ),    // data starts
    .dbusy      ( ba_dbusy[2]),
    .all_dbusy  ( all_dbusy  ),
    .idle       ( idle[2]    ),

    .dbusy64    (ba_dbusy64[2]),
    .all_dbusy64( all_dbusy64),
    .wr_busy    ( wr_busy[2] ),

    .post_act   ( post_act[2]),
    .all_act    ( all_act    ),
    .dok        ( ba_dok[2]  ),
    .rdy        ( ba_rdy[2]  ),
    .set_prech  ( rfsh_bg    ),

    .dqm_busy   ( dqm_busy[2]),
    .all_dqm    ( all_dqm    ),

    .row        ( ba2_row    ),
    .match      ( match[2]   ),

    // SDRAM interface
    .br         ( br[2]      ), // bus request
    .bg         ( bg[2]      ), // bus grant

    .sdram_a    ( bx2_a      ),
    .cmd        ( bx2_cmd    )
);

jtframe_sdram64_bank #(
    .AW       ( AW            ),
    .HF       ( HF            ),
    .SHIFTED  ( SHIFTED       ),
    .BURSTLEN ( BURSTLEN      ),
    .BALEN    ( BA3_LEN       ),
    .AUTOPRECH( BA3_AUTOPRECH )
) u_bank3(
    .rst        ( other_rst  ),
    .clk        ( clk        ),
    .help       ( help       ),

    // requests
    .addr       ( ba3_addr_l ),
    .rd         ( rd_l[3]    ),
    .wr         ( wr_l[3]    ),

    .ack        ( ack[3]     ),
    .dst        ( ba_dst[3]  ),    // data starts
    .dbusy      ( ba_dbusy[3]),
    .all_dbusy  ( all_dbusy  ),
    .wr_busy    ( wr_busy[3] ),
    .idle       ( idle[3]    ),

    .dbusy64    (ba_dbusy64[3]),
    .all_dbusy64( all_dbusy64),

    .post_act   ( post_act[3]),
    .all_act    ( all_act    ),
    .dok        ( ba_dok[3]  ),
    .rdy        ( ba_rdy[3]  ),
    .set_prech  ( rfsh_bg    ),

    .dqm_busy   ( dqm_busy[3]),
    .all_dqm    ( all_dqm    ),

    .row        ( ba3_row    ),
    .match      ( match[3]   ),

    // SDRAM interface
    .br         ( br[3]      ), // bus request
    .bg         ( bg[3]      ), // bus grant

    .sdram_a    ( bx3_a      ),
    .cmd        ( bx3_cmd    )
);

always @(*) begin
    rfsh_bg = &idle && (noreq | help) && rfsh_br;
    prog_bg = pre_br & !rfshing;
    if( rfshing ) begin
        bg=0;
    end else begin
        if( BAPRIO ) begin
            casez( br ) // Bank requests have priority (eases timing)
                4'b???1: bg=4'b0001;
                4'b??10: bg=4'b0010;
                4'b?100: bg=4'b0100;
                4'b1000: bg=4'b1000;
                default: bg=0;
            endcase
        end else begin // Bank requests are randomized (tougher timing)
            case( {br, prio[1:0]} )
                6'b0000_00: bg=4'b0000;
                6'b0000_01: bg=4'b0000;
                6'b0000_10: bg=4'b0000;
                6'b0000_11: bg=4'b0000;
                6'b0001_00: bg=4'b0001;
                6'b0001_01: bg=4'b0001;
                6'b0001_10: bg=4'b0001;
                6'b0001_11: bg=4'b0001;
                6'b0010_00: bg=4'b0010;
                6'b0010_01: bg=4'b0010;
                6'b0010_10: bg=4'b0010;
                6'b0010_11: bg=4'b0010;
                6'b0011_00: bg=4'b0001;
                6'b0011_01: bg=4'b0010;
                6'b0011_10: bg=4'b0001;
                6'b0011_11: bg=4'b0010;
                6'b0100_00: bg=4'b0100;
                6'b0100_01: bg=4'b0100;
                6'b0100_10: bg=4'b0100;
                6'b0100_11: bg=4'b0100;
                6'b0101_00: bg=4'b0001;
                6'b0101_01: bg=4'b0001;
                6'b0101_10: bg=4'b0100;
                6'b0101_11: bg=4'b0100;

                6'b0110_00: bg=4'b0010;
                6'b0110_01: bg=4'b0010;
                6'b0110_10: bg=4'b0100;
                6'b0110_11: bg=4'b0100;

                6'b0111_00: bg=4'b0001;
                6'b0111_01: bg=4'b0010;
                6'b0111_10: bg=4'b0100;
                6'b0111_11: bg=4'b0001;  //*0001

                6'b1000_00: bg=4'b1000;
                6'b1000_01: bg=4'b1000;
                6'b1000_10: bg=4'b1000;
                6'b1000_11: bg=4'b1000;

                6'b1001_00: bg=4'b0001;
                6'b1001_01: bg=4'b0001;
                6'b1001_10: bg=4'b1000;
                6'b1001_11: bg=4'b1000;

                6'b1010_00: bg=4'b0010;
                6'b1010_01: bg=4'b0010;
                6'b1010_10: bg=4'b1000;
                6'b1010_11: bg=4'b1000;

                6'b1011_00: bg=4'b0001;
                6'b1011_01: bg=4'b0010; //*0010
                6'b1011_10: bg=4'b0010;
                6'b1011_11: bg=4'b1000;

                6'b1100_00: bg=4'b1000;
                6'b1100_01: bg=4'b0100;
                6'b1100_10: bg=4'b0100;
                6'b1100_11: bg=4'b1000;

                6'b1101_00: bg=4'b0001;
                6'b1101_01: bg=4'b0100; //*0100
                6'b1101_10: bg=4'b0100;
                6'b1101_11: bg=4'b1000;

                6'b1110_00: bg=4'b1000; //*1000
                6'b1110_01: bg=4'b0010;
                6'b1110_10: bg=4'b0100;
                6'b1110_11: bg=4'b1000;

                6'b1111_00: bg=4'b0001;
                6'b1111_01: bg=4'b0010;
                6'b1111_10: bg=4'b0100;
                6'b1111_11: bg=4'b1000;
            endcase
        end
    end
end

`ifdef SIMULATION
always @(posedge clk) begin
    if( (rd!=0 || wr!=0) && init ) begin
        $display("\nERROR: SDRAM rd/wr inputs should be zero during initialization (%m)");
        `ifndef VERILATOR
        $finish;
        `endif
    end
end
`endif

endmodule