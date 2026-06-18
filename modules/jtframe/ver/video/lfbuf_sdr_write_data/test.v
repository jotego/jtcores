`timescale 1ns / 1ps

module test;

localparam HW = 8;
localparam VW = 4;
localparam FW = 8;
localparam LINE_W = 1 << HW;

localparam CMD_WRITE = 4'b0100;

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
reg              init_n = 1'b1;
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
wire [12:0]      SDRAM_A;
wire [15:0]      SDRAM_DQ;
wire             SDRAM_DQML, SDRAM_DQMH;
wire             SDRAM_nWE, SDRAM_nCAS, SDRAM_nRAS, SDRAM_nCS;
wire [1:0]       SDRAM_BA;
wire             SDRAM_CKE;
wire [7:0]       st_dout;
wire [3:0]       sdram_cmd = { SDRAM_nCS, SDRAM_nRAS, SDRAM_nCAS, SDRAM_nWE };

integer errors = 0;
integer write_count = 0;
integer timeout = 0;
integer i;
integer sdram_x;
reg [LINE_W-1:0] wrote = 0;
reg [15:0]       sdram_shadow [0:LINE_W-1];

`include "test_tasks.vh"

always #5 clk = ~clk;

function [15:0] pattern;
    input [HW-1:0] x;
begin
    pattern = 16'h5000 | { 8'd0, x };
end
endfunction

jtframe_lfbuf_sdr_ctrl #(
    .VW(VW),
    .HW(HW)
) uut (
    .rst         ( rst         ),
    .clk         ( clk         ),
    .pxl_cen     ( pxl_cen     ),
    .lhbl        ( lhbl        ),
    .ln_done     ( ln_done     ),
    .vrender     ( vrender     ),
    .ln_v        ( req_v       ),
    .vs          ( vs          ),
    .frame       ( frame       ),
    .fb_blank    ( fb_blank    ),
    .fb_addr     ( fb_addr     ),
    .fb_din      ( fb_din      ),
    .fb_clr      ( fb_clr      ),
    .fb_done     ( fb_done     ),
    .fb_dout     ( fb_dout     ),
    .rd_addr     ( rd_addr     ),
    .line        ( line        ),
    .scr_we      ( scr_we      ),
    .init_n      ( init_n      ),
    .SDRAM_A     ( SDRAM_A     ),
    .SDRAM_DQ    ( SDRAM_DQ    ),
    .SDRAM_DQML  ( SDRAM_DQML  ),
    .SDRAM_DQMH  ( SDRAM_DQMH  ),
    .SDRAM_nWE   ( SDRAM_nWE   ),
    .SDRAM_nCAS  ( SDRAM_nCAS  ),
    .SDRAM_nRAS  ( SDRAM_nRAS  ),
    .SDRAM_nCS   ( SDRAM_nCS   ),
    .SDRAM_BA    ( SDRAM_BA    ),
    .SDRAM_CKE   ( SDRAM_CKE   ),
    .st_addr     ( st_addr     ),
    .st_dout     ( st_dout     )
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

assign SDRAM_DQ = sdram_cmd == CMD_WRITE ? 16'hZZZZ : 16'h0000;

always @(posedge clk) begin
    if( !rst && sdram_cmd == CMD_WRITE ) begin
        sdram_x = SDRAM_A[HW-1:0];
        if( SDRAM_DQML || SDRAM_DQMH ) begin
            $display("FAIL: SDR write %0d masked at x=%0d DQML=%b DQMH=%b",
                write_count, sdram_x, SDRAM_DQML, SDRAM_DQMH);
            fail();
        end
        if( wrote[sdram_x] ) begin
            $display("FAIL: duplicate SDR write for x=%0d data=%04x",
                sdram_x, SDRAM_DQ);
            fail();
        end
        wrote[sdram_x] = 1'b1;
        sdram_shadow[sdram_x] = SDRAM_DQ;
        if( SDRAM_DQ !== pattern(SDRAM_A[HW-1:0]) ) begin
            $display("FAIL: SDR write %0d x=%0d got %04x expected %04x fb_addr=%0d fb_din=%04x",
                write_count, sdram_x, SDRAM_DQ, pattern(SDRAM_A[HW-1:0]), fb_addr, fb_din);
            fail();
        end
        write_count = write_count + 1;
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

task pulse_done;
begin
    @(negedge clk);
    ln_done = 1'b1;
    @(posedge clk);
    @(negedge clk);
    ln_done = 1'b0;
end
endtask

initial begin
    for(i=0; i<LINE_W; i=i+1) begin
        sdram_shadow[i] = 16'hxxxx;
    end

    repeat(8) @(posedge clk);
    rst = 1'b0;
    repeat(160) @(posedge clk);

    fill_line();

    // Establish hblank length and hlim, and allow the controller's display-side
    // READ transaction to finish before the active slot used for the write.
    blank(32);
    active(800);
    blank(300);
    pulse_done();
    active(900);

    for(timeout=0; timeout<500 && write_count<LINE_W; timeout=timeout+1) begin
        @(posedge clk);
    end

    for(i=0; i<LINE_W; i=i+1) begin
        if( !wrote[i] ) begin
            $display("FAIL: missing SDR write for x=%0d after %0d writes", i, write_count);
            errors = errors + 1;
        end else if( sdram_shadow[i] !== pattern(i[HW-1:0]) ) begin
            $display("FAIL: SDR shadow x=%0d got %04x expected %04x",
                i, sdram_shadow[i], pattern(i[HW-1:0]));
            errors = errors + 1;
        end
    end

    if( write_count != LINE_W ) begin
        $display("FAIL: observed %0d SDR writes, expected %0d", write_count, LINE_W);
        errors = errors + 1;
    end

    if( errors != 0 ) begin
        $display("FAIL: %0d errors", errors);
        $finish;
    end

    pass();
end

endmodule
