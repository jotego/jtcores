`timescale 1ns/1ps 

module test;

reg clk;
wire [ 8:0] vdump, vrender, vrender1, H;
wire [11:0] rgb_o;
wire Hinit, Vinit, LHBL, LVBL, HS, VS,
     pxl2_cen, pxl_cen;

wire [ 7:0] cart3_out, cart2_out;
wire [ 5:0] cart1_vid;
wire        cart1_dir, cart2_dir, cart3_dir;

reg en=0;
reg [1:0] cen_cnt=0;
reg [2:0] vs_cnt=0;
reg [3:0] scale=0;
reg       HSl, VSl,LHBLl;

assign pxl2_cen = cen_cnt[0];
assign pxl_cen  = cen_cnt==3;

reg [3:0] linecnt=0; 
reg [2:0] fin=0;
wire      rst = fin[1];

initial begin
    clk = 0;
    forever #5 clk=~clk;
end

always @(posedge clk) begin
    cen_cnt <= cen_cnt + 1'd1;
    HSl     <= HS;
    VSl     <= VS;
    LHBLl   <= LHBL;
    //if(   LHBL ) rgb_cnt <= rgb_cnt+1'd1;
    //if(  ~LHBL ) rgb_cnt <= 0;
    //if( ~LHBL & LHBLl ) rgb_max <= rgb_cnt;
    if( HS & ~HSl)  {scale, linecnt } <= {scale, linecnt } + 1'd1;
    if( VS & ~VSl ) begin
        {fin,en} <= {fin,en}+1'b1;
        vs_cnt <= vs_cnt+1;
    end;
    if (fin[2] || vs_cnt==3) #100 $finish;
end

`define JTFRAME_SCAN2X_NOBLEND

jtframe_pocket_anavideo #(.COLORW(4)) u_analogvideo(
    .clk        ( clk      ),
    .pxl_cen    ( pxl_cen  ),
    .pxl2_cen   ( pxl2_cen ),
    .anv_en     ( 1'b1     ), // enable analogic video output
    .rst        ( rst      ),
    .bypass     ( 1'b1     ),
    .game_r     ( {3'b0,vdump[8]}),
    .game_g     ( vdump[7:4]),
    .game_b     ( vdump[3:0]),
    .LHBL       ( LHBL     ),
    .LVBL       ( LVBL     ),
    .hs         ( HS       ),
    .vs         ( VS       ),
    .bw_en      ( 1'b0/*bw_en*/     ),
    .scanlines  ( 2'd3/*scanlines*/ ),
    // video signal type
    .ypbpr      ( 1'b0/*ypbpr*/     ),
    .no_csync   ( 1'b1      ),
    .scan2x_enb ( en/*1'b0*/),
    //Output
    .cart3_out  ( cart3_out),
    .cart2_out  ( cart2_out),
    .cart1_vid  ( cart1_vid),
    .cart1_dir  ( cart1_dir),
    .cart2_dir  ( cart2_dir),
    .cart3_dir  ( cart3_dir)
);
/*jtframe_hsize uut(
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
*/

localparam [8:0] VB_START = /*LAYOUT==3 ?*/ 9'd238 /*: 9'd239*/,
                 VB_END   = /*LAYOUT==3 ?*/ 9'd014 /*: 9'd015*/;

jtframe_vtimer #(
    .VB_START   (  VB_START ),
    .VB_END     (  VB_END   ),
    .VCNT_END   (  9'd263   ),
    .VS_START   (  9'd260   ),
    .HB_END     (  9'd383   ),
    .HB_START   (  9'd255   ),
    .HCNT_END   (  9'd383   ),
    .HS_START   (  9'h12F   ),
    .HS_END     (  9'h14F   )
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