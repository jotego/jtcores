`timescale 1ns / 1ps
//`default_nettype none

//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 13.06.2023 00:43:59
// Design Name: 
// Module Name: sensor
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

// UG480

// The temperature sensor has a transfer function given by Equation 1-2 .
// temp = (ADC x 503.975)/4096 - 273.15
// For example, ADC Code 2423 ( 977h ) = 25°C.
// The temperature sensor result can be found in status register 00h . 

// When the DEN is logic High, the DRP address (DADDR) and write enable (DWE) 
// inputs are captured on the next rising edge of DCLK. 
// DEN should only go high for one DCLK period.
// If DWE is logic Low, a DRP read operation is carried out. 
// The data for this read operation is valid on the DO bus when DRDY goes high. 
// Thus DRDY should be used to capture the DO bus. For a write operation, 
// the DWE signal is logic High and the DI bus and DRP address (DADDR) 
// is captured on the next rising edge of DCLK. The DRDY signal goes logic High 
// when the data has been successfully written to the DRP register. 
// A new read or write operation cannot be initiated until the DRDY signal has gone low. 

module sensor (
  input wire clk,
  input wire rst,
  input wire trigger,
  output reg [11:0] temp_ent_bcd,
  output reg [3:0] temp_dec_bcd,
  output reg testigo
  );

  initial testigo = 1'b0;

  wire rst, busy;  
  wire eoc;
  reg dato_listo;
  wire [15:0] data_from_drp;
  wire rdy_drp;
  reg en_drp = 1'b0, we_drp = 1'b0;
  
  sensor_temperatura el_sensor
  (
    .daddr_in(7'h00),      // Address bus for the dynamic reconfiguration port
    .dclk_in(clk),         // Clock input for the dynamic reconfiguration port
    .den_in(en_drp),       // Enable Signal for the dynamic reconfiguration port
    .di_in(16'h0000),      // Input data bus for the dynamic reconfiguration port
    .dwe_in(we_drp),       // Write Enable for the dynamic reconfiguration port
    .do_out(data_from_drp),// Output data bus for dynamic reconfiguration port
    .drdy_out(rdy_drp),    // Data ready signal for the dynamic reconfiguration port
  
    .reset_in(rst),        // Reset signal for the System Monitor control logic
    .busy_out(busy),       // ADC Busy signal
    .channel_out(),        // Channel Selection Outputs
    .eoc_out(eoc),         // End of Conversion Signal
    .eos_out(),            // End of Sequence Signal
    .alarm_out(),          // OR'ed output of all the Alarms    
    .vp_in(0),             // Dedicated Analog Input Pair
    .vn_in(0)
  );  
  
  reg [11:0] temp_adc = 12'h977;   // valor inicial que equivale a 25 grados, solo para debug
  reg [27:0] temp1;  // temp_adc * 503.975
  reg [15:0] temp2;  // temp_adc * 503.975/4096
  reg [15:0] temp3;  // temp_adc * 503.975/4096 - 273.15
  reg [3:0] sr_formula = 4'b0001;
  
  always @(posedge clk) begin
    sr_formula <= {sr_formula[2:0], dato_listo};
    if (sr_formula != 4'b0000) begin
      temp1 <= temp_adc * 16'd50397;   // 503.975 * 100
      temp2 <= temp1[27:12] + {15'b0, temp1[11]};
      temp3 <= ((temp2 - 16'd27315)>>2) + 16'd200;  // 273.15 * 100 (con correccion para XADC alimentadas a 1.2V)
    end
  end

  localparam
    INIT     = 3'd0,
    WAITTEMP = 3'd1,
    READTEMP = 3'd2,
    WAITREAD = 3'd3,
    ESPERAINIT = 3'd4;
        
  reg [2:0] estado = INIT; 
  reg [4:0] contespera = 5'h00;
   
  always @(posedge clk) begin
    dato_listo <= 1'b0;
    we_drp <= 1'b0;
    en_drp <= 1'b0;
    
    if (rst == 1'b1 || trigger == 1'b1) begin
      estado <= INIT;
      contespera <= 5'h00;
    end
    else begin
      case (estado)
        INIT: 
          begin
            if (contespera != 5'h1F)
              contespera <= contespera + 1;
            else if (busy == 1'b0)
              estado <= WAITTEMP;
          end
        WAITTEMP:
          begin
            if (eoc == 1'b1)
              estado <= READTEMP;          
          end
        READTEMP:
          begin
            en_drp <= 1'b1;
            estado <= WAITREAD;
          end
        WAITREAD:
          begin
            if (rdy_drp == 1'b1) begin
              temp_adc <= data_from_drp[15:4];
              dato_listo <= 1'b1;
              testigo <= ~testigo;
              estado <= ESPERAINIT;
            end
          end
      endcase
    end
  end  
  
  reg [15:0] sr_doubledabble = 16'h0000;
  reg [35:0] bcd;
  wire [3:0] bcd4 = (bcd[35:32] >= 4'd5)? bcd[35:32]+4'd3 : bcd[35:32];
  wire [3:0] bcd3 = (bcd[31:28] >= 4'd5)? bcd[31:28]+4'd3 : bcd[31:28];
  wire [3:0] bcd2 = (bcd[27:24] >= 4'd5)? bcd[27:24]+4'd3 : bcd[27:24];
  wire [3:0] bcd1 = (bcd[23:20] >= 4'd5)? bcd[23:20]+4'd3 : bcd[23:20];
  wire [3:0] bcd0 = (bcd[19:16] >= 4'd5)? bcd[19:16]+4'd3 : bcd[19:16];
  wire [35:0] next_bcd = {bcd4, bcd3, bcd2, bcd1, bcd0, bcd[15:0]};
  always @(posedge clk) begin
    if (sr_formula[3] == 1'b1) begin
      bcd <= {20'b0000_0000_0000_0000_0000, temp3};
      sr_doubledabble <= 16'b0000_0000_0000_0001;
    end
    if (sr_doubledabble != 16'h0000) begin
      sr_doubledabble <= {sr_doubledabble[14:0], 1'b0};
      bcd <= {next_bcd[34:0], 1'b0};  
    end
    else begin
      temp_ent_bcd <= bcd[35:24];
      temp_dec_bcd <= bcd[23:20];
    end
  end
endmodule

//`default_nettype wire
