`timescale 1ns / 1ps

module test;

localparam HW     = 8;
localparam VW     = 8;
localparam FW     = 8;
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
wire [HW+VW:0]   psram_addr;
wire [15:0]      psram_din;

integer errors = 0;
integer write_count = 0;
integer timeout = 0;
integer i;
reg check_writes = 1'b0;

`include "test_tasks.vh"

always #5 clk = ~clk;

function [15:0] pattern;
    input [HW-1:0] x;
begin
    pattern = 16'h6000 | { 8'd0, x };
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
    .wr         ( psram_wr   ),
    .wr_addr    ( psram_addr ),
    .wr_data    ( psram_din  )
);

always @(posedge clk) begin
    if( !rst && check_writes && psram_wr ) begin
        if( write_count < LINE_W ) begin
            if( psram_addr[HW-1:0] !== write_count[HW-1:0] ) begin
                $display("FAIL: CRAM write %0d used address %0d",
                    write_count, psram_addr[HW-1:0]);
                fail();
            end
            if( psram_din !== pattern(write_count[HW-1:0]) ) begin
                $display("FAIL: CRAM write %0d addr=%0d got %04x expected %04x fb_addr=%0d fb_din=%04x",
                    write_count, psram_addr[HW-1:0], psram_din,
                    pattern(write_count[HW-1:0]), fb_addr, fb_din);
                fail();
            end
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
    repeat(8) @(posedge clk);
    rst = 1'b0;
    repeat(40) @(posedge clk);

    fill_line();

    // Establish hblank length and hlim, and allow the controller's display-side
    // READ transaction to finish before the active slot used for the write.
    blank(32);
    active(800);
    blank(320);
    pulse_done();
    check_writes = 1'b1;
    active(900);

    for(timeout=0; timeout<500 && write_count<LINE_W; timeout=timeout+1) begin
        @(posedge clk);
    end
    check_writes = 1'b0;

    if( write_count < LINE_W ) begin
        $display("FAIL: observed only %0d CRAM writes, expected %0d", write_count, LINE_W);
        errors = errors + 1;
    end

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
                mem[burst_addr[AW-1:0]] <= cr_adq;
                wr      <= 1'b1;
                wr_addr <= burst_addr[AW-1:0];
                wr_data <= cr_adq;
                burst_addr <= burst_addr + 1'd1;
            end else if( read_cyc ) begin
                dout    <= mem[burst_addr[AW-1:0]];
                burst_addr <= burst_addr + 1'd1;
            end
        end
    end
end

endmodule
