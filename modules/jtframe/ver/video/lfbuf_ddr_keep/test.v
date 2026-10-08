`timescale 1ns / 1ps

module test;

localparam HW = 8;
localparam VW = 4;
localparam FW = 8;
localparam LINE_W = 1 << HW;
localparam DDR_BANK_BIT = HW + VW + 3;

reg              rst = 1'b1;
reg              clk = 1'b0;
reg              pxl_cen = 1'b1;
reg              lhbl = 1'b0;
reg              hs = 1'b0;
reg              vs = 1'b0;
reg              lvbl = 1'b1;
reg  [VW-1:0]    vrender = 0;
reg  [HW-1:0]    hdump = 0;
reg  [VW-1:0]    req_v = 4'd3;
reg              ln_done = 1'b0;
reg  [HW-1:0]    ln_addr = 0;
reg  [15:0]      ln_data = 0;
reg              ln_we = 1'b0;
reg              fb_keep = 1'b0;
reg  [7:0]       st_addr = 8'd0;

wire             ln_hs, ln_vs, ln_lvbl;
wire [VW-1:0]    line_ln_v;
wire [15:0]      ln_dout, ln_pxl;
wire             frame;
wire [HW-1:0]    fb_addr;
wire [15:0]      fb_din;
wire             fb_clr;
wire             fb_done;
wire             fb_blank;
wire [15:0]      fb_dout;
wire [63:0]      ddram_dout;
wire [HW-1:0]    rd_addr;
wire             line;
wire             scr_we;
wire             ddram_clk;
wire             ddram_busy;
wire [7:0]       ddram_burstcnt;
wire [31:3]      ddram_addr;
wire             ddram_rd;
wire             ddram_dout_ready;
wire [63:0]      ddram_din;
wire [7:0]       ddram_be;
wire             ddram_we;
wire [7:0]       st_dout;

integer errors = 0;
integer write_count = 0;
integer masked_count = 0;
integer read_count = 0;
integer timeout = 0;
integer i;
reg              check_writes = 1'b0;
reg              check_reads = 1'b0;
reg              saw_done = 1'b0;
reg              write_sparse = 1'b0;
reg  [1:0]       read_mode = 0;
reg  [15:0]      expected;

`include "test_tasks.vh"

always #5 clk = ~clk;

function [15:0] baseline;
    input [HW-1:0] x;
begin
    baseline = 16'h9000 | { 8'd0, x };
end
endfunction

function [15:0] sparse;
    input [HW-1:0] x;
begin
    sparse = x[1:0] == 2'b01 ? 16'h0000 : (16'h5000 | { 8'd0, x });
end
endfunction

function [15:0] keep_expected;
    input [HW-1:0] x;
begin
    keep_expected = sparse(x) == 16'h0000 ? baseline(x) : sparse(x);
end
endfunction

function [15:0] read_expected;
    input [1:0] mode;
    input [HW-1:0] x;
begin
    if( mode == 2'd1 ) read_expected = keep_expected(x);
    else if( mode == 2'd2 ) read_expected = sparse(x);
    else read_expected = baseline(x);
end
endfunction

jtframe_lfbuf_ddr_ctrl #(
    .VW(VW),
    .HW(HW)
) uut (
    .rst                ( rst                ),
    .clk                ( clk                ),
    .pxl_cen            ( pxl_cen            ),
    .lhbl               ( lhbl               ),
    .ln_done            ( ln_done            ),
    .fb_keep            ( fb_keep            ),
    .vrender            ( vrender            ),
    .ln_v               ( req_v              ),
    .vs                 ( vs                 ),
    .frame              ( frame              ),
    .fb_blank           ( fb_blank           ),
    .fb_addr            ( fb_addr            ),
    .fb_din             ( fb_din             ),
    .fb_clr             ( fb_clr             ),
    .fb_done            ( fb_done            ),
    .fb_dout            ( fb_dout            ),
    .rd_addr            ( rd_addr            ),
    .line               ( line               ),
    .scr_we             ( scr_we             ),
    .ddram_clk          ( ddram_clk          ),
    .ddram_busy         ( ddram_busy         ),
    .ddram_burstcnt     ( ddram_burstcnt     ),
    .ddram_addr         ( ddram_addr         ),
    .ddram_dout         ( ddram_dout         ),
    .ddram_dout_ready   ( ddram_dout_ready   ),
    .ddram_rd           ( ddram_rd           ),
    .ddram_din          ( ddram_din          ),
    .ddram_be           ( ddram_be           ),
    .ddram_we           ( ddram_we           ),
    .st_addr            ( st_addr            ),
    .st_dout            ( st_dout            )
);

jtframe_lfbuf_line #(
    .DW(16),
    .VW(VW),
    .HW(HW),
    .FW(FW)
) u_line (
    .rst        ( rst       ),
    .clk        ( clk       ),
    .clk_ctrl   ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .vrender    ( vrender   ),
    .vread      (           ),
    .hdump      ( hdump     ),
    .hs         ( hs        ),
    .lhbl       ( lhbl      ),
    .vs         ( vs        ),
    .lvbl       ( lvbl      ),
    .h_step     ( 9'h100    ),
    .v_step     ( 9'h100    ),
    .ln_hs      ( ln_hs     ),
    .ln_vs      ( ln_vs     ),
    .ln_lvbl    ( ln_lvbl   ),
    .ln_v       ( line_ln_v ),
    .ln_addr    ( ln_addr   ),
    .ln_data    ( ln_data   ),
    .ln_we      ( ln_we     ),
    .ln_dout    ( ln_dout   ),
    .ln_pxl     ( ln_pxl    ),
    .frame      ( frame     ),
    .fb_addr    ( fb_addr   ),
    .rd_addr    ( rd_addr   ),
    .fb_din     ( fb_din    ),
    .fb_clr     ( fb_clr    ),
    .fb_done    ( fb_done   ),
    .fb_blank   ( fb_blank  ),
    .fb_dout    ( fb_dout   ),
    .line       ( line      ),
    .scr_we     ( scr_we    )
);

jtframe_ddr_model u_ddr (
    .clk        ( clk                ),
    .busy       ( ddram_busy         ),
    .burstcnt   ( ddram_burstcnt     ),
    .addr       ( ddram_addr         ),
    .dout       ( ddram_dout         ),
    .dout_ready ( ddram_dout_ready   ),
    .rd         ( ddram_rd           ),
    .din        ( ddram_din          ),
    .be         ( ddram_be           ),
    .we         ( ddram_we           )
);

always @(posedge clk) begin
    if( !rst && check_writes && fb_done ) saw_done = 1'b1;
    if( !rst && check_writes && ddram_we && !ddram_busy ) begin
        expected = write_sparse ? sparse(write_count[HW-1:0]) : baseline(write_count[HW-1:0]);
        if( fb_keep && ddram_addr[DDR_BANK_BIT] !== 1'b0 ) begin
            $display("FAIL: DDR keep write used row bank %0d, expected fixed bank 0", ddram_addr[DDR_BANK_BIT]);
            fail();
        end
        if( ddram_be == 8'h00 ) begin
            if( expected != 16'h0000 ) begin
                $display("FAIL: DDR masked nonblank write %0d expected=%04x", write_count, expected);
                fail();
            end
            masked_count = masked_count + 1;
        end else if( ddram_be == 8'h03 ) begin
            if( ddram_din[15:0] !== expected ) begin
                $display("FAIL: DDR write %0d got %04x expected %04x fb_addr=%0d",
                    write_count, ddram_din[15:0], expected, fb_addr);
                fail();
            end
        end else begin
            $display("FAIL: DDR write %0d used byte enable %02x", write_count, ddram_be);
            fail();
        end
        write_count = write_count + 1;
    end
end

always @(posedge clk) begin
    if( !rst && check_reads && scr_we ) begin
        expected = read_expected(read_mode, read_count[HW-1:0]);
        if( rd_addr !== read_count[HW-1:0] ) begin
            $display("FAIL: DDR lineout write %0d used rd_addr=%0d", read_count, rd_addr);
            fail();
        end
        if( fb_dout !== expected ) begin
            $display("FAIL: DDR lineout write %0d got %04x expected %04x frame=%0d ddram_addr=%0h",
                read_count, fb_dout, expected, frame, ddram_addr);
            fail();
        end
        read_count = read_count + 1;
    end
end

always @(posedge clk) begin
    if( pxl_cen ) begin
        if( lhbl ) hdump <= hdump + 1'd1;
        else hdump <= 0;
    end
end

task active;
    input integer n;
    integer j;
begin
    @(negedge clk);
    lhbl = 1'b1;
    for(j=0; j<n; j=j+1) @(posedge clk);
end
endtask

task blank;
    input integer n;
    integer j;
begin
    @(negedge clk);
    lhbl = 1'b0;
    for(j=0; j<n; j=j+1) @(posedge clk);
end
endtask

task fill_line;
    input integer use_sparse;
begin
    @(negedge clk);
    ln_we = 1'b1;
    for(i=0; i<LINE_W; i=i+1) begin
        ln_addr = i[HW-1:0];
        ln_data = use_sparse ? sparse(i[HW-1:0]) : baseline(i[HW-1:0]);
        @(posedge clk);
        @(negedge clk);
    end
    ln_we = 1'b0;
    ln_addr = 0;
    ln_data = 0;
end
endtask

task pulse_done;
begin
    @(negedge clk);
    ln_done = 1'b1;
    @(posedge clk);
    @(negedge clk);
    ln_done = 1'b0;
end
endtask

task pulse_vs;
begin
    @(negedge clk);
    vs = 1'b1;
    @(posedge clk);
    @(negedge clk);
    vs = 1'b0;
    repeat(3) @(posedge clk);
end
endtask

task establish_timing;
begin
    blank(32);
    active(800);
    blank(300);
end
endtask

task write_current_line;
    input integer use_sparse;
    input integer expect_masked;
begin
    write_count = 0;
    masked_count = 0;
    saw_done = 1'b0;
    write_sparse = use_sparse != 0;
    pulse_done();
    check_writes = 1'b1;
    active(900);

    for(timeout=0; timeout<700 && !saw_done; timeout=timeout+1) @(posedge clk);
    check_writes = 1'b0;

    if( !saw_done ) begin
        $display("FAIL: timed out waiting for DDR line write completion");
        errors = errors + 1;
    end
    if( write_count != LINE_W ) begin
        $display("FAIL: observed %0d DDR writes, expected %0d", write_count, LINE_W);
        errors = errors + 1;
    end
    if( masked_count != expect_masked ) begin
        $display("FAIL: observed %0d DDR masked writes, expected %0d", masked_count, expect_masked);
        errors = errors + 1;
    end
end
endtask

task read_current_line;
    input integer mode;
begin
    vrender = req_v;
    read_count = 0;
    read_mode = mode[1:0];
    check_reads = 1'b1;
    blank(400);

    for(timeout=0; timeout<500 && read_count<LINE_W; timeout=timeout+1) @(posedge clk);
    check_reads = 1'b0;

    if( read_count < LINE_W ) begin
        $display("FAIL: observed only %0d DDR lineout writes, expected %0d", read_count, LINE_W);
        errors = errors + 1;
    end
end
endtask

initial begin
    repeat(8) @(posedge clk);
    rst = 1'b0;
    repeat(4) @(posedge clk);

    fb_keep = 1'b1;
    fill_line(0);
    establish_timing();
    write_current_line(0, 0);

    pulse_vs();
    if( frame !== 1'b1 ) begin
        $display("FAIL: frame did not toggle before DDR keep-bank check");
        errors = errors + 1;
    end

    fb_keep = 1'b1;
    fill_line(1);
    establish_timing();
    write_current_line(1, LINE_W/4);
    read_current_line(1);

    fb_keep = 1'b0;
    fill_line(1);
    establish_timing();
    write_current_line(1, 0);
    pulse_vs();
    read_current_line(2);

    if( errors != 0 ) begin
        $display("FAIL: %0d errors", errors);
        $finish;
    end

    pass();
end

endmodule
