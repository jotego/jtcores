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
    input           rst,
    input           clk,

    input     [3:0] main_dout,
    output    [3:0] main_din,
    input           main_addr,
    input           main_rd,
    input           main_we,

    input     [3:0] snd_dout,
    output    [3:0] snd_din,
    input           snd_addr,
    input           snd_rd,
    input           snd_we,
    output          snd_nmin,
    output          snd_rst
);

    wire [3:0] snd_ptr, main_ptr, status;
    wire [3:0] main_ram, snd_ram;
    wire       nmi_enb, subrst;
    wire [1:0] set_sndst,  snd_full,
               set_mainst, main_full;

    assign status     = { main_full, snd_full };
    assign snd_nmin   = nmi_enb || snd_full[1:0]==0;
    assign main_din   = main_ptr[2] ? status : main_ram;
    assign snd_din    =  snd_ptr[2] ? status : snd_ram;
    assign snd_rst    = subrst;

    jtrastan_pc060_unit u_main(
        .rst        ( rst       ),
        .clk        ( clk       ),

        .din        ( main_dout ),
        .a          ( main_addr ),
        .rd         ( main_rd   ),
        .we         ( main_we   ),

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

        .din        ( snd_dout  ),
        .a          (  snd_addr ),
        .rd         (  snd_rd   ),
        .we         (  snd_we   ),

        // other CPU buffer
        .full_rq    ( set_mainst), // request setting other_full
        .other_full ( main_full ),

        // this CPU buffer
        .set_full   ( set_sndst ),
        .is_full    ( snd_full  ),

        .ptr        ( snd_ptr   ),
        .flag       ( nmi_enb   )
    );

    // Force 1kB RAM to be used, so synthesis works
    jtframe_dual_ram #(.DW(4),.AW(10)) u_share(
        // Port 0: main
        .clk0   ( clk           ),
        .data0  ( main_dout     ),
        .addr0  ( { 5'd0,main_we, main_ptr[3:0] } ), // main reads low half, writes upper half
        .we0    ( main_we       ),
        .q0     ( main_ram      ),
        // Port 1: sound sub CPU
        .clk1   ( clk           ),
        .addr1  ( { 5'd0,~snd_we, snd_ptr[3:0] } ), // sound reads upper half, writes lower half
        .data1  ( snd_dout      ),
        .we1    ( snd_we        ),
        .q1     ( snd_ram       )
    );

endmodule

///////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////

module jtrastan_pc060_unit(
    input            rst,
    input            clk,
    input            a,
    input            rd,
    input            we,
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
    reg        evnt, al;
    reg  [4:0] cnt;
    reg  [3:0] dinl, written;
    wire [1:0] set_full_s;

    always @(posedge clk) begin
        if( rst ) begin
            flag    <= 0;
            ptr     <= 0;
            full_rq <= 0;
            is_full <= 0;
        end else begin
            evnt <= rd | we;
            al   <= a;
            dinl <= din;
            if( other_full[0] ) full_rq[0] <= 0;
            if( other_full[1] ) full_rq[1] <= 0;
            if( set_full  [0] ) is_full[0] <= 1;
            if( set_full  [1] ) is_full[1] <= 1;

            if( we && !a ) ptr <= din;
            if( we &&  a ) written <= dinl;
            if( (rd|we) && !evnt && a ) begin
                if( ptr<4 ) ptr <= ptr + 4'd1;
                case( ptr )
                    1:  if( we )
                            full_rq[0] <= 1;
                        else
                            is_full[0] <= 0;
                    3:  if( we )
                            full_rq[1] <= 1;
                        else
                            is_full[1] <= 0;
                    4: flag <= dinl[0];
                    5: flag <= 1;
                    6: flag <= 0;
                    default:;
                endcase
            end
        end
    end
endmodule