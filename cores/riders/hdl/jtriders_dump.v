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
    Date: 20-8-2024 */

module jtriders_dump(
    input             clk,

    input      [ 7:0] dump_scr, 
    input      [ 7:0] dump_obj, 
    input      [ 7:0] dump_pal,

    input      [ 7:0] pal_mmr,  
    input      [ 7:0] scr_mmr,  
    input      [ 7:0] obj_mmr,

    input      [ 7:0] other,        // stand-alone byte coming from main CPU

    input      [15:0] ioctl_addr,
    output reg [ 7:0] ioctl_din,
    output     [ 3:0] obj_amsb,

    input      [ 7:0] debug_bus,

    input      [ 7:0] st_scr,
    output reg [ 7:0] st_dout
);
parameter FULLRAM = 0;
localparam SCR_END  = FULLRAM==1 ? 16'h6000 : 16'h4000,
           PAL_END  = SCR_END +16'h1000,
           OBJ_END  = PAL_END +16'h2000,
           PMMR_END = OBJ_END +16'h0010,
           SMMR_END = PMMR_END+16'h0008,
           OMMR_END = SMMR_END+16'h0008;

assign obj_amsb = ioctl_addr[15:12] - PAL_END[15:12];

always @(posedge clk) begin
    st_dout <= debug_bus[5] ? (debug_bus[4] ? pal_mmr : obj_mmr) : st_scr;
    // VRAM dumps - 16+4+1 = 21kB +17 bytes = 22544 bytes
    if( ioctl_addr < SCR_END )
        ioctl_din <= dump_scr;  // 16 kB 0000~3FFF
    else if( ioctl_addr < PAL_END  )
        ioctl_din <= dump_pal;  // 4kB 4000~4FFF
    else if( ioctl_addr < OBJ_END  )
        ioctl_din <= dump_obj;  // 8kB 5000~6FFF
    else if( ioctl_addr < PMMR_END )//     7000~700F
        ioctl_din <= pal_mmr;
    else if( ioctl_addr < SMMR_END )
        ioctl_din <= scr_mmr;  // 8 bytes, MMR 7017
    else if( ioctl_addr < OMMR_END )
        ioctl_din <= obj_mmr; // 7 bytes, MMR 701F
    else ioctl_din <= other; // 7020
end

endmodule