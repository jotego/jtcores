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
    Date: 11-1-2019 */

module jtgng_objdma(
    input              rst,
    input              clk,
    input              cen6,    //  6 MHz
    // screen
    input              LVBL,
    // shared bus
    output  reg [ 8:0] AB,
    input       [ 7:0] DB,
    input              OKOUT,
    output  reg        bus_req,  // Request bus
    input              bus_ack,  // bus acknowledge
    output  reg        blen,     // bus line counter enable
    // output data
    input       [8:0]  pre_scan,
    output      [7:0]  ram_dout
);

reg [1:0] bus_state;

localparam ST_IDLE=2'd0, ST_WAIT=2'd1,ST_BUSY=2'd2;
localparam MEM_PREBUF=1'd0,MEM_BUF=1'd1;

// Ghosts'n Goblins copy only 'h180 objects as per schematics
// 1943 copy more, but it is not clear what the limit is.
// There is enough time during the vertical blank to copy the whole
// buffer at 6MHz, so the GnG limitation may have been set to
// give more time to the main CPU.
// It takes 170us to copy the whole ('h1FF) buffer

parameter OBJMAX=9'h180;

reg mem_sel;

always @(posedge clk)
    if( rst ) begin
        blen      <= 1'b0;
        bus_state <= ST_IDLE;
    end else if(cen6) begin
        case( bus_state )
            ST_IDLE: if( OKOUT ) begin
                    bus_req   <= 1'b1;
                    bus_state <= ST_WAIT;
                end
                else begin
                    bus_req <= 1'b0;
                    blen    <= 1'b0;
                end
            ST_WAIT: if( bus_ack && mem_sel == MEM_PREBUF && !LVBL ) begin
                blen      <= 1'b1;
                bus_state <= ST_BUSY;
            end
            ST_BUSY: if( AB==OBJMAX ) begin
                bus_req <= 1'b0;
                blen    <= 1'b0;
                bus_state <= ST_IDLE;
            end
            default: bus_state <= ST_IDLE;
        endcase
    end

reg ABslow;
always @(posedge clk) if(cen6) begin
    if( !blen )
        {AB, ABslow} <= 10'd0;
    else begin
        {AB, ABslow} <= {AB, ABslow} + 1'b1;
    end
end

always @(posedge clk)
    if(rst)
        mem_sel <= MEM_PREBUF;
    else if(cen6) begin
        mem_sel <= ~mem_sel;
    end


wire [9:0]  wr_addr = mem_sel==MEM_PREBUF ? {1'b0, AB } : 10'd0;
wire [7:0]  ram_din = mem_sel==MEM_PREBUF ? DB : 8'd0;
wire        ram_we  = mem_sel==MEM_PREBUF ? blen : 1'b0;

jtgng_dual_ram #(.aw(10)) objram (
    .clk        ( clk               ),
    .clk_en     ( cen6              ),
    .data       ( ram_din           ),
    .rd_addr    ( {1'b0, pre_scan } ),
    .wr_addr    ( wr_addr           ),
    .we         ( ram_we            ),
    .q          ( ram_dout          )
);



endmodule // load