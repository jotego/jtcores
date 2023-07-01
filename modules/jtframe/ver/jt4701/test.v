`timescale 1ns/1ps

module test;

reg           clk;
reg           rst;
reg  [1:0]    x_in;
wire [1:0]    y_in;
reg           rightn;
reg           leftn;
reg           middlen;
reg           x_rst;
reg           y_rst;
reg           csn;        // chip select
reg           uln;        // byte selection
reg           xn_y;       // select x or y for reading
wire          cfn;        // counter flag
wire          sfn;        // switch flag
wire [7:0]    dout;

reg  [8:0]    slowcnt;

initial begin
    rightn = 1;
    leftn  = 1;
    middlen= 1;
    x_rst  = 0;
    y_rst  = 0;
    csn    = 1;
    uln    = 1;
    xn_y   = 1;
    phases = 2'b0;
    slowcnt= 0;
    rst    = 0;
    #5;
    rst    = 1;
    #105;
    rst    = 0;
    #10_000;
    $finish;
end

initial begin
    clk    = 0;
    forever #10 clk = ~clk;
end

reg [1:0] seq[0:14];

initial begin
    seq[0] = 2'b11;
    seq[1] = 2'b11;
    seq[2] = 2'b11;
    seq[3] = 2'b11;
    seq[4] = 2'b11;
    seq[5] = 2'b10;
    seq[6] = 2'b00;
    seq[7] = 2'b00;
    seq[8] = 2'b00;
    seq[9] = 2'b01;
    seq[10] = 2'b11;
    seq[11] = 2'b11;
    seq[12] = 2'b10;
    seq[13] = 2'b10;
    seq[14] = 2'b11;
end

reg [1:0] phases;

always @(posedge clk) begin
    slowcnt <= slowcnt+3'd1;
    case( slowcnt[2:0] )
        3'd3: phases[0] <= ~phases[0];
        3'd7: phases[1] <=  phases[0];
    endcase
end

always @(*) begin
    case( seq[slowcnt[8:5]] )
        2'b00: x_in = { phases[0], phases[1] };
        default: x_in = seq[slowcnt[8:5]] & phases;
    endcase
end

jt4701 UUT(
    .clk        ( clk        ),
    .rst        ( rst        ),
    .x_in       ( x_in       ),
    .y_in       ( y_in       ),
    .rightn     ( rightn     ),
    .leftn      ( leftn      ),
    .middlen    ( middlen    ),
    .x_rst      ( x_rst      ),
    .y_rst      ( y_rst      ),
    .csn        ( csn        ),
    .uln        ( uln        ),
    .xn_y       ( xn_y       ),
    .cfn        ( cfn        ),
    .sfn        ( sfn        ),
    .dout       ( dout       )
);

reg do_inc, do_dec;

initial begin
    do_inc = 1;
    do_dec = 0;
end

always @( posedge clk ) begin
    case( slowcnt[7:0] )
        0: begin
            do_inc=1;
            do_dec=0;
        end
        63: begin
            do_inc=0;
            do_dec=0;
        end
        127: begin
            do_inc=0;
            do_dec=1;
        end
        197: begin
            do_inc=0;
            do_dec=0;
        end
    endcase
end

jt4701_dialemu u_dialemu(
    .clk        ( clk        ),
    .rst        ( rst        ),
    .pulse      ( slowcnt[0] ),
    .inc        ( do_inc     ),
    .dec        ( do_dec     ),
    .dial       ( y_in       )
);


initial begin
    $dumpfile("test.lxt");  
    $dumpvars;  
end

endmodule