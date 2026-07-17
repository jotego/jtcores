`timescale 1ns / 1ps

module test;

localparam HW = 9;
localparam VW = 4;
localparam FW = 8;
localparam BRAM_HW = 8;
localparam LINE_W = 1 << HW;
localparam BRAM_LINE_W = 1 << BRAM_HW;

reg              rst = 1'b1;
reg              clk = 1'b0;
reg              pxl_cen = 1'b0;
reg              lhbl = 1'b0;
reg              hs = 1'b0;
reg              vs = 1'b0;
reg              lvbl = 1'b1;
reg  [VW-1:0]    vrender = 0;
reg  [HW-1:0]    hdump = 0;
reg              ln_done = 1'b0;
reg  [HW-1:0]    ln_addr = 0;
reg  [15:0]      ln_data = 0;
reg              ln_we = 1'b0;
reg              fb_keep = 1'b0;
reg  [7:0]       st_addr = 8'd0;

wire             ln_hs, ln_vs, ln_lvbl;
wire [VW-1:0]    ln_v;
wire [15:0]      ln_dout, ln_pxl;
wire [7:0]       st_dout;

integer errors = 0;
integer i;
integer timeout;
reg     saw_done;
reg  [BRAM_HW+VW:0] check_addr;
reg              cen_div = 1'b0;

`include "test_tasks.vh"

always #5 clk = ~clk;

always @(posedge clk) begin
    cen_div <= ~cen_div;
    pxl_cen <= cen_div;
end

function [15:0] pattern;
    input [HW-1:0] x;
begin
    pattern = 16'h5000 | { 7'd0, x };
end
endfunction

function [15:0] stored_word;
    input [BRAM_HW+VW:0] addr;
begin
    stored_word = {
        uut.u_ctrl.u_ram.u_hi.u_ram.mem[addr],
        uut.u_ctrl.u_ram.u_lo.u_ram.mem[addr]
    };
end
endfunction

jtframe_lfbuf_bram #(
    .DW(16),
    .VW(VW),
    .HW(HW),
    .FW(FW)
) uut (
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .vrender    ( vrender   ),
    .hdump      ( hdump     ),
    .hs         ( hs        ),
    .vs         ( vs        ),
    .lhbl       ( lhbl      ),
    .lvbl       ( lvbl      ),
    .h_step     ( 9'h100    ),
    .v_step     ( 9'h100    ),
    .ln_addr    ( ln_addr   ),
    .ln_data    ( ln_data   ),
    .ln_done    ( ln_done   ),
    .ln_we      ( ln_we     ),
    .fb_keep    ( fb_keep   ),
    .ln_hs      ( ln_hs     ),
    .ln_vs      ( ln_vs     ),
    .ln_lvbl    ( ln_lvbl   ),
    .ln_dout    ( ln_dout   ),
    .ln_pxl     ( ln_pxl    ),
    .ln_v       ( ln_v      ),
    .st_addr    ( st_addr   ),
    .st_dout    ( st_dout   )
);

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
    for(j=0; j<n;) begin
        @(posedge clk);
        if( pxl_cen ) j=j+1;
    end
end
endtask

task blank;
    input integer n;
    integer j;
begin
    @(negedge clk);
    lhbl = 1'b0;
    for(j=0; j<n;) begin
        @(posedge clk);
        if( pxl_cen ) j=j+1;
    end
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

task run_384_count_write_line;
begin
    saw_done = 1'b0;
    pulse_done();
    @(negedge clk);
    lhbl = 1'b1;
    for(timeout=0; timeout<256;) begin
        @(posedge clk);
        if( uut.u_ctrl.fb_done ) saw_done = 1'b1;
        if( pxl_cen ) timeout=timeout+1;
    end
    @(negedge clk);
    lhbl = 1'b0;
    for(timeout=0; timeout<128;) begin
        @(posedge clk);
        if( uut.u_ctrl.fb_done ) saw_done = 1'b1;
        if( pxl_cen ) timeout=timeout+1;
    end

    if( !saw_done ) begin
        $display("FAIL: BRAM write did not complete within a 384-count line");
        errors = errors + 1;
    end
end
endtask

task check_storage;
begin
    for(i=0; i<BRAM_LINE_W; i=i+1) begin
        check_addr = { 1'b0, {VW{1'b0}}, i[BRAM_HW-1:0] };
        if( stored_word(check_addr) !== pattern(i[HW-1:0]) ) begin
            $display("FAIL: BRAM storage addr=%0d got %04x expected %04x",
                i, stored_word(check_addr), pattern(i[HW-1:0]));
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

    // Establish hblank length and hlim for a 384-count video line.
    active(256);
    blank(128);
    active(256);
    blank(128);

    if( uut.u_ctrl.hlim !== 9'd256 ) begin
        $display("FAIL: hlim=%0d expected 256 for 384-count line", uut.u_ctrl.hlim);
        errors = errors + 1;
    end

    run_384_count_write_line();
    check_storage();

    if( errors != 0 ) begin
        $display("FAIL: %0d errors", errors);
        $finish;
    end

    pass();
end

endmodule
