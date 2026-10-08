/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 10-10-2023 */

module jtframe_romrq_xscache #(parameter
    SDRAMW  = 22,  // SDRAM width
    AW      = 18,
    DW      =  8,
    CACHE_SIZE = 4
)(
    input               rst,
    input               clk,

    input               clr, // clears the cache
    input [SDRAMW-1:0]  offset,

    // <-> SDRAM
    input [15:0]        din,
    input               dst,
    input               we,
    output              req,
    output [SDRAMW-1:0] sdram_addr,

    // <-> Consumer
    input      [AW-1:0] addr,
    input               addr_ok,    // signals that value in addr is valid
    output              data_ok,    // strobe that signals that data is ready
    output     [DW-1:0] dout
);

wire [DW-1:0] din_mux;
wire   [15:0] din_upper;
wire          din_ok;

assign sdram_addr = offset + { {SDRAMW-AW{1'b0}}, addr>>(DW==8)};
assign din_upper  = {8'd0,din[15:8]};

generate
    if(DW==32) begin
        reg [15:0] din_lo;
        reg        drdy;

        assign din_ok = drdy;
        assign din_mux={din,din_lo};

        always @(posedge clk) begin
            if( rst ) begin
                drdy   <= 0;
                din_lo <= 0;
            end else begin
                drdy <= 0;
                if( we & dst ) begin
                    din_lo <= din;
                    drdy   <= 1;
                end
            end
        end
    end else begin // DW==8/16
        assign din_mux[0+:(DW==32?16:DW)] = DW==8 ? (addr[0] ? din_upper[0+:DW] : din[0+:DW]) : din[0+:DW];
        assign din_ok = we & dst;
    end
endgenerate

jtframe_ucache #(.AW(AW),.DW(DW),.SIZE(CACHE_SIZE)) u_cache(
    .rst    ( rst       ),
    .clk    ( clk       ),

    .addr   ( addr      ),
    .clr    ( clr       ),

    // Client
    .cs     ( addr_ok   ),
    .ok     ( data_ok   ),

    // SDRAM
    .sdram_cs( req      ),
    .sdram_ok( din_ok   ),


    .din    ( din_mux   ),
    .dout   ( dout      )
);

endmodule
