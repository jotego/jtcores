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
    Date: 12-9-2019 */

// Bionic Commando: Main CPU


module jtbiocom_bus(
    input      [16:1]  mcu_addr,
    input      [19:1]  cpu_addr,
    input              mcu_wr,
    input              UDSWn,
    input              LDSWn,
    input              mcu_DMAn,
    input      [ 7:0]  mcu_dout,
    input      [15:0]  cpu_dout,

    output reg [19:1]  bus_addr,
    output reg [15:0]  bus_din,
    output reg         bus_UDSWn,
    output reg         bus_LDSWn
);

always @(*) begin
    if ( !mcu_DMAn ) begin // MCU access
        bus_addr  = {3'b111, mcu_addr };
        bus_din   = { 8'hff, mcu_dout };
        bus_UDSWn = 1'b1;
        bus_LDSWn = ~mcu_wr;
    end else begin // OBJ access
        bus_addr  = cpu_addr;
        bus_din   = cpu_dout;
        bus_UDSWn = UDSWn;
        bus_LDSWn = LDSWn;
    end
end


endmodule
