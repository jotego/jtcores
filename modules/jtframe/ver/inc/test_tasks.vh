task assert_msg(input test, input string msg);
    if(!test) begin
        $display("Assertion failed: %s",msg);
        repeat (40) @(posedge clk);
        $finish;
    end
endtask

task fail();
    $display("FAIL");
    $finish;
endtask

task pass();
    $display("PASS");
    $finish;
endtask

// wait around video signals
task wait_for_line(input [8:0]line); begin
    while(vdump!=line) @(posedge clk);
end endtask

task wait_for_col(input [8:0]col); begin
    while(hdump!=col) @(posedge clk);
end endtask

task adv_lines(input [8:0] cnt); begin
    repeat(cnt) @(posedge hs);
end endtask