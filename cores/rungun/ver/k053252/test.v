`timescale 1ns/1ps

module test;

`include "test_tasks.vh"

reg rst, clk; // 32 MHz

wire      nc, pxl_cen, hs, vs, lvbl, lhbl, rdy;
reg       cs, rnw, prog_done, first=0;
reg [3:0] addr;
reg [7:0] din;

initial begin
    clk=0;
    forever #15.625 clk=~clk;   // 32 MHz
end

initial begin
    rst=0;
    #10 rst=1;
    #350 rst=0;
end

assign rdy = prog_done & first;

task write_all(input [127:0] cfg);
    for(integer k=0;k<16;k=k+1) write(k,cfg[(15-k)*8+:8]);
endtask

task write(input [3:0]a, input [7:0] d);
    addr = a;
    rnw  = 0;
    cs   = 1;
    din  = d;
    repeat(4) @(negedge clk);
    rnw  = 1;
    cs   = 0;
    repeat(4) @(negedge clk);
endtask    

initial begin
    prog_done = 0;
    repeat (100) @(negedge clk);
    write_all(128'h01_FF_00_21_00_37_01_00_01_20_0C_0E_54_00_00_00);
    prog_done = 1;
    repeat (512*256*6) @(negedge pxl_cen);
    pass();
end

always @(posedge clk) if(pxl_cen & rdy) begin
    assert_msg( !vs || !lvbl,"vs cannot be high if lvbl is high too");
    assert_msg( !hs || !lhbl,"hs cannot be high if lhbl is high too");
end

always @(negedge lvbl) if(prog_done) begin
    first <= 1;
end

always @(posedge lvbl) if(rdy) begin
    assert_msg(uut.vcnt==9'hf7,"lvbl at unexpected time");
end

reg lvbl_l;
reg [8:0] lines;

always @(posedge hs) begin
    if(!rdy) begin
        lines  <= 0;
        lvbl_l <= 0;
    end else begin
        lvbl_l <= lvbl;
        lines <= lines + 1;
        if(!lvbl && lvbl_l) begin
            lines <= 1;
            if(lines!=0) assert_msg(lines==9'd289,"Must have 289 lines");
        end
    end
end

jtk053252 uut(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .sel        ( 3'd0      ),

    .cs         ( cs        ),
    .addr       ( addr      ),
    .rnw        ( rnw       ),
    .din        ( din       ),
    .dout       (           ),

    .lvbl       ( lvbl      ),
    .hs         ( hs        ),
    .vs         ( vs        ),
    .lhbl       ( lhbl      ),
    // IOCTL dump
    .ioctl_addr (           ),
    .ioctl_din  (           )
);

// Furrtek's model for the chip. Use as reference
k053252 u_ref(
    .PIN_RESET  ( ~rst              ),
    .PIN_CLK    ( clk               ),
    .PIN_SEL    ( 3'd0              ),
    .PIN_CCS    ( ~cs               ),
    .PIN_RW     ( rnw               ),
    .PIN_AB     ( addr              ),
    .PIN_DB_IN  ( din               ),
    .PIN_HLD1   ( 1'b1              ),
    .PIN_VLD1   ( 1'b1              )
);

jtframe_frac_cen #(2,3) u_frac_cen(
    .clk    ( clk       ),
    .n      ( 3'd1      ),
    .m      ( 3'd4      ),
    .cen    ( {nc,pxl_cen} ),
    .cenb   (           )
);

initial begin
    $dumpfile("test.lxt");
    $dumpvars;
    $dumpon;
end

endmodule