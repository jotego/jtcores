/*  This file is part of JTKICKER.
    JTKICKER program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTKICKER program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTKICKER.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 13-1-2022 */

module jtmikie_main(
    input               rst,
    input               clk,        // 24 MHz
    input               cpu4_cen,   // 6 MHz
    output              cpu_cen,    // Q clock
    // ROM
    output      [15:0]  rom_addr,
    output reg          rom_cs,
    input       [ 7:0]  rom_data,
    input               rom_ok,

    // cabinet I/O
    input       [ 1:0]  start_button,
    input       [ 1:0]  coin_input,
    input       [ 5:0]  joystick1,
    input       [ 5:0]  joystick2,
    input               service,

    // GFX
    output              cpu_rnw,
    output      [ 7:0]  cpu_dout,
    output reg          vram_cs,
    output reg          objram_cs,

    // Sound
    output reg  [ 7:0]  snd_latch,
    output reg          snd_on,

    // configuration
    output reg  [ 2:0]  pal_sel,
    output reg          flip,

    // interrupt triggers
    input               LVBL,

    input      [7:0]    vram_dout,
    input      [7:0]    vscr_dout,  // output from Konami 085 custom chip
    input      [7:0]    obj_dout,
    // DIP switches
    input               dip_pause,
    input      [7:0]    dipsw_a,
    input      [7:0]    dipsw_b,
    input      [1:0]    dipsw_c
);

reg  [ 7:0] cabinet, cpu_din;
wire [ 7:0] ram_dout;
wire [15:0] A;
wire        RnW, irq_n, nmi_n;
wire        irq_trigger;
reg         irq_clrn, ram_cs, snd_cs;
reg         ior_cs, in5_cs, in6_cs,
            color_cs, iow_cs, intshow_cs;
// reg         afe_cs; // watchdog
wire        VMA;

assign irq_trigger = ~LVBL & dip_pause;
assign cpu_rnw     = RnW;
assign rom_addr    = A;

always @(*) begin
    rom_cs  = VMA && A[15:13]>2 && RnW && VMA; // ROM = 4000 - FFFF
    iow_cs     = 0;
    in5_cs     = 0;
    in6_cs     = 0;
    ior_cs     = 0;
    color_cs   = 0;
    intshow_cs = 0;
    objram_cs  = 0;
    vram_cs    = 0;
    ram_cs     = 0;
    snd_cs     = 0;
    if( VMA && A[15:13]==1 ) begin // 2000-3FFF
        case( A[12:11] )
            0:  case( A[10:8] )  // 2000-27FF
                    0: iow_cs      = 1; // 2000
                    // 1: watchdog    // 2100
                    2: color_cs = 1;  // 2200
                    3: intshow_cs = 1;
                    4: begin
                        ior_cs = 1;    // 2400-2403
                        snd_cs = ~RnW;
                    end
                    5: { in6_cs, in5_cs } = { A[0], ~A[0] };
                    default:;
                endcase
            1: objram_cs = 1;   // 2800-2FFF
            2: ram_cs   = 1;    // 3800-3BFF    - part of VRAM chip
            3: vram_cs  = 1;    // 3C00-3FFF
        endcase
    end
end

always @(posedge clk) begin
    case( A[1:0] )
        0: cabinet <= { ~3'd0, start_button, service, coin_input };
        1: cabinet <= { 2'd3, joystick1[5:4], joystick1[2], joystick1[3], joystick1[0], joystick1[1]};
        2: cabinet <= { 2'd3, joystick2[5:4], joystick2[2], joystick2[3], joystick2[0], joystick2[1]};
        3: cabinet <= {6'h3f,dipsw_c};
    endcase
    cpu_din <= rom_cs  ? rom_data  :
               vram_cs ? vram_dout :
               ram_cs  ? ram_dout  :
               intshow_cs ? vscr_dout :
               objram_cs  ? obj_dout :
               ior_cs  ? cabinet  :
               in6_cs  ? dipsw_b  :
               in5_cs  ? dipsw_a  : 8'hff;
end

always @(posedge clk) begin
    if( rst ) begin
        irq_clrn <= 0;
        flip     <= 0;
        snd_on   <= 0;
        pal_sel  <= 0;
        snd_latch<= 0;
    end else if(cpu_cen) begin
        if( iow_cs && !RnW ) begin
            case(A[2:0]) // 74LS259
                2: snd_on    <= cpu_dout[0];
                6: flip      <= cpu_dout[0];
                7: irq_clrn  <= cpu_dout[0];
                default:;
            endcase
        end
        if( color_cs ) pal_sel <= cpu_dout[2:0];
        if( snd_cs   ) snd_latch <= cpu_dout;
    end
end

jtframe_ff u_irq(
    .rst      ( rst         ),
    .clk      ( clk         ),
    .cen      ( 1'b1        ),
    .din      ( 1'b1        ),
    .q        (             ),
    .qn       ( irq_n       ),
    .set      (             ),    // active high
    .clr      ( ~irq_clrn   ),    // active high
    .sigedge  ( irq_trigger )     // signal whose edge will trigger the FF
);

jtframe_sys6809 #(.RAM_AW(10)) u_cpu(
    .rstn       ( ~rst      ),
    .clk        ( clk       ),
    .cen        ( cpu4_cen  ),   // This is normally the input clock to the CPU
    .cpu_cen    ( cpu_cen   ),   // 1/4th of cen -> 3MHz

    // Interrupts
    .nIRQ       ( irq_n     ),
    .nFIRQ      ( 1'b1      ),
    .nNMI       ( 1'b1      ),
    .irq_ack    (           ),
    // Bus sharing
    .bus_busy   ( 1'b0      ),
    // memory interface
    .A          ( A         ),
    .RnW        ( RnW       ),
    .VMA        ( VMA       ),
    .ram_cs     ( ram_cs    ),
    .rom_cs     ( rom_cs    ),
    .rom_ok     ( rom_ok    ),
    // Bus multiplexer is external
    .ram_dout   ( ram_dout  ),
    .cpu_dout   ( cpu_dout  ),
    .cpu_din    ( cpu_din   )
);

endmodule
