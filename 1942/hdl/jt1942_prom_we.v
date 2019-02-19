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
    Date: 20-1-2019 */

module jt1942_prom_we(
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
    output reg [9:0]     prom_we
);

localparam OBJADDR = 22'h1A000;
wire [21:0] obj_addr = ioctl_addr - OBJADDR;

reg set_strobe, set_done;
reg [9:0] prom_we0;

always @(posedge clk_rgb) begin
    if( set_strobe ) begin
        prom_we <= prom_we0;
        set_done <= 1'b1;
    end else if(set_done) begin
        prom_we <= 10'd0;
        set_done <= 1'b0;
    end
end

always @(posedge clk_rom) begin
    if( set_done ) set_strobe <= 1'b0;
    if ( ioctl_wr ) begin
        prog_we   <= 1'b1;
        prog_data <= ioctl_data;
        if(ioctl_addr < OBJADDR) begin
            prog_addr <= {1'b0, ioctl_addr[21:1]};
            prog_mask <= {ioctl_addr[0], ~ioctl_addr[0]};
        end
        else if(ioctl_addr < (OBJADDR+22'h20_000)) begin
            prog_addr <= OBJADDR[17:1] + {obj_addr[16:15], obj_addr[13:0]};
            prog_mask <= {obj_addr[14], ~obj_addr[14]};
        end
        else begin // PROMs
            prog_addr <= { 4'hF, ioctl_addr[17:0] };
            prog_mask <= 2'b11;
            case(ioctl_addr[11:8])
                4'd0: prom_we0 <= 10'h0_01;    // k6
                4'd1: prom_we0 <= 10'h0_02;    // d1
                4'd2: prom_we0 <= 10'h0_04;    // d2
                4'd3: prom_we0 <= 10'h0_08;    // d6
                4'd4: prom_we0 <= 10'h0_10;    // e8
                4'd5: prom_we0 <= 10'h0_20;    // e9
                4'd6: prom_we0 <= 10'h0_40;    // e10
                4'd7: prom_we0 <= 10'h0_80;    // f1
                4'd8: prom_we0 <= 10'h1_00;    // k3
                4'd9: prom_we0 <= 10'h2_00;    // m11
                default: prom_we0 <= 10'h0;    // 
            endcase 
            set_strobe <= 1'b1;
        end
    end
    else begin
        prog_we <= 1'b0;
    end
end

endmodule // jt1492_promprog