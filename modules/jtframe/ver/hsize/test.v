`timescale 1ns/1ps 

module test;

reg clk;
wire [ 8:0] vdump, vrender, vrender1, H;
wire [11:0] rgb_o;
wire Hinit, Vinit, LHBL, LVBL, HS, VS,
     pxl2_cen, pxl_cen;

reg en=0;
reg [1:0] cen_cnt=0;
reg [2:0] vs_cnt=0;
reg [3:0] scale=0;
reg       HSl, VSl,LHBLl;

assign pxl2_cen = cen_cnt[0];
assign pxl_cen  = cen_cnt==3;

reg [3:0] linecnt=0; 
reg [2:0] fin=0;

initial begin
    clk = 0;
    forever #5 clk=~clk;
end

always @(posedge clk) begin
    cen_cnt <= cen_cnt + 1'd1;
    HSl     <= HS;
    VSl     <= VS;
    LHBLl   <= LHBL;
    if(   LHBL ) rgb_cnt <= rgb_cnt+1'd1;
    if(  ~LHBL ) rgb_cnt <= 0; 
    //if( ~LHBL & LHBLl ) rgb_max <= rgb_cnt;
    if( HS & ~HSl)  {scale, linecnt } <= {scale, linecnt } + 1'd1;
    if( VS & ~VSl ) begin
        {fin,en} <= {fin,en}+1'b1;
        vs_cnt <= vs_cnt+1;
    end;
    if (fin[2] || vs_cnt==3) #100 $finish;
end

jtframe_hsize uut(
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .pxl2_cen   ( pxl2_cen  ),

    .scale      ( scale     ),
    .offset     ( 5'd0      ),
    .enable     ( en        ),
    .r_in       ( {3'b0,vdump[8]}),
    .g_in       ( vdump[7:4]),
    .b_in       ( vdump[3:0]),
    .HS_in      ( HS        ),
    .VS_in      ( VS        ),
    .HB_in      ( ~LHBL     ),
    .VB_in      ( ~LVBL     ),
    // filtered video
    .HS_out     (           ),
    .VS_out     (           ),
    .HB_out     (           ),
    .VB_out     (           ),
    .r_out      (rgb_o[11:8] ),
    .g_out      (rgb_o[7:4] ),
    .b_out      (rgb_o[3:0] )
);

jtframe_vtimer #(
    .HB_START( 279 ),
    .HB_END  ( 383 ),   // 384 pixels per line, H length = 64us
    .VB_END  ( 15  ),
    .VCNT_END( 263 ),
    .HS_START( 312 ),
    .VS_START( 253 ),
    .VS_END  ( 256 )
) u_timer(
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .vdump      ( vdump     ),
    .vrender    (           ),
    .vrender1   (           ),
    .H          (           ),
    .Hinit      (           ),
    .Vinit      (           ),
    .LHBL       ( LHBL      ),
    .LVBL       ( LVBL      ),
    .HS         ( HS        ),
    .VS         ( VS        )
);

initial begin
    $dumpfile("test.lxt");
    $dumpvars;
    #10000000 $finish;
end

endmodule