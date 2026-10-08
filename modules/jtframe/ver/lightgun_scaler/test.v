module test;

reg clk;

`include "test_tasks.vh"

parameter  W=384, H=224;
localparam MAX=256;

initial begin
    $dumpfile("test.lxt");
    $dumpvars;
    $dumpon;
    #20000000
    $display("FAIL");
    $finish;
end

reg  [15:0] joy_in=0;
wire [ 8:0] x_out, y_out;
integer     x_in, y_in,  x_eint,    y_eint,
            x=0,  y=0,   x_error=0, y_error=0;
real        x_exp,y_exp, x_conv,    y_conv;

initial begin
    clk=0;
    forever #10 clk=~clk;
end

initial begin
    calc_conv_factors();
    initial_assignments();
    for (y = 0; y < MAX; y++) begin
        initial_x();
        for (x = 0; x < MAX; x++) begin
            assign_input();
            calc_exp_output();
            check_output();
            increase_x();
        end
        increase_y();
    end
    pass();
end

task assign_input();
    joy_in = {y_in[7:0], x_in[7:0]};
    @(posedge clk);
endtask

task calc_exp_output();
    x_exp = x * x_conv;
    y_exp = y * y_conv;
    @(posedge clk);
    x_eint = $rtoi(x_exp);
    y_eint = $rtoi(y_exp);
    @(posedge clk);
endtask

task check_output();
    if(y_out != y_eint[8:0]) y_error = y_out;
    if(x_out != x_eint[8:0]) x_error = x_out;
    assert_msg(y_out == y_eint[8:0], "Y output does not match expected value");
    assert_msg(x_out == x_eint[8:0], "X output does not match expected value");
endtask

task calc_conv_factors();
    x_conv = $itor(W)/$itor(MAX);
    y_conv = $itor(H)/$itor(MAX);
endtask

task initial_assignments();
    x_in = -128; y_in = -128;
    x_eint = 0;  y_eint = 0;
    repeat (20) @(posedge clk);
endtask

task initial_x();
    x_in = -128;
endtask

task increase_x();
    x_in = x_in + 1;
    @(posedge clk);
endtask

task increase_y();
    y_in = y_in + 1;
    @(posedge clk);
endtask

jtframe_lightgun_scaler#(.W(W),.H(H)) uut(
    .clk     ( clk      ),
    .joyana  ( joy_in   ),
    .strobe  (          ),
    .x       ( x_out    ),
    .y       ( y_out    )
);

endmodule