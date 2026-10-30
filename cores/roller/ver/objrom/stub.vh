module jt053244 #(
    parameter HFLIP_OFFSET=0,VFLIP_OFFSET=0,DEBUG_FLICKER=1
)(
    input rst,clk,pxl2_cen,pxl_cen,cs,cpu_we,
    input [3:0] cpu_addr,
    input [15:0] cpu_dout,
    input [1:0] cpu_dsn,
    output [21:1] rmrd_addr,
    output [13:1] dma_addr,
    input [15:0] dma_data,
    output dma_bsy,
    output [15:0] code,
    output [6:0] attr,
    output hflip,vflip,
    output [9:0] hpos,
    output [3:0] ysub,
    output [11:0] hzoom,
    output hz_keep,
    input [8:0] hdump,vdump,
    input lvbl,hs,
    input [8:0] pxl,
    output shd,dr_start,
    input dr_busy,
    input [7:0] debug_bus,st_addr,
    output [7:0] st_dout
);
assign {rmrd_addr,dma_addr,dma_bsy,code,attr,hflip,vflip,hpos,ysub,hzoom,hz_keep,shd,dr_start,st_dout}=0;
endmodule

module jtframe_objdraw #(
    parameter SHADOW=0,SHADOW_PEN=0,SW=2,AW=10,CW=16,PW=16,
              LATCH=0,SWAPH=0,ZW=0,ZI=0,ZENLARGE=0,FLIP_OFFSET=0,KEEP_OLD=0
)(
    input rst,clk,pxl_cen,hs,flip,
    input [9:0] hdump,
    input draw,
    output busy,
    input [15:0] code,
    input [9:0] xpos,
    input [3:0] ysub,
    input hz_keep,
    input [11:0] hzoom,
    input hflip,vflip,
    input [PW-5:0] pal,
    output [22:2] rom_addr,
    output rom_cs,
    input rom_ok,
    input [31:0] rom_data,
    output [15:0] pxl
);
assign {busy,rom_addr,rom_cs,pxl}=0;
endmodule

module jtframe_dual_nvram16 #(
    parameter AW=12,SIMFILE=""
)(
    input clk0,
    input [15:0] data0,
    input [AW:1] addr0,
    input [1:0] we0,
    output [15:0] q0,
    input clk1,
    input [AW:1] addr1a,
    output [15:0] q1a,
    input [7:0] data1,
    input [AW:0] addr1b,
    input we1b,
    output [7:0] q1b,
    input sel_b
);
assign q0=16'h1234;
assign {q1a,q1b}=0;
endmodule
