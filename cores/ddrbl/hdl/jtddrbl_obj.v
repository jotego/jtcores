//============================================================================
//  jtddrbl_obj.v — Konami 005885 sprite engine for Double Dribble (GX690).
//  Extracted from jtddrbl_k005885.v (D9). Scans the 5-byte OBJ list in the
//  chip's VRAM (A12=1, render port), fetches the packed 4bpp sprite gfx, looks
//  up the sprite colour (I15 256x4 PROM on chip 2 / 1:1 on chip 1) and fills a
//  jtframe_obj_buffer that is read back at display time as obj_pxl (0=transp.).
//
//  The VRAM-scan and gfx-ROM ports are time-shared with the tilemap engine in
//  the parent chip: this module owns them only during obj_win (h_cnt>=272); the
//  parent muxes obj_rd_addr / rom_addr onto the shared buses.
//
//  Author: Andrea Bogazzi <andreabogazzi79@gmail.com>
//  JTCORES integration is GPL-3 (see jtcores LICENSE).
//============================================================================

module jtddrbl_obj #(
    // Sprite colour: 0 = use the 256-byte I15 LUT PROM (chip 2), 1 = pens 1:1 (chip 1)
    // 0 = FG (chip 1, 25 sprites), 1 = BG (chip 2, 64 sprites)
    parameter        LAYER_BG     = 0,
    parameter [17:0] OBJSTART     = 18'h0_0000,
    parameter [17:0] OBJMASK      = 18'h3_FFFF
) (
    input              clk,
    input              rst,
    input              pxl_cen,

    // video timing from the parent chip
    input      [ 8:0]  h_cnt,
    input      [ 8:0]  v_cnt,
    input              obj_win,          // sprite window (h_cnt>=272)
    input              hblank,           // active-high horizontal blank (display gate)

    // OBJ-list scan on the shared VRAM render port (parent muxes when obj_win)
    output     [11:0]  obj_rd_addr,
    input      [ 7:0]  vram_scn_dout,

    // External PROM
    output     [ 3:0]  OCF,OCB,
    input      [ 3:0]  OCD,
    // sprite gfx fetch on the shared gfx-ROM bus (parent muxes when obj_win)
    output     [17:0]  rom_addr,
    output             rom_cs,
    input      [ 7:0]  RDU,
    input      [ 7:0]  RDL,
    input              rom_ok,

    output     [ 3:0]  obj_pxl
);

localparam [8:0] HB_OPEN   = 9'd14;    // visible window opens at h_cnt 14
// 5 bytes/sprite (doc/005885_sprite_format.md). NSPR = FG 25 / BG 64.
//   byte0=code[7:0]  byte1={col[3:0],_,code[10:8]}  byte2=Y  byte3=X
//   byte4={_,flipy(6),flipx(5),size[4:2],x8(0)}
localparam [8:0] OBJ_BYTES = LAYER_BG ? 9'd320 : 9'd125;  // 5*NSPR
localparam [8:0] OBJ_DY    = 9'd1;     // sprite render-ahead (vrr = v_cnt + OBJ_DY)

reg  [ 8:0] obj_base;      // byte offset of current sprite (0,5,10,...)
reg  [ 2:0] obj_byte;      // OBJ byte being addressed
reg  [ 3:0] obj_st;        // scan/render FSM state
reg  [ 2:0] obj_rp;        // pipelined OBJ-RAM read phase (0..6)
reg         obj_run;
reg  [ 7:0] s_y, s_b0, s_b1;
reg  [ 8:0] s_xpos;
reg  [ 3:0] s_col;
reg  [ 2:0] s_size;
reg         s_fx, s_fy, s_x8;
reg  [ 5:0] row_sp;        // sprite-space row (0..obj_h-1, vflip-adjusted)
reg  [ 5:0] spr_hp;        // screen-space column within the sprite (0..obj_w-1)
reg  [15:0] spr_word;      // fetched gfx word (4 px)
reg  [ 1:0] spr_dn;        // nibble counter for the dump
reg         old_hblk_obj;
reg         line_we;
reg  [ 8:0] line_addr;
reg  [ 3:0] line_data;     // OCD (looked-up sprite colour), 0 = transparent

assign obj_rd_addr = { 3'd0, obj_base } + { 9'd0, obj_byte };
assign { OCF, OCB }= { s_col, dump_nibble };

wire [10:0] spr_num = { s_b1[2:0], s_b0 };                  // 11-bit sprite number
wire [ 8:0] vrr   = v_cnt + OBJ_DY;                         // render row (next line)
wire [ 5:0] obj_h = (s_size[2]|s_size[1]) ? 6'd32 : 6'd16;  // sprite height
wire [ 5:0] obj_w = (s_size[2]|s_size[0]) ? 6'd32 : 6'd16;  // sprite width
wire        y_hit = (vrr >= {1'b0,s_y}) && (vrr < ({1'b0,s_y} + {3'd0,obj_h}));

// MAME masks the base number per size (ddribble.cpp draw_sprites):
//   32x32 (s_size=100): &~3   16x32 (010): &~2   32x16 (001): &~1   16x16: &~0
wire [10:0] base_num = (s_size==3'b100) ? (spr_num & ~11'd3) :
                       (s_size==3'b010) ? (spr_num & ~11'd2) :
                       (s_size==3'b001) ? (spr_num & ~11'd1) : spr_num;
// Multi-tile expansion: 32px sprite = 4x 16x16 sub-tiles (x_offset {0,1},
// y_offset {0,2}); the sub-tile index follows spr_hp / row_sp.
wire        sub_x   = (obj_w==6'd32) & spr_hp[4];
wire        sub_y   = (obj_h==6'd32) & row_sp[4];
wire [10:0] eff_num = base_num + {10'd0,sub_x} + {9'd0,sub_y,1'b0};

wire [16:0] spr_local = { eff_num, row_sp[3], spr_hp[3], row_sp[2:0], spr_hp[2] };
assign rom_addr = OBJSTART | ({1'b0, spr_local} & OBJMASK);
assign rom_cs   = obj_run && (obj_st==4'd6 || obj_st==4'd7);

wire [ 5:0] hp_scr   = s_fx ? (obj_w - 6'd1 - spr_hp) : spr_hp;
wire [ 9:0] full_col = ({1'b0, s_xpos} + {4'd0, hp_scr}) - 10'd1;

wire [3:0] dump_nibble = spr_word[15:12];                 // OCB (sprite pixel)

// Scan the OBJ list in the sprite window: size+Y first (skip non-overlap), else
// read code/colour/X and fetch+dump the 16x16 gfx row into the line buffer.
always @(posedge clk) begin
    old_hblk_obj <= obj_win;
    line_we <= 1'b0;
    if (rst) begin
        obj_run<=1'b0; obj_st<=4'd0; obj_base<=9'd0; obj_byte<=3'd4; obj_rp<=3'd0;
    end else if (!old_hblk_obj && obj_win) begin   // sprite-scan window start
        obj_run<=1'b1; obj_st<=4'd0; obj_base<=9'd0; obj_byte<=3'd4; obj_rp<=3'd0;
    end else if (!obj_win) begin
        obj_run<=1'b0;
    end else if (obj_run) case (obj_st)
        // Pipelined OBJ-RAM read: issue the five byte addresses (4,2,0,1,3)
        // back-to-back, capturing each datum 1 clk later (BRAM read latency).
        4'd0: begin
            obj_rp <= obj_rp + 3'd1;
            case (obj_rp)                          // present the next byte address
                3'd0: obj_byte <= 3'd2;            // (byte4 already on the bus)
                3'd1: obj_byte <= 3'd0;
                3'd2: obj_byte <= 3'd1;
                3'd3: obj_byte <= 3'd3;
                default:;
            endcase
            case (obj_rp)                          // capture the datum issued 1 clk ago
                3'd1: begin s_size<=vram_scn_dout[4:2]; s_fx<=vram_scn_dout[5];   // byte4
                            s_fy<=vram_scn_dout[6]; s_x8<=vram_scn_dout[0]; end
                3'd2: s_y  <= vram_scn_dout;                                      // byte2
                3'd3: s_b0 <= vram_scn_dout;                                      // byte0
                3'd4: begin s_col<=vram_scn_dout[7:4]; s_b1<=vram_scn_dout; end   // byte1
                3'd5: begin s_xpos<={s_x8,vram_scn_dout};                         // byte3
                    // sprite-space row within the (16 or 32)-tall sprite; vflip mirrors it.
                    row_sp <= s_fy ? (obj_h - 6'd1 - (vrr[5:0]-s_y[5:0])) : (vrr[5:0]-s_y[5:0]);
                    spr_hp <= 6'd0; obj_st <= 4'd6; end
                default:;
            endcase
            // y_hit valid once s_y is captured (phase 2); skip off-scanline sprites.
            if (obj_rp==3'd3 && !y_hit) obj_st <= 4'd9;
        end
        4'd6: obj_st<=4'd7;                                    // issue gfx fetch
        4'd7: if (rom_ok) begin spr_word<={RDU,RDL}; spr_dn<=2'd0; obj_st<=4'd8; end
        4'd8: begin                                            // dump 4 px (high-nibble first)
                  line_we   <= (OCD != 4'd0);
                  line_addr <= full_col[8:0];
                  line_data <= OCD;                        // looked-up sprite colour
                  spr_word  <= { spr_word[11:0], 4'd0 };
                  spr_hp    <= spr_hp + 6'd1;
                  spr_dn    <= spr_dn + 2'd1;
                  if (spr_dn==2'd3)
                      obj_st <= ((spr_hp+6'd1) >= obj_w) ? 4'd9 : 4'd6;
              end
        4'd9: begin                                            // next sprite
                  obj_byte<=3'd4; obj_st<=4'd0; obj_rp<=3'd0;
                  if (obj_base >= OBJ_BYTES-9'd5) obj_run<=1'b0;
                  else obj_base<=obj_base+9'd5;
              end
        default: obj_st<=4'd9;
    endcase
end

// Sprite line buffer (jtframe_obj_buffer, double-buffered, erase-on-read).
wire [8:0] obj_dcol = { 1'b0, h_cnt[7:0] - HB_OPEN[7:0] };
// Toggle the double buffer at h_cnt 2 so display read and obj_win write hit opposite banks.
wire objbuf_lhbl = (h_cnt < 9'd2) || (h_cnt >= 9'd14);
jtframe_obj_buffer #(.DW(4), .AW(9), .ALPHA(4'h0)) u_objbuf(
    .clk     ( clk            ),
    .LHBL    ( objbuf_lhbl    ),
    .flip    ( 1'b0           ),
    .wr_data ( line_data      ),
    .wr_addr ( line_addr      ),
    .we      ( line_we        ),
    .rd_addr ( obj_dcol       ),
    // erase-on-read gated to the visible window so each column is erased once
    .rd      ( pxl_cen & ~hblank ),
    .rd_data ( obj_pxl        )
);

endmodule
