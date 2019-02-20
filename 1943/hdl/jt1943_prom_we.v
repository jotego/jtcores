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
    Date: 20-2-2019 */

module jt1943_prom_we(
    input                clk_rom,
    input                clk_rgb,
    input                downloading, 
    input      [21:0]    ioctl_addr, 
    input      [ 7:0]    ioctl_data,
    input                ioctl_wr,   
    output reg [21:0]    prog_addr,
    output reg [ 7:0]    prog_data,
    output reg [ 1:0]    prog_mask,
    output reg           prog_we,
    output reg [11:0]    prom_we
);

localparam SCR1ADDR = 22'h24_000*2, ROMEND=22'h6C_000*2;
wire [21:0] scr_start = ioctl_addr - SCR1ADDR;

reg set_strobe, set_done;
reg [11:0] prom_we0;

always @(posedge clk_rgb) begin
    if( set_strobe ) begin
        prom_we <= prom_we0;
        set_done <= 1'b1;
    end else if(set_done) begin
        prom_we <= 'd0;
        set_done <= 1'b0;
    end
end

always @(posedge clk_rom) begin
    if( set_done ) set_strobe <= 1'b0;
    if ( ioctl_wr ) begin
        prog_we   <= 1'b1;
        prog_data <= ioctl_data;
        if(ioctl_addr < SCR1ADDR) begin
            prog_addr <= {1'b0, ioctl_addr[21:1]};
            prog_mask <= {ioctl_addr[0], ~ioctl_addr[0]};
        end
        else if(ioctl_addr < ROMEND) begin
            prog_addr <= SCR1ADDR[21:1] + {scr_start[21:15], scr_start[13:0]};
            prog_mask <= {scr_start[14], ~scr_start[14]};
        end
        else begin // PROMs
            prog_addr <= { 3'h7, ioctl_addr[18:0] };
            prog_mask <= 2'b11;
            case(ioctl_addr[11:8])
                4'h0: prom_we0 <= 12'h0_01;    // 
                4'h1: prom_we0 <= 12'h0_02;    // 
                4'h2: prom_we0 <= 12'h0_04;    // 
                4'h3: prom_we0 <= 12'h0_08;    // 
                4'h4: prom_we0 <= 12'h0_10;    // 
                4'h5: prom_we0 <= 12'h0_20;    // 
                4'h6: prom_we0 <= 12'h0_40;    // 
                4'h7: prom_we0 <= 12'h0_80;    // 
                4'h8: prom_we0 <= 12'h1_00;    // 
                4'h9: prom_we0 <= 12'h2_00;    // 
                4'ha: prom_we0 <= 12'h4_00;    // 
                4'hb: prom_we0 <= 12'h8_00;    // 
                default: prom_we0 <= 12'h0;    // 
            endcase 
            set_strobe <= 1'b1;
        end
    end
    else begin
        prog_we <= 1'b0;
    end
end

endmodule // jt1492_promprog