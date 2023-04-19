/*  This file is part of JTCORES1.
    JTCORES1 program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTCORES1 program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTCORES1.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 27-1-2021 */


module jtcps2_colmix(
    input              rst,
    input              clk,
    input              pxl_cen,

    input              objcfg_cs,
    input      [15:0]  cpu_dout,
    input      [15:0]  layer_ctrl,
    input      [ 1:0]  dsn,
    input      [ 3:1]  addr,

    input      [11:0]  scr_pxl,
    input      [11:0]  obj_pxl,
    input              obj_en,
    output reg [11:0]  pxl,

    input      [ 7:0]  debug_bus
);

localparam [2:0] OBJ=3'b0, SCR1=3'b1, SCR2=3'd2, SCR3=3'd3, STA=3'd4;
localparam [3:1] OBJ_PRIO = 3'b010;

reg         obj1st, mux_sel;
reg  [ 3:0] scr_prio;
reg  [15:0] lyr_prio;

wire [2:0] obj_prio = obj_pxl[11:9],
           scr_lyr  = scr_pxl[11:9];

//wire [7:0] lyr_order = layer_ctrl[13:6];

function blank;
    input [11:0] a;
    blank = a[3:0]==4'hf;
endfunction

always @(*) begin
    case( scr_lyr )
        1: scr_prio = lyr_prio[ 7: 4];
        2: scr_prio = lyr_prio[11: 8];
        3: scr_prio = lyr_prio[15:12];
        default: scr_prio = 4'd7;
    endcase
    obj1st = obj_prio > scr_prio[2:0];
    mux_sel = obj1st ? blank(obj_pxl) : ~blank(scr_pxl);
end

always @(posedge clk) begin
    if( objcfg_cs && addr[3:1]==OBJ_PRIO) begin
        if( dsn[1] ) lyr_prio[15:8] <= cpu_dout[15:8];
        if( dsn[0] ) lyr_prio[ 7:0] <= cpu_dout[ 7:0];
    end
end

always @(posedge clk) if(pxl_cen) begin
    pxl <= !obj_en ? scr_pxl :
        ( mux_sel ? scr_pxl : {3'd0, obj_pxl[8:0]} );
end

`ifdef PRIO_SIM
    initial begin
        lyr_prio=`PRIO_SIM;
        $display("Layer priority register set to %04X\n",lyr_prio);
    end
`endif

endmodule