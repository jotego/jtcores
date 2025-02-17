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