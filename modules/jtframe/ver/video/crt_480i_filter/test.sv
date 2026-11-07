`timescale 1ns/1ps

module test;

`include "test_tasks.vh"

reg clk=0;
reg [1:0] level=0;
integer lv, n, a, c, b, expected, actual, fi, j, wa, wc, wb;
integer seed=32'h4801, random_value;
real side, phase, weight[0:3], total;
reg [26:0] word_expected;

always #5 clk=~clk;

task check_mix(input integer above, centre, below, filter_level);
    begin
        case( filter_level )
            0: expected = centre;
            1: expected = (above + 6*centre + below)/8;
            2: expected = (above + 3*centre + below)/5;
            3: expected = (above + 2*centre + below)/4;
        endcase
        actual = uut.u_crt_480i.mix_lines(above[7:0], centre[7:0], below[7:0], filter_level[1:0]);
        if( actual !== expected ) begin
            $display("FAIL kernel %0d: (%0d,%0d,%0d), got %0d expected %0d",
                filter_level, above, centre, below, actual, expected);
            $fatal(1);
        end
    end
endtask

initial begin
    $dumpfile("test.lxt");
    $dumpvars;
    #1;
    // Cover every input to the constant-reciprocal implementation of /5.
    for( n=0; n<=1275; n=n+1 ) begin
        c = n/3 > 255 ? 255 : n/3;
        a = n-3*c > 255 ? 255 : n-3*c;
        b = n-3*c-a;
        check_mix(a,c,b,2);
    end
    for( lv=0; lv<4; lv=lv+1 ) begin
        for( n=0; n<256; n=n+1 ) check_mix(n,n,n,lv);
        for( n=0; n<4096; n=n+1 ) begin
            random_value = $random(seed);
            check_mix({24'd0,random_value[7:0]}, {24'd0,random_value[15:8]},
                {24'd0,random_value[23:16]}, lv);
        end
        side = lv==0 ? 0.0 : lv==1 ? 0.125 : lv==2 ? 0.2 : 0.25;
        level = lv[1:0];
        for( fi=0; fi<256; fi=fi+1 ) begin
            // Convolve the kernel at the nearest line with an interpolated
            // copy shifted by one line, then discard the fourth tap.
            phase = (fi<128 ? 128-fi : fi-128)/256.0;
            for( j=0; j<4; j=j+1 ) weight[j]=0.0;
            for( j=0; j<3; j=j+1 ) begin
                weight[j]   = weight[j]   + (1.0-phase)*(j==1 ? 1.0-2.0*side : side);
                weight[j+1] = weight[j+1] + phase*(j==1 ? 1.0-2.0*side : side);
            end
            total = weight[0]+weight[1]+weight[2];
            wa = $rtoi(256.0*weight[fi<128 ? 2 : 0]/total+0.5+1e-9);
            wb = $rtoi(256.0*weight[fi<128 ? 0 : 2]/total+0.5+1e-9);
            wc = 256-wa-wb;
            word_expected = {wa[8:0],wc[8:0],wb[8:0]};
            @(negedge clk);
            uut.u_crt_480i.frac = fi[7:0];
            @(posedge clk);
            #1;
            if( uut.u_crt_480i.wq !== word_expected ) begin
                $display("FAIL ROM filter=%0d phase=%0d got=%h expected=%h",
                    lv, fi, uut.u_crt_480i.wq, word_expected);
                $fatal(1);
            end
            actual = uut.u_crt_480i.weighted_sum(8'd37,8'd211,8'd89);
            expected = (37*wa+211*wc+89*wb+128)/256;
            if( actual !== expected ) $fatal(1,"FAIL resampled pixel");
            for( n=0; n<256; n=n+1 ) begin
                actual = uut.u_crt_480i.weighted_sum(n[7:0],n[7:0],n[7:0]);
                if( actual !== n ) $fatal(1,"FAIL resampled constant colour");
            end
        end
    end
    pass();
end

crt_480i_filter uut(
    .clk   ( clk   ),
    .level ( level )
);

endmodule
