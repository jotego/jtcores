module test;

`include "test_tasks.vh"

wire              rst, clk, vs;
reg               locked=0, rot=0, rot_ccw=0;

reg         [3:0] board_coin=0, board_start=0,
                  key_coin=0,   key_start=0,
                  joy_coin=0,   joy_start=0;
reg               key_service=0,key_tilt=0,  key_reset=0;

reg        [15:0] ana1=0, ana2=0,
                  board_joy1=0, board_joy2=0, board_joy3=0, board_joy4=0;
reg         [9:0] key_joy1=0, key_joy2=0, key_joy3=0, key_joy4=0;
reg               joy_test=0, key_test=0;

reg         [2:0] mouse_but_1p=0, mouse_but_2p=0;

wire        [5:0] recjoy1;

wire        [9:0] game_joy1, game_joy2, game_joy3, game_joy4;
wire        [3:0] game_coin, game_start;
wire              game_test, game_service, game_tilt, soft_rst;

integer dir;

function [3:0] tr(input [9:0]x); begin
    tr = x[3:0]; // UDLR
`ifdef JTFRAME_JOY_DURL
    tr = {x[2],x[3],x[0],x[1]};
`endif
`ifdef JTFRAME_JOY_RLDU
    tr = {x[0],x[1],x[2],x[3]};
`endif
end endfunction

wire [3:0] tr1=tr(game_joy1);

initial begin
    @(negedge rst);
    repeat (20) @(posedge clk);
    assert_msg(game_test==1,"test DIP must be high (disabled) on start up");
    key_test = 1;
    repeat (20) @(posedge clk);
    assert_msg(game_test==0,"test DIP must be low after keyboard set");

    key_test = 0;
    repeat (20) @(posedge clk);
    assert_msg(game_test==1,"test DIP must be high after keyboard unset");

    for( dir=0; dir<4; dir=dir+1 ) begin
        board_joy1[3:0]=1<<dir;
        repeat (20) @(posedge clk);
        assert_msg(tr1==~board_joy1[3:0],"failed to set direction");
    end
    board_joy1[3:0]=0;

    for( dir=0; dir<4; dir=dir+1 ) begin
        key_joy1[3:0]=1<<dir;
        repeat (20) @(posedge clk);
        assert_msg(tr1==~key_joy1[3:0],"failed to set direction");
    end

    pass();
end

jtframe_joysticks uut(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .vs         ( vs            ),
    .locked     ( locked        ),
    .rot        ( rot           ),
    .rot_ccw    ( rot_ccw       ),

    .board_coin ( board_coin    ),
    .board_start( board_start   ),
    .key_coin   ( key_coin      ),
    .key_start  ( key_start     ),
    .joy_coin   ( joy_coin      ),
    .joy_start  ( joy_start     ),
    .key_service( key_service   ),
    .key_tilt   ( key_tilt      ),
    .key_reset  ( key_reset     ),

    .ana1       ( ana1          ),
    .ana2       ( ana2          ),
    .board_joy1 ( board_joy1    ),
    .board_joy2 ( board_joy2    ),
    .board_joy3 ( board_joy3    ),
    .board_joy4 ( board_joy4    ),
    .key_joy1   ( key_joy1      ),
    .key_joy2   ( key_joy2      ),
    .key_joy3   ( key_joy3      ),
    .key_joy4   ( key_joy4      ),
    .joy_test   ( joy_test      ),
    .key_test   ( key_test      ),

    .mouse_but_1p(mouse_but_1p  ),
    .mouse_but_2p(mouse_but_2p  ),

    .recjoy1    ( recjoy1       ),

    .game_joy1  ( game_joy1     ),
    .game_joy2  ( game_joy2     ),
    .game_joy3  ( game_joy3     ),
    .game_joy4  ( game_joy4     ),
    .game_coin  ( game_coin     ),
    .game_start ( game_start    ),
    .game_test  ( game_test     ),
    .game_service( game_service ),
    .game_tilt  ( game_tilt     ),
    .soft_rst   ( soft_rst      )
);

jtframe_test_clocks clocks(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .pxl_cen    (               ),
    .lhbl       ( vs            )
);

endmodule