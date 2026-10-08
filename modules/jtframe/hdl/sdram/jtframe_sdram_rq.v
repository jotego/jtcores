/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 28-2-2019 */

// Three types of slots:
// 0 = read only    ( default )
// 1 = write only
// 2 = R/W

module jtframe_sdram_rq #(parameter AW=18, DW=8, TYPE=0)(
    input               rst,
    input               clk,
    input               clr,
    input [AW-1:0]      addr,
    input [  21:0]      offset,     // It is not supposed to change during game play
    input               addr_ok,    // signals that value in addr is valid
    input [31:0]        din,        // data read from SDRAM
    input               din_ok,
    input               wrin,
    input               we,
    output              req,
    output              req_rnw,
    output              data_ok,    // strobe that signals that data is ready
    output     [21:0]   sdram_addr,
    input    [DW-1:0]   wrdata,
    output   [DW-1:0]   dout        // sends SDRAM data back to requester
);


generate

////////////////////////////////////////////////////////////
/////// read/write type
/////// simple pass through
/////// It requires addr_ok signal to toggle for each request
////////////////////////////////////////////////////////////
if( TYPE==2 ) begin : rw_type
    jtframe_ram_rq #(.AW(AW), .DW(DW) ) u_rw(
        .rst        ( rst           ),
        .clk        ( clk           ),
        .addr       ( addr          ),
        .offset     ( offset        ),     // It is not supposed to change during game play
        .addr_ok    ( addr_ok       ),    // signals that value in addr is valid
        .din        ( din           ),        // data read from SDRAM
        .din_ok     ( din_ok        ),
        .wrin       ( wrin          ),
        .we         ( we            ),
        .req        ( req           ),
        .req_rnw    ( req_rnw       ),
        .data_ok    ( data_ok       ),    // strobe that signals that data is ready
        .sdram_addr ( sdram_addr    ),
        .wrdata     ( wrdata        ),
        .dout       ( dout          )        // sends SDRAM data back to requester
    );
end

////////////////////////////////////////////////////////////
/////// read only type
////////////////////////////////////////////////////////////
if( TYPE==0) begin : ro_type

    assign req_rnw = 1'b1;

    jtframe_romrq #(.AW(AW),.DW(DW) )u_ro(
        .rst        ( rst       ),
        .clk        ( clk       ),
        .clr        ( clr       ),
        .offset     ( offset    ),
        .addr       ( addr      ),
        .addr_ok    ( addr_ok   ),    // signals that value in addr is valid
        .din        ( din       ),
        .din_ok     ( din_ok    ),
        .we         ( we        ),
        .req        ( req       ),
        .data_ok    ( data_ok   ),    // strobe that signals that data is ready
        .sdram_addr ( sdram_addr),
        .dout       ( dout      )
    );
end

endgenerate

endmodule
