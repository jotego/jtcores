////////// VIDEO ////////////////////////////////////////////
//
// - video synchronization (hsync, vsync, vblank, hblank)
// - char, bg1, bg2, sprite drawing  
// - char, bg1, bg2, sprite mixing & output 
//
module toki_video(
  input             rst,

  // Clock
  input             clk,
  input             pxl_cen,
  input             pxl2_cen,

  // Video out
  input       [3:0] gfx_en, // debug : graphical layer enable

  output            hsync,
  output            vsync, 
  output            hblank, 
  output            vblank,
  output      [8:0] hpos,
  output      [8:0] vpos, 

  // RGB out
  output [3:0]      r,
  output [3:0]      g,
  output [3:0]      b,

  // Shared video RAM
  output reg [10:1] palette_addr,
  input      [15:0] palette_out,

  output     [10:1] vram_addr,
  input      [15:0] vram_out,

  output     [10:1] bg1_addr,
  input      [15:0] bg1_out,

  output     [10:1] bg2_addr,
  input      [15:0] bg2_out,

  output     [10:1] sprite_addr,
  input      [15:0] sprite_out,

  // ROM data
  input      [15:0] gfx1_rom_data,
  input             gfx1_rom_ok,
  output     [16:1] gfx1_rom_addr,
  output            gfx1_rom_cs,

  input      [15:0] gfx2_rom_data,
  input             gfx2_rom_ok,
  output     [19:1] gfx2_rom_addr,
  output            gfx2_rom_cs,

  input      [15:0] gfx3_rom_data,
  input             gfx3_rom_ok,
  output     [18:1] gfx3_rom_addr,
  output            gfx3_rom_cs,

  input      [15:0] gfx4_rom_data,
  input             gfx4_rom_ok,
  output     [18:1] gfx4_rom_addr,
  output            gfx4_rom_cs,

  // Scroll latch
  input      [8:0]  bg1_scroll_x,
  input      [8:0]  bg1_scroll_y,
  input      [8:0]  bg2_scroll_x,
  input      [8:0]  bg2_scroll_y,
  input             bg_order
);

////////// VIDEO SYNC /////////////
//
wire display_on;

hvsync u_hvsync(
  .clk(clk),
  .pxl_cen(pxl_cen),

  .hsync(hsync),
  .vsync(vsync),
  .hblank(hblank),
  .vblank(vblank),

  .display_on(display_on),

  .hpos(hpos),
  .vpos(vpos)
);

///////// CHAR DRAWING //////////
//
// char : 8x8 tile 
//
parameter VRAM_PALETTE_OFFSET = 10'h100;

wire       vram_used;
wire [7:0] vram_line_buffer_out;
reg  [7:0] vram_line_buffer_addr;

scan_char_ram vram_scan_char_ram_u(
  .clk(clk),
  .rst(rst),

  .line_number(line_number),

  .ram_addr(vram_addr),
  .ram_out(vram_out),

  .gfx_rom_data(gfx1_rom_data),
  .gfx_rom_ok(gfx1_rom_ok),
  .gfx_rom_addr(gfx1_rom_addr),
  .gfx_rom_cs(gfx1_rom_cs),

  .line_buffer_addr(vram_line_buffer_addr),
  .line_buffer_out(vram_line_buffer_out)
);

///////// BG1 DRAWING /////////////////
//
// background 1 : 16x16 tile 
//
parameter BG1_PALETTE_OFFSET = 10'h200;

wire       bg1_used;
wire [7:0] bg1_line_buffer_out;
reg  [7:0] bg1_line_buffer_addr = 0;

scan_tile_ram bg1_scan_tile_ram_u(
  .clk(clk),
  .rst(rst),

  .line_number(line_number),

  .ram_addr(bg1_addr),
  .ram_out(bg1_out),

  .gfx_rom_data(gfx3_rom_data),
  .gfx_rom_ok(gfx3_rom_ok),
  .gfx_rom_addr(gfx3_rom_addr),
  .gfx_rom_cs(gfx3_rom_cs),

  .line_buffer_addr(bg1_line_buffer_addr),
  .line_buffer_out(bg1_line_buffer_out),

  .scroll_x(bg1_scroll_x),
  .scroll_y(bg1_scroll_y)
);

///////// BG2 DRAWING /////////////////
//
// background 2 : 16x16 tile 
//
parameter BG2_PALETTE_OFFSET = 10'h300;

wire        bg2_used;
wire [7:0]  bg2_line_buffer_out;
reg  [7:0]  bg2_line_buffer_addr = 0;

scan_tile_ram bg2_scan_tile_ram_u(
  .clk(clk),
  .rst(rst),

  .line_number(line_number),

  .ram_addr(bg2_addr),
  .ram_out(bg2_out),

  .gfx_rom_data(gfx4_rom_data),
  .gfx_rom_ok(gfx4_rom_ok),
  .gfx_rom_addr(gfx4_rom_addr),
  .gfx_rom_cs(gfx4_rom_cs),

  .line_buffer_addr(bg2_line_buffer_addr),
  .line_buffer_out(bg2_line_buffer_out),

  .scroll_x(bg2_scroll_x),
  .scroll_y(bg2_scroll_y)
);

///////// SPRITE DRAWING /////////////////
//
// sprite : 16x16 tile 
//
wire        sprite_used;
wire  [7:0] sprite_line_buffer_out;
reg   [7:0] sprite_line_buffer_addr = 0;

scan_sprite_ram scan_sprite_ram_u(
  .clk(clk),
  .rst(rst),

  .line_number(line_number),

  .ram_addr(sprite_addr),
  .ram_out(sprite_out),

  .gfx_rom_data(gfx2_rom_data),
  .gfx_rom_ok(gfx2_rom_ok),
  .gfx_rom_addr(gfx2_rom_addr),
  .gfx_rom_cs(gfx2_rom_cs),

  .line_buffer_addr(sprite_line_buffer_addr),
  .line_buffer_out(sprite_line_buffer_out),
  .used_out(sprite_used)
);

///////// COLOR MIX & OUTPUT ////////////////////////////
//
// select the right pixel from the different line buffer 
// go from top layer (char) to background layer
// check background order
// check if pixel is transparent
// get first non-transparent pixel 
// get pixel final color from the palette
// output the pixel to the screen
//
reg [7:0] line_number;

always @(posedge hblank) begin
  if (vpos + 1 > 15  && vpos + 1 < 240)
    line_number <= vpos[7:0] + 8'd1;
end

assign r = palette_out[3:0];
assign g = palette_out[7:4];
assign b = palette_out[11:8];

always @(posedge clk) begin
  vram_line_buffer_addr <= hpos[7:0] - 8'b1;
  bg1_line_buffer_addr <= hpos[7:0] - 8'b1;
  bg2_line_buffer_addr <= hpos[7:0] - 8'b1;
  sprite_line_buffer_addr <= hpos[7:0] - 8'b1;

  if (display_on) begin
    if (vram_line_buffer_out[3:0] != 'hf)
      palette_addr[10:1] <= {2'd0, vram_line_buffer_out} + VRAM_PALETTE_OFFSET;
    else if (sprite_used == 1'b1)
      palette_addr[10:1] <= {2'd0, sprite_line_buffer_out}; 
    else begin
      if (bg_order == 1'b0) begin
        if (bg1_line_buffer_out[3:0] != 'hf) 
          palette_addr[10:1] <= {2'd0, bg1_line_buffer_out} + BG1_PALETTE_OFFSET;
        else if (bg2_line_buffer_out[3:0] != 'hf) 
          palette_addr[10:1] <= {2'd0, bg2_line_buffer_out} + BG2_PALETTE_OFFSET;
        else
          palette_addr[10:1] <= 'h3ff;
        end
      else begin
        if (bg2_line_buffer_out[3:0] != 'hf) 
          palette_addr[10:1] <= {2'd0, bg2_line_buffer_out} + BG2_PALETTE_OFFSET;
        else if (bg1_line_buffer_out[3:0] != 'hf)
          palette_addr[10:1] <= {2'd0, bg1_line_buffer_out} + BG1_PALETTE_OFFSET;
        else
          palette_addr[10:1] <= 'h3ff;
        end
     end
  end
end

endmodule
