`timescale 1ns/1ps

module test;

reg clk;
wire [ 8:0] vdump, vrender, vrender1, H;
wire [11:0] rgb_o;
wire Hinit, Vinit, LHBL, LVBL, HS, VS,
     pxl2_cen, pxl_cen;

reg en=1;
reg [1:0] cen_cnt=0;
reg [2:0] vs_cnt=0;
reg [3:0] scale=5;
reg       HSl, VSl,LHBLl;

assign pxl2_cen = cen_cnt[0];
assign pxl_cen  = cen_cnt==3;

reg [1:0] linecnt=0;
reg fin=0;

initial begin
    clk = 0;
    forever #5 clk=~clk;    
end

reg cen2=0;
always @(negedge clk) cen2 <= ~cen2;

reg [3:0] rgb=0;
reg [1:0] filter=0;

always @(posedge clk) if (cen2) begin
    if( ~LHBL) {rgb,filter} <= 0;
    else {rgb,filter} <= {rgb,filter} + 1'd1;
end

reg [10:0] rgb_cnt=0;
reg [10:0] rgb_max;

always @(posedge clk) begin
    cen_cnt <= cen_cnt + 1'd1;
    HSl   <= HS;
    VSl   <= VS;
    LHBLl <= LHBL;
    if(   LHBL               ) rgb_cnt <= rgb_cnt+1'd1;
    if(  ~LHBL /*&  ~LHBLl*/ ) rgb_cnt <= 0; 
    //if( ~LHBL & LHBLl ) rgb_max <= rgb_cnt;
    //if( HS & ~HSl) {scale, linecnt } <= {scale, linecnt } + 1'd1;
    if( VS & ~VSl ) begin
        #100 {fin,scale, linecnt } <= {fin,scale, linecnt } + 1'd1;
        en <= en+1'b1;
        vs_cnt <= vs_cnt+1;
    end;
    if (fin || vs_cnt==12) #100 $finish;
end

initial #(16600*1000*4) $finish;

jtframe_hsize uut(
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .pxl2_cen   ( pxl2_cen  ),

    .scale      ( scale     ),
    .offset     ( 5'd0      ),
    .enable     ( 1'b1      ),

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
    // .HCNT_START ( 9'h020    ),
    // .HCNT_END   ( 9'h19F    ),
    // .HB_START   ( 9'h029    ),
    // .HB_END     ( 9'h069    ),  // 10.67 us in RE verilog model
    // .HS_START   ( 9'h034    ),

    // .V_START    ( 9'h0F8    ),
    // .VB_START   ( 9'h1EF    ),
    // .VB_END     ( 9'h10F    ),  //  2.56 ms
    // .VS_START   ( 9'h1FF    ),  // ~512.5us, measured on X-Men PCB
    // .VS_END     ( 9'h0FF    ),
    // .VCNT_END   ( 9'h1FF    )   // 16.896 ms (59.18Hz)
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
   // #10000000 $finish;
end

endmodule



/*
//BORRAR!!!!

wire HS_out,VS_out,HB_out,VB_out;
wire [`JTFRAME_COLORW-1:0] r_out,g_out, b_out;
jtframe_hsize #(
    .COLORW     (`JTFRAME_COLORW)
    ) uut(
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .pxl2_cen   ( pxl2_cen  ),

    .scale      ( 4'b0     ),
    .offset     ( 5'd0      ),
    .enable     ( 1'b1        ),

    .r_in       ( red       ),
    .g_in       ( green       ),
    .b_in       ( blue       ),
    .HS_in      ( HS        ),
    .VS_in      ( VS        ),
    .HB_in      ( LHBL     ),
    .VB_in      ( LVBL     ),
    // filtered video
    .HS_out     (  HS_out         ),
    .VS_out     (  VS_out         ),
    .HB_out     (  HB_out         ),
    .VB_out     (  VB_out         ),
    .r_out      (  r_out         ),
    .g_out      (  g_out         ),
    .b_out      (  b_out         )
);
///
*/