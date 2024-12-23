/*  This file is part of JTFRAME.
    JTFRAME program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTFRAME program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTFRAME.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 28-2-2019 */

// The best use case is with addr_ok going down and up for each addr change
// but it works too with addr_ok permanently high as long as addr input is
// not changed until the data_ok signal is produced. If the requester cannot
// guarantee that, it should toggle addr_ok for each request

// LATCH LATENCY Timing Requirements
//    0     1    medium
//    1     2    easy

`timescale 1ns/1ps

module jtframe_romrq #(parameter
    SDRAMW  = 22,  // SDRAM width
    AW      = 18,
    DW      =  8,
    CACHE_SIZE=0,  // Set to !=0 to use jtframe_romrq_xscache, where only served data is cached
                   // Set to ==0 to use jtframe_romrq_bcache, where all data coming from SDRAM is ached

    // parameters only for jtframe_romrq_bcache:
    OKLATCH =  1,  // Set to 1 to latch the data_ok signal. This implies that
                   // data_ok will be high for one clock cycle after the input address
                   // has changed. The requesting module needs to take care of that
                   // If OKLATCH is zero, data_ok is combinational and it will go to
                   // zero as soon as the input address changes. This simplifies the
                   // requesting logic but it is more demanding for timing constraints
    DOUBLE  =  0,
    LATCH   =  0  // dout is latched
)(
    input               rst,
    input               clk,

    input               clr, // clears the cache
    input [SDRAMW-1:0]  offset,

    // <-> SDRAM
    input [15:0]        din,
    input               din_ok,
    input               dst,
    input               we,
    output              req,
    output [SDRAMW-1:0] sdram_addr,

    // <-> Consumer
    input [AW-1:0]      addr,
    input               addr_ok,    // signals that value in addr is valid
    output              data_ok,    // strobe that signals that data is ready
    output     [DW-1:0] dout
);

generate
    if( CACHE_SIZE==0) begin
        jtframe_romrq_bcache #(
            .SDRAMW ( SDRAMW    ),
            .AW     ( AW        ),
            .DW     ( DW        ),
            .OKLATCH( OKLATCH   ),
            .DOUBLE ( DOUBLE    ),
            .LATCH  ( LATCH     )
        ) u_block_cache(
            .rst    ( rst       ),
            .clk    ( clk       ),

            .clr    ( clr       ),
            .offset ( offset    ),

            // <-> SDRAM
            .din        ( din       ),
            .din_ok     ( din_ok    ),
            .dst        ( dst       ),
            .we         ( we        ),
            .req        ( req       ),
            .sdram_addr (sdram_addr ),

            // <-> Consumer
            .addr       ( addr      ),
            .addr_ok    ( addr_ok   ),
            .data_ok    ( data_ok   ),
            .dout       ( dout      )
        );
    end else begin
        jtframe_romrq_xscache #(
            .SDRAMW     ( SDRAMW    ),
            .AW         ( AW        ),
            .DW         ( DW        ),
            .CACHE_SIZE ( CACHE_SIZE)
        ) u_data_cache(
            .rst    ( rst       ),
            .clk    ( clk       ),

            .clr    ( clr       ),
            .offset ( offset    ),

            // <-> SDRAM
            .din        ( din       ),
            .dst        ( dst       ),
            .we         ( we        ),
            .req        ( req       ),
            .sdram_addr (sdram_addr ),

            // <-> Consumer
            .addr       ( addr      ),
            .addr_ok    ( addr_ok   ),
            .data_ok    ( data_ok   ),
            .dout       ( dout      )
        );
    end
endgenerate

endmodule // jtframe_romrq
