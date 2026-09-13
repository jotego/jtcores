// Smoke test for IKA32010: elaborate, reset, and let the DSP run a ROM of
// zeros. 0x0000 is ADD 0,0, a one-cycle instruction, so the program counter
// must walk up the address space one instruction per four clock enables. The
// value is mainly the verilator lint that simunit runs before this.
module test;
    reg         clk = 0, rst_n = 0;
    reg         cen = 0;
    wire        men_n, den_n, we_n;
    wire [11:0] aout;
    wire [15:0] dout;
    integer     fetches = 0;
    reg  [11:0] last = 0;

    always #10 clk = ~clk;
    always @(posedge clk) cen <= ~cen;

    // count instruction reads at consecutive addresses
    always @(posedge clk) if( cen && !men_n && aout != last ) begin
        if( aout == last + 12'd1 ) fetches = fetches + 1;
        last <= aout;
    end

    IKA32010 uut(
        .i_EMUCLK       ( clk       ),
        .i_CLKIN_PCEN   ( cen       ),
        .o_CLKOUT       (           ),
        .o_CLKOUT_PCEN  (           ),
        .o_CLKOUT_NCEN  (           ),
        .i_RS_n         ( rst_n     ),
        .o_MEN_n        ( men_n     ),
        .o_DEN_n        ( den_n     ),
        .o_WE_n         ( we_n      ),
        .o_AOUT         ( aout      ),
        .i_DIN          ( 16'd0     ),
        .o_DOUT         ( dout      ),
        .o_DOUT_OE      (           ),
        .i_BIO_n        ( 1'b1      ),
        .i_INT_n        ( 1'b1      )
    );

    initial begin
        repeat(20)   @(posedge clk);
        rst_n = 1;
        repeat(4000) @(posedge clk);
        if( fetches > 400 ) $display("PASS (%0d sequential fetches)", fetches);
        else                $display("FAIL: only %0d sequential fetches", fetches);
        $finish;
    end
endmodule
