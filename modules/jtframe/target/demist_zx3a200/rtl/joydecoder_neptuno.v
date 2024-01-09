`timescale 1ns / 1ps
//`default_nettype none

//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    09:00:25 07/20/2018 
// Design Name: 
// Module Name:    joydecoder 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////

module joydecoder_neptuno (
//-------------------------------------------
  input wire clk_i,//si reloj de entrada en este caso 1.3888Mhz va a patilla 11 integrado
  input wire joy_data_i,//datos serializados patilla viene de la patilla 9 integrado
  output wire joy_clk_o,//este reloj no se usa
  output wire joy_load_o,//este reloj negado se usa directamente en las patillas 12 y 13

//-----------------------------------------
  output wire joy1_up_o,
  output wire joy1_down_o,
  output wire joy1_left_o,
  output wire joy1_right_o,
  output wire joy1_fire1_o,
  output wire joy1_fire2_o,
  output wire joy1_fire3_o,
  output wire joy1_start_o,
  output wire joy2_up_o,
  output wire joy2_down_o,
  output wire joy2_left_o,
  output wire joy2_right_o,
  output wire joy2_fire1_o,
  output wire joy2_fire2_o,
  output wire joy2_fire3_o,
  output wire joy2_start_o
  );
  

     // Divisor de relojes
  reg [7:0] delay_count = 8'd0;
  wire ena_x;
  
  always @ (posedge clk_i) 
  begin
      delay_count <= delay_count + 1'b1;       
  end
    
  //assign ena_x = delay_count[3]; //para clk aprox, 4Mhz
  //assign ena_x = delay_count[4]; //para clk aprox, 8Mhz
  //assign ena_x = delay_count[5]; //para clk aprox, 16Mhz
  
  assign ena_x = delay_count[3];
  
  

   reg [11:0] joy1  = 12'hFFF, joy2  = 12'hFFF;

   reg joy_renew = 1'b1;
   reg [4:0]joy_count = 5'd0;
   
   assign joy_clk_o = ena_x;
   assign joy_load_o = joy_renew;
  
   assign joy1_up_o    = joy1[0];
   assign joy1_down_o  = joy1[1];
   assign joy1_left_o  = joy1[2];
   assign joy1_right_o = joy1[3];
   assign joy1_fire1_o = joy1[4];
   assign joy1_fire2_o = joy1[5];
   assign joy1_fire3_o = joy1[6];
   assign joy1_start_o = joy1[7];
   assign joy2_up_o    = joy2[0];
   assign joy2_down_o  = joy2[1];
   assign joy2_left_o  = joy2[2];
   assign joy2_right_o = joy2[3];
   assign joy2_fire1_o = joy2[4];
   assign joy2_fire2_o = joy2[5];
   assign joy2_fire3_o = joy2[6];
   assign joy2_start_o = joy2[7];
  

  always @(posedge ena_x) 
    begin 
      if (joy_count == 5'd0) 
      begin
         joy_renew <= 1'b0;
        end 
    else 
      begin
         joy_renew <= 1'b1;
        end
      if (joy_count == 5'd18) 
      begin
         joy_count <= 5'd0;
        end
    else 
      begin
         joy_count <= joy_count + 1'd1;
        end      
     end
   always @(posedge ena_x) begin
         case (joy_count)
            5'd2  : joy1[7]  <= joy_data_i;   //  1p start
            5'd3  : joy1[6]  <= joy_data_i;   //  1p fire3
            5'd4  : joy1[5]  <= joy_data_i;   //  1p fire2
            5'd5  : joy1[4]  <= joy_data_i;   //  1p fire1
            5'd6  : joy1[3]  <= joy_data_i;   //  1p right
            5'd7  : joy1[2]  <= joy_data_i;   //  1p left
            5'd8  : joy1[1]  <= joy_data_i;   //  1p down
            5'd9  : joy1[0]  <= joy_data_i;   //  1p up
            5'd10 : joy2[7]  <= joy_data_i;   //  2p start
            5'd11 : joy2[6]  <= joy_data_i;   //  2p fire3
            5'd12 : joy2[5]  <= joy_data_i;   //  2p fire2
            5'd13 : joy2[4]  <= joy_data_i;   //  2p fire1
            5'd14 : joy2[3]  <= joy_data_i;   //  2p right
            5'd15 : joy2[2]  <= joy_data_i;   //  2p left
            5'd16 : joy2[1]  <= joy_data_i;   //  2p down
            5'd17 : joy2[0]  <= joy_data_i;   //  2p up

         endcase              
      end
endmodule
