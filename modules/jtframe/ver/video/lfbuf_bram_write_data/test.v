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
reg  [VW-1:0]    req_v = 4'd3;
reg              ln_done = 1'b0;
reg  [HW-1:0]    ln_addr = 0;
reg  [15:0]      ln_data = 0;
reg              ln_we = 1'b0;
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
integer read_count = 0;
integer timeout = 0;
integer i;
reg check_reads = 1'b0;
reg write_frame = 1'b0;
reg [AW-1:0] check_addr;

`include "test_tasks.vh"

always #5 clk = ~clk;

function [15:0] pattern;
    input [HW-1:0] x;
begin
    pattern = 16'h5000 | { 8'd0, x };
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
    if( !rst && check_reads && scr_we ) begin
        if( rd_addr !== read_count[HW-1:0] ) begin
            $display("FAIL: lineout write %0d used rd_addr=%0d", read_count, rd_addr);
            fail();
        end
        if( fb_dout !== pattern(read_count[HW-1:0]) ) begin
            $display("FAIL: lineout write %0d addr=%0d got %04x expected %04x frame=%0d",
                read_count, rd_addr, fb_dout, pattern(read_count[HW-1:0]), frame);
            fail();
        end
        read_count = read_count + 1;
    end
end

always @(posedge clk) begin
    if( pxl_cen ) begin
        if( lhbl ) begin
            hdump <= hdump + 1'd1;
        end else begin
            hdump <= 0;
        end
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
begin
    @(negedge clk);
    ln_we = 1'b1;
    for(i=0; i<LINE_W; i=i+1) begin
        ln_addr = i[HW-1:0];
        ln_data = pattern(i[HW-1:0]);
        @(posedge clk);
        @(negedge clk);
    end
    ln_we = 1'b0;
    ln_addr = 0;
    ln_data = 0;
end
endtask

task pulse_vs;
begin
    @(negedge clk);
    vs = 1'b1;
    @(posedge clk);
    @(negedge clk);
    vs = 1'b0;
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

task wait_fb_done;
begin
    @(negedge clk);
    lhbl = 1'b1;
    for(timeout=0; timeout<500 && !fb_done; timeout=timeout+1) begin
        @(posedge clk);
    end
    if( !fb_done ) begin
        $display("FAIL: timed out waiting for BRAM line write completion");
        errors = errors + 1;
    end
    @(posedge clk);
end
endtask

task check_storage;
begin
    for(i=0; i<LINE_W; i=i+1) begin
        check_addr = { write_frame, req_v, i[HW-1:0] };
        if( uut.ram[check_addr] !== pattern(i[HW-1:0]) ) begin
            $display("FAIL: BRAM storage addr=%0d got %04x expected %04x",
                i, uut.ram[check_addr], pattern(i[HW-1:0]));
            errors = errors + 1;
        end
    end
end
endtask

initial begin
    repeat(8) @(posedge clk);
    rst = 1'b0;
    repeat(4) @(posedge clk);

    fill_line();

    // Establish hblank length and hlim, and allow the controller's display-side
    // READ transaction to finish before the active slot used for the write.
    blank(32);
    active(800);
    blank(300);
    write_frame = frame;
    pulse_done();
    wait_fb_done();

    check_storage();

    pulse_vs();
    repeat(2) @(posedge clk);
    vrender = req_v;
    read_count = 0;
    check_reads = 1'b1;
    blank(400);

    for(timeout=0; timeout<500 && read_count<LINE_W; timeout=timeout+1) begin
        @(posedge clk);
    end
    check_reads = 1'b0;

    if( read_count < LINE_W ) begin
        $display("FAIL: observed only %0d lineout writes, expected %0d", read_count, LINE_W);
        errors = errors + 1;
    end

    if( errors != 0 ) begin
        $display("FAIL: %0d errors", errors);
        $finish;
    end

    pass();
end

endmodule
