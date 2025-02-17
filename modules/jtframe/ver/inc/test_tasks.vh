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
