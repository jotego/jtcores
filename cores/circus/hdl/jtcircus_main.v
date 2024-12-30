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
    Date: 23-8-2024 */

// very similar to jtroadf_main
module jtcircus_main(
    input            rst,
    input            clk,        // 24 MHz
    input            cpudiv_cen, // 2.048*4 MHz
    output           cpu_cen,    // Q clock

    // ROM
    output    [15:0] rom_addr,
    output reg       rom_cs,
    input      [7:0] rom_data,
    input            rom_ok,

    // cabinet I/O
    input      [3:0] cab_1p,
    input      [3:0] coin,
    input      [5:0] joystick1,
    input      [5:0] joystick2,
    input            service,

    // GFX
    output           cpu_rnw,
    output     [7:0] cpu_dout,
    output reg       vgap_cs,
    output reg       vram_cs,
    output reg       objram_cs,
    output reg       obj_frame,

    // Sound
    output reg [7:0] snd_latch,
    output reg       snd_irq,
    output reg       mute,

    // configuration
    output reg       flip,

    // interrupt triggers
    input            LVBL,

    input      [7:0] vram_dout,
    input      [7:0] obj_dout,
    // DIP switches
    input            dip_pause,
    input      [7:0] dipsw_a,
    input      [7:0] dipsw_b,
    input      [6:0] dipsw_c
);

reg  [ 7:0] cabinet, cpu_din;
wire [ 7:0] ram_dout;
wire [15:0] A;
wire        RnW, irq_n;
wire        irq_trigger;
reg         irq_clrn, ram_cs, snd_data_cs;
reg         ior_cs, in5_cs, in6_cs,
            iow_cs;
wire        VMA;

assign irq_trigger = ~LVBL & dip_pause;
assign cpu_rnw     = RnW;
assign rom_addr    = A;

always @(*) begin
    rom_cs      = VMA && RnW && A[15:13]>2; // ROM = 6000 - FFFF
    iow_cs      = 0;
    in5_cs      = 0;
    in6_cs      = 0;
    ior_cs      = 0;
    vgap_cs     = 0;
    objram_cs   = 0;
    vram_cs     = 0;
    ram_cs      = 0;
    snd_data_cs = 0;
    snd_irq     = 0;

    if( VMA ) begin
        if( A[15:13]==1 ) // chip 4G
            case( A[12:11] ) // chip 10E
                0,1: ram_cs  = 1;
                2:   vram_cs = 1;
                3: objram_cs = 1;
            endcase
        if( A[15:13]==0 )
            case( A[12:10] ) // chip 3B
                0: iow_cs      = 1;
                // 1: watch dog
                2: snd_data_cs = 1;
                3: snd_irq     = 1;
                4: ior_cs      = 1;
                5: in5_cs      = 1;
                6: in6_cs      = 1;
                7: vgap_cs     = 1;
                default:;
            endcase
    end
end

always @(posedge clk) begin
    cabinet <= 8'hff;
    if( in5_cs ) cabinet <= dipsw_a;
    if( in6_cs ) cabinet <= dipsw_b;
    if( ior_cs ) case( A[1:0] )
        0: cabinet <= { 2'b0, dipsw_c[6], cab_1p[1:0], service, coin[1:0] };
        1: cabinet <= { 2'b0, joystick1[5:0] };
        2: cabinet <= { 2'b0, joystick2[5:0] };
        3: cabinet <= { 2'b0,   dipsw_c[5:0] };
    endcase
    cpu_din <= rom_cs    ? rom_data  :
               vram_cs   ? vram_dout :
               ram_cs    ? ram_dout  :
               objram_cs ? obj_dout  : cabinet;
    if( snd_data_cs ) snd_latch <= cpu_dout;
end

always @(posedge clk) begin
    if( rst ) begin
        irq_clrn  <= 0;
        flip      <= 0;
        obj_frame <= 0;
        mute      <= 0;
    end else if(cpu_cen) begin
        if( iow_cs && !RnW ) begin
            case(A[2:0]) // 74LS259 @ 1D
                0: flip      <= cpu_dout[0];
                1: irq_clrn  <= cpu_dout[0];
                2: mute      <= cpu_dout[0];
                // 3: coin 1 counter
                // 4: coin 2 counter
                5: obj_frame <= cpu_dout[0];
                // 6-7: unconnected
                default:;
            endcase
        end
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

jtframe_sys6809 #(.RAM_AW(12),.KONAMI(1)) u_cpu(
    .rstn       ( ~rst      ),
    .clk        ( clk       ),
    .cen        ( cpudiv_cen),   // This is normally the input clock to the CPU
    .cpu_cen    ( cpu_cen   ),   // 1/4th of cen -> 2.048 MHz
    .bus_busy   ( 1'b0      ),
    // Interrupts
    .nIRQ       ( irq_n     ),
    .nFIRQ      ( 1'b1      ),
    .nNMI       ( 1'b1      ),
    .irq_ack    (           ),
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
