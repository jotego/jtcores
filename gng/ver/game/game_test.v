`timescale 1ns/1ps

/*

    Game test

    ~0.95 frames/minute on DELL laptop
    at least 900 frames to see SERVICE screen

*/

/* verilator lint_off STMTDLY */

module game_test;
`ifndef NCVERILOG
    `ifdef DUMP
    initial begin
        // #(200*100*1000*1000);
        $display("DUMP enabled");
        $dumpfile("test.lxt");
        `ifdef LOADROM
            $dumpvars(1,game_test.UUT.u_main);
            $dumpvars(1,game_test.UUT.u_video.u_obj);
            //$dumpvars(1,game_test.UUT.u_rom);
            //$dumpvars(1,game_test);
            //$dumpvars(1,game_test.datain);
            // $dumpvars(0,game_test);
            $dumpon;
        `else
            `ifdef DEEPDUMP
                $dumpvars(0,game_test);
            `else
                //$display("DUMP starts");
                $dumpvars(1,game_test.UUT.u_main);
                $dumpvars(0,game_test.UUT.u_video.u_obj);
                //$dumpvars(1,game_test.UUT.u_rom);
                //$dumpvars(1,game_test.UUT.u_video);
                //$dumpvars(1,game_test.UUT.u_video.u_char);
                //$dumpvars(0,UUT.chargen);
                //#30_000_000;
            `endif
            $dumpon;
        `endif
    end
    `endif
`else
    initial begin
        $display("NC Verilog: will dump all signals");
        $shm_open("test.shm");
        `ifdef DEEPDUMP
            $shm_probe(game_test,"AS");
        `else        
            $shm_probe(UUT.u_main,"A");
            $shm_probe(UUT.u_rom,"A");
            `ifndef NOSOUND
            $shm_probe(UUT.u_sound,"A");
            $shm_probe(UUT.u_sound.u_mixer,"A");
            `endif
        `endif
        // $shm_probe(UUT.u_video,"A");
        // $shm_probe(UUT.u_video.u_obj,"AS");
        // #280_000_000
        // #280_000_000
        // $shm_probe(UUT.u_sound.u_cpu,"AS");
    end
`endif

wire            downloading;
wire    [24:0]  romload_addr;
wire    [15:0]  romload_data;
wire [3:0] red, green, blue;
wire LHBL, LVBL;
wire [8:0] snd;
wire snd_sample;
wire   HS, VS;

wire cen12, cen6, cen3, cen1p5, clk, rst;
wire [21:0]  sdram_addr;
wire [15:0]  data_read;


test_harness u_harness(
    .rst         ( rst           ),
    .clk         ( clk           ),
    .cen12       ( cen12         ),
    .cen6        ( cen6          ),
    .cen3        ( cen3          ),
    .cen1p5      ( cen1p5        ),
    .downloading ( downloading   ),
    .loop_rst    ( loop_rst      ),
    .autorefresh ( autorefresh   ),
    .sdram_addr  ( sdram_addr    ),
    .data_read   ( data_read     ),
    .romload_addr( romload_addr  ),
    .romload_data( romload_data  )
);

jtgng_game UUT (
    .rst        ( rst       ),
    .soft_rst   ( 1'b0      ),
    .clk        ( clk       ),
    .cen12      ( cen12     ),
    .cen6       ( cen6      ),
    .cen3       ( cen3      ),
    .cen1p5     ( cen1p5    ),
    .red        ( red       ),
    .green      ( green     ),
    .blue       ( blue      ),
    .LHBL       ( LHBL      ),
    .LVBL       ( LVBL      ),
    .HS         ( HS        ),
    .VS         ( VS        ),

    .joystick1  ( 8'hff     ),
    .joystick2  ( 8'hff     ),
    // ROM load
    .downloading ( downloading   ),
    .romload_addr( romload_addr  ),
    .romload_data( romload_data  ),
    .loop_rst    ( loop_rst      ),
    .autorefresh ( autorefresh   ),
    .sdram_addr  ( sdram_addr    ),
    .data_read   ( data_read     ),
    // Debug
    .enable_char( 1'b1          ),
    .enable_obj ( 1'b1          ),
    .enable_scr ( 1'b1          ),
    .enable_psg ( 1'b1          ),
    .enable_fm  ( 1'b1          ),
    // DIP switches
    //.dip_flip     (   1'b0    ),
    .dip_game_mode  (   1'b0    ),
    .dip_attract_snd(   1'b0    ),
    .dip_upright    (   1'b1    ),
    .ym_snd         (           ),
    .sample         (           )
);


endmodule // jt_gng_a_test