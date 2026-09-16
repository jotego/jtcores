/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 13-7-2022 */

// Video board, schematic sheet 5 of 7

module jtoutrun_colmix(
    input              rst,
    input              clk,
    input              pxl2_cen,  // pixel clock enable (2x)
    input              pxl_cen,   // pixel clock enable

    input              video_en,
    input      [ 1:0]  game_id,
    input              gear,
    input              gear_en,
    input              ingame,

    input              preLHBL,
    input              preLVBL,

    // CPU interface
    input              pal_cs,
    input      [13:1]  cpu_addr,
    input      [15:0]  cpu_dout,
    input      [ 1:0]  dswn,
    output     [15:0]  cpu_din,

    // From tile map generator
    input      [10:0]  tmap_addr,
    input      [13:0]  obj_pxl,
    input      [ 7:0]  rd_pxl,
    input      [ 4:3]  rc,
    input              shadow,
    input              sa,
    input              sb,
    input              fix,

    output     [ 4:0]  red,
    output     [ 4:0]  green,
    output     [ 4:0]  blue,
    output             LVBL,
    output             LHBL,
    input      [ 7:0]  debug_bus,

    // SD card dumps
    input      [21:0]  ioctl_addr,
    input              ioctl_ram,
    output     [ 7:0]  ioctl_din,
    // Get some random data during start-up for the palette
    input      [21:0]  prog_addr,
    input      [ 7:0]  prog_data,
    input              prog_we,
    input      [ 1:0]  prog_ba
);

wire [ 1:0] we;
wire [15:0] pal_out;
wire [14:0] rgb;
reg  [11:0] pal_addr, pre_addr;
reg  [13:0] objl;
reg         muxsel, shadowl;
reg  [14:0] gated;
// reg  [ 1:0] blink;

assign we = ~dswn & {2{pal_cs}};
reg  [ 8:0] ovl_x, ovl_y;
reg         ovl_hbl;
localparam [21:0] GLYPH_WORD = 22'd1024;
localparam [ 4:0] CH_H = 5'd8,  CH_I = 5'd9,  CH_L = 5'd12,
                  CH_O = 5'd15, CH_W = 5'd23;

wire        turbo = game_id==2;

reg  [21:0] pa_l;
reg  [ 7:0] pd_l, plane0;
reg         pv_l;
reg  [ 7:0] gl_addr;
reg  [23:0] gl_data;
reg         gl_we;
wire [23:0] gl_dout;
wire [21:0] gl_word = prog_addr - GLYPH_WORD;
wire        gl_hit  = prog_we && prog_ba==2'd2 && gl_word[21:9]==0;
wire        gl_new  = prog_we && prog_ba==2'd2 && (!pv_l || prog_addr!=pa_l);

function [23:0] unpack( input [7:0] b0, b1, b2 );
    integer x;
    for( x=0; x<8; x=x+1 ) unpack[x*3 +: 3] = { b2[7-x], b1[7-x], b0[7-x] };
endfunction

always @(posedge clk) begin
    gl_we <= 0;
    if( gl_new && gl_hit ) begin
        if( !prog_addr[0] ) begin
            plane0  <= prog_data;
        end else begin
            gl_we   <= 1;
            gl_addr <= gl_word[8:1];
            gl_data <= unpack( plane0, pd_l, prog_data );
        end
    end
    if( prog_we && prog_ba==2'd2 ) begin
        pa_l <= prog_addr;
        pd_l <= prog_data;
        pv_l <= 1;
    end
end

wire [ 8:0] gear_x = turbo ? 9'd197 : 9'd79;
wire [ 8:0] gear_y = turbo ? 9'd209 : 9'd208;
wire [ 8:0] dx = ovl_x - gear_x, dy = ovl_y - gear_y;
wire [ 4:0] gear_w = gear ? 5'd16 : 5'd24;
wire        gear_box = dy < 9'd8 && dx < {4'd0, gear_w};

reg  [ 4:0] ch;
always @(*) begin
    if( gear )
        ch = dx[3] ? CH_I : CH_H;
    else case( dx[4:3] )
        2'd0:    ch = CH_L;
        2'd1:    ch = CH_O;
        default: ch = CH_W;
    endcase
end

jtframe_dual_ram #(.DW(24),.AW(8)) u_glyph(
    .clk0   ( clk       ),
    .data0  ( gl_data   ),
    .addr0  ( gl_addr   ),
    .we0    ( gl_we     ),
    .q0     (           ),

    .clk1   ( clk       ),
    .data1  ( 24'd0     ),
    .addr1  ( {ch, dy[2:0]} ),
    .we1    ( 1'b0      ),
    .q1     ( gl_dout   )
);

wire [ 2:0] gl_pxl  = gl_dout[ dx[2:0]*3 +: 3 ];
wire        gl_edge = gl_pxl == (turbo ? 3'd1 : 3'd7);
wire        gear_on = gear_en && ingame && video_en && gear_box && gl_pxl!=0;

reg [14:0] gear_rgb;
always @(*) begin
    if( gl_edge || turbo ) begin
        gear_rgb = gl_edge ? 15'd0 : 15'h7fff;
    end else case( gl_pxl )
        3'd1:    gear_rgb = gear ? {5'd29,5'd22,5'd25} : {5'd18,5'd29,5'd22};
        3'd2:    gear_rgb = gear ? {5'd27,5'd20,5'd22} : {5'd16,5'd27,5'd20};
        3'd3:    gear_rgb = gear ? {5'd25,5'd18,5'd20} : {5'd12,5'd25,5'd18};
        3'd4:    gear_rgb = gear ? {5'd22,5'd16,5'd18} : {5'd10,5'd22,5'd16};
        default: gear_rgb = gear ? {5'd20,5'd14,5'd16} : {5'd08,5'd20,5'd14};
    endcase
end

assign { red, green, blue } = gear_on ? gear_rgb : rgb;

always @(posedge clk) if(pxl_cen) begin
    ovl_hbl <= LHBL;
    ovl_x   <= LHBL ? ovl_x+9'd1 : 9'd0;
    if( !LHBL && ovl_hbl ) ovl_y <= LVBL ? ovl_y+9'd1 : 9'h1ff;
end

wire [4:0] rpal, gpal, bpal;

`ifndef GRAY
assign rpal  = { pal_out[ 3:0], pal_out[12] };
assign gpal  = { pal_out[ 7:4], pal_out[13] };
assign bpal  = { pal_out[11:8], pal_out[14] };
`else
assign rpal  = { pal_addr[3:0], pal_addr[3] };
assign gpal  = { pal_addr[3:0], pal_addr[3] };
assign bpal  = { pal_addr[3:0], pal_addr[3] };
`endif

function [4:0] dim;
    input [4:0] a;
    dim = a - (a>>2);
endfunction

function [4:0] light;
    input [4:0] a;
    begin : fn_light
        reg [5:0] aux;
        aux = {1'b0, a } + ( {1'b0, a } >>2);
        light = aux[5] ? 5'h1f : aux[4:0];
    end
endfunction

// Super Hang On Equations 315-5251
// muxel ==0 selects tile mapper output, ==1 selects road
// muxsel = obj0 & obj1 & obj2 & obj3 & FIX & !rc3q #
//       obj0 & obj1 & obj2 & obj3 & sa_n & sb_n & FIX #
//       !obj0 & obj1 & !obj2 & obj3 & obj10 & !obj11 & FIX;

always @(posedge clk) if(pxl_cen) begin
    pal_addr <= pre_addr;
    shadowl  <= shadow;
    objl     <= obj_pxl;

    gated <= !video_en ? 15'd0 :
         !shadowl     ? { rpal, gpal, bpal }                      : // no shade effect
          pal_out[15] ? { light(rpal), light(gpal), light(bpal) } : // brighter
                        { dim(rpal), dim(gpal), dim(bpal) };        // dimmer
end

always @(*) begin
    // This equation has the shadow term added. It isn't in the
    // original equation. So I may be interpreting some of the terms
    // wrong. Active high/low in PAL equations can be confusing...
    muxsel = !fix && ((objl[3:0]==4'h0 || shadow)  && (!rc[3] || (!sa && !sb) ));
            // the pen for transparency is not clear
            // using the signal polarity in the original equation
            // breaks the columns in stage 2 left
            // 0 or 1111 seems to work
            //  || ( objl[11:10]==2'b01 && objl[3:0]==4'b1111 /*debug_bus[3:0]*/ ));
    pre_addr = muxsel ? { 2'b01, {3{rd_pxl[7]}}, rd_pxl[6:0] } :
          (sa | sb | fix ) ? { 1'b0, tmap_addr }:
                              { 1'b1, objl[13:7], objl[3:0]}; // skips the shadow and priority bits
end

// reg LVBLl;

// always @(posedge clk) begin
//     LVBLl <= LVBL;
//     if( LVBLl && !LVBL ) blink <= blink+2'd1;
// end

jtframe_dual_nvram16 #(
    .AW     (13       ),
    .SIMFILE("pal.bin")
) u_ram(
    .clk0   ( clk       ),
    .clk1   ( clk       ),

    // CPU writes
    .addr0  ( cpu_addr  ),
    .data0  ( cpu_dout  ),
    .we0    ( we        ),
    .q0     ( cpu_din   ),

    // Video reads
    .addr1a ( {1'b0, prog_we ? prog_addr[11:0] : pal_addr } ),
    .q1a    ( pal_out   ),
    // SD card dumps
`ifdef SIMULATION
    .we1b   ( 1'd0      ),
`else
    .we1b   ( prog_we   ),
`endif
    .data1  ( prog_addr[7:0]  ),
    .addr1b ( ioctl_addr[13:0]),
    .sel_b  ( ioctl_ram | prog_we ),
    .q1b    ( ioctl_din )
);

jtframe_blank #(.DLY(3),.DW(15)) u_blank(
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .preLHBL    ( preLHBL   ),
    .preLVBL    ( preLVBL   ),
    .LHBL       ( LHBL      ),
    .LVBL       ( LVBL      ),
    .preLBL     (           ),
    .rgb_in     ( gated     ),
    .rgb_out    ( rgb[14:0] )
);

endmodule