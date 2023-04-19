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
    Date: 11-1-2019 */

module jtgng_objdma #(parameter
    OBJMAX      =   10'h180,    // Buffer size, obj count is this number divided by 4. 180h -> 60h = 96dec
    DW          =   8,          // Most games are 8-bit wide, Bionic Commando is 12-bit wide
    AW          =   9,          // Bionic Commando is 10
    INVY        =   0
) (
    input               rst,
    input               clk,
    (* direct_enable *) input cen,
    // screen
    input               LVBL,
    // shared bus
    output     [AW-1:0] AB,
    input      [DW-1:0] DB,
    input               OKOUT,
    output  reg         bus_req,  // Request bus
    input               bus_ack,  // bus acknowledge
    output  reg         blen,     // bus line counter enable
    // output data
    input      [AW-1:0] pre_scan,
    output     [DW-1:0] dma_dout
);

reg [1:0] bus_state;

localparam ST_IDLE=2'd0, ST_WAIT=2'd1,ST_BUSY=2'd2;
localparam MEM_PREBUF=1'd0,MEM_BUF=1'd1;

// Ghosts'n Goblins copies only 'h180 objects as per schematics
// 1943 copy more, but it is not clear what the limit is.
// There is enough time during the vertical blank to copy the whole
// buffer at 6MHz, so the GnG limitation may have been set to
// give more time to the main CPU.
// It takes 170us to copy the whole ('h1FF) buffer

reg             mem_sel;
wire            OKOUT_latch;
reg   [10:0]    full_cnt;

assign AB = full_cnt[AW:1];

jtframe_cencross_strobe u_okout(
    .rst    ( rst         ),
    .clk    ( clk         ),
    .cen    ( cen         ),
    .stin   ( OKOUT       ),
    .stout  ( OKOUT_latch )
);

always @(posedge clk, posedge rst)
    if( rst ) begin
        blen      <= 1'b0;
        bus_state <= ST_IDLE;
        bus_req   <= 1'b0;
    end else if(cen ) begin
        case( bus_state )
            ST_IDLE: if( OKOUT_latch ) begin
                    bus_req   <= 1'b1;
                    bus_state <= ST_WAIT;
                end
                else begin
                    bus_req <= 1'b0;
                    blen    <= 1'b0;
                end
            ST_WAIT: if( bus_ack && !LVBL ) begin
                blen      <= 1'b1;
                bus_state <= ST_BUSY;
            end
            ST_BUSY: if( full_cnt[10:1]==OBJMAX[9:0] ) begin
                bus_req <= 1'b0;
                blen    <= 1'b0;
                bus_state <= ST_IDLE;
            end
            default: bus_state <= ST_IDLE;
        endcase
    end

always @(posedge clk) if(cen) begin
    if( !blen )
        full_cnt <= 0;
    else begin
        full_cnt <= full_cnt + 1'b1;
    end
end

always @(posedge clk, posedge rst)
    if(rst)
        mem_sel <= MEM_PREBUF;
    else if( cen ) begin
        mem_sel <= ~mem_sel;
    end

wire ram_we  = mem_sel==MEM_PREBUF ? blen : 1'b0;

reg  [DW-1:0] wr_data;

always @(posedge clk) begin
    wr_data <= (AB[1:0]==2'b10 && INVY) ?
        { {DW-8{1'b0}}, 8'd240}-DB : DB;
end

// The real PCB did not have a dual port RAM but at this point
// of the signal chain, it does not affect timing accuracy as
// what matters is the DMA period, which is accurate.
`ifndef OBJDMA_SIMFILE
`define OBJDMA_SIMFILE "objdma.bin"
`endif

jtgng_dual_ram #(.AW(AW),.DW(DW),.SIMFILE(`OBJDMA_SIMFILE)) u_objram (
    .clk        ( clk         ),
    .clk_en     ( 1'b1        ),
    .data       ( wr_data     ),
    .rd_addr    ( pre_scan    ),
    .wr_addr    ( AB          ),
    .we         ( ram_we      ),
    .q          ( dma_dout    )
);

endmodule // load