module test;

wire rst, clk;
`include "test_tasks.vh"

wire released, tx_send;
reg  [7:0] press0, press1, press2,
           press3, press4, press5;
wire [7:0] key;
wire [5:0] is_pr;
wire [2:0] pressed, nextkey;
reg        tx_ready;
int        test_key, i=0, in_pressed;

localparam KEYS=6;
localparam LATENCY=10;  // clock cycles it takes for a press to appear at the output

assign is_pr   ={|press5,  |press4,  |press3,  |press2,  |press1,  |press0};
assign pressed = |press0 + |press1 + |press2 + |press3 + |press4 + |press5;
assign nextkey = |press0? 3'd0 : |press1? 3'd1 : |press2? 3'd2   : |press3? 3'd3 : |press4? 3'd4 : |press5? 3'd5 : 3'd7;

initial begin
    release_all_keys();
    tx_ready = 1;

    @(negedge rst);

    do_nothing();

    test_key=10;
    set_press(0);
    check_pressed_key();
    set_press(1);
    check_pressed_key();
    set_press(2);
    check_pressed_key();
    set_press(3);
    check_pressed_key();
    set_press(4);
    check_pressed_key();
    set_press(5);
    check_pressed_key();
    $display("Checked all keys set and released one by one");

    set_all_keys();
    check_all_keys();
    $display("Checked all keys set and released at once");

    set_press(0);
    set_press(1);
    test_unsync_release();
    $display("Checked two keys released at different times");

    set_press(1);
    set_press(3);
    set_press(5);
    test_unsync_release();
    $display("Checked three keys released at different times");

    set_all_keys();
    test_unsync_release();
    $display("Checked all keys released at different times");

    multiple_press_release_test();
    $display("Checked multiple combinations of press-released keys");

    pass();
end

task release_all_keys(); begin
    press0 = 0; press1 = 0; press2 = 0;
    press3 = 0; press4 = 0; press5 = 0;
end endtask

task set_all_keys();
    test_key=10;
    press0 = test_key;    press1 = test_key*2;  press2 = test_key*3;
    press3 = test_key*4;  press4 = test_key*5;  press5 = test_key*6;
endtask

task set_keys(input [2:0] sel, input clr);
    case (sel)
        0: press0 = clr ? 0 : test_key*1;
        1: press1 = clr ? 0 : test_key*2;
        2: press2 = clr ? 0 : test_key*3;
        3: press3 = clr ? 0 : test_key*4;
        4: press4 = clr ? 0 : test_key*5;
        5: press5 = clr ? 0 : test_key*6;
        6: if(clr) release_all_keys(); else set_all_keys();
        default:;
    endcase
endtask

task set_press(input [2:0] sel);
    test_key=10;
    set_keys(sel,0);
endtask

task do_nothing(); begin
    release_all_keys();
    repeat (LATENCY*10) begin
        @(posedge clk);
        assert_msg(tx_send==0, "no output if no key is pressed");
    end
end endtask

task set_tx_busy(); begin
    assert_msg(tx_send==1, "a send command should be issued");
    repeat (1) @(posedge clk);
    tx_ready = 0;
    assert_msg(tx_send==0, "the send command strobe must have disappeared");
end endtask

task wait_for_tx_ready(input int expk,input expr); begin
    repeat(LATENCY*40) begin
        @(posedge clk);
        assert_msg(tx_send==0, "no new send commands issued until tx_ready is asserted");
        assert_msg(key==expk,    "output should be held");
        assert_msg(released==expr,"incorrect released command");
    end
    tx_ready = 1;
end endtask

task check_output(input int k, input r); begin
    assert_msg(key==k,    "output must match input");
    if(r)
        assert_msg(released==1,"the key was released");
    else
        assert_msg(released==0,"the key was pressed");
end endtask

task check_value(input int key, input rel, input [2:0] sel);
        wait (tx_send==1) @(posedge clk);
        check_output(key,rel);
        set_tx_busy();
        set_keys(sel,1);
        wait_for_tx_ready(key,rel);
endtask

task check_several_keys();
    int keyp;
    tx_ready = 1;
    @(posedge clk) keyp = is_pr;
    check_n_write(keyp[0+:KEYS],0,6);
    @(posedge clk);
    check_n_write(keyp[0+:KEYS],0,7);

    do_nothing();
endtask

task check_pressed_key(); begin
    check_several_keys();
end endtask

task check_all_keys();
    check_several_keys();
endtask

task test_unsync_release();
    int  keyp, keyp2;
    reg  [2:0] key2rel;

    @(posedge clk) in_pressed = pressed;
    keyp = is_pr;
    repeat( in_pressed+1 )begin
        keyp2 = is_pr;
        key2rel = nextkey;
        check_n_write(keyp[0+:KEYS],0,key2rel);
        @(posedge clk) keyp = keyp2;
    end

    do_nothing();
endtask

    int rstr=0;
    reg [5:0] wr=0, set=0, set_l=0;
    reg fin=0;

task multiple_press_release_test();
    rstr = 32'b110101_001010_010100_101000_010011;

    set_all_keys();
    set_l <= 6'h3F; wr = 0;
    set   <= 6'h3F; fin=0;

    while (!fin) begin
        wr   = rstr[5:0];
        check_n_write(set_l, wr,7);
        if(rstr==0) fin=1;
        rstr = rstr >> 6;
        @(posedge clk); begin
            set <= is_pr;
            set_l = set;
        end
    end

    release_all_keys();
    @(posedge clk);
    check_n_write(set_l,0,7);

    do_nothing();
endtask

task check_n_write(input [KEYS-1:0] check, write, input [2:0] r);
    int reld;
    test_key=10;
    reld = check & ~is_pr;
    for (int a = 0; a < KEYS; a++) begin
        if( check[a] ) begin
            check_value(test_key*(a+1),reld[a],r);
        end
        if( write[a] ) set_keys(a,is_pr[a]);
    end
endtask

// note the modified interface:
jtframe_pocket_keyboard_decoder #(.KEYS(KEYS))uuu(
    .rst       ( rst        ),
    .clk       ( clk        ),
    .key_en    ( 1'b1       ),

    // pressed keys, this would connect to controller 3
    // we rename the ports so they make sense at the module level
    .press0    ( press0     ),
    .press1    ( press1     ),
    .press2    ( press2     ),
    .press3    ( press3     ),
    .press4    ( press4     ),
    .press5    ( press5     ),
    .spress    ( 8'b0       ),

    // tx part
    .released  ( released   ),  // tx data
    .key       ( key        ),
    .tx_send   ( tx_send    ),  // single-clock strobe to signal a send
    .tx_ready  ( tx_ready   )   // low if the Tx is busy
);

jtframe_test_clocks clocks(
    .rst        ( rst           ),
    .clk        ( clk           )
);

endmodule