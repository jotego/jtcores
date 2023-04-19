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
    Date: 11-11-2021 */

module jtkicker_main(
    input               rst,
    input               clk,        // 24 MHz
    input               cpu4_cen,   // 6 MHz
    output              cpu_cen,    // Q clock
    input               ti1_cen,
    input               ti2_cen,
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
    output reg          vscr_cs,
    output reg          vram_cs,
    output reg          obj1_cs,
    output reg          obj2_cs,

    // configuration
    output reg  [ 2:0]  pal_sel,
    output reg          flip,

    // interrupt triggers
    input               LVBL,
    input               V16,

    input      [7:0]    vram_dout,
    input      [7:0]    vscr_dout,  // output from Konami 085 custom chip
    input      [7:0]    obj_dout,
    // DIP switches
    input               dip_pause,
    input      [7:0]    dipsw_a,
    input      [7:0]    dipsw_b,
    input      [3:0]    dipsw_c,

    // Sound
    output signed [15:0] snd,
    output               sample,
    output               peak
);

reg  [ 7:0] cabinet, cpu_din;
wire [15:0] A;
wire        RnW, irq_n, nmi_n;
wire        irq_trigger, nmi_trigger;
reg         nmi_clrn, irq_clrn;
reg         ior_cs, dip2_cs, dip3_cs,
            intshow_cs, ti1_cs, ti2_cs,
            color_cs, tidata1_cs, tidata2_cs, iow_cs;
// reg         afe_cs; // watchdog
wire        VMA;

assign irq_trigger = ~LVBL & dip_pause;
assign nmi_trigger =  V16;
assign cpu_rnw     = RnW;
assign sample      = ti1_cen;
assign rom_addr    = A;

always @(*) begin
    rom_cs  = VMA && A[15:14] !=0 && RnW && VMA; // ROM = 4000 - FFFF
    iow_cs     = 0;
    // afe_cs     = 0;
    intshow_cs = 0;
    ti2_cs     = 0;
    ti1_cs     = 0;
    dip2_cs    = 0;
    dip3_cs    = 0;
    ior_cs     = 0;
    tidata2_cs = 0;
    tidata1_cs = 0;
    color_cs   = 0;
    vscr_cs    = 0;
    obj1_cs    = 0;
    obj2_cs    = 0;
    vram_cs    = 0;
    if( VMA && A[15:14]==0 ) begin
        case( A[13:11] )
            0: case(A[10:8] )
                0: iow_cs     = 1;
                // 1: afe_cs     = 1; // watchdog
                2: intshow_cs = 1; // related to VSCR, raster line count?
                3: ti2_cs     = 1; // TITG2 in sch.
                4: ti1_cs     = 1; // TITG1 in sch.
                5: dip2_cs    = 1;
                6: dip3_cs    = 1;
                7: ior_cs     = 1; // IOEN in sch.
                default:;
            endcase
            1: tidata2_cs = 1;
            2: tidata1_cs = 1;
            3: color_cs   = 1;
            4: vscr_cs    = 1;  // vertical scroll position
            5: obj2_cs    = 1;
            6: obj1_cs    = 1;
            7: vram_cs    = 1;
        endcase
    end
end

always @(posedge clk) begin
    case( A[1:0] )
        0: cabinet <= { ~3'd0, start_button, service, coin_input };
        1: cabinet <= {2'b11, joystick1[5:4], joystick1[2], joystick1[3], joystick1[0], joystick1[1]};
        2: cabinet <= {2'b11, joystick2[5:4], joystick2[2], joystick2[3], joystick2[0], joystick2[1]};
        3: cabinet <= dipsw_a;
    endcase
    cpu_din <= rom_cs  ? rom_data  :
               vram_cs ? vram_dout :
               intshow_cs ? vscr_dout :
               (obj1_cs | obj2_cs) ? obj_dout  :
               ior_cs  ? cabinet   :
               dip2_cs ? dipsw_b   :
               dip3_cs ? { 4'hf, dipsw_c } : 8'hff;
end

always @(posedge clk) begin
    if( rst ) begin
        nmi_clrn <= 0;
        irq_clrn <= 0;
        flip     <= 0;
        pal_sel  <= 0;
    end else if(cpu_cen) begin
        if( iow_cs && !RnW ) begin
            nmi_clrn <= cpu_dout[1];
            irq_clrn <= cpu_dout[2];
            flip     <= cpu_dout[0];
        end
        if( color_cs ) pal_sel <= cpu_dout[2:0];
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

jtframe_ff u_nmi(
    .rst      ( rst         ),
    .clk      ( clk         ),
    .cen      ( 1'b1        ),
    .din      ( 1'b1        ),
    .q        (             ),
    .qn       ( nmi_n       ),
    .set      (             ),    // active high
    .clr      ( ~nmi_clrn   ),    // active high
    .sigedge  (nmi_trigger  )     // signal whose edge will trigger the FF
);

reg  [ 7:0] ti1_data, ti2_data;
wire [10:0] ti1_snd,  ti2_snd;
wire        rdy1, rdy2;

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        ti1_data <= 0;
        ti2_data <= 0;
    end else begin
        if( tidata1_cs ) ti1_data <= cpu_dout;
        if( tidata2_cs ) ti2_data <= cpu_dout;
    end
end

jt89 u_ti1(
    .rst    ( rst           ),
    .clk    ( clk           ),
    .clk_en ( ti1_cen       ),
    .wr_n   ( rdy1          ),
    .cs_n   ( ~ti1_cs       ),
    .din    ( ti1_data      ),
    .sound  ( ti1_snd       ),
    .ready  ( rdy1          )
);

jt89 u_ti2(
    .rst    ( rst           ),
    .clk    ( clk           ),
    .clk_en ( ti2_cen       ),
    .wr_n   ( rdy2          ),
    .cs_n   ( ~ti2_cs       ),
    .din    ( ti2_data      ),
    .sound  ( ti2_snd       ),
    .ready  ( rdy2          )
);

jtframe_sys6809 #(.RAM_AW(0)) u_cpu(
    .rstn       ( ~rst      ),
    .clk        ( clk       ),
    .cen        ( cpu4_cen  ),   // This is normally the input clock to the CPU
    .cpu_cen    ( cpu_cen   ),   // 1/4th of cen -> 3MHz

    // Interrupts
    .nIRQ       ( irq_n     ),
    .nFIRQ      ( 1'b1      ),
    .nNMI       ( nmi_n     ),
    .irq_ack    (           ),
    // Bus sharing
    .bus_busy   ( 1'b0      ),
    // memory interface
    .A          ( A         ),
    .RnW        ( RnW       ),
    .VMA        ( VMA       ),
    .ram_cs     ( 1'b0      ),
    .rom_cs     ( rom_cs    ),
    .rom_ok     ( rom_ok    ),
    // Bus multiplexer is external
    .ram_dout   (           ),
    .cpu_dout   ( cpu_dout  ),
    .cpu_din    ( cpu_din   )
);


jtframe_mixer #(.W0(11),.W1(11)) u_mixer(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .cen    ( ti1_cen   ),
    // input signals
    .ch0    ( ti1_snd   ),
    .ch1    ( ti2_snd   ),
    .ch2    ( 16'd0     ),
    .ch3    ( 16'd0     ),
    // gain for each channel in 4.4 fixed point format
    .gain0  ( 8'h18     ),
    .gain1  ( 8'h18     ),
    .gain2  ( 8'h00     ),
    .gain3  ( 8'h00     ),
    .mixed  ( snd       ),
    .peak   ( peak      )
);

endmodule
