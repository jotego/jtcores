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
    Date: 25-8-2021 */

// Clocks are derived from H counter on the original PCB
// Yet, that doesn't seem to be important and it only
// matters the frequency of the signals:
// E,Q: 3 MHz
// Q is 1/4th of wave advanced

module jtflane_main(
    input               rst,
    input               clk,        // 24 MHz
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
    output      [13:0]  gfx_addr,
    output              cpu_rnw,
    output      [ 7:0]  cpu_dout,
    input               gfx_irqn,
    input               gfx_nmin,
    output reg          gfx_cs,
    input               pal_cs,

    input      [7:0]    gfx_dout,
    input      [7:0]    pal_dout,
    // DIP switches
    input               dip_pause,
    input      [7:0]    dipsw_a,
    input      [7:0]    dipsw_b,
    input      [3:0]    dipsw_c,

    // ADPCM ROM
    output       [16:0] pcma_addr,
    input        [ 7:0] pcma_dout,
    output              pcma_cs,
    input               pcma_ok,

    output       [16:0] pcmb_addr,
    input        [ 7:0] pcmb_dout,
    output              pcmb_cs,
    input               pcmb_ok,

    output       [18:0] pcmc_addr,
    input        [ 7:0] pcmc_dout,
    output              pcmc_cs,
    input               pcmc_ok,

    output       [18:0] pcmd_addr,
    input        [ 7:0] pcmd_dout,
    output              pcmd_cs,
    input               pcmd_ok,

    // Sound
    output signed [15:0] snd,
    output               sample,
    output               peak
);

wire [ 7:0] prot_dout, ram_dout;
wire [15:0] A;
wire        RnW, irq_n, irq_ack;
wire        irq_trigger;
reg         bank_cs, in_cs, io_cs, prot_cs, sys_cs, ram_cs;
reg  [ 1:0] bank;
reg         pcm_msb, pcm0_cs, pcm1_cs;
reg  [ 7:0] port_in, cpu_din, cabinet;
wire        VMA, cen_fm;
wire signed [11:0] pcm0_snd, pcm1_snd;

assign irq_trigger = ~gfx_irqn & dip_pause;
assign cpu_rnw     = RnW;
assign gfx_addr    = A[13:0];
assign sample      = 0;

assign pcmc_addr[18:17] = {1'b0, pcm_msb};
assign pcmd_addr[18:17] = {1'b1, pcm_msb};

always @(*) begin
    rom_cs  = A[15:12] >= 4 && RnW && VMA;
    io_cs   = A[15:12] == 0 && A[11];
    ram_cs  = A[15:12] == 1 && A[11];
    gfx_cs  = A[15:12] <  4 && !io_cs && !ram_cs;

    in_cs   = 0;
    sys_cs  = 0;
    bank_cs = 0;
    pcm0_cs = 0;
    pcm1_cs = 0;
    prot_cs = 0;
    if( io_cs ) begin
        case(A[10:8])
            0: in_cs   = RnW;
            1: sys_cs  = RnW;
            4: bank_cs = !RnW;
            5: pcm0_cs = 1;
            6: pcm1_cs = 1;
            7: prot_cs = 1;
            default:;
        endcase
    end
end

always @(*) begin
    rom_addr = A[15] ? { 2'b00, A[14:0] } : 16'h8000 + { 1'b0, bank, A[13:0] };
end

wire [7:0] sys_dout = A[0] ? dipsw_b :dipsw_a;

always @(posedge clk) begin
    case( A[1:0] )
        0: cabinet <= { 4'hf, dipsw_c };
        1: cabinet <= {2'b11, joystick2[5:0]};
        2: cabinet <= {2'b11, joystick1[5:0]};
        3: cabinet <= { ~3'd0, cab_1p, service, coin };
    endcase
    cpu_din <= rom_cs ? rom_data  :
               ram_cs ? ram_dout  :
               pal_cs ? pal_dout  :     // pal_cs has priority over gfx_cs
               gfx_cs ? gfx_dout  :
               in_cs  ? cabinet   :
               sys_cs ? sys_dout  :
               prot_cs? prot_dout : 8'hff;
end

always @(posedge clk) begin
    if( rst ) begin
        bank      <= 0;
        pcm_msb   <= 0;
    end else if(cpu_cen) begin
        if( bank_cs ) begin
            bank    <= cpu_dout[3:2];
            pcm_msb <= cpu_dout[4];
        end
    end
end

jtframe_cen3p57 #(.CLK24(1)) u_cen(
    .clk        ( clk       ),
    .cen_3p57   ( cen_fm    ),
    .cen_1p78   (           )
);

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

jtframe_sys6809 #(.RAM_AW(11)) u_cpu(
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
    .rst    ( rst       ),
    .clk    ( clk       ),
    .cen    ( cpu_cen   ),
    .addr   ( A[4:0]    ),
    .wr_n   ( RnW       ),
    .cs     ( prot_cs   ),
    .din    ( cpu_dout  ),
    .dout   ( prot_dout )
);

`ifndef NOSOUND
jt007232 #(.INVA0(1)) u_pcm0(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cen        ( cen_fm    ),
    .addr       ( A[3:0]    ),
    .dacs       ( pcm0_cs   ), // active high
    .cen_q      (           ),
    .cen_e      (           ),
    .wr_n       ( RnW       ),
    .din        ( cpu_dout  ),

    .swap_gains ( 1'b0      ),

    // External memory - the original chip
    // only had one bus
    .roma_addr  ( pcma_addr ),
    .roma_dout  ( pcma_dout ),
    .roma_cs    ( pcma_cs   ),
    .roma_ok    ( pcma_ok   ),

    .romb_addr  ( pcmb_addr ),
    .romb_dout  ( pcmb_dout ),
    .romb_cs    ( pcmb_cs   ),
    .romb_ok    ( pcmb_ok   ),
    // sound output - raw
    .snda       (           ),
    .sndb       (           ),
    .snd        ( pcm0_snd  ),
    // debug bus
    .debug_bus  ( 8'd0      ),
    .st_dout    (           )
);

jt007232 #(.INVA0(1)) u_pcm1(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cen        ( cen_fm    ),
    .addr       ( A[3:0]    ),
    .dacs       ( pcm1_cs   ), // active high
    .cen_q      (           ),
    .cen_e      (           ),
    .wr_n       ( RnW       ),
    .din        ( cpu_dout  ),

    .swap_gains ( 1'b0      ),

    // External memory - the original chip
    // only had one bus
    .roma_addr  ( pcmc_addr[16:0] ),
    .roma_dout  ( pcmc_dout ),
    .roma_cs    ( pcmc_cs   ),
    .roma_ok    ( pcmc_ok   ),

    .romb_addr  ( pcmd_addr[16:0] ),
    .romb_dout  ( pcmd_dout ),
    .romb_cs    ( pcmd_cs   ),
    .romb_ok    ( pcmd_ok   ),
    // sound output - raw
    .snda       (           ),
    .sndb       (           ),
    .snd        ( pcm1_snd  ),
    // debug
    .debug_bus  ( 8'd0      ),
    .st_dout    (           )
);

jtframe_mixer #(.W0(12),.W1(12)) u_mixer(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .cen    ( cen3      ),
    // input signals
    .ch0    ( pcm0_snd  ),
    .ch1    ( pcm1_snd  ),
    .ch2    (           ),
    .ch3    (           ),
    // gain for each channel in 4.4 fixed point format
    .gain0  ( 8'h0C     ),
    .gain1  ( 8'h0C     ),
    .gain2  ( 8'h00     ),
    .gain3  ( 8'h00     ),
    .mixed  ( snd       ),
    .peak   ( peak      )
);
`else
    assign snd     = 0;
    assign peak    = 0;
    assign pcma_cs = 0;
    assign pcmb_cs = 0;
    assign pcmc_cs = 0;
    assign pcmd_cs = 0;
`endif

endmodule
