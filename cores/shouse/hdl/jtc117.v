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
    Date: 19-9-2023 */

// Implementation of Namco's CUS117 - Memory Mapper for two CPUs
// Based on MAME's c117 information and Atari's schematics


module jtc117(
    input               rst,
    input               clk,

    // Master
    input        [15:0] maddr,  // not all bits are used, but easier to connect as a whole
    input        [ 7:0] mdout,
    input               mrnw,
    output reg          mirq,
    output reg          mfirq,
    output reg  [21:12] mahi,   // address high bits
    output reg          mram_cs,

    // Sub
    input        [15:0] saddr,
    input        [ 7:0] sdout,
    input               srnw,
    output reg  [21:12] sahi,
    output reg          sirq,
    output reg          sfirq,
    output reg          sram_cs,
    output              srst_n,

    output reg   [ 9:0] cs,


);
    reg         vb_edge, lvbl_l;
    wire        xirq_n;
    reg  [15:0] samux;
    reg  [ 7:0] sdmux;

    always @* begin
        samux = saddr;
        sdmux = sdout;
        swmux = srnw;
        if( !srst_n && &maddr[15:13] && maddr[12:9]==14 ) begin
            saddr[15:12] = 4'hf;
            saddr[12: 9] = 7;
            sdmux        = mdout;
            swmux        = mrnw;
        end
    end

    always @(posedge clk, posedge rst) begin
        if( rst ) begin
            lvbl_l  <= 0;
            vb_edge <= 0;
        end else begin
            lvbl_l  <= lvbl;
            vb_edge <= !lvbl && lvbl_l;
        end
    end

    jtc117_unit u_main(
        .rst        ( rst       ),
        .clk        ( clk       ),

        .vb_edge    ( vb_edge   ),

        .addr       ( maddr     ),
        .dout       ( mdout     ),
        .rnw        ( mrnw      ),

        .xirq_n     (           ),
        .oirq_n     ( xirq_n    ),

        .rstn_out   ( srst_n    ),
        .irq_n      ( mirq_n    ),
        .firq_n     ( mfirq_n   ),
        .ahi        ( mahi      )
    );

    jtc117_unit u_sub(
        .rst        ( rst       ),
        .clk        ( clk       ),

        .vb_edge    ( vb_edge   ),

        .addr       ( samux     ),
        .dout       ( sdmux     ),
        .rnw        ( swmux     ),

        .xirq_n     ( xirq_n    ),
        .oirq_n     (           ),

        .rstn_out   (           ),
        .irq_n      ( sirq_n    ),
        .firq_n     ( sfirq_n   ),
        .ahi        ( sahi      )
    );

endmodule

//////////////////////////////////////////////////////////////////////
module jtc117_unit(
    input               rst,
    input               clk,

    input               vb_edge,

    input        [15:0] addr,  // not all bits are used, but easier to connect as a whole
    input        [ 7:0] dout,
    input               rnw,

    input               xirq_n,
    output reg          oirq_n,

    output reg          rstn_out,
    output reg          irq_n,
    output reg          firq_n,
    output reg  [21:12] ahi,   // address high bits
    output reg          ram_cs,
);
    reg  [22:13] banks[0:7];
    wire         mmr_cs;

    assign mmr_cs = &addr[15:13];

    always @(posedge clk, posedge rst) begin
        if( rst ) begin
            rstn_out <= 0;
            firq_n   <= 1;
            // not all defaults values have been verified
            banks[0] <= 10'h180; banks[1] <= 10'h180;
            banks[2] <= 10'h180; banks[3] <= 10'h180;
            banks[4] <= 10'h180; banks[5] <= 10'h180;
            banks[6] <= 10'h180; banks[7] <= 10'h3FF;
        end else begin
            oirq_n <= 1;
            if( !xirq_n ) firq_n <= 0;
            if( vb_edge ) irq_n  <= 0;
            if( !rnw && mmr_cs ) begin
                casez( addr[12:9] )
                    4'b0???: begin
                        if( addr[0] )
                            banks[addr[11:9]][22:21] = dout[1:0];
                        else
                            banks[addr[11:9]][20:13] = dout;
                    end
                    8: rstn_out <= dout[0];
                    // 9: watchdog
                    // 10: ?
                    11: irq_n  <= 1;
                    12: firq_n <= 1;
                    13: oirq_n <= 0;
                endcase
            end
        end
    end
endmodule