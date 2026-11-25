`timescale 1ns / 1ps

// A refresh must not start in the same cycle as an ACTIVE command, otherwise
// its precharge-all closes the row and the next read/write goes to a closed
// bank (lost download data or garbage reads). Continuous programming writes
// build up refresh debt, so the refresh gets forced while the programmer is
// requesting. Random gaps between writes also cover the case of a request
// starting in the same cycle as the refresh, as noreq is registered in HF mode.

module test;

`include "test_tasks.vh"

reg         rst=1, clk=0;
reg  [31:0] lfsr=32'h1234_5678;
integer     cycles=0;

always #5 clk = ~clk;

initial begin
    repeat(8) @(posedge clk);
    rst = 0;
end

always @(posedge clk) begin
    lfsr   <= { lfsr[30:0], lfsr[31]^lfsr[21]^lfsr[1]^lfsr[0] };
    cycles <= cycles + 1;
end

// refresh request every 1000 cycles
wire rfsh = cycles%1000 == 0;
// back-to-back writes first, then random gaps
wire [7:0] gaps = cycles<100_000 ? 8'hff : lfsr[7:0];

wire lf_bad, hf_bad;
wire [31:0] lf_wr, hf_wr, lf_ref, hf_ref;

prog_sdram #(.HF(0)) uut_lf(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .rfsh   ( rfsh      ),
    .gap    ( gaps[3:0] ),
    .bad    ( lf_bad    ),
    .writes ( lf_wr     ),
    .rfshs  ( lf_ref    )
);

prog_sdram #(.HF(1)) uut_hf(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .rfsh   ( rfsh      ),
    .gap    ( gaps[7:4] ),
    .bad    ( hf_bad    ),
    .writes ( hf_wr     ),
    .rfshs  ( hf_ref    )
);

initial begin
    repeat(200_000) @(posedge clk);
    $display("LF: %0d writes, %0d refreshes. HF: %0d writes, %0d refreshes",
        lf_wr, lf_ref, hf_wr, hf_ref);
    assert_msg( lf_wr>1000 && hf_wr>1000, "too few programming writes");
    assert_msg( lf_ref>100 && hf_ref>100, "too few refresh commands");
    assert_msg( !lf_bad && !hf_bad, "read/write to a closed bank");
    pass();
end

endmodule

module prog_sdram #(parameter HF=0)(
    input             rst,
    input             clk,
    input             rfsh,
    input       [3:0] gap,
    output reg        bad,
    output reg [31:0] writes,
    output reg [31:0] rfshs
);

localparam [3:0] CMD_REFRESH   = 4'b0001,
                 CMD_PRECHARGE = 4'b0010,
                 CMD_ACTIVE    = 4'b0011,
                 CMD_WRITE     = 4'b0100,
                 CMD_READ      = 4'b0101;

wire [15:0] sdram_dq;
wire [12:0] sdram_a;
wire [ 1:0] sdram_ba;
wire        sdram_nwe, sdram_ncas, sdram_nras, sdram_ncs;
wire        init, prog_rdy;
reg  [21:0] prog_addr;
reg         prog_wr;
reg  [ 3:0] wait_cnt;
reg  [ 3:0] active;
wire [ 3:0] cmd = { sdram_ncs, sdram_nras, sdram_ncas, sdram_nwe };

// programming writes back to back or with a short gap
always @(posedge clk) begin
    if( rst || init ) begin
        prog_wr   <= 0;
        prog_addr <= 0;
        wait_cnt  <= 0;
        writes    <= 0;
    end else begin
        if( prog_wr && prog_rdy ) begin
            // like jtframe_dwnld, the next write can follow without a gap
            prog_wr   <= gap[3];
            prog_addr <= prog_addr + 22'd1;
            writes    <= writes + 1;
            wait_cnt  <= {1'b0,gap[2:0]};
        end else if( !prog_wr ) begin
            if( wait_cnt==0 ) prog_wr <= 1; else wait_cnt <= wait_cnt - 1'd1;
        end
    end
end

// SDRAM command checker
always @(posedge clk) begin
    if( rst || init ) begin
        active <= 0;
        bad    <= 0;
        rfshs  <= 0;
    end else begin
        case( cmd )
            CMD_ACTIVE:    active[sdram_ba] <= 1;
            CMD_PRECHARGE: if( sdram_a[10] ) active <= 0; else active[sdram_ba] <= 0;
            CMD_REFRESH: begin
                rfshs <= rfshs + 1;
                if( active!=0 ) begin
                    $display("%m refresh with an active bank at %t", $time);
                    bad <= 1;
                end
            end
            CMD_WRITE, CMD_READ: begin
                if( !active[sdram_ba] ) begin
                    $display("%m read/write to closed bank %0d at %t", sdram_ba, $time);
                    bad <= 1;
                end
                if( sdram_a[10] ) active[sdram_ba] <= 0; // auto precharge
            end
            default:;
        endcase
    end
end

jtframe_sdram64 #(.AW(22),.HF(HF)) uut(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .init       ( init          ),
    .rfsh       ( rfsh          ),

    .ba0_addr   ( 22'd0         ),
    .ba1_addr   ( 22'd0         ),
    .ba2_addr   ( 22'd0         ),
    .ba3_addr   ( 22'd0         ),
    .rd         ( 4'd0          ),
    .wr         ( 4'd0          ),
    .ba0_din    ( 16'd0         ),
    .ba0_dsn    ( 2'd3          ),
    .ba1_din    ( 16'd0         ),
    .ba1_dsn    ( 2'd3          ),
    .ba2_din    ( 16'd0         ),
    .ba2_dsn    ( 2'd3          ),
    .ba3_din    ( 16'd0         ),
    .ba3_dsn    ( 2'd3          ),
    .ack        (               ),
    .dst        (               ),
    .dok        (               ),
    .rdy        (               ),
    .dout       (               ),

    .prog_en    ( 1'b1          ),
    .prog_addr  ( prog_addr     ),
    .prog_rd    ( 1'b0          ),
    .prog_wr    ( prog_wr       ),
    .prog_din   ( prog_addr[15:0] ),
    .prog_dsn   ( 2'd0          ),
    .prog_ba    ( prog_addr[1:0] ),
    .prog_dst   (               ),
    .prog_dok   (               ),
    .prog_rdy   ( prog_rdy      ),
    .prog_ack   (               ),

    .sdram_dq   ( sdram_dq      ),
`ifdef VERILATOR
    .sdram_din  (               ),
`endif
    .sdram_a    ( sdram_a       ),
    .sdram_dqml (               ),
    .sdram_dqmh (               ),
    .sdram_ba   ( sdram_ba      ),
    .sdram_nwe  ( sdram_nwe     ),
    .sdram_ncas ( sdram_ncas    ),
    .sdram_nras ( sdram_nras    ),
    .sdram_ncs  ( sdram_ncs     ),
    .sdram_cke  (               )
);

endmodule
