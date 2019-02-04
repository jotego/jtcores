`timescale 1ns/1ps

module test_harness(
    output  reg  rst,
    output  reg  clk,
    output  reg  clk27,
    output       cen12, 
    output       cen6,
    output       cen3,
    output       cen1p5,
    input   [21:0]  sdram_addr,
    output  [15:0]  data_read,
    input   loop_rst, 
    input   autorefresh,   
    output  downloading,
    output    [24:0]  romload_addr,
    output    [15:0]  romload_data,
    // SPI
    output  SPI_SCK,
    output  SPI_DI,  // SPI always from FPGA's view
    input   SPI_DO,
    output  CONF_DATA0,
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

parameter sdram_instance = 1;


`ifdef MAXFRAME
reg frame_done=1'b1, max_frames_done=1'b0;
`else 
reg frame_done=1'b1, max_frames_done=1'b1;
`endif

wire spi_done;
integer fincnt;

reg clk_rom;
initial begin
    clk_rom=1'b0;
    forever clk_rom = #(10.417/2) ~clk_rom; // 96 MHz
end

always @(posedge clk)
    if( spi_done && frame_done && max_frames_done ) begin
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

parameter clk_speed=12;

always @(*) 
    case(clk_speed)
        24: clk = clk_cnt[1];
        12: clk = clk_cnt[2];
        6:  clk = clk_cnt[3];
        default: begin 
            $display("ERROR: Invalid value of clk_speed");
            $finish;
        end
    endcase // clk_speedendcase

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


jtgng_cen #(.clk_speed(clk_speed)) u_cen(
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
            .clk_slow       ( clk & cen12   ),
            .loop_rst       ( loop_rst      ),  
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
spitx u_spitx(
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

data_io datain (
    .sck        (SPI_SCK      ),
    .ss         (SPI_SS2      ),
    .sdi        (SPI_DI       ),
    .downloading_sdram(downloading  ),
    .index      (             ),
    .clk_sdram  (SDRAM_CLK    ),
    .addr_sdram (romload_addr ),
    .data_sdram (romload_data )
);
`else 
assign downloading = 0;
assign romload_addr = 0;
assign romload_data = 0;
assign spi_done = 1'b1;
`endif

endmodule // jt_1942_a_test