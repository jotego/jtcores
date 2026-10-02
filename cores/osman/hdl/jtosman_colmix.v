/*  This file is part of JTCORES. GPLv3. See jtosman_game.v header.
    Author: Andrea Bogazzi.

    Osman colour mixer. Palette xBGR-555, 1 word/colour: {x,B[14:10],G[9:5],R[4:0]}.
    simpl156 screen_update draw order back->front: fill pen 256 (0x100 backdrop) <
    pf2 (col_bank 0x10 -> pens 0x100+) < pf1 (col_bank 0x00 -> pens 0x000+) < sprites
    (gfxdecode base 0x200). deco16 pxl = {colour[3:0],pixel[3:0]}; pen 0 transparent.
    v0: layer inputs are 0 -> the whole screen shows the backdrop pen 0x100.
*/
module jtosman_colmix(
    input             clk,
    input             pxl_cen,
    input             LHBL,
    input             LVBL,
    // deco16ic draws BOTH sizes per playfield: pf?a = 16x16, pf?b = 8x8 (same name RAM,
    // gfx bank 0/1). col_bank: pf1 -> pen 0x000+, pf2 -> pen 0x100+.
    input      [ 7:0] pf1a_pxl, pf1b_pxl,   // pf1 16x16 / 8x8   {colour[3:0],pixel[3:0]}
    input      [ 7:0] pf2a_pxl, pf2b_pxl,   // pf2 16x16 / 8x8
    input      [11:0] obj_pxl,     // {epri,pri[1:0],colour[4:0],pixel[3:0]} base 0x200

    output reg [ 9:0] pal_addr,    // palette read (RAM in jtosman_video), 1024 colours
    input      [15:0] pal_data,

    output     [ 7:0] red,
    output     [ 7:0] green,
    output     [ 7:0] blue
);

wire pf1a_op = pf1a_pxl[3:0]!=4'd0;
wire pf1b_op = pf1b_pxl[3:0]!=4'd0;
wire pf2a_op = pf2a_pxl[3:0]!=4'd0;
wire pf2b_op = pf2b_pxl[3:0]!=4'd0;
wire obj_op  = obj_pxl[3:0]!=4'd0;

// Sprite priority. simpl156 draws pf2 into the priority bitmap with value 2, pf1 with 4;
// draw_sprites tests each pixel with drawgfx's (pmask & (1<<pri_bitmap))!=0 => occluded.
// pri = obj_pxl[10:9] (word2[15:14]); pri_callback pmask: 0->0, 1->0xf0, 2/3->0xfc.
//   pri 0 (pmask 0)   : never occluded            -> in FRONT of both playfields
//   pri 1 (pmask 0xf0): 1<<4 hits pf1, 1<<2 misses -> BEHIND pf1, in front of pf2
//   pri 2/3 (0xfc)    : hits both pf1(4) and pf2(2)-> BEHIND both playfields
wire [1:0] obj_pri = obj_pxl[10:9];
wire obj_front = obj_op & (obj_pri==2'd0);   // front of everything
wire obj_mid   = obj_op & (obj_pri==2'd1);   // between pf1 and pf2
wire obj_back  = obj_op &  obj_pri[1];        // pri 2/3: behind both, above backdrop

// front->back: obj(0) > pf1_16 > pf1_8 > obj(1) > pf2_16 > pf2_8 > obj(2/3) > backdrop(0x100).
wire [9:0] pal_idx = obj_front ? {1'b1, obj_pxl[8:0]}  :   // 0x200 + colour*16 + pixel
                     pf1a_op ? {2'b00, pf1a_pxl}     :   // pf1 pen 0x000-0x0FF
                     pf1b_op ? {2'b00, pf1b_pxl}     :
                     obj_mid ? {1'b1, obj_pxl[8:0]}  :   // sprites between pf1 and pf2
                     pf2a_op ? {2'b01, pf2a_pxl}     :   // pf2 pen 0x100-0x1FF
                     pf2b_op ? {2'b01, pf2b_pxl}     :
                     obj_back ? {1'b1, obj_pxl[8:0]} :   // sprites behind both playfields
                               10'h100;                   // backdrop pen 256

always @(posedge clk) if(pxl_cen) pal_addr <= pal_idx;

// xBGR-555 -> 8-bit RGB (5->8 replicate high bits)
wire [7:0] r8 = { pal_data[ 4:0], pal_data[ 4:2] };
wire [7:0] g8 = { pal_data[ 9:5], pal_data[ 9:7] };
wire [7:0] b8 = { pal_data[14:10], pal_data[14:12] };

jtframe_blank #(.DLY(0),.DW(24)) u_blank(
    .clk( clk ), .pxl_cen( pxl_cen ),
    .preLHBL( LHBL ), .preLVBL( LVBL ),
    .LHBL(), .LVBL(), .preLBL(),
    .rgb_in ( { g8, r8, b8 } ),
    .rgb_out( { green, red, blue } )
);

endmodule
