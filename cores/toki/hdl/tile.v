////////// SCAN TILE RAM /////////////////////////////
//
// draw 16x16 tile line by line 
// RAM describe a 512x512 zone 
// current screen position is adjusted 
// by scroll_x & scroll_y register
//
module scan_tile_ram(
  input                 clk,
  input                 rst,

  input           [7:0] line_number,

  output reg     [10:1] ram_addr,
  input          [15:0] ram_out,

  input          [15:0] gfx_rom_data,
  input                 gfx_rom_ok,
  output reg     [18:1] gfx_rom_addr,
  output reg            gfx_rom_cs,

  input           [7:0] line_buffer_addr,
  output          [7:0] line_buffer_out,

  input           [8:0] scroll_x,
  input           [8:0] scroll_y
);

reg [8:0] scroll_x_latch;
reg [8:0] scroll_y_latch;

(* ramstyle = "no_rw_check" *)reg [7:0] line_buffer [255:0];
assign line_buffer_out = line_buffer[line_buffer_addr];

reg [2:0]   state = 0;
parameter   STATE_START = 3'd0;
parameter   STATE_WAIT_START_DECODING = 3'd1;
parameter   STATE_FETCH_ROM_WORDS = 3'd3;
parameter   STATE_COPY_ROM_WORDS = 3'd4;
parameter   STATE_WAIT_COPY_PIXEL = 3'd5;
parameter   STATE_COPY_PIXEL = 3'd6;
parameter   STATE_FINISHED = 3'd7;

reg [15:0]  rom_words [3:0];
reg  [1:0]  rom_words_index;
reg  [9:0]  tile_count; // number of tile processed 
reg  [3:0]  pix_index;
reg  [7:0]  previous_line_number;
reg  [7:0]  line_buffer_index;

wire [3:0]  color;
wire [11:0] rom_index; //0xFFF ()4096 tile possible
wire [15:0] plane1, plane2, plane3, plane4;

assign plane1[15:0] = {rom_words[3][15:12], rom_words[2][15:12], rom_words[1][15:12], rom_words[0][15:12]};
assign plane2[15:0] = {rom_words[3][11:8], rom_words[2][11:8], rom_words[1][11:8], rom_words[0][11:8]};
assign plane3[15:0] = {rom_words[3][7:4], rom_words[2][7:4], rom_words[1][7:4], rom_words[0][7:4]};
assign plane4[15:0] = {rom_words[3][3:0], rom_words[2][3:0], rom_words[1][3:0], rom_words[0][3:0]};

assign rom_index[11:0] = ram_out[11:0];
assign color[3:0] = ram_out[15:12];

always @(posedge clk, posedge rst) begin
    if (rst) begin
      tile_count <= 0;
      rom_words[0] <= 16'b0;
      rom_words[1] <= 16'b0;
      rom_words[2] <= 16'b0;
      rom_words[3] <= 16'b0;
      rom_words_index <= 2'b0;
      tile_count <= 10'b0; // number of tile processed 
      pix_index <= 4'b0;
      previous_line_number <= 8'b0;
      line_buffer_index <= 8'b0;
      state <= STATE_START;
      end
    else begin
    case (state)
      STATE_START : begin 
         tile_count <= 0;
         rom_words[0] <= 16'b0;
         rom_words[1] <= 16'b0;
         rom_words[2] <= 16'b0;
         rom_words[3] <= 16'b0;
         rom_words_index <= 2'b0;
         pix_index <= 4'b0;

         scroll_x_latch <= scroll_x;
         scroll_y_latch <= scroll_y;
 
         previous_line_number <= line_number;
         ram_addr[10:1] <=  (({2'b0, line_number}+{1'b0,scroll_y})/10'd16)*10'd32 + ((({1'b0, scroll_x[8:0]} / 10'd16) + tile_count) %10'd32);
         rom_words_index <= 0;
         line_buffer_index <= 0;
         state <= STATE_WAIT_START_DECODING;
      end      

      STATE_WAIT_START_DECODING: begin
           state <= STATE_FETCH_ROM_WORDS;
      end  

      STATE_FETCH_ROM_WORDS : begin
        //we need to get the first word (even)
        //then the odd word that follow
        //then an even word at +16 words 
        //then an odd words at +16 words
        if (rom_words_index <= 1)
          gfx_rom_addr[18:1] <= rom_index[11:0]*18'd64 + ((({10'b0,line_number}+{9'b0,scroll_y_latch})%18'd16)*18'd2) + ({16'b0, rom_words_index});
        else
          gfx_rom_addr[18:1] <= rom_index[11:0]*12'd64 + ((({10'b0, line_number}+{9'b0,scroll_y_latch})%18'd16)*18'd2) + ({16'b0, rom_words_index}%18'd2) + 18'd32;
        gfx_rom_cs <= 1'b1; 
        state <=  STATE_COPY_ROM_WORDS;
      end 

      STATE_COPY_ROM_WORDS : begin 
        if (gfx_rom_ok)  begin
           rom_words[rom_words_index] <= gfx_rom_data[15:0];
           gfx_rom_cs <= 1'b0;
           if (rom_words_index < 3) begin
             state <= STATE_FETCH_ROM_WORDS;
             rom_words_index <= rom_words_index + 2'd1; 
             end
           else begin
             rom_words_index <= 2'd0;
             tile_count <= tile_count + 10'b1;
             if ((line_buffer_index + scroll_x_latch) % 9'd16 != 9'b0) begin
               pix_index <= scroll_x_latch[3:0];   
               end
             else
               pix_index <= 0; 
               state <= STATE_WAIT_COPY_PIXEL; 
             end
           end
      end

      STATE_WAIT_COPY_PIXEL: begin
        state <= STATE_COPY_PIXEL;
      end

      STATE_COPY_PIXEL : begin
        if ({plane1[pix_index],plane2[pix_index],plane3[pix_index],plane4[pix_index]}  != 'hf) begin
          line_buffer[line_buffer_index] <= {color[3:0],{plane1[pix_index],plane2[pix_index],plane3[pix_index],plane4[pix_index]}};
          end
        else
          line_buffer[line_buffer_index] <= 'hf;
        line_buffer_index <= line_buffer_index + 8'b1;
       
        if ((line_buffer_index + 8'b1) >= 256)
          state <= STATE_FINISHED;
        else if (pix_index <= 14) begin
          pix_index <= pix_index + 4'd1;
          state <= STATE_WAIT_COPY_PIXEL;
          end              
        else begin
          ram_addr <=  (({2'b0,line_number}+{1'b0,scroll_y_latch})/10'd16)*10'd32  + ( (({1'b0,scroll_x_latch[8:0]} / 10'd16) + tile_count) %10'd32);
          rom_words_index <= 0;
          state <= STATE_WAIT_START_DECODING;
          end
      end
     
      STATE_FINISHED: begin
        if (previous_line_number != line_number)
          state <= STATE_START;
        tile_count <= 10'd0;
        previous_line_number <= line_number;
      end
     
      default :
        state <= STATE_FINISHED;

    endcase
  end
end

endmodule
