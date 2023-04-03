/*  This file is part of JTCONTRA.
    JTCONTRA program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTCONTRA program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTCONTRA.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 2-2-2023 */

// Clocks are derived from H counter on the original PCB
// Yet, that doesn't seem to be important and it only
// matters the frequency of the signals:
// E,Q: 3 MHz
// Q is 1/4th of wave advanced

module jtcastle_main(
    input               rst,
    input               clk,        // 48 MHz
    output              cpu_cen,
    // communication with sound CPU
    output              snd_irq,
    output      [ 7:0]  snd_latch,
    // ROM
    output      [17:0]  rom_addr,
    output              rom_cs,
    input       [ 7:0]  rom_data,
    input               rom_ok,
    // cabinet I/O
    input       [ 1:0]  start_button,
    input       [ 1:0]  coin_input,
    input       [ 6:0]  joystick1,
    input       [ 6:0]  joystick2,
    input               service,
    // GFX
    output      [15:0]  cpu_addr,
    output              cpu_rnw,
    output      [ 7:0]  cpu_dout,
    input               gfx_firqn,
    input               gfx_irqn,
    input               gfx_nmin,
    inout               gfx1_cs,
    inout               gfx2_cs,
    inout               pal_cs,

    output     [1:0]    video_bank,
    output              prio,

    input      [7:0]    gfx1_dout,
    input      [7:0]    gfx2_dout,
    input      [7:0]    pal_dout,
    // DIP switches
    input               dip_pause,
    input      [7:0]    dipsw_a,
    input      [7:0]    dipsw_b,
    input      [3:0]    dipsw_c
);

localparam RAM_AW = 13;

wire [ 7:0] ram_dout, cpu_din, Aupper;
wire [15:0] A;
wire        RnW, irq_n, nmi_n, irq_ack;
wire        irq_trigger, nmi_trigger, firq_trigger;
wire        ram_cs, VMA, cpu_we, dtack;
wire        cen24, cen12;

assign irq_trigger  = ~gfx_irqn  & dip_pause;
assign firq_trigger = ~gfx_firqn & dip_pause;
assign nmi_trigger  = ~gfx_nmin  & dip_pause;
assign cpu_addr     = A;
assign cpu_rnw      = ~cpu_we;
assign dtack        = ~rom_cs | rom_ok;
assign cpu_cen      = cen24;

reg        io_cs;
reg  [4:0] bank; // MSB unused
reg  [7:0] port_in;
wire [7:0] div_dout;

jtframe_frac_cen #(.W(2),.WC(2)) u_cen(
    .clk    ( clk           ),
    .n      ( 2'd1          ),
    .m      ( 2'd2          ),
    .cen    ( {cen12,cen24} ),
    .cenb   (               )
);

// Decoder 052127 takes as inputs A[15:9]
// The schematics available are for a board version
// with small ROM chips, whereas all available dumps
// use a 32kB+128kB combination
always @(*) begin
    pal_cs   = 0;
    io_cs    = 0;
    ram_cs   = 0;
    if( A[15:12]==0 ) begin
        case(A[11:8])
            4'd4: io_cs  = 1;
            4'd6: pal_cs = 1;
            4'd7: ram_cs = 1; // RAM A[11] is driven in a funny way in the sch
            default:;
        endcase
    end
    rom_cs   = A[15:12]>=6 && !cpu_we && VMA;
    gfx1_cs  = A[15:8]==0 || A[15:13]==3'd2>>1;
    gfx2_cs  = A[15:8]==2 || A[15:13]==3'd4>>1;
    rom_addr = { A[15], A[15] ? {2'd0,A[14:13]} : bank[3:0], A[12:0] };
end

always @(posedge clk) begin
    cpu_din<= rom_cs  ? rom_data  :
              ram_cs  ? ram_dout  :
              io_cs   ? port_in   :
              pal_cs  ? pal_dout  :
              gfx1_cs ? gfx1_dout :
              gfx2_cs ? gfx2_dout : 8'hff;
end

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        bank       <= 0;
        snd_irq    <= 0;
        snd_latch  <= 0;
        port_in    <= 0;
        prio       <= 0;
        video_bank <= 0;
    end else if(cen12 && io_cs ) begin
        case( A[4:2] )
            0: bank <= cpu_dout[5:0]; // coin lock and a bit for a RAM bank seem to be here too
            1: snd_latch <= cpu_dout;
            2: snd_irq   <= 1;
            // 3: AFR in sch ?
            4: case( A[1:0] ) // COINEN in sch.
                0: port_in <= {3'b111, start_button, service, coin_input };
                1: port_in <= {2'b11, joystick1[5:0] };
                2: port_in <= {2'b11, joystick2[5:0] };
                3: port_in <= {2'b11, joystick2[6], joystick1[6], dipsw_c[3:0] };
            endcase
            5: port_in <= A[0] ? dipsw_b : dipsw_a;
            6: { prio, video_bank } <= cpu_dout[2:0];
            default: port_in <= 8'hff;
        endcase
    end
end

jtkcpu u_cpu(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .cen    ( cen12     ),
    .cen2   ( cen24     ),

    .halt   ( 1'd0      ),
    .dtack  ( dtack     ),
    .nmi_n  ( gfx_nmin ),
    .irq_n  ( gfx_irqn ),
    .firq_n (gfx_firqn ),

    // memory bus
    .din    ( cpu_din   ),
    .dout   ( cpu_dout  ),
    .addr   ({Aupper, A}),
    .we     ( cpu_we    )
);


// jtframe_sys6809 #(.RAM_AW(RAM_AW),.KONAMI(2)) u_cpu(
//     .rstn       ( ~rst      ),
//     .clk        ( clk       ),
//     .cen        ( cen12     ),   // This is normally the input clock to the CPU
//     .cpu_cen    ( cpu_cen   ),   // 1/4th of cen -> 3MHz

//     // Interrupts
//     .nIRQ       ( irq_n     ),
//     .nFIRQ      ( firq_n    ),
//     .nNMI       ( nmi_n     ),
//     .irq_ack    ( irq_ack   ),
//     // Bus sharing
//     .bus_busy   ( 1'b0      ),
//     // memory interface
//     .A          ( A         ),
//     .RnW        ( RnW       ),
//     .VMA        ( VMA       ),
//     .ram_cs     ( ram_cs    ),
//     .rom_cs     ( rom_cs    ),
//     .rom_ok     ( rom_ok    ),
//     // Bus multiplexer is external
//     .ram_dout   ( ram_dout  ),
//     .cpu_dout   ( cpu_dout  ),
//     .cpu_din    ( cpu_din   )
// );

endmodule
