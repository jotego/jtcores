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
    input               sub_Q,
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
    output reg          mrst_n,

    // Sub
    input        [15:0] saddr,
    input        [ 7:0] sdout,
    input               srnw,
    input               svma,
    output              sirq_n,
    output              sfirq_n,
    output reg          srst_n,

    output       [ 9:0] cs,
    output              rom_cs,
    output              ram_cs,
    output              rnw,
    output              vma,
    output       [21:0] baddr,
    output       [ 7:0] bdout,
    // Debug
    input        [ 7:0] debug_bus,
    output reg   [ 7:0] st_dout
);
    reg          vb_edge, lvbl_l, fedge, firqn_l, bsel_l, prstn;
    wire         xirq, srrqn, wdogn, mwdn, swdn, xbank, bsel_negedge;
    wire [22:12] mahi, sahi;
    wire [ 7: 0] mst_dout, sst_dout;

    function range( input [21:12] s, e );
        range = baddr[21:12]>=s && baddr[21:12]<e;
    endfunction

    assign { rom_cs, baddr } = bsel ? { sahi[22]&svma&srnw, sahi[21:12], saddr[11:0] } :
                                      { mahi[22]&mvma&mrnw, mahi[21:12], maddr[11:0] };
    assign vma    = bsel ? svma : mvma;
    assign bdout  = bsel ? sdout : mdout;
    assign cs[0]  = range(10'h200,10'h280); // made-up number
    assign cs[1]  = range(10'h280,10'h2C0); // made-up number
    assign cs[2]  = range(10'h2C0,10'h2D0); // 3D,     acc. to MAME
    assign cs[3]  = range(10'h2E0,10'h2E8); // COL,    acc. to MAME
    assign cs[4]  = range(10'h2F0,10'h2F8); // CHAR,   acc. to MAME
    assign cs[5]  = range(10'h2F8,10'h2FA); // KEY,    acc. to MAME
    assign cs[6]  = range(10'h2FC,10'h2FD); // OBJ,    acc. to MAME
    assign cs[7]  = range(10'h2FD,10'h2FE); // SCRDT,  acc. to MAME
    assign cs[8]  = range(10'h2FE,10'h2FF); // SOUND,  acc. to MAME
    assign cs[9]  = range(10'h2FF,10'h300); // TRIRAM, acc. to MAME
    assign ram_cs = range(10'h300,10'h320); // RAM, 32 or 128kB on board. MAME uses 32kB
    assign rnw    = bsel ? srnw : mrnw;
    assign wdogn  = mwdn & swdn;
    assign bsel_negedge = bsel_l & ~bsel;

    always @(posedge clk, posedge rst) begin
        if( rst ) begin
            mrst_n <= 0;
            prstn  <= 0;    // pre reset n
            srst_n <= 0;
            bsel_l <= 0;
            st_dout <= 0;
        end else begin
            bsel_l <= bsel;
            mrst_n <= wdogn;
            prstn  <= wdogn & srrqn;
            if( sub_Q ) srst_n <= prstn;    // always toggle it here
            st_dout <= debug_bus[0] ? sst_dout : mst_dout;
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
        .wdogn      ( mwdn      ),
        .wd_en      ( 1'b1      ),

        .addr       ( maddr     ),
        .dout       ( mdout     ),
        .rnw        ( mrnw      ),
        .vma        ( mvma      ),

        .xbank      ( 1'b0      ),
        .xdout      ( 8'd0      ),

        .xirq       ( fedge     ),
        .oirq       ( xirq      ),
        .obank      ( xbank     ),

        .orstn      ( srrqn     ), // sub reset request
        .irq_n      ( mirq_n    ),
        .firq_n     ( mfirq_n   ),
        .ahi        ( mahi      ),
        .st_dout    ( mst_dout  )
    );

    jtc117_unit u_sub(
        .rst        ( rst       ),
        .clk        ( clk       ),

        .vb_edge    ( vb_edge   ),
        .wdogn      ( swdn      ),
        .wd_en      ( srst_n    ),

        .addr       ( saddr     ),
        .dout       ( sdout     ),
        .rnw        ( srnw      ),
        .vma        ( svma      ),

        .xbank      ( xbank & bsel_negedge ),
        .xdout      ( mdout     ),

        .xirq       ( xirq|fedge),
        .oirq       (           ),
        .obank      (           ),

        .orstn      (           ), // the sub CPU can probably reset the master too
        .irq_n      ( sirq_n    ),
        .firq_n     ( sfirq_n   ),
        .ahi        ( sahi      ),
        .st_dout    ( sst_dout  )
    );
endmodule

//////////////////////////////////////////////////////////////////////
module jtc117_unit(
    input               rst,
    input               clk,

    input               vb_edge,
    input               wd_en,

    input        [15:0] addr,  // not all bits are used, but easier to connect as a whole
    input        [ 7:0] dout,
    input               rnw,
    input               vma,

    // bank 7 can be set by the other CPU
    input               xbank,
    input        [ 7:0] xdout,

    input               xirq,
    output reg          oirq,
    output reg          obank,

    output reg          orstn, // rst to other logic
    output reg          wdogn, // rst from watchdog
    output reg          irq_n,
    output reg          firq_n,
    output      [22:12] ahi,   // address high bits
    output      [  7:0] st_dout
);
    parameter WDW=7; // watchdog bit width

    reg  [22:13] banks[0:7];
    wire [  3:0] rsel;
    wire         mmr_cs;
    wire [ 2: 0] idx;
    reg [WDW-1:0]wdog_cnt;

    assign idx    = addr[15:13];
    assign rsel   = addr[12: 9];
    assign mmr_cs = &{idx, vma, ~rnw};
    assign ahi    = { banks[idx], addr[12] };
    assign st_dout= { {8-WDW{1'b0}}, wdog_cnt};
`ifdef SIMULATION
    wire rst_sel = mmr_cs && rsel==8;
`endif

    reg pre_o;

    always @(posedge clk, posedge rst) begin
        if( rst ) begin
            orstn  <= 0;
            firq_n <= 1;
            oirq   <= 0;
            // not all defaults values have been verified
            // they all point to RAM except bank 7, pointing to the last ROM
            banks[0] <= 10'h180; banks[1] <= 10'h180;
            banks[2] <= 10'h180; banks[3] <= 10'h180;
            banks[4] <= 10'h180; banks[5] <= 10'h180;
            banks[6] <= 10'h180; banks[7] <= 10'h3FF;
            wdog_cnt <= 0;
            pre_o    <= 0;
        end else begin
            oirq  <= 0;
            obank <= 0;
            wdogn <= ~&wdog_cnt;
            if( xirq    ) firq_n <= 0;
            if( vb_edge ) begin
                irq_n <= 0;
                wdog_cnt <= wd_en ? wdog_cnt + 1'd1 : {WDW{1'b0}};
                if( pre_o ) orstn <= 1;
                pre_o <= 0;
            end
            if( xbank ) banks[7][22:13] = { 2'b11, xdout };
            if( mmr_cs ) begin
                casez( rsel )
                    4'b0???: begin
                        if( !addr[0] )
                            banks[addr[11:9]][22:21] = dout[1:0];
                        else
                            banks[addr[11:9]][20:13] = dout;
                    end
                    8: begin
                        if( !dout[0] )
                            orstn <= 0;
                        else
                            pre_o <= 1; // delaying the reset release until VB ensures consistent boot up
                        // orstn <= dout[0];
                    end
                    9: wdog_cnt <= 0;
                    // 10: ?
                    11: irq_n  <= 1;
                    12: firq_n <= 1;
                    13: oirq   <= 1;
                    14: obank  <= 1;
                endcase
            end
        end
    end
endmodule