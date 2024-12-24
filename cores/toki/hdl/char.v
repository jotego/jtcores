////////// char ram  //////////////////////////////////
//
// State machine that draw a line of 8x8 tile
// each time line number change.
// RAM is fully scanned, address in ram give 
// tile position on screen, there is 32 tiles by line
// RAM data describe a tile :
//  -  [3:0] color
//  - [11:0] index of tile in ROM 
//  
//  Tile data are DWORD stored in ROM as 4 bit planes 
//  second dword of each data is at address + 0x8000
//
//  each pixel of tile are 8 bits : 
//    4 bits color, 4 bits index (rom data)
//  pixel are transparent if ROM data is 0xf
//  pixel value is an index into the video palette 
//
module scan_char_ram(
  input                 clk,
  input                 rst,

  input           [7:0] line_number,

  output reg     [10:1] ram_addr,
  input          [15:0] ram_out,

  input          [15:0] gfx_rom_data,
  input                 gfx_rom_ok,
  output reg     [16:1] gfx_rom_addr,
  output reg            gfx_rom_cs,

  input           [7:0] line_buffer_addr,
  output          [7:0] line_buffer_out
);

(* ramstyle = "no_rw_check" *)reg [7:0] line_buffer [255:0];
assign line_buffer_out = line_buffer[line_buffer_addr];

reg [3:0]  state = 4'd0;

parameter STATE_START = 4'd0;
parameter STATE_FETCH_RAM  = 4'd1;
parameter STATE_COPY_FIRST_ROM_WORD = 4'd2;
parameter STATE_COPY_SECOND_ROM_WORD = 4'd3;
parameter STATE_FETCH_PIXEL = 4'd4;
parameter STATE_FINISHED = 4'd5;
parameter STATE_NEXT_PIXEL = 4'd6;
parameter STATE_WAIT_RAM = 4'd7;
parameter STATE_FETCH_ROM = 4'd8;

reg  [4:0] tile_index;
reg [15:0] first_rom_word;
reg [15:0] second_rom_word;
reg  [2:0] pix_index;
reg  [7:0] previous_line_number;

reg  [3:0] color;
reg [11:0] rom_index; //4096 tiles 

wire [7:0] plane1, plane2, plane3, plane4;

assign plane1 = {first_rom_word[11:8],   first_rom_word[3:0]};  // low nibbles
assign plane2 = {first_rom_word[15:12],  first_rom_word[7:4]};  // high nibbles
assign plane3 = {second_rom_word[11:8],  second_rom_word[3:0]}; // low nibbles
assign plane4 = {second_rom_word[15:12], second_rom_word[7:4]}; // high nibbles

always @(posedge clk, posedge rst) begin
  if (rst) begin 
      tile_index <= 0;
      pix_index <= 0;
      state <= STATE_START;
      end
  else begin  
    case (state)
      STATE_START : begin
        tile_index <= 0;
        pix_index <= 0;
        state <= STATE_FETCH_RAM;
      end

      STATE_FETCH_RAM: begin
        ram_addr[10:1] <= (({2'b0, line_number}/10'd8)*10'd32) + {5'b0, tile_index[4:0]};
        state <= STATE_WAIT_RAM; 
      end

      STATE_WAIT_RAM: begin
        state <= STATE_FETCH_ROM; 
      end  

      STATE_FETCH_ROM: begin
        rom_index[11:0] <= ram_out[11:0];
        color[3:0] <= ram_out[15:12];
        gfx_rom_addr[16:1] <= ram_out[11:0]*16'd8 + ({8'h0, line_number}%16'd8);
        gfx_rom_cs <= 1'b1;
        state <= STATE_COPY_FIRST_ROM_WORD;
      end  

      STATE_COPY_FIRST_ROM_WORD : begin 
        if (gfx_rom_ok)  begin
          first_rom_word[15:0] <= gfx_rom_data[15:0];
          gfx_rom_addr[16:1] <= rom_index[11:0]*16'd8 + ({8'h0, line_number}%16'd8) + 16'h8_000;
          gfx_rom_cs <= 1'b1;
          state <= STATE_COPY_SECOND_ROM_WORD;
          end
      end

      STATE_COPY_SECOND_ROM_WORD : begin
         if (gfx_rom_ok) begin
           second_rom_word[15:0] <= gfx_rom_data[15:0];
           gfx_rom_cs <= 1'b0;
           pix_index <= 3'b0;
           state <= STATE_FETCH_PIXEL;
           end
      end
      
      STATE_FETCH_PIXEL:  begin
        //8 bits : color 4 bits, 4 bits index 
        if ({plane4[pix_index],plane3[pix_index],plane2[pix_index],plane1[pix_index]} != 'hf)
          line_buffer[tile_index*8 + {2'b0, pix_index}] <= {color[3:0],{plane4[pix_index],plane3[pix_index],plane2[pix_index],plane1[pix_index]}};
        else
          line_buffer[tile_index*8 + {2'b0, pix_index}] <= 'hf;
        state <= STATE_NEXT_PIXEL;
      end

      STATE_NEXT_PIXEL: begin
        if (pix_index < 3'd7) begin
          pix_index <= pix_index + 2'd1;
          state <= STATE_FETCH_PIXEL;
          end
        else if (pix_index == 7) begin
          if (tile_index == 31)
            state <= STATE_FINISHED;
          else begin
            tile_index <= tile_index + 1'b1; 
            state <= STATE_FETCH_RAM;
            end
          end
      end

      STATE_FINISHED: begin
        if (previous_line_number != line_number) begin
          tile_index <= 0;
          pix_index <= 0;
          state <= STATE_START;
          end
        previous_line_number <= line_number;
      end
    
     default : 
       state <= STATE_FINISHED;

    endcase 
    end
end

endmodule
