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
    Date: 23-9-2023 */

module jtframe_ramslot_ctrl #(parameter
    SDRAMW   = 22,
    SW       = 3,         // total number of slots (including writable ones)
    WRSW     = 1,         // number of writable slots. Up to 2
    DW0      = 16,
    DW1      = 0
)(
    input               rst,
    input               clk,
    input [SW-1:0]      req,
    input [SW*SDRAMW-1:0] slot_addr_req,
    input [(WRSW==0? 0:WRSW-1):0]    req_rnw,        // only for slot0
    input [DW1+DW0-1:0] slot_din,
    input [(WRSW==0? 1 : WRSW*2-1):0]  wrmask,   // only used if DW!=8
    input               erase_bsy,
    output reg [SW-1:0] slot_sel,
    // SDRAM controller interface
    input               sdram_ack,
    output  reg         sdram_rd,
    output  reg         sdram_wr,
    output  reg [SDRAMW-1:0] sdram_addr,
    input               data_rdy,
    output  reg [15:0]  data_write,  // only 16-bit writes
    output  reg [ 1:0]  sdram_wrmask // each bit is active low
);

localparam XW = WRSW<=1 ? DW0 : DW1; // helper to prevent linter warnings
                                     // if WRSW=2, it is used for DW1,
                                     // else, it isn't really used but won't produce warnings

wire [SW-1:0] active = ~slot_sel & req;
reg  [SW-1:0] acthot; // priority encoding of active, only one bit is set

wire [DW0*2-1:0] s0_din2 = {2{slot_din[0+:DW0]}};
wire [ XW*2-1:0] s1_din2 = {2{slot_din[(WRSW==2?DW0:0)+:XW]}}; // not used when WRSR==1

integer i,j;

always @* begin
    acthot = 0;
    for( j=0; j<SW && acthot==0; j=j+1 ) begin
        if( active[j] ) acthot[j]=1;
    end
end

always @(posedge clk) begin
    if( rst ) begin
        sdram_addr <= 0;
        sdram_rd   <= 0;
        sdram_wr   <= 0;
        slot_sel   <= 0;
        data_write <= 0;
    end else begin
        if( sdram_ack ) begin
            sdram_rd   <= 0;
            sdram_wr   <= 0;
        end

        // accept a new request
        if( slot_sel==0 || data_rdy ) begin
            slot_sel     <= 0;
            sdram_wrmask <= 2'b11;

            for( i=0; i<SW; i=i+1 ) begin
                if( acthot[i] ) begin
                    if( i==0 )            data_write <= erase_bsy ? 16'd0 : s0_din2[15:0];
                    if( i==1 && WRSW==2 ) data_write <= erase_bsy ? 16'd0 : s1_din2[15:0];
                    sdram_addr  <= slot_addr_req[i*SDRAMW +: SDRAMW];
                    if( i<WRSW ) begin // RAM slots
                        if( DW0==8 ) begin
                            sdram_addr  <= slot_addr_req[i*SDRAMW +: SDRAMW]>>1;
                            sdram_wrmask<= { ~slot_addr_req[i*SDRAMW], slot_addr_req[i*SDRAMW] };
                        end else begin
                            sdram_addr  <= slot_addr_req[i*SDRAMW +: SDRAMW];
                            /* verilator lint_off WIDTH */
                            sdram_wrmask<= wrmask>>(2*i); // ignore the warning in Quartus
                            /* verilator lint_on WIDTH */
                        end
                    end

                    sdram_rd    <= i<WRSW ?  req_rnw[i] : 1'd1;
                    sdram_wr    <= i<WRSW ? ~req_rnw[i] : 1'd0;
                    slot_sel[i] <= 1;
                end
            end
        end
    end
end

endmodule