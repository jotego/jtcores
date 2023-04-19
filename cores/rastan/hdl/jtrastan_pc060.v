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

module jtrastan_pc060(
    input           rst48,
    input           clk48,
    input     [3:0] main_dout,
    output    [3:0] main_din,
    input           main_addr,
    input           main_rnw,
    input           main_cs,

    input           rst24,
    input           clk24,
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
               nmi_enb, subrst;
    wire [1:0] set_sndst,  snd_full,
               set_mainst, main_full;

    assign status     = { main_full, snd_full };
    assign snd_nmin   = nmi_enb || snd_full[1:0]==0;
    assign main_din   = main_ptr[2] ? status : main_ram;
    assign snd_din    =  snd_ptr[2] ? status : snd_ram;

    jtrastan_pc060_unit u_main(
        .rst        ( rst48     ),
        .clk        ( clk48     ),
        .clk_other  ( clk24     ),

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
        .rst        ( rst24     ),
        .clk        ( clk24     ),
        .clk_other  ( clk48     ),

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
        .flag       ( nmi_enb   )
    );

    jtframe_sync #(.W(1),.LATCHIN(1)) u_sync1(
        .clk_in ( clk48     ),
        .clk_out( clk24     ),
        .raw    ( subrst    ),
        .sync   ( snd_rst   )
    );

    // Force 1kB RAM to be used, so synthesis works
    jtframe_dual_ram #(.DW(4),.AW(10)) u_share(
        // Port 0: main
        .clk0   ( clk48         ),
        .data0  ( main_dout     ),
        .addr0  ( { 7'd0,main_ramwr, main_ptr[1:0] } ),
        .we0    ( main_ramwr    ),
        .q0     ( main_ram      ),
        // Port 1: sound sub CPU
        .clk1   ( clk24         ),
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

    always @(posedge clk, posedge rst) begin
        if( rst ) begin
            flag    <= 0;
            ptr     <= 0;
            full_rq <= 0;
            is_full <= 0;
        end else begin
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
                        4: flag <= din[0];
                        5: flag <= 1;
                        6: flag <= 0;
                        default:;
                    endcase
                end
            end
        end
    end
endmodule