`timescale 1ns / 1ps
//`default_nettype none
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09.06.2023 12:02:04
// Design Name: 
// Module Name: audio_inserter
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module audio_packet_inserter (
  input wire clk,
  input wire channel_ready,
  input wire source_ready,
  input wire [15:0] audio_l,
  input wire [15:0] audio_r,
  input wire [71:0] in_data,
  output reg [71:0] out_data
  );

  localparam [8:0] SS     = 9'b101011100;  // K28.2
  localparam [8:0] SE     = 9'b111111101;  // K29.7
  localparam [8:0] BEGINAUDIO = 9'h155;

  // Cabecera time stamp packet: 55,01,17,44
  localparam [8:0] HB0_ATS     = 9'h051;  //
  localparam [8:0] PB0_ATS     = 9'h077;  //
  localparam [8:0] HB1_ATS     = 9'h005;  // Cabecera y datos ECC después de pasar por el
  localparam [8:0] PB1_ATS     = 9'h067;  // modulo de interleaving.
  localparam [8:0] HB2_ATS     = 9'h074;  // Fig. 2.40 pag. 105. DP std. 1.2
  localparam [8:0] PB2_ATS     = 9'h053;  //
  localparam [8:0] HB3_ATS     = 9'h041;  //
  localparam [8:0] PB3_ATS     = 9'h033;  //

  // Cabecera audio stream: 55,02,00,01
  localparam [8:0] HB0_AUD     = 9'h055;  //
  localparam [8:0] PB0_AUD     = 9'h07E;  //
  localparam [8:0] HB1_AUD     = 9'h005;  // Cabecera y datos ECC después de pasar por el
  localparam [8:0] PB1_AUD     = 9'h0C7;  // modulo de interleaving.
  localparam [8:0] HB2_AUD     = 9'h001;  // Fig. 2.40 pag. 105. DP std. 1.2
  localparam [8:0] PB2_AUD     = 9'h007;  //
  localparam [8:0] HB3_AUD     = 9'h000;  //
  localparam [8:0] PB3_AUD     = 9'h060;  //

  reg [15:0] sample1_l, sample1_r;
  reg [15:0] sample2_l, sample2_r;
  reg [7:0] pb4_aud, pb5_aud, pb6_aud, pb7_aud;
  reg [11:0] cont_pares_simbolos = 12'h000;

  reg [31:0] s0_ch1, s0_ch2, s1_ch1, s1_ch2;
  reg [8:0] s0_ch1_b0, s0_ch1_b1, s0_ch1_b2, s0_ch1_b3;
  reg [8:0] s0_ch2_b0, s0_ch2_b1, s0_ch2_b2, s0_ch2_b3;
  reg [8:0] s1_ch1_b0, s1_ch1_b1, s1_ch1_b2, s1_ch1_b3;
  reg [8:0] s1_ch2_b0, s1_ch2_b1, s1_ch2_b2, s1_ch2_b3;

  always @(posedge clk) begin
    cont_pares_simbolos <= cont_pares_simbolos + 1;

    if (cont_pares_simbolos == 0) begin
      sample1_l <= audio_l;
      sample1_r <= audio_r;
    end
    if (cont_pares_simbolos == 120*16) begin  // y otro en bloque 120. Eso son 67.5 kHz de fs.
      sample2_l <= audio_l;
      sample2_r <= audio_r;
    end
    
    out_data <= in_data;
    if (in_data[8:0] == BEGINAUDIO) begin
      cont_pares_simbolos <= 1; // comienzo del bloque 130, donde insertaremos la info de audio
      out_data[8:0] <= SS;       out_data[17:9] <= HB0_AUD;
    end
    else begin
      case (cont_pares_simbolos)
        1: begin out_data[8:0] <= PB0_AUD;       out_data[17:9] <= HB1_AUD; end
        2: begin out_data[8:0] <= PB1_AUD;       out_data[17:9] <= HB2_AUD; end
        3: begin out_data[8:0] <= PB2_AUD;       out_data[17:9] <= HB3_AUD; end
        4: begin out_data[8:0] <= PB3_AUD;       out_data[17:9] <= s0_ch1_b0; end
        5: begin out_data[8:0] <= s0_ch1_b1; out_data[17:9] <= s0_ch1_b2; end
        6: begin out_data[8:0] <= s0_ch1_b3; out_data[17:9] <= {1'b0, pb4_aud}; end
        7: begin out_data[8:0] <= s0_ch2_b0; out_data[17:9] <= s0_ch2_b1; end
        8: begin out_data[8:0] <= s0_ch2_b2; out_data[17:9] <= s0_ch2_b3; end
        9: begin out_data[8:0] <= {1'b0, pb5_aud};   out_data[17:9] <= s1_ch1_b0; end
       10: begin out_data[8:0] <= s1_ch1_b1; out_data[17:9] <= s1_ch1_b2; end
       11: begin out_data[8:0] <= s1_ch1_b3; out_data[17:9] <= {1'b0, pb6_aud}; end
       12: begin out_data[8:0] <= s1_ch2_b0; out_data[17:9] <= s1_ch2_b1; end
       13: begin out_data[8:0] <= s1_ch2_b2; out_data[17:9] <= s1_ch2_b3; end
       14: begin out_data[8:0] <= {1'b0, pb7_aud};   out_data[17:9] <= SE; end
       
       15: begin out_data[8:0] <= SS;            out_data[17:9] <= HB0_ATP; end
       16: begin out_data[8:0] <= PB1_ATP;       out_data[17:9] <= HB2_ATP; end
       17: begin out_data[8:0] <= PB2_ATP;       out_data[17:9] <= HB3_ATP; end
       18: begin out_data[8:0] <= PB3_ATP;       out_data[17:9] <= {1'b0, MAUD[23:16]}; end
       19: begin out_data[8:0] <= {1'b0, MAUD[15:8]}; out_data[17:9] <= {1'b0, MAUD[7:0]}; end
       20: begin out_data[8:0] <= 9'h000;        out_data[17:9] <= PB4_ATP; end 
       
       default: begin out_data[8:0] <= in_data[8:0];  out_data[17:9] <= in_data[17:9]; end
      endcase 
    end  
  end
endmodule

//`default_nettype wire
