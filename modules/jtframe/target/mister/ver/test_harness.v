`timescale 1ns/1ps

module mister_harness(
    output  reg        rst,
    output  reg        clk50,
    // Frame count
    output  reg [31:0] frame_cnt,
    input              VS,
    // video
    input              VGA_CLK,
    input              VGA_CE,
    input              VGA_DE,
    input  [7:0]       VGA_R,
    input  [7:0]       VGA_G,
    input  [7:0]       VGA_B,
    input              VGA_HS,
    input              VGA_VS,
    input              VGA_VB,
    input              VGA_HB,
    // SDRAM
    input              dwnld_busy,
    inout [15:0]       SDRAM_DQ,
    inout [12:0]       SDRAM_A,
    inout              SDRAM_DQML,
    inout              SDRAM_DQMH,
    inout              SDRAM_nWE,
    inout              SDRAM_nCAS,
    inout              SDRAM_nRAS,
    inout              SDRAM_nCS,
    inout [1:0]        SDRAM_BA,
    inout              SDRAM_CLK,
    inout              SDRAM_CKE
);

parameter sdram_instance = 1, GAME_ROMNAME="_PASS ROM NAME to mister_harness_";
parameter TX_LEN = 207;
////////////////////////////////////////////////////////////////////
initial frame_cnt=0;
always @(posedge VS ) begin
    frame_cnt<=frame_cnt+1;
    $display("Frame %4d", frame_cnt);
end

`ifdef MAXFRAME
reg frames_done=1'b0;
always @(negedge VS)
    if( frame_cnt == `MAXFRAME ) frames_done <= 1'b1;
`else
reg frames_done=1'b1;
`endif

integer fincnt;

////////////////////////////////////////////////////////////////////
// video output dump

video_dump u_dump(
    .pxl_clk    ( VGA_CLK       ),
    .pxl_cen    ( VGA_CE        ),
    .pxl_hb     ( VGA_HB        ),
    .pxl_vb     ( VGA_VB        ),
    .red        ( VGA_R[7:4]    ),
    .green      ( VGA_G[7:4]    ),
    .blue       ( VGA_B[7:4]    ),
    .frame_cnt  ( frame_cnt     )
    //input        downloading
);

////////////////////////////////////////////////////////////////////
always @(posedge clk50)
    if( frames_done ) begin
        for( fincnt=0; fincnt<`SIM_MS; fincnt=fincnt+1 ) begin
            #(1000*1000); // ms
            $display("%d ms",fincnt+1);
        end
        $finish;
    end

initial begin
    clk50 = 1'b0;
    forever clk50 = #(20/2) ~clk50; // 50 MHz
end


reg rst_base=1'b1;

initial begin
    rst_base = 1'b1;
    #100 rst_base = 1'b0;
    #150 rst_base = 1'b1;
    #2500 rst_base=1'b0;
end

integer rst_cnt;

always @(negedge clk50 or posedge rst_base)
    if( rst_base ) begin
        rst <= 1'b1;
        rst_cnt <= 2;
    end else begin
        if(rst_cnt) rst_cnt<=rst_cnt-1;
        else rst<=rst_base;
    end

mt48lc16m16a2 #(.filename(GAME_ROMNAME)) mister_sdram (
    .Dq         ( SDRAM_DQ      ),
    .Addr       ( SDRAM_A       ),
    .Ba         ( SDRAM_BA      ),
    .Clk        ( SDRAM_CLK     ),
    .Cke        ( SDRAM_CKE     ),
    .Cs_n       ( SDRAM_nCS     ),
    .Ras_n      ( SDRAM_nRAS    ),
    .Cas_n      ( SDRAM_nCAS    ),
    .We_n       ( SDRAM_nWE     ),
    .Dqm        ( {SDRAM_DQMH,SDRAM_DQML}   ),
    .downloading( dwnld_busy    ),
    .VS         ( VS            ),
    .frame_cnt  ( frame_cnt     )
);

endmodule // jt_1942_a_test
