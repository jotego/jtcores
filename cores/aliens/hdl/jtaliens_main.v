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
    Date: 5-5-2023 */

module jtaliens_main(
    input               rst,
    input               clk,
    input               cen24,
    input               cen12,
    output              cpu_cen,

    output      [ 7:0]  cpu_dout,

    output      [17:0]  rom_addr,
    input       [ 7:0]  rom_data,
    output reg          rom_cs,
    input               rom_ok,
    // RAM
    output              ram_we,
    output              cpu_we,
    input       [ 7:0]  ram_dout,
    // cabinet I/O
    input       [ 1:0]  start_button,
    input       [ 1:0]  coin_input,
    input       [ 5:0]  joystick1,
    input       [ 5:0]  joystick2,
    input               service,

    // From video
    input               rst8,
    input               irq_n,
    input               firq_n,
    input               nmi_n,

    input      [7:0]    tilesys_dout, objsys_dout,
    input      [7:0]    pal_dout,

    // To video
    output reg          rmrd,
    output              pal_we,
    output reg          tilesys_cs,
    output reg          objsys_cs,
    // To sound
    output reg          snd_irq,
    output reg  [ 7:0]  snd_latch,
    // DIP switches
    input               dip_pause,
    input       [19:0]  dipsw
);

wire [ 7:0] Aupper;
reg  [ 7:0] cpu_din, port_in;
wire [15:0] A;
reg         ram_cs, banked_cs, io_cs, pal_cs, work, init;
wire        dtack;  // to do: add delay for io_cs

assign rom_addr   = banked_cs ? { Aupper[4:0], A[12:0] } // 5+13=18
                              : { 2'b10, A }; // 2+16=18
assign dtack      = ~rom_cs | rom_ok;
assign ram_we     = ram_cs & cpu_we;
assign pal_we     = pal_cs & cpu_we;

// Decoder 053326 takes as inputs A[15:10], BK4, W0C0
// Decoder 053327 after it, takes A[10:7] for generating
// OBJCS, VRAMCS, CRAMCS, IOCS
always @(*) begin
    // PROG, BANK and WORK in sch
    banked_cs  = /*!Aupper[4] &&*/ A[15:13]==1; // 2000-3FFFF
    rom_cs     = A[15] || banked_cs; // >=8000
    ram_cs     = A[15:13]==0 && ( A[12] || A[11] || A[10] || !work);
    // after second decoder:
    io_cs      = A[15:7]=='b0101_1111_1 && ~|A[6:5];
    pal_cs     = A[15:10]==0 && work; // CRAMCS in sch
    objsys_cs  = A[15:11]=='b01111 && !rmrd && init &&
                    (A[10] || (A[9:7]==0 && ~|A[6:5] && ~|A[4:3]));
    tilesys_cs = A[15:14]==1 && !io_cs && !pal_cs && !objsys_cs;
end

always @* begin
    cpu_din = rom_cs     ? rom_data  :
              ram_cs     ? ram_dout  :
              io_cs      ? port_in   :    // io_cs must take precedence over tilesys_cs
              pal_cs     ? pal_dout  :
              tilesys_cs ? tilesys_dout :
              objsys_cs  ? objsys_dout  : 8'hff;
end

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        snd_irq   <= 0;
        snd_latch <= 0;
        port_in   <= 0;
        work      <= 0;
        rmrd      <= 0;
    end else begin
        if(cpu_cen) snd_irq <= 0;
        if( io_cs ) begin
            if( cpu_we ) begin
                case( A[3:0] )
                    4'h8: begin
                        { init, rmrd, work } <= cpu_dout[7:5];
                        // bits 1:0 are coin counters
                    end
                    4'hc: begin
                        snd_latch <= cpu_dout;
                        snd_irq   <= 1;
                    end
                    default:;
                endcase
            end else case( A[3:0] )
                0: port_in <= { 3'b111, service, dipsw[19:16] };
                1: port_in <= { start_button[0], coin_input[0], joystick1 };
                2: port_in <= { start_button[1], coin_input[1], joystick2 };
                3: port_in <= dipsw[15:8];
                4: port_in <= dipsw[ 7:0];
                // 8 watchdog
                default: port_in <= 8'hff;
            endcase
        end
    end
end

/* verilator tracing_off */
reg  rst_cmb;
// there is a reset for the first 8 frames, skip it in sims
always @(posedge clk) rst_cmb <= rst `ifndef SIMULATION | rst8 `endif ;

jtkcpu u_cpu(
    .rst    ( rst_cmb   ),
    .clk    ( clk       ),
    .cen2   ( cen24     ),
    .cen_out( cpu_cen   ),

    .halt   ( 1'd0      ),
    .dtack  ( dtack     ),
    .nmi_n  ( nmi_n     ),
    .irq_n  ( irq_n | ~dip_pause ),
    .firq_n ( firq_n    ),

    // memory bus
    .din    ( cpu_din   ),
    .dout   ( cpu_dout  ),
    .addr   ({Aupper, A}),
    .we     ( cpu_we    )
);
/* verilator tracing_on */

endmodule