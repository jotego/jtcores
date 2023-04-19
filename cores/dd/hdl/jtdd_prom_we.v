/*  This file is part of JTCORES.
    JTCORES program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTCORES program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTCORES.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 2-12-2017 */

// SCR is written starting at 0x4_0000 of SDRAM
// OBJ from 0x8_0000

// Skip test and legal screens
// Replace 7eb825 for 7e8063 in main (non banked) CPU ROM.
// The game will boot directly to the demo


module jtdd_prom_we(
    input                clk,
    input                downloading,
    input      [24:0]    ioctl_addr,
    input      [ 7:0]    ioctl_dout,
    input                ioctl_wr,
    output reg [21:0]    prog_addr,
    output reg [ 7:0]    prog_data,
    output reg [ 1:0]    prog_mask, // active low
    output reg           prog_we,
    output reg           prom_we,
    input                sdram_ack
);

parameter PW=1;

parameter BANK_ADDR   = 22'h00000;
parameter MAIN_ADDR   = 22'h20000;
parameter SND_ADDR    = 22'h28000;
parameter ADPCM_0     = 22'h30000;
parameter ADPCM_1     = 22'h40000;
parameter CHAR_ADDR   = 22'h50000;
// Scroll
parameter SCRZW_ADDR  = 22'h60000;
parameter SCRXY_ADDR  = 22'h80000;
// objects
parameter OBJWZ_ADDR  = 22'hA0000;
parameter OBJXY_ADDR  = 22'hE0000;
// FPGA BRAM:
parameter MCU_ADDR    = 22'h120000;
parameter PROM_ADDR   = 22'h124000;
// ROM length 124300
localparam SCRWR = 5'd6;
localparam OBJWR = 5'd8;

localparam [4:0] OBJHALF = OBJXY_ADDR[20:16]-OBJWZ_ADDR[20:16];

`ifdef SIMULATION
// simulation watchers
reg w_main, w_snd, w_char, w_scr, w_obj, w_mcu, w_prom, w_adpcm;
`define CLR_ALL   {w_main, w_snd, w_char, w_scr, w_obj, w_mcu, w_prom, w_adpcm} <= 8'd0;
`define INFO_MAIN  w_main <= 1'b1;
`define INFO_SND   w_snd  <= 1'b1;
`define INFO_CHAR  w_char <= 1'b1;
`define INFO_ADPCM w_adpcm<= 1'b1;
`define INFO_SCR   w_scr  <= 1'b1;
`define INFO_OBJ   w_obj  <= 1'b1;
`define INFO_MCU   w_mcu  <= 1'b1;
`define INFO_PROM  w_prom <= 1'b1;
`else
// nothing for synthesis
`define CLR_ALL  
`define INFO_MAIN 
`define INFO_SND  
`define INFO_CHAR 
`define INFO_ADPCM 
`define INFO_SCR  
`define INFO_OBJ  
`define INFO_MCU  
`define INFO_PROM 
`endif

reg set_strobe, set_done;
reg [PW-1:0] prom_we0 = {PW{1'd0}};

always @(posedge clk) begin
    prom_we <= {PW{1'd0}};
    if( set_strobe ) begin
        prom_we <= prom_we0;
        set_done <= 1'b1;
    end else if(set_done) begin
        set_done <= 1'b0;
    end
end

wire [3:0] scr_msb  = ioctl_addr[19:16]-SCRZW_ADDR[19:16];
wire [3:0] scr2_msb = ioctl_addr[19:16]-SCRXY_ADDR[19:16];
wire [4:0] obj_msb  = ioctl_addr[20:16]-OBJWZ_ADDR[20:16];
wire [4:0] obj2_msb = ioctl_addr[20:16]-OBJXY_ADDR[20:16];
wire       scr_top  = scr_msb[1];
wire       obj_top  = obj_msb>=OBJHALF;
wire [1:0] mask8    = {~ioctl_addr[0], ioctl_addr[0]};

always @(posedge clk) begin
    if( set_done ) set_strobe <= 1'b0;
    if ( ioctl_wr ) begin
        prog_we   <= 1'b1;
        prog_data <= ioctl_dout;
        `CLR_ALL
        if(ioctl_addr[21:16] < ADPCM_0[21:16]) begin // Main/Sound ROM
            prog_addr <= {1'b0, ioctl_addr[21:1]};
            prog_mask <= mask8;
            `INFO_MAIN
            `INFO_SND
        end
        else if(ioctl_addr[21:16] < CHAR_ADDR[21:16]) begin // ADPCM
            prog_addr <= {1'b0, ioctl_addr[21:1]};
            prog_mask <= mask8;
            `INFO_ADPCM
        end
        else if(ioctl_addr[21:16] < SCRZW_ADDR[21:16]) begin // CHAR ROM
            prog_addr <= {1'b0, ioctl_addr[21:5], ioctl_addr[2:0], ioctl_addr[4]};
            prog_mask <= {~ioctl_addr[3], ioctl_addr[3]};
            `INFO_CHAR
        end
        else if(ioctl_addr[21:16] < OBJWZ_ADDR[21:16] ) begin // Scroll    
            prog_mask <= scr_top ? 2'b01 : 2'b10;
            prog_addr <= { SCRWR+{1'b0,scr_top ? scr2_msb : scr_msb}, 
                ioctl_addr[15:6], ioctl_addr[3:0], ioctl_addr[5:4] };
            `INFO_SCR
        end
        else if(ioctl_addr[21:16] < MCU_ADDR[21:16] ) begin // Objects
            prog_mask <= !obj_top ? 2'b10 : 2'b01;
            prog_addr <= { OBJWR+( obj_top  ? obj2_msb : obj_msb), 
                ioctl_addr[15:6], ioctl_addr[3:0], ioctl_addr[5:4] };
            `INFO_OBJ
        end
        else if(ioctl_addr[21:12] < PROM_ADDR[21:12] ) begin // MCU
            prog_addr <= { 6'hC,3'b0, ioctl_addr[13:1] };
            prog_mask <= mask8;
            `INFO_MCU
        end
        else begin // PROMs
            prog_addr <= ioctl_addr[21:0];
            prog_we   <= 1'b0;
            prog_mask <= 2'b11;
            prom_we0  <= ioctl_addr[10:8] == 3'd0;
            set_strobe<= 1'b1;
            `INFO_PROM
        end
    end
    else begin
        if(sdram_ack || !downloading) prog_we  <= 1'b0;
        prom_we0 <= {PW{1'd0}};
    end
end

endmodule