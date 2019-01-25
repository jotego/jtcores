`timescale 1ns/1ps

/* verilator lint_off STMTDLY */

module mist_test;
`ifndef NCVERILOG
    `ifdef DUMP
    initial begin
        // #(200*100*1000*1000);
        $display("DUMP enabled");
        $dumpfile("test.lxt");
        `ifdef LOADROM
            $dumpvars(1,mist_test.UUT.u_main);
            $dumpvars(1,mist_test.UUT.u_sound);
            $dumpvars(1,mist_test.UUT.u_rom);
            $dumpvars(1,mist_test);
            $dumpvars(1,mist_test.datain);
            // $dumpvars(0,mist_test);
            $dumpon;
        `else
            `ifdef DEEPDUMP
                $dumpvars(0,mist_test);
            `else
                #75_000_000;
                $display("DUMP starts");
                $dumpvars(1,mist_test.UUT.u_game.u_main);
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
            $shm_probe(UUT.u_game.u_main,"A");
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

`ifdef MAXFRAME
reg frame_done=1'b1, max_frames_done=1'b0;
`else 
reg frame_done=1'b1, max_frames_done=1'b1;
`endif

reg can_finish=1'b0;
wire spi_done;
integer fincnt;

initial begin
    for( fincnt=0; fincnt<`SIM_MS; fincnt=fincnt+1 ) begin
        #(1000*1000); 
        $display("%d ms",fincnt+1);
    end
    can_finish = 1'b1;
end

reg rst, clk27;

always @(posedge clk27)
    if( spi_done && frame_done && can_finish && max_frames_done ) begin
        $finish;
    end

initial begin
    clk27 = 1'b0;
    forever clk27 = #(37.037/2) ~clk27; // 27 MHz
end

reg rst_base;

initial begin
    rst_base = 1'b0;
    #500 rst_base = 1'b1;
    #2500 rst_base=1'b0;
end

integer rst_cnt;

always @(negedge clk27 or posedge rst_base)
    if( rst_base ) begin
        rst <= 1'b1; 
        rst_cnt <= 2;
    end else begin
        if(rst_cnt) rst_cnt<=rst_cnt-1;
        else rst<=rst_base;
    end

wire [15:0] SDRAM_DQ;
wire [12:0] SDRAM_A;
wire [ 1:0] SDRAM_BA;
wire SDRAM_DQML, SDRAM_DQMH, SDRAM_nWE, SDRAM_nCAS, SDRAM_nRAS, SDRAM_nCS, SDRAM_CKE;
wire [5:0] VGA_R, VGA_G, VGA_B;
wire VGA_HS, VGA_VS;

wire SPI_DO, SPI_DI, SPI_SCK, SPI_SS2, SPI_SS3, SPI_SS4, CONF_DATA0;

jt1942_mist UUT(
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
    .SPI_SS3    ( SPI_SS3   ),
    .SPI_SS4    ( SPI_SS4   ),
    .CONF_DATA0 ( CONF_DATA0),
    // sound
    .AUDIO_L    ( AUDIO_L   ),
    .AUDIO_R    ( AUDIO_R   ),
    // unused
    .LED()
);

`ifdef FASTSDRAM
quick_sdram mist_sdram(
    .SDRAM_DQ   ( SDRAM_DQ      ),
    .SDRAM_A    ( SDRAM_A       ),
    .SDRAM_CLK  ( SDRAM_CLK     ),
    .SDRAM_nCS  ( SDRAM_nCS     ),
    .SDRAM_nRAS ( SDRAM_nRAS    ),
    .SDRAM_nCAS ( SDRAM_nCAS    ),
    .SDRAM_nWE  ( SDRAM_nWE     )
);
`else
mt48lc16m16a2 #(.filename("../../../rom/JT1942.rom")) mist_sdram (
    .Dq         ( SDRAM_DQ      ),
    .Addr       ( SDRAM_A       ),
    .Ba         ( SDRAM_BA      ),
    .Clk        ( SDRAM_CLK     ),
    .Cke        ( SDRAM_CKE     ),
    .Cs_n       ( SDRAM_nCS     ),
    .Ras_n      ( SDRAM_nRAS    ),
    .Cas_n      ( SDRAM_nCAS    ),
    .We_n       ( SDRAM_nWE     ),
    .Dqm        ( {SDRAM_DQMH,SDRAM_DQML}   )
);
`endif

`ifdef LOADROM
spitx u_spitx(
    .rst        ( rst        ),
    .SPI_DO     ( SPI_DO     ),
    .SPI_SCK    ( SPI_SCK    ),
    .SPI_DI     ( SPI_DI     ),
    .SPI_SS2    ( SPI_SS2    ),
    .SPI_SS3    ( SPI_SS3    ),
    .SPI_SS4    ( SPI_SS4    ),
    .CONF_DATA0 ( CONF_DATA0 ),
    .spi_done   ( spi_done   )
);
`else 
assign spi_done = 1'b1;
`endif

endmodule // jt_gng_a_test