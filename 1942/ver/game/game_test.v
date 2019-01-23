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

reg spi_done=1'b1;
integer fincnt;

reg rst=1'b1, clk, clk_rom;

always @(posedge clk)
    if( spi_done && frame_done && max_frames_done ) begin
        for( fincnt=0; fincnt<`SIM_MS; fincnt=fincnt+1 ) begin
            #(1000*1000); // ms
            $display("%d ms",fincnt+1);
        end
        $finish;
    end



wire SDRAM_CLK = clk_rom;

initial begin
    clk_rom=1'b0;
    forever clk_rom = #(10.417/2) ~clk_rom; // 96 MHz
end

reg [2:0] clk_cnt=3'd0;

always @(posedge clk_rom) begin
    clk_cnt <= clk_cnt + 3'd1;
end

always @(*) clk = clk_cnt[1];

reg rst_base=1'b1;

initial begin
    rst_base = 1'b1;
    #100 rst_base = 1'b0;
    #150 rst_base = 1'b1;
    #2500 rst_base=1'b0;
end

integer rst_cnt;
wire cen6, cen3, cen1p5;

always @(negedge clk or posedge rst_base)
    if( rst_base ) begin
        rst <= 1'b1; 
        rst_cnt <= 2;
    end else if(cen6) begin
        if(rst_cnt) rst_cnt<=rst_cnt-1;
        else rst<=rst_base;
    end

wire [3:0] red, green, blue;
wire LHBL, LVBL;

wire [15:0] SDRAM_DQ;
wire [12:0] SDRAM_A;
wire [ 1:0] SDRAM_BA;
wire SDRAM_DQML, SDRAM_DQMH, SDRAM_nWE, SDRAM_nCAS, SDRAM_nRAS, SDRAM_nCS, SDRAM_CKE;

wire            downloading;
wire    [24:0]  romload_addr;
wire    [15:0]  romload_data;


jtgng_cen u_cen(
    .clk    ( clk    ),    // 24 MHz
    .cen6   ( cen6   ),
    .cen3   ( cen3   ),
    .cen1p5 ( cen1p5 )
);

wire [8:0] snd;
wire snd_sample;

wire   [21:0]  sdram_addr;
wire   [15:0]  data_read;
wire   loop_rst, autorefresh, loop_start; 
wire   HS, VS;

reg [6:0] prom_we;
always @(*)
    if( !downloading ) prom_we = 7'd0;
    else case(romload_addr[10:8])
        3'd0: prom_we = 7'h1;
        3'd1: prom_we = 7'h2;
        3'd2: prom_we = 7'h4;
        3'd3: prom_we = 7'h8;
        3'd4: prom_we = 7'h10;
        3'd5: prom_we = 7'h20;
        3'd6: prom_we = 7'h40;
    endcase // romload_addr[10:8]

jt1942_game UUT(
    .rst        ( rst       ),
    .soft_rst   ( 1'b0      ),
    .clk        ( clk       ),
    .clk_rom    ( clk_rom   ),
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
    .joystick1  ( 8'hff     ),
    .joystick2  ( 8'hff     ),
    // ROM load
    .downloading ( downloading   ),
    .romload_addr( romload_addr  ),
    .romload_data( romload_data  ),
    .loop_rst    ( loop_rst      ),
    .loop_start  ( loop_start    ),
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
    
    // DIP switches
    .dip_test   ( 1'b0      ),
    .dip_planes ( 2'b0      ),
    .dip_level  ( 2'b0      ),
    .dip_upright( 1'b0      ),
    .dip_price  ( 4'b0      ),    
    // Sound output
    .snd            ( snd       ),
    .sample         ( snd_sample)
);

jtgng_sdram u_sdram(
    .rst            ( rst           ),
    .clk            ( clk_rom       ), // 96MHz = 32 * 6 MHz -> CL=2  
    .loop_rst       ( loop_rst      ),  
    .loop_start     ( loop_start    ),
    .autorefresh    ( autorefresh   ),
    .data_read      ( data_read     ),
    // ROM-load interface
    .downloading    ( downloading   ),
    .romload_addr   ( romload_addr  ),
    .romload_data   ( romload_data  ),
    .sdram_addr     ( sdram_addr    ),
    // SDRAM interface
    .SDRAM_DQ       ( SDRAM_DQ      ),
    .SDRAM_A        ( SDRAM_A       ),
    .SDRAM_DQML     ( SDRAM_DQML    ),
    .SDRAM_DQMH     ( SDRAM_DQMH    ),
    .SDRAM_nWE      ( SDRAM_nWE     ),
    .SDRAM_nCAS     ( SDRAM_nCAS    ),
    .SDRAM_nRAS     ( SDRAM_nRAS    ),
    .SDRAM_nCS      ( SDRAM_nCS     ),
    .SDRAM_BA       ( SDRAM_BA      ),
    .SDRAM_CKE      ( SDRAM_CKE     ) 
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

/*
`ifdef VGACONV
reg clk_vga;
wire [3:0] VGA_R, VGA_G, VGA_B;
wire VGA_HS, VGA_VS;

initial begin
    clk_vga =1'b0;
    forever clk_vga  = #20.063 ~clk_vga ; //20
end

jt1942_vga vga_conv (
    .clk_1942    ( clk_pxl       ), //  6 MHz
    .clk_vga    ( clk_vga       ), // 25 MHz
    .rst        ( rst           ),
    .red        ( red           ),
    .green      ( green         ),
    .blue       ( blue          ),
    .LHBL       ( LHBL          ),
    .LVBL       ( LVBL          ),
    .vga_red    ( VGA_R         ),
    .vga_green  ( VGA_G         ),
    .vga_blue   ( VGA_B         ),
    .vga_hsync  ( VGA_HS        ),
    .vga_vsync  ( VGA_VS        )
);
`ifdef CHR_DUMP
integer frame_cnt;
reg enter_hbl, enter_vbl;
always @(posedge clk_vga) begin
    if( rst ) begin
        enter_hbl <= 1'b0;
        enter_vbl <= 1'b0;
        frame_cnt <= 0;
    end else begin
        enter_hbl <= VGA_HS;
        enter_vbl <= VGA_VS;
        if( enter_vbl != VGA_VS && !VGA_VS) begin
            $write(")]\n# New frame\nframe_%d=[(\n", frame_cnt);
            frame_cnt <= frame_cnt + 1;
        end
        else
        if( enter_hbl != VGA_HS && !VGA_HS)
            $write("),\n(");
        else
            if( VGA_HS ) $write("%d,%d,%d,",red,red, green, green, blue, blue);
    end
end
`endif

`endif
*/

`ifdef MAXFRAME
integer fout, frame_cnt;
reg skip;

reg enter_hbl, enter_vbl;
always @(posedge clk ) if(cen6) begin
    if( rst || downloading ) begin
        enter_hbl <= 1'b0;
        enter_vbl <= 1'b0;
        frame_cnt <= 0;
        skip <= 1'b1;
    end else if(!downloading) begin
        enter_hbl <= LHBL;
        enter_vbl <= LVBL;
        if( enter_vbl != LVBL && !LVBL ) begin
            if( frame_cnt>0) $fclose(fout);
            $display("New frame (%d)", frame_cnt);
            `ifdef MAXFRAME
            if( frame_cnt == `MAXFRAME-1 ) max_frames_done<=1'b1;
            `endif
            fout = $fopen("frame_0"+(frame_cnt&32'h1f),"wb"); // do not move this line

            frame_cnt <= frame_cnt + 1;
            skip <= 1'b1;
            frame_done <= 1'b1;
        end
        else begin
            if( enter_hbl != LHBL && !LHBL) begin
                skip <= 1'b0; // skip first line;
                frame_done <= 1'b0;
                $fwrite(fout,"%u",32'hFFFFFFFF); // new line marker
            end
            if( !skip && LHBL ) 
                $fwrite(fout,"%u", {8'd0, red, 4'd0, green, 4'd0, blue, 4'd0});
                // $write("%d,%d,%d,",red*8'd16,green*8'd16,blue*8'd16);
        end
    end
end
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
localparam TX_LEN           = 234496;

reg [7:0] rom_buffer[0:TX_LEN-1];

initial begin
    file=$fopen("../../../rom/JT1942.rom","rb");
    tx_cnt=$fread( rom_buffer, file );
    if( tx_cnt != TX_LEN ) begin
        $display("Cannot read a JT1942.rom file long enough");
        $fclose(file);
        $finish;
    end
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

data_io datain (
    .sck        (SPI_SCK      ),
    .ss         (SPI_SS2      ),
    .sdi        (SPI_DI       ),
    .downloading_sdram(downloading  ),
    // .index      (index        ),
    .clk_sdram  (SDRAM_CLK    ),
    .addr_sdram (romload_addr ),
    .data_sdram (romload_data )
);

`else 
assign downloading = 0;
assign romload_addr = 0;
assign romload_data = 0;
`endif

endmodule // jt_1942_a_test