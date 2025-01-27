task assert_msg(input test, input string msg);
    if(!test) begin
        $display("Assertion failed: %s",msg);
        $finish;
    end
endtask