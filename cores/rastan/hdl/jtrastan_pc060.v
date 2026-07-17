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
    Date: 4-4-2022 */

// Designed according to MAME's description:
// it lacks the mute output for the amp

// Both CPUs run on the single 48MHz clk; they are told apart only by their cens
// (cen_m = 68000 8MHz MCLK, cen_s = Z80 4MHz SCLK), which are phase-locked 2:1 like
// the board's one 16MHz crystal. The internal 2FF "sync" stages are kept (they cross
// clk->clk now, i.e. plain 2-cycle latency) because that latency is part of the
// validated handshake timing.
module jtrastan_pc060(
    input           rst,
    input           clk,
    input           cen_m,   // MCLK = 8MHz on the schematics (68000 side)
    input           cen_s,   // SCLK = 4MHz on the schematics (Z80 side)
    input     [3:0] main_dout,
    output    [3:0] main_din,
    input           main_addr,
    input           main_rnw,
    input           main_cs,

    input     [3:0] snd_dout,
    output    [3:0] snd_din,
    input           snd_addr,
    input           snd_rnw,
    input           snd_cs,
    output          snd_nmin,
    output          snd_rst
);

    wire [3:0] snd_ptr, main_ptr, status;
    wire [3:0] main_ram, snd_ram;
    wire       main_ramwr, snd_ramwr,
               nmi_en, subrst;
    wire [1:0] set_sndst,  snd_full,
               set_mainst, main_full;

    assign status     = { main_full, snd_full };
    assign snd_nmin   = ~nmi_en || snd_full[1:0]==0;
    assign main_din   = main_ptr[2] ? status : main_ram;
    assign snd_din    =  snd_ptr[2] ? status : snd_ram;

    jtrastan_pc060_unit u_main(
        .rst        ( rst       ),
        .clk        ( clk       ),
        .cen        ( cen_m     ),
        .clk_other  ( clk       ),

        .din        ( main_dout ),
        .cs         ( main_cs   ),
        .a          ( main_addr ),
        .we         ( ~main_rnw ),
        .ram_we     ( main_ramwr),

        // other CPU buffer
        .full_rq    ( set_sndst ), // request setting other_full
        .other_full ( snd_full  ),

        // this CPU buffer
        .set_full   ( set_mainst),
        .is_full    ( main_full ),

        .ptr        ( main_ptr  ),
        .flag       ( subrst    )
    );

    jtrastan_pc060_unit u_snd(
        .rst        ( rst       ),
        .clk        ( clk       ),
        .cen        ( cen_s     ),
        .clk_other  ( clk       ),

        .din        ( snd_dout  ),
        .cs         (  snd_cs   ),
        .a          (  snd_addr ),
        .we         ( ~snd_rnw  ),
        .ram_we     ( snd_ramwr ),

        // other CPU buffer
        .full_rq    ( set_mainst), // request setting other_full
        .other_full ( main_full ),

        // this CPU buffer
        .set_full   ( set_sndst ),
        .is_full    ( snd_full  ),

        .ptr        ( snd_ptr   ),
        .flag       ( nmi_en    )
    );

    jtframe_sync #(.W(1),.LATCHIN(1)) u_sync1(
        .clk_in ( clk       ),
        .clk_out( clk       ),
        .raw    ( subrst    ),
        .sync   ( snd_rst   )
    );

    // Force 1kB RAM to be used, so synthesis works
    jtframe_dual_ram #(.DW(4),.AW(10)) u_share(
        // Port 0: main
        .clk0   ( clk           ),
        .data0  ( main_dout     ),
        .addr0  ( { 7'd0,main_ramwr, main_ptr[1:0] } ),
        .we0    ( main_ramwr    ),
        .q0     ( main_ram      ),
        // Port 1: sound sub CPU
        .clk1   ( clk           ),
        .addr1  ( { 7'd0,~snd_ramwr, snd_ptr[1:0] } ),
        .data1  ( snd_dout      ),
        .we1    ( snd_ramwr     ),
        .q1     ( snd_ram       )
    );

endmodule

///////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////

module jtrastan_pc060_unit(
    input            rst,
    input            clk,
    input            cen,       // run the register FSM at the real chip rate (8/4MHz)
    input            clk_other,
    input            cs,
    input            a,
    input            we,
    output           ram_we,
    input      [3:0] din,

    // other CPU buffer
    output reg [1:0] full_rq, // request setting other_full
    input      [1:0] other_full,

    // this CPU buffer
    input      [1:0] set_full,
    output reg [1:0] is_full,

    output reg [3:0] ptr,
    output reg       flag       // set writting to 5, cleared with 6
);
    reg        csl, wel, al;
    reg  [4:0] cnt;
    wire [1:0] set_full_s;

    assign ram_we = cs & we & a & ~ptr[3] & ~ptr[2];

    jtframe_sync #(.W(2),.LATCHIN(1)) u_sync2(
        .clk_in ( clk_other  ),
        .clk_out( clk        ),
        .raw    ( set_full   ),
        .sync   ( set_full_s )
    );

    // Data/flag handshake FSM, stepped at the real chip access rate (cen = 8/4MHz).
    // Empirically this yields fewer race slivers than free-running at full clock.
    always @(posedge clk, posedge rst) begin
        if( rst ) begin
            ptr     <= 0;
            full_rq <= 0;
            is_full <= 0;
        end else if( cen ) begin
            wel <= we;
            csl <= cs;
            al  <= a;
            if( other_full[0] ) full_rq[0] <= 0;
            if( other_full[1] ) full_rq[1] <= 0;
            if( set_full_s[0] ) is_full[0] <= 1;
            if( set_full_s[1] ) is_full[1] <= 1;

            if( ~cs & csl ) begin
                if( wel && !al )
                    ptr <= din;
                else begin
                    if( !ptr[2] ) ptr <= ptr + 4'd1;
                    case( ptr )
                        1:  if( wel )
                                full_rq[0] <= 1;
                            else
                                is_full[0] <= 0;
                        3:  if( wel )
                                full_rq[1] <= 1;
                            else
                                is_full[1] <= 0;
                        default:;
                    endcase
                end
            end
        end
    end

    // Control flag (slave side = NMI mask H2_Q, master side = sub-CPU reset A10_Q).
    // Decap-faithful: on the real chip these are driven DIRECTLY by the reg-4/5/6
    // write strobe (async), NOT by the cen-gated FSM. React on the fast clock the
    // instant the write is decoded, so the NMI mask (mode 5) lands essentially
    // immediately at the reg-5 write instead of one cen-gated access later -> the
    // NMI sliver the service-test race lives in is closed.
    always @(posedge clk, posedge rst) begin
        if( rst )
            flag <= 0;
        else if( cs & we & a & ptr[2] & ~ptr[3] ) // data write to reg 4/5/6
            case( ptr[1:0] )
                2'd0: flag <= din[0]; // mode 4
                2'd1: flag <= 1'b0;   // mode 5 -> mask NMI
                2'd2: flag <= 1'b1;   // mode 6 -> unmask NMI
                default:;
            endcase
    end
endmodule
