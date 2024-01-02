 `timescale 1ns / 1ps
//`default_nettype none

//    This file is part of the ZXUNO Spectrum core. 
//    Creation date is 21:14:58 2019-03-30 by Miguel Angel Rodriguez Jodar
//    (c)2014-2020 ZXUNO association.
//    ZXUNO official repository: http://svn.zxuno.com/svn/zxuno
//    Username: guest   Password: zxuno
//    Github repository for this core: https://github.com/mcleod-ideafix/zxuno_spectrum_core
//
//    ZXUNO Spectrum core is free software: you can redistribute it and/or modify
//    it under the terms of the GNU General Public License as published by
//    the Free Software Foundation, either version 3 of the License, or
//    (at your option) any later version.
//
//    ZXUNO Spectrum core is distributed in the hope that it will be useful,
//    but WITHOUT ANY WARRANTY; without even the implied warranty of
//    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//    GNU General Public License for more details.
//
//    You should have received a copy of the GNU General Public License
//    along with the ZXUNO Spectrum core.  If not, see <https://www.gnu.org/licenses/>.
//
//    Any distributed copy of this file must keep this notice intact.

module debug (
  input wire clk, 
  input wire clken,
  input wire rst_n,
  input wire visible,
  input wire [10:0] hc,
  input wire [10:0] vc,
  input wire [7:0] ri,
  input wire [7:0] gi,
  input wire [7:0] bi,
  output reg [7:0] ro,
  output reg [7:0] go,
  output reg [7:0] bo,
  //////////////////////////
  input wire [7:0] v8_0,
  input wire [7:0] v8_1,
  input wire [7:0] v8_2,
  input wire [7:0] v8_3,
  input wire [7:0] v8_4,
  input wire [7:0] v8_5,
  input wire [7:0] v8_6,
  input wire [7:0] v8_7,
  input wire [7:0] v8_8,
  input wire [7:0] v8_9,
  input wire [7:0] v8_a,
  input wire [7:0] v8_b,
  input wire [7:0] v8_c,
  input wire [7:0] v8_d,
  input wire [7:0] v8_e,
  input wire [7:0] v8_f,
  input wire [7:0] v8_g
  );
  
  parameter [10:0] OFFX = 200;  // 81+(704-47*8)/2;  este valor debe ser multiplo de 8
  parameter [10:0] OFFY = 272;  // parte de abajo de la pantalla
  
  reg [3:0] digito;
  wire [7:0] bitmap;
  reg espacio;
  reg [4:0] nxt_espacio_digito;

  reg [5:0] charpos = 6'd0;
  reg [7:0] sr = 8'h00;
  
  reg [6:0] cont_frames = 7'h00;
  wire [11:0] temp_ent_bcd;
  wire [3:0] temp_dec_bcd;
  
  // Contador de frames. Es solo para generar una señal que
  // ocurra cada poco tiempo, para disparar una nueva medida
  always @(posedge clk) begin
    if (clken)
      if (hc == 11'd0 && vc == 11'd0)
        cont_frames <= cont_frames + 1;
  end
  wire nueva_medida = (cont_frames == 7'h00);
  
  sensor el_termometro (
    .clk(clk),
    .rst(~rst_n),
    .trigger(nueva_medida),
    .temp_ent_bcd(temp_ent_bcd),
    .temp_dec_bcd(temp_dec_bcd),
    .testigo()
  );

  charset_rom hexchars (
    .clk(clk),
    .digito(digito),
    .scan(vc[2:0]),
    .espacio(espacio),
    .bitmap(bitmap)
    );
    
  always @(posedge clk) begin
    if (clken == 1'b1) begin
      if (hc[2:0] == 3'd7)
        sr <= bitmap;
      else
        sr <= {sr[6:0], 1'b0};
        
      if (vc >= OFFY && vc < (OFFY+8) && hc >= OFFX && hc < (OFFX+57*8)) begin
        if (hc[2:0] == 3'd0)
          charpos <= charpos + 1;
      end
      else
        charpos <= 0;
    end
  end

  always @* begin
    case (charpos)
      6'd0  : nxt_espacio_digito = {1'b0, v8_0[7:4]};
      6'd1  : nxt_espacio_digito = {1'b0, v8_0[3:0]};
      6'd2  : nxt_espacio_digito = {1'b1, 4'h0};

      6'd3  : nxt_espacio_digito = {1'b0, v8_1[7:4]};
      6'd4  : nxt_espacio_digito = {1'b0, v8_1[3:0]};
      6'd5  : nxt_espacio_digito = {1'b1, 4'h0};
  
      6'd6  : nxt_espacio_digito = {1'b0, v8_2[7:4]};
      6'd7  : nxt_espacio_digito = {1'b0, v8_2[3:0]};
      6'd8  : nxt_espacio_digito = {1'b1, 4'h0};

      6'd9  : nxt_espacio_digito = {1'b0, v8_3[7:4]};
      6'd10 : nxt_espacio_digito = {1'b0, v8_3[3:0]};
      6'd11 : nxt_espacio_digito = {1'b1, 4'h0};

      6'd12 : nxt_espacio_digito = {1'b0, v8_4[7:4]};
      6'd13 : nxt_espacio_digito = {1'b0, v8_4[3:0]};
      6'd14 : nxt_espacio_digito = {1'b1, 4'h0};

      6'd15 : nxt_espacio_digito = {1'b0, v8_5[7:4]};
      6'd16 : nxt_espacio_digito = {1'b0, v8_5[3:0]};
      6'd17 : nxt_espacio_digito = {1'b1, 4'h0};

      6'd18 : nxt_espacio_digito = {1'b0, v8_6[7:4]};
      6'd19 : nxt_espacio_digito = {1'b0, v8_6[3:0]};
      6'd20 : nxt_espacio_digito = {1'b1, 4'h0};

      6'd21 : nxt_espacio_digito = {1'b0, v8_7[7:4]};
      6'd22 : nxt_espacio_digito = {1'b0, v8_7[3:0]};
      6'd23 : nxt_espacio_digito = {1'b1, 4'h0};

      6'd24 : nxt_espacio_digito = {1'b0, v8_8[7:4]};
      6'd25 : nxt_espacio_digito = {1'b0, v8_8[3:0]};
      6'd26 : nxt_espacio_digito = {1'b1, 4'h0};

      6'd27 : nxt_espacio_digito = {1'b0, v8_9[7:4]};
      6'd28 : nxt_espacio_digito = {1'b0, v8_9[3:0]};
      6'd29 : nxt_espacio_digito = {1'b1, 4'h0};
      
      6'd30 : nxt_espacio_digito = {1'b0, v8_a[7:4]};
      6'd31 : nxt_espacio_digito = {1'b0, v8_a[3:0]};
      6'd32 : nxt_espacio_digito = {1'b1, 4'h0};
  
      6'd33 : nxt_espacio_digito = {1'b0, v8_b[7:4]};
      6'd34 : nxt_espacio_digito = {1'b0, v8_b[3:0]};
      6'd35 : nxt_espacio_digito = {1'b1, 4'h0};
  
      6'd36 : nxt_espacio_digito = {1'b0, v8_c[7:4]};
      6'd37 : nxt_espacio_digito = {1'b0, v8_c[3:0]};
      6'd38 : nxt_espacio_digito = {1'b1, 4'h0};
  
      6'd39 : nxt_espacio_digito = {1'b0, v8_d[7:4]};
      6'd40 : nxt_espacio_digito = {1'b0, v8_d[3:0]};
      6'd41 : nxt_espacio_digito = {1'b1, 4'h0};
  
      6'd42 : nxt_espacio_digito = {1'b0, v8_e[7:4]};
      6'd43 : nxt_espacio_digito = {1'b0, v8_e[3:0]};
      6'd44 : nxt_espacio_digito = {1'b1, 4'h0};
  
      6'd45 : nxt_espacio_digito = {1'b0, v8_f[7:4]};
      6'd46 : nxt_espacio_digito = {1'b0, v8_f[3:0]};
      
      6'd47 : nxt_espacio_digito = {1'b1, 4'h0};
      6'd48 : nxt_espacio_digito = {1'b1, 4'h0};
      6'd49 : nxt_espacio_digito = {1'b1, 4'h0};
      6'd50 : nxt_espacio_digito = {1'b1, 4'h0};
      
      6'd51 : nxt_espacio_digito = {1'b0, temp_ent_bcd[11:8]};
      6'd52 : nxt_espacio_digito = {1'b0, temp_ent_bcd[7:4]};
      6'd53 : nxt_espacio_digito = {1'b0, temp_ent_bcd[3:0]};
      6'd54 : nxt_espacio_digito = {1'b1, 4'h1};  // punto decimal
      6'd55 : nxt_espacio_digito = {1'b0, temp_dec_bcd};
      6'd56 : nxt_espacio_digito = {1'b1, 4'h2};  // simbolo de grados
      
      default: nxt_espacio_digito = {1'b1, 4'h0};            
    endcase

    espacio = nxt_espacio_digito[4];
    digito = nxt_espacio_digito[3:0];        
  end

  wire pixel = sr[7];
  always @* begin
    if (visible == 1'b1 && hc >= OFFX && hc < (OFFX + 57*8) && vc >= OFFY && vc < (OFFY + 8)) begin
      if (pixel == 1'b1)
        if (hc >= OFFX + 47*8)
          {ro,go,bo} = 24'hFFFF00;   // la temperatura en amarillo
        else  
          {ro,go,bo} = 24'hFFFFFF;   // los datos de los registros DP en blanco 
      else
        {ro,go,bo} = 24'h000000;
    end
    else
      {ro,go,bo} = {ri,gi,bi};
  end  
endmodule

module charset_rom (
  input wire clk,
  input wire [3:0] digito,
  input wire [2:0] scan,
  input wire espacio,
  output reg [7:0] bitmap
  );
  
  reg [7:0] charset[0:143];
  initial begin
    $readmemh ("fuente_hexadecimal_ibm.hex", charset);
    
    charset[128] = 8'b00000000;
    charset[129] = 8'b00000000;
    charset[130] = 8'b00000000;
    charset[131] = 8'b00000000;
    charset[132] = 8'b00000000;
    charset[133] = 8'b00000000;
    charset[134] = 8'b00011000;
    charset[135] = 8'b00000000;

    charset[136] = 8'b00011000;
    charset[137] = 8'b00100100;
    charset[138] = 8'b00011000;
    charset[139] = 8'b00000000;
    charset[140] = 8'b00000000;
    charset[141] = 8'b00000000;
    charset[142] = 8'b00000000;
    charset[143] = 8'b00000000;
  end
  
  always @(posedge clk) begin
    if (espacio == 1'b0)
      bitmap <= charset[{1'b0, digito, scan}];
    else if (digito == 4'd1)
      bitmap <= charset[{5'd16, scan}];
    else if (digito == 4'd2)  
      bitmap <= charset[{5'd17, scan}];
    else  
      bitmap <= 8'h00;
  end
endmodule

//`default_nettype wire
