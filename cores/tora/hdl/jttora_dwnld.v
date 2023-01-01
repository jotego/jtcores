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
    Date: 30-10-2019 */


module jttora_dwnld(
    input                clk,
    input                downloading,
    input      [21:0]    ioctl_addr,
    input      [ 7:0]    ioctl_dout,
    input                ioctl_wr,
    output reg [21:0]    prog_addr,
    output reg [ 7:0]    prog_data,
    output reg [ 1:0]    prog_mask, // active low
    output reg           prog_we,
    output               prog_rd,
    output     [ 1:0]    prom_we,
    output               jap,
    input                sdram_ack,
    input                data_ok,

    input      [15:0]    sdram_dout,
    output reg           dwnld_busy = 1'b0
);

(*keep*) wire         convert;
wire [21:0]  dwnld_addr, obj_addr;
wire [ 7:0]  dwnld_data, obj_data;
wire [ 1:0]  dwnld_mask, obj_mask;
wire         dwnld_we, obj_we;

reg          last_convert;

always @(posedge clk) begin    
    last_convert <= convert;
    if( downloading ) begin
        prog_addr <= dwnld_addr;
        prog_data <= dwnld_data;
        prog_mask <= dwnld_mask;
        prog_we   <= dwnld_we;
        dwnld_busy<= 1'b1;
    end else if(convert) begin
        prog_addr <= obj_addr;
        prog_data <= obj_data;
        prog_mask <= obj_mask;
        prog_we   <= obj_we;        
    end else begin
        prog_we   <= 1'b0;
        prog_mask <= 2'b11;
        if(last_convert) begin
            `ifdef SIMULATION
            $display("INFO: Rom conversion finished");
            `endif
            dwnld_busy<= 1'b0;
        end
    end
end

jttora_prom_we u_prom_we(
    .clk         (  clk          ),
    .downloading (  downloading  ),
    .ioctl_addr  (  ioctl_addr   ),
    .ioctl_dout  (  ioctl_dout   ),
    .ioctl_wr    (  ioctl_wr     ),
    .prog_addr   (  dwnld_addr   ),
    .prog_data   (  dwnld_data   ),
    .prog_mask   (  dwnld_mask   ),
    .prog_we     (  dwnld_we     ),
    .prom_we     (  prom_we      ),
    .jap         (  jap          ),
    .sdram_ack   (  sdram_ack    )
);

jtgng_obj32 u_obj32(
    .clk         (  clk          ),
    .downloading (  downloading  ),
    .sdram_dout  (  sdram_dout   ),
    .convert     (  convert      ),
    .prog_addr   (  obj_addr     ),
    .prog_data   (  obj_data     ),
    .prog_mask   (  obj_mask     ), // active low
    .prog_we     (  obj_we       ),
    .prog_rd     (  prog_rd      ),
    .sdram_ack   (  sdram_ack    ),
    .data_ok     (  data_ok      )
);

endmodule