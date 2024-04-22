////////// SCAN SPRITE RAM  /////////////////////////////
//
// draw 16x16 sprite line by line
// 
//
module scan_sprite_ram(
  input                 clk,
  input                 rst,

  input           [7:0] line_number,
  
  output reg     [10:1] ram_addr,
  input          [15:0] ram_out,

  input          [15:0] gfx_rom_data,
  input                 gfx_rom_ok,
  output reg     [19:1] gfx_rom_addr,
  output reg            gfx_rom_cs,

  input           [7:0] line_buffer_addr,
  output          [7:0] line_buffer_out,
 
  output                used_out
);

(* ramstyle = "no_rw_check" *)reg  [255:0] used = 256'b0;
assign used_out = used[line_buffer_addr];

(* ramstyle = "no_rw_check" *)reg [7:0] line_buffer [255:0];
assign line_buffer_out = line_buffer[line_buffer_addr];

/// STATE MACHINE
reg [3:0]  state = 0;
parameter STATE_START = 4'd0;
parameter STATE_FETCH_RAM_WORDS = 4'd1;
parameter STATE_COPY_RAM_WORDS = 4'd2;
parameter STATE_START_DECODING = 4'd3;
parameter STATE_DECODING_CHECK = 4;
parameter STATE_FETCH_ROM_WORDS = 4'd5;
parameter STATE_COPY_ROM_WORDS = 4'd6;
parameter STATE_COPY_PIXEL = 4'd7;
parameter STATE_FINISHED = 4'd8;

reg  [7:0]  previous_line_number;

reg         flip_x;
reg  [3:0]  color;
reg  [8:0]  x;
reg  [8:0]  y;

reg [12:0] rom_index; //0xFFF / 4096 tiles 

reg  [3:0] pix_index;
reg [15:0] ram_words [3:0];
reg  [1:0] ram_words_index;
reg [15:0] rom_words [3:0];
reg  [1:0] rom_words_index;

wire [15:0] plane1, plane2, plane3, plane4;

assign plane1[15:0] = {rom_words[3][15:12], rom_words[2][15:12], rom_words[1][15:12],  rom_words[0][15:12]};
assign plane2[15:0] = { rom_words[3][11:8],  rom_words[2][11:8],  rom_words[1][11:8],   rom_words[0][11:8]};
assign plane3[15:0] = {  rom_words[3][7:4],   rom_words[2][7:4],   rom_words[1][7:4],    rom_words[0][7:4]};
assign plane4[15:0] = {  rom_words[3][3:0],   rom_words[2][3:0],   rom_words[1][3:0],    rom_words[0][3:0]};

wire [8:0]  line_buffer_index;
assign line_buffer_index[8:0] = flip_x ?  x[8:0] + 8'd15 - {5'b0, pix_index} : 
                                          x[8:0] + {5'b0, pix_index};

wire [3:0]  plane_color;
assign plane_color[3:0] = {plane1[pix_index], plane2[pix_index], plane3[pix_index], plane4[pix_index]};

always @(posedge clk, posedge rst) begin
    if (rst) begin
      previous_line_number <= 8'd0;
      used  <= 256'b0;
      flip_x <= 1'd0;
      pix_index <= 4'd0;
      rom_index <= 13'd0;
      rom_words_index <= 2'd0;
      ram_words_index <= 2'b0;
      ram_addr <= 10'h0;
      state <= STATE_START;
      end
    else begin
    case (state)
      STATE_START : begin
        previous_line_number <= line_number;
        used[255:0] <= 256'b0;
        pix_index <= 4'd0;
        rom_index <= 13'd0;
        rom_words_index <= 2'd0;
        ram_words_index <= 2'b0;
        ram_addr <= 10'h0;
        state <= STATE_FETCH_RAM_WORDS;
      end      

      STATE_FETCH_RAM_WORDS : begin
         ram_words[ram_words_index] <= ram_out[15:0];
         ram_addr <= ram_addr + 10'd1;
         state <= STATE_COPY_RAM_WORDS;
      end

      STATE_COPY_RAM_WORDS: begin
        if (ram_addr == 'h3ff) begin
           state <= STATE_FINISHED;
           end
        else begin
          if (ram_words_index == 2'd3) begin
           state <= STATE_START_DECODING;
           ram_words_index <= 2'd0;
           end
          else begin
           ram_words_index <= ram_words_index + 2'd1; 
           state <= STATE_FETCH_RAM_WORDS;
          end
        end
      end

      STATE_START_DECODING : begin
         if ((ram_words[2] != 'hf000) && (ram_words[0] != 'hffff) && ({ram_words[2][15], ram_words[1][11:0]} != 13'b0)) begin
           flip_x <= ram_words[0][8];
           color <= ram_words[1][15:12];
           rom_index[12:0] <= {ram_words[2][15], ram_words[1][11:0]};
           x[8:0] <= ram_words[2][8:0] + (ram_words[0][7:4] * 8'd16); 
           y[8:0] <= ram_words[3][8:0] + (ram_words[0][3:0] * 8'd16);
           rom_words_index <= 2'd0;
           state <= STATE_DECODING_CHECK;
           end
         else
           state <= STATE_FETCH_RAM_WORDS;
      end

      STATE_DECODING_CHECK: begin
         if (({1'b0, line_number} >= y && {1'b0, line_number} <= y + 15) && (x < 256 || x[8:0] > 9'd497)) 
           state <= STATE_FETCH_ROM_WORDS;
         else 
           state <= STATE_FETCH_RAM_WORDS;
      end

      STATE_FETCH_ROM_WORDS : begin
        if (rom_words_index <= 1)
          gfx_rom_addr[19:1] <= rom_index[12:0]*19'd64 + (({11'b0, line_number} - {10'b0, y})*19'd2) + ({17'b0, rom_words_index});
        else
          gfx_rom_addr[19:1] <= rom_index[12:0]*19'd64 + (({11'b0, line_number} - {10'b0, y})*19'd2) + ({17'b0, rom_words_index}%19'd2) + 19'd32;
        gfx_rom_cs <= 1'b1; 
        state <=  STATE_COPY_ROM_WORDS;
      end 

      STATE_COPY_ROM_WORDS : begin 
        if (gfx_rom_ok)  begin
          rom_words[rom_words_index] <= gfx_rom_data[15:0];
          gfx_rom_cs <= 1'b0;
          if (rom_words_index < 3) begin
            rom_words_index <= rom_words_index + 2'd1; 
            state <= STATE_FETCH_ROM_WORDS;
            end
          else begin
            rom_words_index <= 0;
            pix_index <= 0;
            state <= STATE_COPY_PIXEL;
            end
        end
      end

      STATE_COPY_PIXEL: begin
        if ((line_buffer_index < 9'd256) && (plane_color != 15) && (used[line_buffer_index[7:0]] == 1'b0)) begin   
          line_buffer[line_buffer_index[7:0]] <= {color[3:0], plane_color};
          used[line_buffer_index[7:0]] <= 1'b1;
          end

        if (pix_index < 15) begin
          pix_index <= pix_index + 4'd1;
          state <= STATE_COPY_PIXEL; 
          end              
        else if (ram_addr == 'h3ff) 
          state <= STATE_FINISHED; 
        else
          state <= STATE_FETCH_RAM_WORDS;
      end

      STATE_FINISHED: begin
        ram_addr <= 10'h0;
        if (previous_line_number != line_number)
          state <= STATE_START;
        previous_line_number <= line_number;
      end
      
    endcase
  end
end

endmodule
