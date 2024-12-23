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
    Date: 3-10-2020 */

// Clocks are derived from H counter on the original PCB
// Yet, that doesn't seem to be important and it only
// matters the frequency of the signals:
// E,Q: 3 MHz
// Q is 1/4th of wave advanced

module jtlabrun_main(
    input               clk,        // 24 MHz
    input               rst,
    input               cen12,
    input               cen3,
    output              cpu_cen,
    // ROM
    output reg  [16:0]  rom_addr,
    output reg          rom_cs,
    input       [ 7:0]  rom_data,
    input               rom_ok,
    // cabinet I/O
    input       [ 1:0]  cab_1p,
    input       [ 1:0]  coin,
    input       [ 5:0]  joystick1,
    input       [ 5:0]  joystick2,
    input               service,
    // GFX
    output reg  [13:0]  gfx_addr,
    output              cpu_rnw,
    output      [ 7:0]  cpu_dout,
    input               gfx_irqn,
    input               gfx_nmin,
    output reg          gfx_cs,
    output reg          pal_cs,

    input      [7:0]    gfx_dout,
    input      [7:0]    pal_dout,
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

localparam RAM_AW = 11;

wire [ 7:0] ram_dout, prot_dout, ym0_dout, ym1_dout;
wire [15:0] A;
wire        RnW, irq_n, irq_ack;
wire        irq_trigger;
reg         bank_cs, in_cs, pre_gfx, pre_cfg, ym0_cs, ym1_cs, ram_cs, prot_cs, sys_cs;
reg  [ 2:0] bank;
reg  [ 7:0] port_in, cpu_din, cabinet;
wire [ 9:0] psg0_snd, psg1_snd;
wire        fm0_irq_n, fm1_irq_n;
wire        VMA;

wire signed [15:0] fm0_snd, fm1_snd;

assign irq_trigger = ~gfx_irqn & dip_pause;
assign cpu_rnw     = RnW;

always @(*) begin
    rom_cs  = (A[15] || A[15:14]==2'b01) && RnW && VMA;
    ram_cs  = A[15:11] == 5'b00011; // 18xx-1fxx
    pre_gfx = A[15:13] == 3'b001; // 2xxx 3xxx
    pre_cfg = A[15:8] == 8'd0;
    pal_cs  = A[15:11] == 5'b00010; // 10xx-17xx
    ym0_cs  = 0;
    ym1_cs  = 0;
    bank_cs = 0;
    in_cs   = 0;
    prot_cs = 0;
    sys_cs  = 0;
    if( A[15:12]==4'd0 && A[11] ) begin
        case(A[10:8])
            3'd0: ym0_cs  = VMA;
            3'd1: ym1_cs  = VMA;
            3'd2: in_cs   = RnW;
            3'd3: sys_cs  = RnW;
            3'd4: bank_cs = !RnW;
            3'd5: prot_cs = 1;
            // 3'd6:  // watchdog
            default:;
        endcase
    end
end

always @(posedge clk) begin
    gfx_cs   <= pre_gfx | pre_cfg;
    gfx_addr <= { pre_gfx, ~A[12] & pre_gfx, A[11:0] };
end

always @(*) begin
    rom_addr = A[15] ? { 2'b00, A[14:0] } : { bank+3'b10, A[13:0] }; // 14+3=17
end

wire [7:0] sys_dout ={ ~5'd0, service, coin };

always @(posedge clk) begin
    cabinet <= A[0] ? {cab_1p[0],1'b1, joystick1[5:4], joystick1[2], joystick1[3], joystick1[0], joystick1[1]} :
                      {cab_1p[1],1'b1, joystick2[5:4], joystick2[2], joystick2[3], joystick2[0], joystick2[1]};
    cpu_din <= rom_cs ? rom_data : (
               ram_cs ? ram_dout : (
               gfx_cs ? gfx_dout : (
               in_cs  ? cabinet  : (
               ym0_cs ? ym0_dout : (
               ym1_cs ? ym1_dout : (
               sys_cs ? sys_dout :
               pal_cs ? pal_dout : (
               prot_cs? prot_dout : 8'hff )))))));
end

always @(posedge clk) begin
    if( rst ) begin
        bank      <= 3'd0;
    end else if(cpu_cen) begin
        if( bank_cs ) bank <= cpu_dout[2:0];
    end
end

jtframe_ff u_ff(
    .clk      ( clk         ),
    .rst      ( rst         ),
    .cen      ( 1'b1        ),
    .din      ( 1'b1        ),
    .q        (             ),
    .qn       ( irq_n       ),
    .set      (             ),    // active high
    .clr      ( irq_ack     ),    // active high
    .sigedge  ( irq_trigger )     // signal whose edge will trigger the FF
);

jtframe_sys6809 #(.RAM_AW(RAM_AW)) u_cpu(
    .rstn       ( ~rst      ),
    .clk        ( clk       ),
    .cen        ( cen12     ),   // This is normally the input clock to the CPU
    .cpu_cen    ( cpu_cen   ),   // 1/4th of cen -> 3MHz

    // Interrupts
    .nIRQ       ( irq_n     ),
    .nFIRQ      ( 1'b1      ),
    .nNMI       ( gfx_nmin  ),
    .irq_ack    ( irq_ack   ),
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

jt051733 u_prot(
    .clk    ( clk       ),
    .rst    ( rst       ),
    .cen    ( cpu_cen   ),
    .addr   ( A[4:0]    ),
    .wr_n   ( RnW       ),
    .cs     ( prot_cs   ),
    .din    ( cpu_dout  ),
    .dout   ( prot_dout )
);

wire fm_wrn = RnW | ~cpu_cen;

jt03 u_fm0(
    .rst        ( rst        ),
    // CPU interface
    .clk        ( clk        ),
    .cen        ( cen3       ),
    .din        ( cpu_dout   ),
    .addr       ( ~A[0]      ),
    .cs_n       ( ~ym0_cs    ),
    .wr_n       ( fm_wrn     ),
    .psg_snd    ( psg0_snd   ),
    .fm_snd     ( fm0_snd    ),
    .snd_sample ( sample     ),
    .dout       ( ym0_dout   ),
    .IOA_in     ( dipsw_a    ),
    .IOB_in     ( dipsw_b    ),
    // unused outputs
    .irq_n      ( fm0_irq_n  ),
    .psg_A      (            ),
    .psg_B      (            ),
    .psg_C      (            ),
    .IOA_out    (            ),
    .IOB_out    (            ),
    .IOA_oe     (            ),
    .IOB_oe     (            ),
    .snd        (            ),
    .debug_view (            )
);

jt03 u_fm1(
    .rst        ( rst        ),
    // CPU interface
    .clk        ( clk        ),
    .cen        ( cen3       ),
    .din        ( cpu_dout   ),
    .addr       ( ~A[0]      ),
    .cs_n       ( ~ym1_cs    ),
    .wr_n       ( fm_wrn     ),
    .psg_snd    ( psg1_snd   ),
    .fm_snd     ( fm1_snd    ),
    .snd_sample (            ),
    .dout       ( ym1_dout   ),
    .IOA_in     ( 8'hff      ),
    .IOB_in     ( { 4'hf, dipsw_c } ),
    // unused outputs
    .irq_n      ( fm1_irq_n  ),
    .psg_A      (            ),
    .psg_B      (            ),
    .psg_C      (            ),
    .IOA_out    (            ),
    .IOB_out    (            ),
    .IOA_oe     (            ),
    .IOB_oe     (            ),
    .snd        (            ),
    .debug_view (            )
);

wire [10:0] psg_snd = {1'b0,psg0_snd} + {1'b0,psg1_snd};
wire signed [10:0] psg2x;

jt49_dcrm2 #(.sw(11)) u_dcrm (
    .rst    (  rst      ),
    .clk    (  clk      ),
    .cen    (  cen3     ),
    .din    (  psg_snd  ),
    .dout   (  psg2x    )
);

`ifndef NOSOUND
jtframe_mixer #(.W0(16),.W1(16),.W2(11)) u_mixer(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .cen    ( cen3      ),
    // input signals
    .ch0    ( fm0_snd   ),
    .ch1    ( fm1_snd   ),
    .ch2    ( psg2x     ),
    .ch3    (           ),
    // gain for each channel in 4.4 fixed point format
    .gain0  ( 8'hF0     ),
    .gain1  ( 8'hF0     ),
    .gain2  ( 8'hC0     ),
    .gain3  ( 8'h00     ),
    .mixed  ( snd       ),
    .peak   ( peak      )
);
`else
assign snd  = 0;
assign peak = 0;
`endif

endmodule
