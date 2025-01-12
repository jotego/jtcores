`timescale  1ns/1ps

module test;
    reg  clk, rst, ack, dst, rdy;
    wire rd,wr;

    initial begin
        clk=0;
        forever #10 clk=~clk;
    end

    always @(posedge clk) begin
        {rdy,dst,ack} <= {dst,ack,rd|wr};
    end

    initial begin
        rst=0;
        #50 rst=1;
        #50 rst=0;
        #4_0000 $finish;
    end

    initial begin
        $dumpfile("test.lxt");
        $dumpvars;
    end

    jtframe_ram1_1slot uut(
        .rst        ( rst       ),
        .clk        ( clk       ),

        .slot0_addr (  8'd0     ),
        .slot0_dout (           ),
        .slot0_din  (  16'd0    ),

        .slot0_offset( 22'd0    ),

        .slot0_cs   ( 1'b0      ),
        .slot0_ok   (           ),
        .slot0_wen  ( 1'b0      ),
        .slot0_wrmask( 2'b0     ),
        .hold_rst   (           ),

        // SDRAM controller interface
        .sdram_ack  ( ack       ),
        .sdram_rd   ( rd        ),
        .sdram_wr   ( wr        ),
        .sdram_addr (           ),
        .data_rdy   ( rdy       ),
        .data_dst   ( dst       ),
        .data_read  ( 16'd0     ),
        .data_write (           ),  // only 16-bit writes
        .sdram_wrmask(          )   // each bit is active low
    );

endmodule