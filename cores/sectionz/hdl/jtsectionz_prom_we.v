/*  This file is part of JT_GNG.
    JT_GNG program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JT_GNG program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JT_GNG.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 15-4-2020 */

`timescale 1ns/1ps

module jtsectionz_prom_we(
    input                clk,
    input                downloading,
    input      [21:0]    ioctl_addr,
    input      [ 7:0]    ioctl_data,
    input                ioctl_wr,
    output reg [21:0]    prog_addr,
    output reg [ 7:0]    prog_data,
    output reg [ 1:0]    prog_mask, // active low
    output reg           prog_we,
    input                sdram_ack,
    output reg [ 7:0]    game_cfg
);

parameter [21:0] CPU_OFFSET=22'h0;
parameter [21:0] SND_OFFSET=22'h0;
parameter [21:0] CHAR_OFFSET=22'h0;
parameter [21:0] SCR_OFFSET=22'h0;
parameter [21:0] OBJ_OFFSET=22'h0;

localparam START_BYTES  = 8*2;
localparam START_HEADER = 32;
localparam STARTW=8*START_BYTES;
localparam [21:0] FULL_HEADER = START_HEADER;

reg  [STARTW-1:0] starts;
wire       [15:0] snd_start, obj_start, scr_start, char_start;

assign obj_start  = starts[15: 0];
assign scr_start  = starts[31:16];
assign char_start = starts[47:32];
assign snd_start  = starts[63:48];

wire [21:0] bulk_addr  = ioctl_addr - FULL_HEADER; // the header is excluded
wire [21:0] cpu_addr   = bulk_addr ; // the header is excluded
wire [21:0] snd_addr   = bulk_addr - { snd_start,  8'd0 };
wire [21:0] char_addr  = bulk_addr - { char_start, 8'd0 };
wire [21:0] scr_addr   = bulk_addr - { scr_start,  8'd0 };
wire [21:0] obj_addr   = bulk_addr - { obj_start,  8'd0 };

wire is_start = ioctl_addr > 7 && ioctl_addr < (8+START_BYTES);
wire is_cpu   = bulk_addr[21:8] < snd_start;
wire is_snd   = bulk_addr[21:8] < char_start && bulk_addr[21:8]>=snd_start;
wire is_char  = bulk_addr[21:8] < scr_start  && bulk_addr[21:8]>=char_start;
wire is_scr   = bulk_addr[21:8] < obj_start  && bulk_addr[21:8]>=scr_start;
wire is_obj   = bulk_addr[21:8] >=obj_start;

always @(posedge clk) begin
    if ( ioctl_wr && downloading ) begin
        prog_data <= ioctl_data;
        prog_mask <= !ioctl_addr[0] ? 2'b10 : 2'b01;            
        prog_addr <= is_cpu  ? bulk_addr[22:1] + CPU_OFFSET  : (
                     is_snd  ?  snd_addr[22:1] + SND_OFFSET  : (
                     is_char ? char_addr[22:1] + CHAR_OFFSET : (
                     is_scr  ?  scr_addr[22:1] + SCR_OFFSET  : obj_addr[22:1] + OBJ_OFFSET )));
        if( ioctl_addr < START_BYTES ) begin
            if( ioctl_addr[3:0]==4'd0 ) game_cfg <= ioctl_data;
            if( is_start ) starts  <= { starts[STARTW-9:0], ioctl_data };
            prog_we <= 1'b0;
        end else begin
            prog_we   <= 1'b1;
        end
    end
    else begin
        if(!downloading || sdram_ack) prog_we  <= 1'b0;
    end
end

endmodule