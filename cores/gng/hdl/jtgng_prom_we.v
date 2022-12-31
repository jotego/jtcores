/*  This file is part of JTGNG.
    JTGNG program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTGNG program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTGNG.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 8-8-2019 */


module jtgng_prom_we(
    input                clk,
    input                downloading,
    input      [21:0]    ioctl_addr,
    input      [ 7:0]    ioctl_dout,
    input                ioctl_wr,
    output reg [21:0]    prog_addr,
    output reg [ 7:0]    prog_data,
    output reg [ 1:0]    prog_mask, // active low
    output reg           prog_we,
    input                sdram_ack
    // output reg [ 5:0]    prom_we
);
//                     Starts at
// MAIN                   00000h
// CHAR                   14000h
// SOUND                  18000h
// SCROLL X               20000h
// SCROLL Z               28000h
// SCROLL Y               30000h
// SCROLL Y(2)            38000h
// Objects ZY             40000h
// Objects XW             50000h
// ROM length 60000h

localparam 
    CHARADDR = 22'h1_4000,
    SNDADDR  = 22'h1_8000, 

    SCRXADDR = 22'h2_0000,
    SCRZADDR = 22'h2_8000,
    SCRYADDR = 22'h3_0000,
    SCRZADDR2= 22'h3_8000,

    OBJZADDR = 22'h4_0000,
    OBJXADDR = 22'h5_0000,

    ROMEND   = 22'h6_0000;

`ifdef SIMULATION
wire region0_main  = ioctl_addr < SNDADDR;
wire region1_snd   = ioctl_addr < CHARADDR;
wire region2_char  = ioctl_addr < SCRXADDR;
wire region3_scrx  = ioctl_addr < SCRZADDR;
wire region4_scrz  = ioctl_addr < SCRYADDR;
wire region5_scry  = ioctl_addr < SCRZADDR2;
wire region6_scrz2 = ioctl_addr < OBJZADDR;
wire region7_objzy = ioctl_addr < OBJXADDR;
wire region8_objxw = ioctl_addr < ROMEND;
`endif

// offset the SDRAM programming address by 
reg [14:0] scr_offset=15'd0;
reg [15:0] obj_offset=16'd0;

// reg set_strobe, set_done;
// reg [5:0] prom_we0 = 6'd0;
// 
// always @(posedge clk) begin
//     prom_we <= 6'd0;
//     if( set_strobe ) begin
//         prom_we <= prom_we0;
//         set_done <= 1'b1;
//     end else if(set_done) begin
//         set_done <= 1'b0;
//     end
// end

wire inmain = ioctl_addr < CHARADDR;
wire insnd  = ioctl_addr >= SNDADDR && ioctl_addr < SCRXADDR;
wire incpu  = inmain | insnd;

always @(posedge clk) begin
    // if( set_done ) set_strobe <= 1'b0;
    if ( ioctl_wr ) begin
        prog_we   <= 1'b1;
        prog_data <= ioctl_dout;
        if(ioctl_addr < SCRXADDR) begin // Main ROM (regular copy)
            prog_addr <= {1'b0, ioctl_addr[21:1]};
            prog_mask <= {ioctl_addr[0], ~ioctl_addr[0]} ^ {2{incpu}};
            scr_offset <= 15'd0;
        end
        else if(ioctl_addr < SCRXADDR) begin // CHAR ROM (regular copy)
            prog_addr <= {1'b0, ioctl_addr[21:1]};
            prog_mask <= {ioctl_addr[0], ~ioctl_addr[0]};
            scr_offset <= 15'd0;
        end
        else if(ioctl_addr < OBJZADDR ) begin // Scroll    
            prog_mask <= ioctl_addr[15] ? 2'b10 : 2'b01;
            prog_addr <= (SCRXADDR>>1) +
                { 6'd0, ioctl_addr[16], scr_offset }; // original bit order
            scr_offset <= scr_offset+14'd1;
            obj_offset <= 16'd0;
        end
        else if(ioctl_addr < ROMEND ) begin // Objects
            prog_mask  <= ioctl_addr[16] ? 2'b10 : 2'b01;
            prog_addr  <= (OBJZADDR>>1) + 
                { 6'd0, {obj_offset[15:6], obj_offset[4:1], obj_offset[5], obj_offset[0] } };
            obj_offset <= obj_offset+16'd1;
        end
    end
    else if(!downloading || sdram_ack) begin
        prog_we  <= 1'b0;
        // prom_we0 <= 6'd0;
    end
end

endmodule // jtframe_promprog