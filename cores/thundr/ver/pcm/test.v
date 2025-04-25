module test;

`include "test_tasks.vh"

wire        rst, clk, lvbl, lhbl, rom_cs;
wire [ 7:0] pcm;
wire        cen;
reg         addr=0, wr=0, rom_ok=0;
reg  [ 7:0] din=0, rom_data=0;
wire [18:0] rom_addr;

localparam [0:0] SELECT=1'b1, KON=1'b0;

always @(posedge clk) begin
    rom_ok <= rom_cs;
end

always @*begin
    case(rom_addr)
        6: rom_data = 8'h12;
        7: rom_data = 8'h34;
        'h1234: rom_data = 8'hab;
        'h1235: rom_data = 8'hcd;
        'h1236: rom_data = 8'hef;
        'h1237: rom_data = 8'h00;
        'h1238: rom_data = 8'h10;
        'h1239: rom_data = 8'h56;
        'h123a: rom_data = 8'h78;
        'h123b: rom_data = 8'hff;
        default: rom_data = 0;
    endcase
end

task ctl_wr( input kon, input [7:0] data );
    addr = kon;
    din  = data;
    wr   = 1;
    repeat (2) @(posedge clk);
    wr   = 0;
    repeat (2) @(posedge clk);
endtask

initial begin
    repeat (2) @(negedge lhbl);
    ctl_wr(SELECT, 8'h3 );
    ctl_wr(   KON, 8'h8>>2 );
    repeat (2) @(negedge lhbl);
    pass();
end

jtthundr_pcm_single uut(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cen        ( cen           ),
    .addr       ( addr          ),
    .din        ( din           ),
    .wr         ( wr            ),

    .rom_addr   ( rom_addr      ),
    .rom_data   ( rom_data      ),
    .rom_cs     ( rom_cs        ),
    .rom_ok     ( rom_ok        ),

    .snd        ( pcm           )
);

jtframe_test_clocks clocks(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .lvbl       ( lvbl          ),
    .lhbl       ( lhbl          ),
    .pxl_cen    ( cen           )
);

endmodule