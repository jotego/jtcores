module test;

localparam W=11;

reg clk;
reg signed [6:0] rawa, rawb;
reg [7:0] reg12;
wire signed [W-1:0] snda, sndb;

initial begin
    clk=0;
    forever #10 clk=~clk;
end

integer gain=0,expa,expb, gaina, gainb;

initial begin
    reg12=0;
    rawa=0;
    rawb=0;
    repeat (20) @(posedge clk);

    rawa=127;
    rawb=-128;
    for(gain=0;gain<256;gain=gain+1) begin
        reg12=gain[7:0];
        repeat (2) @(posedge clk);
        gaina = {1'b0,reg12[7:4]};
        gainb = {1'b0,reg12[3:0]};
        @(posedge clk);
        expa = rawa*gaina;
        expb = rawb*gainb;
        @(posedge clk);
        if(snda!=$signed(expa[W-1:0]) || sndb!=$signed(expb[W-1:0])) begin
            $display("Bad value at gain %d/%d",reg12[3:0],reg12[7:4]);
            $display("channel a: %d <> %d",snda,expa);
            $display("channel b: %d <> %d",sndb,expb);
            $display("FAIL");
            $finish;
        end
        if( expa[30:W-1]!={32-W{expa[31]}} || expb[30:W-1]!={32-W{expb[31]}}) begin
            $display("Bad sign at gain %d/%d",reg12[3:0],reg12[7:4]);
            $display("channel a: %d <> %d",snda,expa);
            $display("channel b: %d <> %d",sndb,expb);
            $display("FAIL");
            $finish;
        end
    end
    $display("PASS");
    $finish;
end


jt007232_gain uut(
    .clk        ( clk   ),
    .reg12      ( reg12 ),
    .swap_gains ( 1'b0  ),
    .rawa       ( rawa  ),
    .rawb       ( rawb  ),
    .snda       ( snda  ),
    .sndb       ( sndb  )
);

endmodule