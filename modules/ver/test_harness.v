`timescale 1ns/1ps

module test_harness(
    output  reg      rst,
    output  reg      clk,
    output  reg      clk27,
    output           cen12,
    output           cen6,
    output           cen3,
    output           cen1p5,
    input   [21:0]   sdram_addr,
    output  [15:0]   data_read,
    output           loop_rst,
    input            autorefresh,
    input            H0,
    output           downloading,
    output    [21:0] ioctl_addr,
    output    [ 7:0] ioctl_data,
    output           ioctl_wr,
    // Video dumping
    input             HS,
    input             VS,
    input       [3:0] red,
    input       [3:0] green,
    input       [3:0] blue,
    output reg [31:0] frame_cnt,
    // SPI
    output       SPI_SCK,
    output       SPI_DI,  // SPI always from FPGA's view
    input        SPI_DO,
    output       SPI_SS2,
    output       CONF_DATA0,
    // SDRAM
    inout [15:0] SDRAM_DQ,
    inout [12:0] SDRAM_A,
    inout        SDRAM_DQML,
    inout        SDRAM_DQMH,
    inout        SDRAM_nWE,
    inout        SDRAM_nCAS,
    inout        SDRAM_nRAS,
    inout        SDRAM_nCS,
    inout [1:0]  SDRAM_BA,
    inout        SDRAM_CLK,
    inout        SDRAM_CKE
);

parameter sdram_instance = 1, GAME_ROMNAME="_PASS ROM NAME to test_harness_";
parameter TX_LEN = 207;
parameter CLK_SPEED=12;

////////////////////////////////////////////////////////////////////
// video output dump
`ifdef DUMP_VIDEO
integer fvideo;
initial begin
    fvideo = $fopen("video.bin","wb");
end

wire [15:0] video_dump = { 2'b0,VS,HS, red, green, blue  };

// Define VIDEO_START with the first frame number for which
// video will be dumped. If undefined, it will start from frame 0
`ifndef VIDEO_START
`define VIDEO_START 0
`endif

always @(posedge clk) if(cen6 && frame_cnt>=`VIDEO_START ) begin
    $fwrite(fvideo,"%u", video_dump);
end

`endif

////////////////////////////////////////////////////////////////////
initial frame_cnt=0;
always @(posedge VS ) begin
    frame_cnt<=frame_cnt+1;
    $display("New frame %d", frame_cnt);
end

`ifdef MAXFRAME
reg frames_done=1'b0;
always @(negedge VS)
    if( frame_cnt == `MAXFRAME ) frames_done <= 1'b1;
`else
reg frames_done=1'b1;
`endif

wire spi_done;
integer fincnt;

wire clk_rom;
jtgng_pll0 u_pll(
    .inclk0 ( 1'b0    ),
    .c1     ( clk     ),      // 12
    .c2     ( clk_rom )      // 96
    // output       c3,     // 96 (shifted by -2.5ns)
    // output   locked
);

////////////////////////////////////////////////////////////////////
always @(posedge clk)
    if( spi_done && frames_done ) begin
        for( fincnt=0; fincnt<`SIM_MS; fincnt=fincnt+1 ) begin
            #(1000*1000); // ms
            $display("%d ms",fincnt+1);
        end
        $finish;
    end

initial begin
    clk27 = 1'b0;
    forever clk27 = #(37.037/2) ~clk27; // 27 MHz
end

reg [3:0] clk_cnt=3'd0;

//reg clk_gen;
//always @(clk_rom) clk_gen = #8 clk_rom;
always @(posedge clk_rom) begin
    clk_cnt <= clk_cnt + 4'd1;
end

reg rst_base=1'b1;

initial begin
    rst_base = 1'b1;
    #100 rst_base = 1'b0;
    #150 rst_base = 1'b1;
    #2500 rst_base=1'b0;
end

integer rst_cnt;

always @(negedge clk or posedge rst_base)
    if( rst_base ) begin
        rst <= 1'b1;
        rst_cnt <= 2;
    end else if(cen6) begin
        if(rst_cnt) rst_cnt<=rst_cnt-1;
        else rst<=rst_base;
    end


jtgng_cen #(.CLK_SPEED(CLK_SPEED)) u_cen(
    .clk    ( clk    ),
    .cen12  ( cen12  ),
    .cen6   ( cen6   ),
    .cen3   ( cen3   ),
    .cen1p5 ( cen1p5 )
);

generate
    if (sdram_instance==1) begin
        assign #5 SDRAM_CLK = clk_rom;

        jtgng_sdram u_sdram(
            .rst            ( rst           ),
            .clk            ( clk_rom       ), // 96MHz = 32 * 6 MHz -> CL=2
            .H0             ( H0            ),
            .loop_rst       ( loop_rst      ),
            .autorefresh    ( autorefresh   ),
            .data_read      ( data_read     ),
            // ROM-load interface
            .downloading    ( downloading   ),
            .prog_addr      ( ioctl_addr    ),
            .prog_data      ( ioctl_data    ),
            .prog_we        ( ioctl_wr      ),
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
    end
endgenerate



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
mt48lc16m16a2 #(.filename(GAME_ROMNAME)) mist_sdram (
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
spitx #(.filename(GAME_ROMNAME), .TX_LEN(TX_LEN) )
    u_spitx(
    .rst        ( rst        ),
    .SPI_DO     ( 1'b0       ),
    .SPI_SCK    ( SPI_SCK    ),
    .SPI_DI     ( SPI_DI     ),
    .SPI_SS2    ( SPI_SS2    ),
    .SPI_SS3    ( SPI_SS3    ),
    .SPI_SS4    ( SPI_SS4    ),
    .CONF_DATA0 ( CONF_DATA0 ),
    .spi_done   ( spi_done   )
);

data_io #(.aw(22)) datain (
    .sck        (SPI_SCK      ),
    .ss         (SPI_SS2      ),
    .sdi        (SPI_DI       ),
    .downloading_sdram(downloading  ),
    .index      (             ),
    .clk_sdram  (SDRAM_CLK    ),
    .ioctl_addr ( ioctl_addr  ),
    .ioctl_data ( ioctl_data  ),
    .ioctl_wr   ( ioctl_wr    )
);
`else
assign downloading = 0;
assign romload_addr = 0;
assign romload_data = 0;
assign spi_done = 1'b1;
assign SPI_SS2  = 1'b0;
`endif

endmodule // jt_1942_a_test