module test;

localparam W=16;
localparam OFF=512;

reg clk, rst;
reg signed  [    9:0] sin_r, sin_l;
reg         [    7:0] gain_in;
wire signed [  W-1:0] snd_out;
wire signed [W*2-1:0] snd_out_s;

/*
initial begin
    $dumpfile("test.lxt");
    $dumpvars;
    $dumpon;
    // #10000000 $finish;
end
*/

initial begin
    clk=0;
    forever #10 clk=~clk;
end

integer snd_in=0,st=0,gain=0,exp_m,exp_s,exp_l,expd_l,expd_r,dec_s;
real    gain_dec, div = 64.0000;

initial begin
    rst  = 1;
    sin_r=0;
    sin_l=0;
    repeat (20) @(posedge clk);
    rst  = 0;
    gain_in=8'h80;
    @(posedge clk)
    for(snd_in=0;snd_in<1024;snd_in=snd_in+1) begin
        sin_r=snd_in[9:0];
        repeat (3) @(posedge clk);
        exp_m = $signed(snd_in[9:0]) << 6;
        @(posedge clk);
        if( snd_out!=exp_m) begin
            $display("Bad signed value (mono) at sin %d",sin_r);
            $display("output vs expected: %d <> %d",snd_out[15-:10],exp_m);
            $display("FAIL");
            $finish;
        end
        for(st=0;st<1024;st=st+5) begin
            sin_l=st[9:0];
            repeat (3) @(posedge clk);
            exp_l = $signed(st[9:0]) << 6;
            exp_s = (exp_l << W ) + exp_m[0+:W];
            @(posedge clk);
            if( snd_out_s!=exp_s) begin
                $display("Bad signed value (stereo) at sin %d/%d",sin_l,sin_r);
                $display("output vs expected: %d/%d <> %d/%d",snd_out_s[31-:10],snd_out_s[15-:10],exp_l,exp_m);
                $display("FAIL");
                $finish;
            end
            for(gain=0;gain<128;gain=gain+4) begin
                gain_in=gain[7:0];
                gain_dec = gain[7:0]/div;
                repeat (3) @(posedge clk);
                expd_l = (exp_l*gain_dec)/2;
                expd_r = (exp_m*gain_dec)/2;
                @(posedge clk);
                dec_s  = (expd_l << W) + expd_r[0+:W];
                @(posedge clk);
                if( snd_out!=expd_r) begin
                    $display("Bad signed value (mono) at gain %d,%0.5f",gain,gain_dec);
                    $display("output vs expected: %d <> %d",snd_out,expd_r);
                    $display("FAIL");
                    $finish;
                end
                if( snd_out_s!=dec_s) begin
                    $display("Bad signed value (stereo) at gain %d,%0.5f",gain,gain_dec);
                    $display("output vs expected: %d/%d <> %d/%d",snd_out_s[31-:W],snd_out_s[15-:W],expd_l,expd_r);
                    $display("FAIL");
                    $finish;
                end
            end
        gain_in=8'h80;
        end
    end
    $display("PASS");
    $finish;
end

jtframe_sndchain #(
    .W(10),.STEREO(0),.DCRM(0)
) uut (
    .rst   ( rst           ),
    .clk   ( clk           ),
    .cen   ( 1'b1          ),
    .poles ( 16'b0         ),
    .gain  ( gain_in       ),
    .sin   ( sin_r         ),
    .sout  ( snd_out       ),
    .peak  (               )
);

jtframe_sndchain #(
    .W(10),.STEREO(1),.DCRM(0)
) uut_s (
    .rst   ( rst           ),
    .clk   ( clk           ),
    .cen   ( 1'b1          ),
    .poles ( 16'b0         ),
    .gain  ( gain_in       ),
    .sin   ( {sin_l,sin_r} ),
    .sout  ( snd_out_s     ),
    .peak  (               )
);
endmodule