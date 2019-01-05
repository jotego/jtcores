`timescale 1ns/1ps

/*

    Game test

    ~0.95 frames/minute on DELL laptop
    at least 900 frames to see SERVICE screen

*/

/* verilator lint_off STMTDLY */

module mist_test;
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
                //$display("DUMP starts");
                $dumpvars(1,mist_test.UUT.u_main);
                //$dumpvars(1,mist_test.UUT.u_rom);
                $dumpoff;
                $dumpvars(1,mist_test.UUT.u_video);
                //$dumpvars(1,mist_test.UUT.u_video.u_char);
                //$dumpvars(0,UUT.chargen);
                //#30_000_000;
            `endif
            $dumpon;
        `endif
    end

    `endif

`ifdef MAXFRAME
reg frame_done=1'b1, max_frames_done=1'b0;
`else 
reg frame_done=1'b1, max_frames_done=1'b1;
`endif

reg can_finish=1'b0, spi_done=1'b1;
integer fincnt;

initial begin
    for( fincnt=0; fincnt<`SIM_MS; fincnt=fincnt+1 ) begin
        #(1000*1000); // ms
        $display("%d ms",fincnt+1);
    end
    can_finish = 1'b1;
end

reg rst, clk27;

always @(posedge clk27)
    if( spi_done && frame_done && can_finish && max_frames_done ) begin
        for( fincnt=0; fincnt<`SIM_MS; fincnt=fincnt+1 ) begin
            #(1000*1000); // ms
        end
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
    .SPI_SS2    ( SPI_SS2   ),
    .SPI_SS3    ( SPI_SS3   ),
    .SPI_SS4    ( SPI_SS4   ),
    .CONF_DATA0 ( CONF_DATA0),
    // sound
    .AUDIO_L    ( AUDIO_L   ),
    .AUDIO_R    ( AUDIO_R   )
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
mt48lc16m16a2 mist_sdram (
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
integer file;
wire    SPI_DO;
reg     SPI_DI;
wire    SPI_SCK;
reg     SPI_SS2;
wire    SPI_SS3=1'b0;
wire    SPI_SS4=1'b0;
reg     CONF_DATA0;

localparam UIO_FILE_TX      = 8'h53;
localparam UIO_FILE_TX_DAT  = 8'h54;
localparam UIO_FILE_INDEX   = 8'h55;
localparam TX_LEN           = 32'he000*2; // Only code for both CPUs

reg [7:0] rom_buffer[0:TX_LEN-1];

initial begin
    file=$fopen("../../../rom/JTGNG.rom","rb");
    tx_cnt=$fread( rom_buffer, file );
    $fclose(file);
end

integer tx_cnt, spi_st, next, buff_cnt;
reg spi_clkgate;
reg clk_24;

initial begin
    clk_24 = 0;
    forever #20.833 clk_24 = ~clk_24;
end

localparam SPI_INIT=0, SPI_TX=1, SPI_SET=2, SPI_END=3, SPI_UNSET=4;
assign SPI_SCK = clk_24 /*& spi_clkgate*/;
reg [15:0] spi_buffer;

always @(posedge SPI_SCK or posedge rst) begin
    if( rst ) begin 
        tx_cnt <= 2500;
        spi_st <= 0;
        spi_buffer <= { UIO_FILE_TX, 8'hff };
        spi_clkgate <= 1'b1;
        SPI_SS2 <= 1'b1;
        buff_cnt <= 15;
        spi_done <= 1'b0;       
    end
    else
    case( spi_st )
        SPI_INIT: begin
            if( tx_cnt ) tx_cnt <= tx_cnt-1; // wait for SDRAM to be ready
        else begin
            SPI_SS2 <= 1'b0;
            SPI_DI <= spi_buffer[buff_cnt];
            if( buff_cnt==0 ) begin
                $display("SPI transfer begins");
                spi_st <= SPI_SET;
            end
            else
                buff_cnt <= buff_cnt-1;
            end
        end
        SPI_SET: begin
            SPI_SS2 <= 1'b1;
            spi_buffer[7:0] <= UIO_FILE_TX_DAT;
            spi_st <= SPI_TX;
            buff_cnt <= 7;
        end
        SPI_TX: begin
            SPI_SS2 <= 1'b0;
            SPI_DI <= spi_buffer[buff_cnt];
            if( buff_cnt ) begin
                spi_clkgate <= 1'b1;
                buff_cnt <= buff_cnt-1;
            end
            else begin
                tx_cnt <= tx_cnt + 1;
                // $display("tx_cnt %X",tx_cnt);
                if(tx_cnt==TX_LEN) begin
                    SPI_SS2 <= 1'b1;
                    spi_st <= SPI_UNSET;
                end
                else begin
                    buff_cnt <= 7;
                    spi_buffer[7:0] <= rom_buffer[tx_cnt];
                end
                if(tx_cnt>TX_LEN) spi_st <= SPI_END;
            end
        end
        SPI_END: begin
            spi_done <= 1'b1;
            spi_clkgate <= 1'b0;
        end
        SPI_UNSET: begin
            spi_buffer <= {UIO_FILE_TX, 8'd0};
            buff_cnt <= 15;
            spi_st <= SPI_TX;
        end
    endcase
end

always @(spi_done)
    if(spi_done) begin
        $display("ROM loading completed");
        `ifdef DUMP
        $dumpon;
        `endif
    end
`endif

endmodule // jt_gng_a_test