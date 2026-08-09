`timescale 1ns / 1ps

module test;

localparam HW     = 8;
localparam VW     = 8;
localparam FW     = 8;
localparam AW     = HW+VW+1;
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
reg  [VW-1:0]    req_v = 8'd3;
reg              ln_done = 1'b0;
reg  [HW-1:0]    ln_addr = 0;
reg  [15:0]      ln_data = 0;
reg              ln_we = 1'b0;
reg              fb_keep = 1'b0;

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
wire [21:16]     cr_addr;
wire [15:0]      cr_adq;
wire             cr_wait;
wire             cr_clk;
wire             cr_advn;
wire             cr_cre;
wire [1:0]       cr_cen;
wire             cr_oen;
wire             cr_wen;
wire [1:0]       cr_dsn;
wire             psram_wr;
wire [AW-1:0]    psram_addr;
wire [15:0]      psram_din;

integer errors = 0;
integer write_count = 0;
integer masked_count = 0;
integer timeout = 0;
integer i;
reg check_writes = 1'b0;
reg saw_done = 1'b0;
reg [AW-1:0] check_addr;
reg [VW:0] write_base = 0;

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
    sparse = x[1:0] == 2'b01 ? 16'h0000 : (16'h6000 | { 8'd0, x });
end
endfunction

function [15:0] keep_expected;
    input [HW-1:0] x;
begin
    keep_expected = sparse(x) == 16'h0000 ? baseline(x) : sparse(x);
end
endfunction

jtframe_lfbuf_ctrl #(
    .VW(VW),
    .HW(HW)
) uut (
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .lhbl       ( lhbl      ),
    .vs         ( vs        ),
    .ln_done    ( ln_done   ),
    .fb_keep    ( fb_keep   ),
    .vrender    ( vrender   ),
    .ln_v       ( req_v     ),
    .frame      ( frame     ),
    .fb_blank   ( fb_blank  ),
    .fb_addr    ( fb_addr   ),
    .fb_din     ( fb_din    ),
    .fb_clr     ( fb_clr    ),
    .fb_done    ( fb_done   ),
    .fb_dout    ( fb_dout   ),
    .rd_addr    ( rd_addr   ),
    .line       ( line      ),
    .scr_we     ( scr_we    ),
    .cr_addr    ( cr_addr   ),
    .cr_adq     ( cr_adq    ),
    .cr_wait    ( cr_wait   ),
    .cr_clk     ( cr_clk    ),
    .cr_advn    ( cr_advn   ),
    .cr_cre     ( cr_cre    ),
    .cr_cen     ( cr_cen    ),
    .cr_oen     ( cr_oen    ),
    .cr_wen     ( cr_wen    ),
    .cr_dsn     ( cr_dsn    )
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

psram_model #(
    .HW(HW),
    .VW(VW)
) u_psram (
    .clk        ( cr_clk     ),
    .cr_addr    ( cr_addr    ),
    .cr_adq     ( cr_adq     ),
    .cr_wait    ( cr_wait    ),
    .cr_advn    ( cr_advn    ),
    .cr_cre     ( cr_cre     ),
    .cr_cen     ( cr_cen     ),
    .cr_oen     ( cr_oen     ),
    .cr_wen     ( cr_wen     ),
    .cr_dsn     ( cr_dsn     ),
    .wr         ( psram_wr   ),
    .wr_addr    ( psram_addr ),
    .wr_data    ( psram_din  )
);

always @(posedge clk) begin
    if( !rst && check_writes && fb_done ) saw_done = 1'b1;
    if( !rst && check_writes && uut.st == uut.WRITEOUT && cr_wait && cr_oen && !cr_wen ) begin
        if( cr_dsn == 2'b11 ) masked_count = masked_count + 1;
    end
    if( !rst && check_writes && psram_wr ) begin
        if( write_count == 0 ) write_base = psram_addr[AW-1:HW];
        write_count = write_count + 1;
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
    blank(320);
end
endtask

task write_current_line;
    input integer expect_writes;
    input integer expect_masked;
begin
    write_count = 0;
    masked_count = 0;
    saw_done = 1'b0;
    pulse_done();
    check_writes = 1'b1;
    active(900);

    for(timeout=0; timeout<700 && !saw_done; timeout=timeout+1) @(posedge clk);
    check_writes = 1'b0;

    if( !saw_done ) begin
        $display("FAIL: timed out waiting for CRAM line write completion");
        errors = errors + 1;
    end
    if( write_count != expect_writes ) begin
        $display("FAIL: observed %0d CRAM writes, expected %0d", write_count, expect_writes);
        errors = errors + 1;
    end
    if( fb_keep && write_base[VW] !== 1'b0 ) begin
        $display("FAIL: CRAM keep write used bank %0d, expected fixed bank 0", write_base[VW]);
        errors = errors + 1;
    end
    if( masked_count != expect_masked ) begin
        $display("FAIL: observed %0d CRAM masked writes, expected %0d", masked_count, expect_masked);
        errors = errors + 1;
    end
end
endtask

task check_storage;
    input integer expect_keep_mode;
    input integer expect_sparse_mode;
    reg [15:0] expected;
begin
    for(i=0; i<LINE_W; i=i+1) begin
        check_addr = { write_base, i[HW-1:0] };
        if( expect_keep_mode )
            expected = keep_expected(i[HW-1:0]);
        else if( expect_sparse_mode )
            expected = sparse(i[HW-1:0]);
        else
            expected = baseline(i[HW-1:0]);

        if( u_psram.mem[check_addr] !== expected ) begin
            $display("FAIL: CRAM storage addr=%0d got %04x expected %04x",
                i, u_psram.mem[check_addr], expected);
            errors = errors + 1;
        end
    end
end
endtask

initial begin
    repeat(8) @(posedge clk);
    rst = 1'b0;
    repeat(40) @(posedge clk);

    fb_keep = 1'b1;
    fill_line(0);
    establish_timing();
    write_current_line(LINE_W, 0);
    check_storage(0, 0);

    pulse_vs();
    if( frame !== 1'b1 ) begin
        $display("FAIL: frame did not toggle before CRAM keep-bank check");
        errors = errors + 1;
    end

    fb_keep = 1'b1;
    fill_line(1);
    establish_timing();
    write_current_line(LINE_W - LINE_W/4, LINE_W/4);
    check_storage(1, 0);

    fb_keep = 1'b0;
    fill_line(1);
    establish_timing();
    write_current_line(LINE_W, 0);
    check_storage(0, 1);

    if( errors != 0 ) begin
        $display("FAIL: %0d errors", errors);
        $finish;
    end

    pass();
end

endmodule

module psram_model #(parameter
    HW = 8,
    VW = 8
)(
    input              clk,
    input      [21:16] cr_addr,
    inout      [15:0]  cr_adq,
    output reg         cr_wait,
    input              cr_advn,
    input              cr_cre,
    input      [1:0]   cr_cen,
    input              cr_oen,
    input              cr_wen,
    input      [1:0]   cr_dsn,
    output reg         wr,
    output reg [HW+VW:0] wr_addr,
    output reg [15:0]  wr_data
);

localparam AW = HW+VW+1;

reg [15:0] mem[0:(1<<AW)-1];
reg [21:0] burst_addr = 0;
reg [1:0]  latency = 0;
reg        active = 1'b0;
reg        drive = 1'b0;
reg [15:0] dout = 16'd0;

wire selected = !cr_cen[0];
wire write_cyc = selected && active && cr_wait && !cr_cre && cr_oen && !cr_wen;
wire read_cyc  = selected && active && cr_wait && !cr_cre && !cr_oen && cr_wen;

assign cr_adq = drive ? dout : 16'hzzzz;

always @(posedge clk) begin
    wr <= 1'b0;
    if( !selected ) begin
        active  <= 1'b0;
        cr_wait <= 1'b0;
        drive   <= 1'b0;
        latency <= 0;
    end else if( !cr_advn ) begin
        burst_addr <= { cr_addr, cr_adq };
        active     <= 1'b1;
        cr_wait    <= 1'b0;
        drive      <= 1'b0;
        latency    <= 2;
    end else if( active ) begin
        if( latency != 0 ) begin
            latency <= latency - 1'd1;
            cr_wait <= 1'b0;
            drive   <= 1'b0;
        end else begin
            cr_wait <= 1'b1;
            drive   <= read_cyc;
            if( write_cyc ) begin
                if( cr_dsn != 2'b11 ) begin
                    mem[burst_addr[AW-1:0]] <= cr_adq;
                    wr      <= 1'b1;
                    wr_addr <= burst_addr[AW-1:0];
                    wr_data <= cr_adq;
                end
                burst_addr <= burst_addr + 1'd1;
            end else if( read_cyc ) begin
                dout    <= mem[burst_addr[AW-1:0]];
                burst_addr <= burst_addr + 1'd1;
            end
        end
    end
end

endmodule
