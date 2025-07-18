module test;

`include "test_tasks.vh"

wire      rst, clk, pxl_cen, hs, vs, lvbl, lhbl, rdy;
reg       cs, rnw, prog_done, first=0;
reg [3:0] addr;
reg [7:0] din;

assign rdy = prog_done & first;

task write_all(input [127:0] cfg);
    for(integer k=0;k<16;k=k+1) write(k,cfg[(15-k)*8+:8]);
endtask

task write(input [3:0]a, input [7:0] d);
    addr = a;
    rnw  = 0;
    cs   = 1;
    din  = d;
    repeat(2) @(negedge clk);
    rnw  = 1;
    cs   = 0;
    repeat(2) @(negedge clk);
endtask    

initial begin
    prog_done = 0;
    repeat (100) @(negedge clk);
    write_all(128'h01_FF_00_21_00_37_01_00_01_20_0C_0E_54_00_00_00);
    prog_done = 1;
    repeat (512*256*4) @(negedge pxl_cen);
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
    assert_msg(uut.vcnt==9'h21,"lvbl at unexpected time");
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

jtframe_test_clocks #(.PXLCLK(8),.MAXFRAMES(5)) u_clocks(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   )
);

endmodule