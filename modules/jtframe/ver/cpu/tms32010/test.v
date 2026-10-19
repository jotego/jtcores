// Checks that RET returns to the instruction after a two-word CALL, both for
// a CALL reached in sequence and for one reached through CALA. A return one
// word early runs the CALL's operand, 0030, as ADD 30h, and adds 33h to ACC.
// The accumulator is sent to port 1 after the first CALL and to port 2 after
// the second one.
module test;

reg         clk = 0, rst = 1, cen = 0;
reg  [ 1:0] div = 0;
reg  [15:0] rom[0:4095];
reg  [15:0] rom_data, port1 = 16'hffff, port2 = 16'hffff;
wire [11:0] rom_addr;
wire [15:0] dout;
wire [ 2:0] port;
wire        wr, rd;
integer     k;

initial begin
    for( k=0; k<4096; k=k+1 ) rom[k] = 16'h7f80;   // NOP
    rom['h000] = 16'hf900; rom['h001] = 16'h0004;   // B 004
    rom['h002] = 16'hf900; rom['h003] = 16'h0002;   // B 002, interrupt vector
    rom['h004] = 16'h7e33;                          // LACK 33h
    rom['h005] = 16'h5030;                          // SACL 30h
    rom['h006] = 16'h7e05;                          // LACK 05h
    rom['h007] = 16'hf800; rom['h008] = 16'h0030;   // CALL 030
    rom['h009] = 16'h5001;                          // SACL 1
    rom['h00a] = 16'h4901;                          // OUT 1,PA1
    rom['h00b] = 16'h7e20;                          // LACK 20h
    rom['h00c] = 16'h7f8c;                          // CALA -> 020
    rom['h00d] = 16'h5002;                          // SACL 2
    rom['h00e] = 16'h4a02;                          // OUT 2,PA2
    rom['h00f] = 16'hf900; rom['h010] = 16'h000f;   // B 00f
    rom['h020] = 16'hf800; rom['h021] = 16'h0030;   // CALL 030
    rom['h022] = 16'h7f8d;                          // RET
    rom['h030] = 16'h7f8d;                          // RET
end

always #10 clk = ~clk;

always @(posedge clk) begin
    div      <= div + 2'd1;
    cen      <= div == 2'd3;
    rom_data <= rom[rom_addr];
    if( cen && wr ) case( port )
        3'd1: port1 <= dout;
        3'd2: port2 <= dout;
        default:;
    endcase
end

jtframe_tms32010 uut(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cen        ( cen       ),
    .hold       ( 1'b0      ),
    .int_n      ( 1'b1      ),
    .bio_n      ( 1'b1      ),
    .rom_addr   ( rom_addr  ),
    .rom_data   ( rom_data  ),
    .port       ( port      ),
    .din        ( 16'd0     ),
    .dout       ( dout      ),
    .wr         ( wr        ),
    .rd         ( rd        )
);

initial begin
    repeat(40)   @(posedge clk);
    rst = 0;
    repeat(8000) @(posedge clk);
    if( port1 == 16'h0005 && port2 == 16'h0020 )
        $display("PASS");
    else
        $display("FAIL: port1=%04x (want 0005) port2=%04x (want 0020)", port1, port2);
    $finish;
end

endmodule
