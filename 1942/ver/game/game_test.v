`timescale 1ns/1ps

module game_test;
`ifndef NCVERILOG
    `ifdef DUMP
    initial begin
        // #(200*100*1000*1000);
        $display("DUMP enabled");
        $dumpfile("test.lxt");
        `ifdef LOADROM
            $dumpvars(1,game_test.UUT.u_main);
            $dumpvars(1,game_test.UUT);
            $dumpvars(1,game_test.u_sdram);
            $dumpvars(1,game_test.mist_sdram);
            //$dumpvars(1,game_test.UUT.u_video.u_obj);
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
                //$dumpvars(1,game_test.UUT.u_audio);
                //$dumpvars(0,game_test.UUT.u_video.u_obj);
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
            //$shm_probe(UUT.u_main,"A");
            //$shm_probe(UUT.u_video.u_obj,"AS");
            `ifndef NOSOUND
            $shm_probe(UUT.u_sound,"AS");
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


wire [9:0] prom_we;
jt1942_prom_we u_prom_we(
    .downloading    ( downloading   ), 
    .romload_addr   ( romload_addr  ),
    .prom_we        ( prom_we       )
);

reg coin;
initial begin
    coin = 1'b1;
    forever begin
        coin = #1000_000_000 1'b0;
        $display("INFO: Coin inserted ");
        coin =      #500_000 1'b1;
        #2000_000_000;
    end
end

wire cen12, cen6, cen3, cen1p5, clk, rst;
wire [21:0]  sdram_addr;
wire [15:0]  data_read;


test_harness #(.GAME_ROMNAME("../../../rom/JT1942.rom")) u_harness(
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

jt1942_game UUT(
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
    // cabinet I/O
    .joystick1  ( { coin, 7'h7f } ),
    .joystick2  ( 8'hff           ),
    // ROM load
    .downloading ( downloading   ),
    .loop_rst    ( loop_rst      ),
    .autorefresh ( autorefresh   ),
    .sdram_addr  ( sdram_addr    ),
    .data_read   ( data_read     ),

    // PROM programming
    .prog_addr   ( romload_addr[7:0] ),
    .prog_din    ( romload_data[3:0] ),
    .prom_k6_we  ( prom_we[0]        ),
    .prom_d1_we  ( prom_we[1]        ),
    .prom_d2_we  ( prom_we[2]        ),
    .prom_e8_we  ( prom_we[3]        ),
    .prom_e9_we  ( prom_we[4]        ),
    .prom_e10_we ( prom_we[5]        ),
    .prom_f1_we  ( prom_we[6]        ), 
    .prom_d6_we  ( prom_we[7]        ),
    .prom_k3_we  ( prom_we[8]        ),
    .prom_m11_we ( prom_we[9]        ), 

    // DIP switches
    // DIP switches
    .dipsw_a    ( 8'hff     ),
    .dip_pause  ( 1'b0      ),
    .dip_level  ( 2'b11     ),
    .dip_test   ( 1'b1      ),
    .coin_cnt   ( coin_cnt  ),
    // Sound output
    .snd            ( snd       ),
    .sample         ( snd_sample)
);


endmodule // jt_1942_a_test