`timescale 1ns/1ps

module test;

`include "test_tasks.vh"

reg MCLK = 0;
reg RAS = 1, CAS = 1, WE = 1, OE = 1, SC = 0, SE = 0;
reg [7:0] AD = 0, RD_i = 0;
wire [7:0] RD_o, SD_o, RD_o_lookahead, SD_o_lookahead;
wire RD_d, SD_d, RD_d_lookahead, SD_d_lookahead;
integer i;

always #5 MCLK = ~MCLK;

vram uut(
    .MCLK ( MCLK ),
    .RAS  ( RAS  ),
    .CAS  ( CAS  ),
    .WE   ( WE   ),
    .OE   ( OE   ),
    .SC   ( SC   ),
    .SE   ( SE   ),
    .AD   ( AD   ),
    .RD_i ( RD_i ),
    .RD_o ( RD_o ),
    .RD_d ( RD_d ),
    .SD_o ( SD_o ),
    .SD_d ( SD_d )
);

vram #(.SERIAL_LOOKAHEAD(1'b1)) uut_lookahead(
    .MCLK ( MCLK ),
    .RAS  ( RAS  ),
    .CAS  ( CAS  ),
    .WE   ( WE   ),
    .OE   ( OE   ),
    .SC   ( SC   ),
    .SE   ( SE   ),
    .AD   ( AD   ),
    .RD_i ( RD_i ),
    .RD_o ( RD_o_lookahead ),
    .RD_d ( RD_d_lookahead ),
    .SD_o ( SD_o_lookahead ),
    .SD_d ( SD_d_lookahead )
);

task tick;
    begin
        @(posedge MCLK);
        #1;
    end
endtask

task set_page_address(input [15:0] address, input sc_on_load);
    begin
        @(negedge MCLK);
        RAS = 0; CAS = 1; WE = 1; OE = 0; SC = 0; AD = address[15:8];
        tick();
        @(negedge MCLK);
        CAS = 0; AD = address[7:0];
        tick();
        @(negedge MCLK);
        RAS = 1; CAS = 1;
        tick();
        @(negedge MCLK);
        OE = 1; SC = sc_on_load;
        tick();
    end
endtask

task sc_gap2;
    begin
        @(negedge MCLK); SC = 0;
        tick();
        @(negedge MCLK); SC = 1;
        tick();
    end
endtask

task sc_gap4;
    begin
        @(negedge MCLK); SC = 0;
        repeat (3) begin
            tick();
            @(negedge MCLK);
        end
        SC = 1;
        tick();
    end
endtask

task dram_write(input [15:0] address, input [7:0] value);
    begin
        @(negedge MCLK);
        RAS = 0; CAS = 1; WE = 1; OE = 1; SC = 0; AD = address[15:8];
        tick();
        @(negedge MCLK);
        CAS = 0; AD = address[7:0];
        tick();
        @(negedge MCLK);
        WE = 0; RD_i = value;
        tick();
        @(negedge MCLK);
        RAS = 1; CAS = 1; WE = 1;
        tick();
    end
endtask

task dram_read(input [15:0] address, input [7:0] expected);
    begin
        @(negedge MCLK);
        RAS = 0; CAS = 1; WE = 1; OE = 1; SC = 0; AD = address[15:8];
        tick();
        @(negedge MCLK);
        CAS = 0; AD = address[7:0];
        tick();
        @(negedge MCLK);
        OE = 0;
        tick();
        if (RD_o !== expected || RD_o_lookahead !== expected || RD_d !== 1'b0 || RD_d_lookahead !== 1'b0) begin
            $display("FAIL: DRAM read addr=%04x got=%02x/%02x valid_n=%b/%b expected=%02x",
                address,RD_o,RD_o_lookahead,RD_d,RD_d_lookahead,expected);
            fail();
        end
        @(negedge MCLK);
        OE = 1; RAS = 1; CAS = 1;
        tick();
    end
endtask

initial begin : test_serial_latency
    $dumpfile("test.lxt");
    $dumpvars(0,test);

    // This isolated testbench initializes the RAM contents and unreset state
    // so each observed byte is known before the first protocol transaction.
    for (i=0; i<65536; i=i+1) begin
        uut.mem[i] = 8'h00;
        uut_lookahead.mem[i] = 8'h00;
    end
    uut.addr = 0; uut.dt = 0; uut.addr_ser = 0; uut.addr_ser_page = 0;
    uut.o_OE = 1; uut.o_RAS = 1; uut.o_cas = 0; uut.o_SC = 0; uut.o_valid = 0;
    uut.ser_o = 0; uut.vram_ser = 0; uut.RD_o = 0;
    uut_lookahead.addr = 0; uut_lookahead.dt = 0;
    uut_lookahead.addr_ser = 0; uut_lookahead.addr_ser_page = 0;
    uut_lookahead.o_OE = 1; uut_lookahead.o_RAS = 1;
    uut_lookahead.o_cas = 0; uut_lookahead.o_SC = 0; uut_lookahead.o_valid = 0;
    uut_lookahead.ser_o = 0; uut_lookahead.vram_ser = 0; uut_lookahead.RD_o = 0;

    // Establish an old-page serial byte, then give the read register time to
    // expose a distinct next byte before the new page arrives.
    uut.mem[16'h0004] = 8'ha6; uut_lookahead.mem[16'h0004] = 8'ha6;
    uut.mem[16'h0005] = 8'hb7; uut_lookahead.mem[16'h0005] = 8'hb7;
    uut.mem[16'h00fc] = 8'h05; uut_lookahead.mem[16'h00fc] = 8'h05;
    uut.mem[16'h00fd] = 8'h00; uut_lookahead.mem[16'h00fd] = 8'h00;
    uut.mem[16'h00fe] = 8'hfd; uut_lookahead.mem[16'h00fe] = 8'hfd;
    uut.mem[16'h00ff] = 8'h03; uut_lookahead.mem[16'h00ff] = 8'h03;

    set_page_address(16'h0004,1'b0);
    tick();
    @(negedge MCLK); SC = 1;
    tick();
    if (SD_o !== 8'ha6 || SD_o_lookahead !== 8'ha6) begin
        $display("FAIL: old-page seed got %02x/%02x expected a6",SD_o,SD_o_lookahead);
        fail();
    end

    set_page_address(16'h00fc,1'b0);
    if (uut.ser_o !== 8'hb7 || uut_lookahead.ser_o !== 8'h05 ||
        uut.addr_ser !== 8'hfc || uut_lookahead.addr_ser !== 8'hfc) begin
        $display("FAIL: page-load read address serial=%02x/%02x ser_o=%02x/%02x expected fc/fc b7/05",
            uut.addr_ser,uut_lookahead.addr_ser,uut.ser_o,uut_lookahead.ser_o);
        fail();
    end

    // First SC is on the next MCLK after page load. Default behavior retains
    // the old-page byte; lookahead makes the new page's first byte available.
    @(negedge MCLK); SC = 1;
    tick();
    if (SD_o !== 8'hb7 || SD_o_lookahead !== 8'h05) begin
        $display("FAIL: immediate first SC got %02x/%02x expected default b7/lookahead05",SD_o,SD_o_lookahead);
        fail();
    end
    sc_gap2();
    if (SD_o !== 8'h00 || SD_o_lookahead !== 8'h00) begin
        $display("FAIL: two-MCLK SC cadence got %02x/%02x expected 00",SD_o,SD_o_lookahead);
        fail();
    end
    sc_gap4();
    if (SD_o !== 8'hfd || SD_o_lookahead !== 8'hfd) begin
        $display("FAIL: four-MCLK SC cadence got %02x/%02x expected fd",SD_o,SD_o_lookahead);
        fail();
    end
    sc_gap4();
    if (SD_o !== 8'h03 || SD_o_lookahead !== 8'h03) begin
        $display("FAIL: serial byte order got %02x/%02x expected 03",SD_o,SD_o_lookahead);
        fail();
    end

    // Page load retains priority over a coincident SC rising edge: capture
    // the requested address without incrementing, and hold registered SD.
    set_page_address(16'h00fc,1'b1);
    if (uut.addr_ser !== 8'hfc || uut_lookahead.addr_ser !== 8'hfc ||
        SD_o !== 8'h03 || SD_o_lookahead !== 8'h03 || uut_lookahead.ser_o !== 8'h05) begin
        $display("FAIL: page-load/SC priority addr=%02x/%02x SD=%02x/%02x serial=%02x",
            uut.addr_ser,uut_lookahead.addr_ser,SD_o,SD_o_lookahead,uut_lookahead.ser_o);
        fail();
    end

    // The ordinary DRAM write/read path is unchanged by the serial mux.
    dram_write(16'h0123,8'h5a);
    if (uut.mem[16'h0123] !== 8'h5a || uut_lookahead.mem[16'h0123] !== 8'h5a) begin
        $display("FAIL: DRAM write memory=%02x/%02x expected 5a",uut.mem[16'h0123],uut_lookahead.mem[16'h0123]);
        fail();
    end
    dram_read(16'h0123,8'h5a);

    $display("VRAM serial latency PASS: default immediate=b7 lookahead immediate=05; gaps=2/4 MCLK; page priority and DRAM read/write verified");
    pass();
end

endmodule
