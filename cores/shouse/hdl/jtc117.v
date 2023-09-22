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
    input               clk,     // original runs at 6MHz (4x CPU)
    input               bsel,    // bus selection, 0=master, 1=sub, 1.5MHz
    // interrupt triggers
    input               lvbl,
    input               firqn,   // input that will trigger both FIRQ outputs

    // Master
    input        [15:0] maddr,  // not all bits are used, but easier to connect as a whole
    input        [ 7:0] mdout,
    input               mrnw,
    input               mvma,
    output              mirq_n,
    output              mfirq_n,

    // Sub
    input        [15:0] saddr,
    input        [ 7:0] sdout,
    input               srnw,
    input               svma,
    output              sirq_n,
    output              sfirq_n,
    output              srst_n,

    output       [ 9:0] cs,
    output              rom_cs,
    output              ram_cs,
    output              rnw,
    output              vma,
    output       [21:0] baddr,
    output       [ 7:0] bdout
);
    reg          vb_edge, lvbl_l, fedge, firqn_l, swmux;
    wire         xirq;
    reg  [ 15:0] samux;
    reg  [  7:0] sdmux;
    wire [22:12] mahi, sahi;

    function range( input [21:12] s, e );
        range = baddr[21:12]>=s && baddr[21:12]<e;
    endfunction

    assign { rom_cs, baddr } = bsel ? { sahi[22]&svma&srnw, sahi[21:12], saddr[11:0] } :
                                      { mahi[22]&mvma&mrnw, mahi[21:12], maddr[11:0] };
    assign vma    = bsel ? svma : mvma;
    assign bdout  = bsel ? sdout : mdout;
    assign cs[0]  = range(10'h200,10'h280); // made-up number
    assign cs[1]  = range(10'h280,10'h2C0); // made-up number
    assign cs[2]  = range(10'h2C0,10'h2C2); // 3D,     acc. to MAME
    assign cs[3]  = range(10'h2E0,10'h2E8); // COL,    acc. to MAME
    assign cs[4]  = range(10'h2F0,10'h2F8); // CHAR,   acc. to MAME
    assign cs[5]  = range(10'h2F8,10'h2FA); // KEY,    acc. to MAME
    assign cs[6]  = range(10'h2FC,10'h2FD); // OBJ,    acc. to MAME
    assign cs[7]  = range(10'h2FD,10'h2FE); // SCRDT,  acc. to MAME
    assign cs[8]  = range(10'h2FE,10'h2FF); // SOUND,  acc. to MAME
    assign cs[9]  = range(10'h2FF,10'h300); // TRIRAM, acc. to MAME
    assign ram_cs = range(10'h300,10'h320); // RAM, 32 or 128kB on board. MAME uses 32kB
    assign rnw    = bsel ? srnw : mrnw;

    always @* begin
        samux = saddr;
        sdmux = sdout;
        swmux = srnw;
        if( !srst_n && &maddr[15:13] && maddr[12:9]==14 ) begin
            samux[15:12] = 4'hf;
            samux[12: 9] = 7;
            sdmux        = mdout;
            swmux        = mrnw;
        end
    end

    always @(posedge clk, posedge rst) begin
        if( rst ) begin
            lvbl_l  <= 0;
            firqn_l <= 0;
            vb_edge <= 0;
            fedge   <= 0;
        end else begin
            lvbl_l  <= lvbl;
            firqn_l <= firqn;
            vb_edge <= !lvbl && lvbl_l;
            fedge   <= !firqn && firqn_l;
        end
    end

    jtc117_unit u_main(
        .rst        ( rst       ),
        .clk        ( clk       ),

        .vb_edge    ( vb_edge   ),

        .addr       ( maddr     ),
        .dout       ( mdout     ),
        .rnw        ( mrnw      ),
        .vma        ( mvma      ),

        .xirq       ( fedge     ),
        .oirq       ( xirq      ),

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
        .vma        ( svma      ),

        .xirq       ( xirq|fedge),
        .oirq       (           ),

        .rstn_out   (           ), // the sub CPU can probably reset the master too
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
    input               vma,

    input               xirq,
    output reg          oirq,

    output reg          rstn_out,
    output reg          irq_n,
    output reg          firq_n,
    output      [22:12] ahi    // address high bits
);
    reg  [22:13] banks[0:7];
    wire         mmr_cs;
    wire [ 2: 0] idx;


    assign idx = addr[15:13];
    assign mmr_cs = &{idx, vma};
    assign ahi    = { banks[idx], addr[12] };

    always @(posedge clk, posedge rst) begin
        if( rst ) begin
            rstn_out <= 0;
            firq_n   <= 1;
            oirq     <= 0;
            // not all defaults values have been verified
            // they all point to RAM except bank 7, pointing to the last ROM
            banks[0] <= 10'h180; banks[1] <= 10'h180;
            banks[2] <= 10'h180; banks[3] <= 10'h180;
            banks[4] <= 10'h180; banks[5] <= 10'h180;
            banks[6] <= 10'h180; banks[7] <= 10'h3FF;
        end else begin
            oirq <= 0;
            if( xirq ) firq_n <= 0;
            if( vb_edge ) irq_n  <= 0;
            if( !rnw && mmr_cs ) begin
                casez( addr[12:9] )
                    4'b0???: begin
                        if( !addr[0] )
                            banks[addr[11:9]][22:21] = dout[1:0];
                        else
                            banks[addr[11:9]][20:13] = dout;
                    end
                    8: rstn_out <= dout[0];
                    // 9: watchdog
                    // 10: ?
                    11: irq_n  <= 1;
                    12: firq_n <= 1;
                    13: oirq   <= 1;
                endcase
            end
        end
    end
endmodule