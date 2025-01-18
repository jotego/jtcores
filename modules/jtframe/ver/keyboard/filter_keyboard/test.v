module test;

wire          rst, clk;
wire   [31:0] framecnt;
reg    [ 9:0] raw1=0, raw2=0, raw3=0, raw4=0;
wire   [ 9:0] joy1, joy2, joy3, joy4;

task detect_bad_buttons;
begin
    if(joy1[9:4]!=raw1[9:4] ||
       joy2[9:4]!=raw2[9:4] ||
       joy3[9:4]!=raw3[9:4] ||
       joy4[9:4]!=raw4[9:4] ) begin
        $display("Buttons do not match.\nFAIL");
        $finish;
    end
end
endtask

task detect_bad_directions;
begin
    if(&joy1[3:2] || &joy1[1:0] ||
       &joy2[3:2] || &joy2[1:0] ||
       &joy3[3:2] || &joy3[1:0] ||
       &joy4[3:2] || &joy4[1:0] ) begin
        $display("Double directions are not filtered\nFAIL");
        $finish;
    end
    if( !match(raw1,joy1) ||
        !match(raw2,joy2) ||
        !match(raw3,joy3) ||
        !match(raw4,joy4) ) begin
        $display("Directions do not match\nFAIL");
        $finish;
    end
end
endtask

function match(input [3:0] raw, filtered);
begin
    match = match_dir(raw[1:0],filtered[1:0]) &&
            match_dir(raw[1:0],filtered[1:0]);
end
endfunction;

function match_dir(input [1:0] raw, filtered);
begin
    match_dir = raw==3 ? filtered==0 : raw==filtered && filtered!==2'bxx;
end
endfunction


task set_random_values;
begin
    raw1 = $random;
    raw2 = $random;
    raw3 = $random;
    raw4 = $random;
end
endtask

initial begin
    repeat (40) @(posedge clk);
    repeat (200) begin
        set_random_values();
        repeat (2) @(posedge clk);
        detect_bad_buttons();
        detect_bad_directions();
    end
    $display("PASS");
    $finish;
end

jtframe_test_clocks clocks(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .pxl_cen    (               ),
    .lhbl       (               ),
    .lvbl       (               ),
    .framecnt   ( framecnt      )
);

jtframe_filter_keyboard uut(
    .clk    ( clk   ),
    .raw1   ( raw1  ),
    .raw2   ( raw2  ),
    .raw3   ( raw3  ),
    .raw4   ( raw4  ),
    .joy1   ( joy1  ),
    .joy2   ( joy2  ),
    .joy3   ( joy3  ),
    .joy4   ( joy4  )
);

endmodule