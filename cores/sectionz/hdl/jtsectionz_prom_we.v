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


module jtsectionz_prom_we(
    input                clk,
    input                downloading,
    input      [21:0]    ioctl_addr,
    input      [ 7:0]    ioctl_dout,
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

localparam START_BYTES  = 8;
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
//wire [21:0] scr_addr   = bulk_addr - { scr_start,  8'd0 };
wire [21:0] obj_addr   = bulk_addr - { obj_start,  8'd0 };

wire is_start = ioctl_addr > 7 && ioctl_addr < (8+START_BYTES);
wire is_cpu   = bulk_addr[21:8] < snd_start;
wire is_snd   = bulk_addr[21:8] < char_start && bulk_addr[21:8]>=snd_start;
wire is_char  = bulk_addr[21:8] < scr_start  && bulk_addr[21:8]>=char_start;
wire is_scr   = bulk_addr[21:8] < obj_start  && bulk_addr[21:8]>=scr_start;
wire is_obj   = bulk_addr[21:8] >=obj_start;

reg [7:0] scr_buf;
reg [3:0] scr_rewr;
reg [31:0] prev_data;

`ifdef SIMULATION
initial begin
    scr_rewr = 4'b0;
end
`endif

reg [21:0] scr_addr;

always @(posedge clk) begin
    if ( ioctl_wr && downloading ) begin
        prev_data <= { ioctl_dout, prev_data[31:8] };
        if( is_scr ) begin
            if( ioctl_addr[1:0]==2'b11 ) begin
                scr_rewr <= 4'b1;
            end
        end else begin
            prog_data <= ioctl_dout;
            prog_addr <= is_cpu  ? bulk_addr[21:1] + CPU_OFFSET  : (
                         is_snd  ?  snd_addr[21:1] + SND_OFFSET  : (
                         is_char ? char_addr[21:1] + CHAR_OFFSET : (
                         { obj_addr[21:7],obj_addr[5:2],obj_addr[6], obj_addr[1] } + OBJ_OFFSET )));
            scr_rewr  <= 1'b0;
            prog_mask <= ioctl_addr[0]^(is_cpu|is_snd) ? 2'b10 : 2'b01;
        end
        if( ioctl_addr < FULL_HEADER ) begin
            if( !ioctl_addr ) game_cfg <= ioctl_dout;
            if( is_start ) starts  <= { starts[STARTW-9:0], ioctl_dout };
            prog_we <= 1'b0;
        end else if(!is_scr) begin
            prog_we <= 1'b1;
        end
    end
    else begin
        if(!downloading || sdram_ack) prog_we  <= 1'b0;
        else if( !prog_we ) begin
            if( !is_scr )
                scr_addr <= SCR_OFFSET;
            else if( scr_rewr ) begin
                prog_we       <= 1'b1;
                scr_rewr      <= scr_rewr<<1;
                prog_addr     <= scr_addr;
                if( scr_rewr[1] || scr_rewr[3] ) scr_addr <= scr_addr+1;
                casez( scr_rewr )
                    4'b0001: prog_data <= { prev_data[15:12], prev_data[ 7: 4] };
                    4'b0010: prog_data <= { prev_data[31:28], prev_data[23:20] };
                    4'b0100: prog_data <= { prev_data[11: 8], prev_data[ 3: 0] };
                    4'b1000: prog_data <= { prev_data[27:24], prev_data[19:16] };
                endcase
                prog_mask <= scr_rewr[0] || scr_rewr[2] ?  2'b10 : 2'b01;
            end
        end
    end
end

endmodule