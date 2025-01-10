module test;

localparam W=7; //8
localparam OFF=64;

reg clk, rst;
reg [7:0] dout;
reg play;
wire signed [W-1:0] snd_out;

/*
initial begin
    $dumpfile("test.lxt");
    $dumpvars;
    $dumpon;
    #10000000 $finish;
end
*/

initial begin
    clk=0;
    forever #10 clk=~clk;
end

integer snd_in=0,exp;

initial begin
    rst  = 1;
    play = 0;
    dout=0;
    repeat (20) @(posedge clk);
    rst  = 0;
    @(posedge clk)
    play = 1;
    for(snd_in=0;snd_in<128;snd_in=snd_in+1) begin
        dout=snd_in[7:0];
        repeat (2) @(posedge clk);
        exp = snd_in - OFF;
        @(posedge clk);
        if( {{32-W{snd_out[W-1]}},snd_out}!=exp) begin
            $display("Bad signed value at rom_dout %d",dout);
            $display("output vs expected: %d <> %d",snd_out,exp);
            $display("FAIL");
            $finish;
        end
    end
    $display("PASS");
    $finish;
end

jt007232_channel uut(
    .rst        ( rst     ),
    .clk        ( clk     ),
    .cen_q      ( 1'b1    ),
    .rom_start  ( 17'h0   ),
    .pre0       ( 12'hFFF ),
    .pre_sel    ( 2'b0    ),
    .loop       ( 1'b1    ),
    .play       ( play    ),
    .load       ( 1'b1    ),
    .rom_addr   (         ),
    .rom_cs     (         ),
    .rom_ok     ( 1'b1    ),
    .rom_dout   ( dout    ),
    .snd        ( snd_out )
);

endmodule