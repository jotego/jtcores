`timescale 1ns/1ps

/* verilator lint_off STMTDLY */

module mist_test;

wire [31:0] frame_cnt;
wire VGA_HS, VGA_VS;
wire led;

`ifdef DUMP
`ifndef NCVERILOG // iVerilog:
    initial begin
        // #(200*100*1000*1000);
        $display("DUMP enabled");
        $dumpfile("test.lxt");
    end
    `ifdef LOADROM
    always @(negedge led) if( $time > 20000 ) begin // led = downloading signal
        $display("DUMP starts");
        $dumpvars(0,mist_test);
        $dumpon;
    end
    `else
    initial begin
        $display("DUMP starts");
        `ifdef DEEPDUMP
            $dumpvars(0,mist_test);
        `else
            $dumpvars(1,mist_test.UUT.u_game.u_main);
            //$dumpvars(0,mist_test.UUT.u_game.u_video.u_obj);
            //$dumpvars(1,mist_test.UUT.u_rom);
            //$dumpoff;
            //$dumpvars(1,mist_test.UUT.u_video);
            //$dumpvars(1,mist_test.UUT.u_video.u_char);
            //$dumpvars(0,UUT.chargen);
        `endif
        $dumpon;
    end
    `endif
`else // NCVERILOG
    initial begin
    //always @(negedge VGA_VS) if( frame_cnt==18 ) begin
        $display("NC Verilog: will dump all signals");
        $shm_open("test.shm");
        `ifdef DEEPDUMP
            $shm_probe(mist_test,"AS");
        `else        
            //$shm_probe(UUT.u_game.u_main,"A");
            //$shm_probe(UUT.u_game.u_video.u_obj,"AS");
            //$shm_probe(UUT.u_game.u_video.u_colmix,"AS");
            $shm_probe(UUT.u_game.u_prom_we,"AS");
            $shm_probe(UUT.u_base.u_sdram,"AS");
            //$shm_probe(UUT.u_scandoubler,"AS");
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
`endif

wire            downloading;
wire    [21:0]  ioctl_addr;
wire    [ 7:0]  ioctl_data;
wire cen12, cen6, cen3, cen1p5, clk, clk27, rst;
wire [21:0]  sdram_addr;
wire [15:0]  data_read;
wire SPI_SCK, SPI_DO, SPI_DI, SPI_SS2, CONF_DATA0;

wire [15:0] SDRAM_DQ;
wire [12:0] SDRAM_A;
wire [ 1:0] SDRAM_BA;
wire SDRAM_DQML, SDRAM_DQMH, SDRAM_nWE,  SDRAM_nCAS, 
     SDRAM_nRAS, SDRAM_nCS,  SDRAM_CLK,  SDRAM_CKE;

wire [5:0] VGA_R, VGA_G, VGA_B;

test_harness #(.sdram_instance(0),.GAME_ROMNAME("../../../rom/JT1943.rom"),
    .TX_LEN(887808)) u_harness(
    .rst         ( rst           ),
    .clk         ( clk           ),
    .clk27       ( clk27         ),
    .cen12       ( cen12         ),
    .cen6        ( cen6          ),
    .cen3        ( cen3          ),
    .cen1p5      ( cen1p5        ),
    .downloading ( downloading   ),
    .ioctl_addr  ( ioctl_addr    ),
    .ioctl_data  ( ioctl_data    ),
    .SPI_SCK     ( SPI_SCK       ),
    .SPI_SS2     ( SPI_SS2       ),
    .SPI_DI      ( SPI_DI        ),
    .SPI_DO      ( SPI_DO        ),
    .CONF_DATA0  ( CONF_DATA0    ),
    // Video dumping. VGA_ signals are equal to game signals in simulation.
    .HS          ( VGA_HS    ), 
    .VS          ( VGA_VS    ),
    .red         ( VGA_R[3:0]),
    .green       ( VGA_G[3:0]),
    .blue        ( VGA_B[3:0]),
    .frame_cnt   ( frame_cnt ),
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


jt1943_mist UUT(
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
    .SPI_SS2    ( SPI_SS2   ),
    .SPI_SS3    ( 1'b0      ),
    .SPI_SS4    ( 1'b0      ),
    .CONF_DATA0 ( CONF_DATA0),
    // sound
    .AUDIO_L    ( AUDIO_L   ),
    .AUDIO_R    ( AUDIO_R   ),
    // unused
    .LED        ( led       )
);


endmodule // jt_gng_a_test