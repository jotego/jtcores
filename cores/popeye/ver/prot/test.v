`timescale 1ns/1ps

module test;

reg        clk=0, rst=1, reset_n=0, cs=0, we=0, addr=0;
reg  [7:0] din=0;
wire [7:0] dout;
reg  [7:0] d[0:32767], u[0:32767];
integer    fd, n, i, s, errors=0, checks=0;

initial forever #10 clk = ~clk;

jtpopeye_prot uut(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .reset_n    ( reset_n   ),
    .cs         ( cs        ),
    .we         ( we        ),
    .addr       ( addr      ),
    .din        ( din       ),
    .dout       ( dout      )
);

task wr( input a, input [7:0] v );
    begin
        @(negedge clk); addr = a; din = v; cs = 1; we = 1;
        repeat(4) @(negedge clk); cs = 0; we = 0;
        repeat(2) @(negedge clk);
    end
endtask

task rd( input a, output [7:0] v );
    begin
        @(negedge clk); addr = a; cs = 1; we = 0;
        @(negedge clk); v = dout; cs = 0;
    end
endtask

task check_table( input integer lo, input integer hi, input integer off, input integer sh );
    reg [7:0] r;
    begin
        wr( 1, sh );
        wr( 0, d[lo] );
        for( i=lo; i<=hi; i=i+1 ) begin
            wr( 0, d[i+1] );
            rd( 1, r );
            checks = checks+1;
            if( r !== u[i+off] ) begin
                errors = errors+1;
                if( errors<10 ) $display("ERROR %04X shift %0d: got %02X expected %02X", i, sh, r, u[i+off]);
            end
        end
    end
endtask

reg [7:0] r;
initial begin
    fd=$fopen(`DROM,"rb"); n=$fread(d,fd); $fclose(fd);
    fd=$fopen(`UROM,"rb"); n=$fread(u,fd); $fclose(fd);
    repeat(4) @(negedge clk); rst=0; reset_n=1;
    rd( 1, r ); checks=checks+1; if( r!==8'd0 ) begin errors=errors+1; $display("ERROR result after reset %02X", r); end
    check_table( 'h16d0, 'h1719, 0, 1 );
    check_table( 'h171a, 'h1752, 0, 2 );
    check_table( 'h1753, 'h17a0, 0, 3 );
    check_table( 'h1aa0, 'h1abe, 1, 1 );
    check_table( 'h1ac9, 'h1ae8, 1, 2 );
    check_table( 'h1aef, 'h1b0e, 1, 3 );
    rd( 0, r ); checks=checks+1; if( r[2]!==1'b0 ) begin errors=errors+1; $display("ERROR status bit 2 set"); end
    reset_n=0; @(negedge clk); reset_n=1;
    rd( 1, r ); checks=checks+1; if( r!==8'd0 ) begin errors=errors+1; $display("ERROR /RESET does not clear"); end
    $display("%0d checks, %0d errors", checks, errors);
    if( errors==0 ) begin $display("PASS"); $finish; end
    else begin $display("FAIL"); $fatal(1); end
end

endmodule
