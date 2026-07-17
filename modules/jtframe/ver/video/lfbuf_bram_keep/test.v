`timescale 1ns / 1ps

module test;

localparam HW = 8;
localparam VW = 4;
localparam FW = 8;
localparam AW = HW+VW+1;
localparam LINE_W = 1 << HW;

reg              rst = 1'b1;
reg              clk = 1'b0;
reg              pxl_cen = 1'b1;
reg              lhbl = 1'b0;
reg              hs = 1'b0;
reg              vs = 1'b0;
reg              lvbl = 1'b1;
reg  [VW-1:0]    vrender = 0;
reg  [HW-1:0]    hdump = 0;
reg  [VW-1:0]    req_v = 4'd2;
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
wire [HW-1:0]    rd_addr;
wire             line;
wire             scr_we;
wire [7:0]       st_dout;

integer errors = 0;
integer i;
integer timeout = 0;
reg write_frame = 1'b0;
reg saw_done = 1'b0;
reg [AW-1:0] check_addr;

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

function [15:0] stored_word;
    input [AW-1:0] addr;
begin
    stored_word = {
        uut.u_ram.u_hi.u_ram.mem[addr],
        uut.u_ram.u_lo.u_ram.mem[addr]
    };
end
endfunction

jtframe_lfbuf_bram_ctrl #(
    .VW(VW),
    .HW(HW)
) uut (
    .rst        ( rst        ),
    .clk        ( clk        ),
    .pxl_cen    ( pxl_cen    ),
    .lhbl       ( lhbl       ),
    .ln_done    ( ln_done    ),
    .fb_keep    ( fb_keep    ),
    .vrender    ( vrender    ),
    .ln_v       ( req_v      ),
    .vs         ( vs         ),
    .frame      ( frame      ),
    .fb_blank   ( fb_blank   ),
    .fb_addr    ( fb_addr    ),
    .fb_din     ( fb_din     ),
    .fb_clr     ( fb_clr     ),
    .fb_done    ( fb_done    ),
    .fb_dout    ( fb_dout    ),
    .rd_addr    ( rd_addr    ),
    .line       ( line       ),
    .scr_we     ( scr_we     ),
    .st_addr    ( st_addr    ),
    .st_dout    ( st_dout    )
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

task establish_timing;
begin
    blank(32);
    active(800);
    blank(300);
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

task wait_fb_done;
begin
    saw_done = 1'b0;
    @(negedge clk);
    lhbl = 1'b1;
    for(timeout=0; timeout<500 && !saw_done; timeout=timeout+1) begin
        @(posedge clk);
        if( fb_done ) saw_done = 1'b1;
    end
    if( !saw_done ) begin
        $display("FAIL: timed out waiting for BRAM line write completion");
        errors = errors + 1;
    end
    @(posedge clk);
end
endtask

task wait_clear;
begin
    for(timeout=0; timeout<300 && fb_clr; timeout=timeout+1) @(posedge clk);
    if( fb_clr ) begin
        $display("FAIL: timed out waiting for line-buffer clear");
        errors = errors + 1;
    end
end
endtask

task write_current_line;
begin
    write_frame = fb_keep ? 1'b0 : frame;
    pulse_done();
    wait_fb_done();
    wait_clear();
end
endtask

task check_storage;
    input integer expect_keep_mode;
    input integer expect_sparse_mode;
    reg [15:0] expected;
begin
    for(i=0; i<LINE_W; i=i+1) begin
        check_addr = { write_frame, req_v, i[HW-1:0] };
        if( expect_keep_mode )
            expected = keep_expected(i[HW-1:0]);
        else if( expect_sparse_mode )
            expected = sparse(i[HW-1:0]);
        else
            expected = baseline(i[HW-1:0]);

        if( stored_word(check_addr) !== expected ) begin
            $display("FAIL: BRAM storage addr=%0d got %04x expected %04x",
                i, stored_word(check_addr), expected);
            errors = errors + 1;
        end
    end
end
endtask

initial begin
    repeat(8) @(posedge clk);
    rst = 1'b0;
    repeat(4) @(posedge clk);

    fb_keep = 1'b0;
    fill_line(0);
    establish_timing();
    write_current_line();
    check_storage(0, 0);

    pulse_vs();
    if( frame !== 1'b1 ) begin
        $display("FAIL: frame did not toggle before BRAM keep-bank check");
        errors = errors + 1;
    end

    fb_keep = 1'b1;
    fill_line(1);
    establish_timing();
    write_current_line();
    check_storage(1, 0);

    fb_keep = 1'b0;
    fill_line(0);
    establish_timing();
    write_current_line();
    check_storage(0, 0);

    fill_line(1);
    establish_timing();
    write_current_line();
    check_storage(0, 1);

    if( errors != 0 ) begin
        $display("FAIL: %0d errors", errors);
        $finish;
    end

    pass();
end

endmodule
