`timescale 1ns/1ps

/*

    Game test

    ~0.95 frames/minute on DELL laptop
    at least 900 frames to see SERVICE screen

*/

/* verilator lint_off STMTDLY */

module mist_test;
`ifndef NCVERILOG
    `ifdef DUMP
    initial begin
        // #(200*100*1000*1000);
        $display("DUMP enabled");
        $dumpfile("test.lxt");
        `ifdef LOADROM
            //$dumpvars(1,mist_test.UUT.u_game.u_main);
            //$dumpvars(1,mist_test.UUT.u_game.u_sound);
            //$dumpvars(1,mist_test.UUT.u_game.u_rom);
            $dumpvars(0,mist_test);
            // $dumpvars(0,mist_test);
            $dumpon;
        `else
            `ifdef DEEPDUMP
                $dumpvars(0,mist_test);
            `else
                #75_000_000;
                $display("DUMP starts");
                $dumpvars(1,mist_test.UUT.u_game.u_main);
                $dumpvars(0,mist_test.UUT.u_game.u_video.u_obj);
                //$dumpvars(1,mist_test.UUT.u_rom);
                //$dumpoff;
                //$dumpvars(1,mist_test.UUT.u_video);
                //$dumpvars(1,mist_test.UUT.u_video.u_char);
                //$dumpvars(0,UUT.chargen);
            `endif
            $dumpon;
        `endif
    end
    `endif
`else // NCVERILOG
    initial begin
        $display("NC Verilog: will dump all signals");
        $shm_open("test.shm");
        `ifdef DEEPDUMP
            $shm_probe(mist_test,"AS");
        `else
            //$shm_probe(UUT.u_game.u_main,"A");
            $shm_probe(UUT.u_game.u_video.u_obj,"AS");
            $shm_probe(UUT.u_scandoubler,"AS");
            `ifndef NOSOUND
            $shm_probe(UUT.u_game.u_sound,"A");
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
// wire    [24:0]  romload_addr;
// wire    [15:0]  romload_data;
wire cen12, cen6, cen3, cen1p5, clk, clk27, rst;
wire [21:0]  sdram_addr;
wire [15:0]  data_read;
wire SPI_SCK, SPI_DO, SPI_DI, CONF_DATA0;

wire [15:0] SDRAM_DQ;
wire [12:0] SDRAM_A;
wire [ 1:0] SDRAM_BA;
wire SDRAM_DQML, SDRAM_DQMH, SDRAM_nWE,  SDRAM_nCAS,
     SDRAM_nRAS, SDRAM_nCS,  SDRAM_CLK,  SDRAM_CKE;

test_harness #(.sdram_instance(0),
    .GAME_ROMNAME("../../../rom/JTCORES.rom"),
    .TX_LEN(32'h10000))
u_harness(
    .rst         ( rst           ),
    .clk         ( clk           ),
    .clk27       ( clk27         ),
    .cen12       ( cen12         ),
    .cen6        ( cen6          ),
    .cen3        ( cen3          ),
    .cen1p5      ( cen1p5        ),
    .downloading ( downloading   ),
//    .loop_rst    ( loop_rst      ),
//    .autorefresh ( autorefresh   ),
//    .sdram_addr  ( sdram_addr    ),
//    .data_read   ( data_read     ),
//    .romload_addr( romload_addr  ),
//    .romload_data( romload_data  ),
    .SPI_SCK     ( SPI_SCK       ),
    .SPI_DI      ( SPI_DI        ),
    .SPI_DO      ( SPI_DO        ),
    .SPI_SS2     ( SPI_SS2       ),
    .CONF_DATA0  ( CONF_DATA0    ),
    // SDRAM
    .SDRAM_DQ    ( SDRAM_DQ  ),
    .SDRAM_A     ( SDRAM_A   ),
    .SDRAM_DQML  ( SDRAM_DQML),
    .SDRAM_DQMH  ( SDRAM_DQMH),
    .SDRAM_nWE   ( SDRAM_nWE ),
    .SDRAM_nCAS  ( SDRAM_nCAS),
    .SDRAM_nRAS  ( SDRAM_nRAS),
    .SDRAM_nCS   ( SDRAM_nCS ),
    .SDRAM_BA    ( SDRAM_BA  ),
    .SDRAM_CLK   ( SDRAM_CLK ),
    .SDRAM_CKE   ( SDRAM_CKE )
);

wire [5:0] VGA_R, VGA_G, VGA_B;
wire VGA_HS, VGA_VS;

jtgng_mist UUT(
    .CLOCK_27   ( { 1'b0, clk27 }),
    .VGA_R      ( VGA_R     ),
    .VGA_G      ( VGA_G     ),
    .VGA_B      ( VGA_B     ),
    .VGA_HS     ( VGA_HS    ),
    .VGA_VS     ( VGA_VS    ),
    // SDRAM interface
    .SDRAM_DQ   ( SDRAM_DQ  ),
    .SDRAM_A    ( SDRAM_A   ),
    .SDRAM_DQML ( SDRAM_DQML),
    .SDRAM_DQMH ( SDRAM_DQMH),
    .SDRAM_nWE  ( SDRAM_nWE ),
    .SDRAM_nCAS ( SDRAM_nCAS),
    .SDRAM_nRAS ( SDRAM_nRAS),
    .SDRAM_nCS  ( SDRAM_nCS ),
    .SDRAM_BA   ( SDRAM_BA  ),
    .SDRAM_CLK  ( SDRAM_CLK ),
    .SDRAM_CKE  ( SDRAM_CKE ),
   // SPI interface to arm io controller
    .SPI_DO     ( SPI_DO    ),
    .SPI_DI     ( SPI_DI    ),
    .SPI_SCK    ( SPI_SCK   ),
    .CONF_DATA0 ( CONF_DATA0),
    // sound
    .AUDIO_L    ( AUDIO_L   ),
    .AUDIO_R    ( AUDIO_R   ),
    // unused
    .SPI_SS2    ( SPI_SS2   ),
    .SPI_SS3    ( 1'b0      ),
    .SPI_SS4    ( 1'b0      ),
    .LED()
);

endmodule // jt_gng_a_test