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

    Author: niknak
    Version: 1.0
    Date: 2-8-2026 */

/*  JTSHARRIER — I/O board: 2x i8255 PPI (jt8255) + inputs + ADC

    PPI0 (0x140000):
      port A out -> sound command latch
      port B out -> lamps / coin counters
      port C     -> sound handshake (NMI pulse to Z80)
    PPI1 (0x140020):
      port A out -> sub control: bit5 RESET, bit6 IRQ4, bits2-3 ADC channel
      port C in  -> ADC status
    Inputs (0x140010): service/coin/start/fire (digital)
    ADC (0x140031): analog flight stick, channel from PPI1 port A[3:2]
*/

module jtsharrier_io(
    input             rst,
    input             clk,
    input             cen,

    // main CPU bus (byte side, D0-7)
    input      [ 2:1] addr,        // A2..A1 -> PPI register select
    input      [ 7:0] cpu_dout,
    input             rnw,
    // LDSWn from main.v: the RnW-qualified lower data strobe, meaning "write data
    // is valid on D0-7 right now". The PPI/ADC live at ODD addresses
    // (140001/3/5/7, 140031), which on a big-endian 68000 is the LOWER byte, so
    // LDS is the strobe that matters here.
    input             dswn,
    input             ppi0_cs,
    input             ppi1_cs,
    input             inp_cs,
    input             adc_cs,
    output reg [ 7:0] io_data,

    // cabinet inputs (from framework). Bit map is in jtsharrier_game.v.
    input      [ 7:0] cab_in,       // SERVICE port: coin/service/start/fire, active low
    input      [ 7:0] dip_swa,      // COINAGE dips (SWA)
    input      [ 7:0] dip_swb,      // game dips (SWB) — bit0 = Cabinet (0=Upright,1=Moving)
    input      [ 7:0] an_x,         // flight stick X (analog, 0..255)
    input      [ 7:0] an_y,         // flight stick Y

    // control outputs
    output     [ 7:0] snd_latch,
    output reg        snd_nmi,      // 1-clk pulse when a command is posted
    output            sub_rstn,     // 0 = hold sub in reset
    output            sub_irqn,     // 0 = assert sub IRQ4
    output     [ 7:0] lamps,

    // PPI0 port C drives SCONT0 and SCONT1 on the CPU board, the tilemap's row
    // and column scroll enables:
    //   bit1 = SCONT0 = row scroll,  bit2 = SCONT1 = column scroll
    // Enabled when the bit is low (segahang.cpp inverts it), so they are
    // inverted here and exposed active high.
    output            colscr_en,
    output            rowscr_en
);

wire        wr = ~rnw & ~dswn;
wire [ 7:0] ppi0_a, ppi0_b, ppi0_c, ppi0_pc, ppi1_a, ppi1_c;

// ---- PPI0 -----------------------------------------------------------------
jt8255 u_ppi0(
    .rst      ( rst      ), .clk ( clk ),
    .addr     ( addr     ),
    .din      ( cpu_dout ),
    .dout     ( ppi0_c   ),   // read path muxed below (dout follows selected port)
    .rdn      ( ~(ppi0_cs & rnw) ),
    .wrn      ( ~(ppi0_cs & wr ) ),
    .csn      ( ~ppi0_cs ),
    .porta_din( 8'hff    ), .portb_din( 8'hff ), .portc_din( 8'hff ),
    .porta_dout( ppi0_a  ), .portb_dout( ppi0_b ), .portc_dout( ppi0_pc )
);
assign snd_latch = ppi0_a;
assign lamps     = ppi0_b;

// Column/row scroll enables from PPI0 port C (SCONT1/SCONT0), active low.
assign colscr_en = ~ppi0_pc[2];
assign rowscr_en = ~ppi0_pc[1];

// NMI pulse when main writes PPI0 port A (register 0).
reg ppi0_pa_wr_d;
wire ppi0_pa_wr = ppi0_cs & wr & (addr==2'd0);
always @(posedge clk) begin
    ppi0_pa_wr_d <= ppi0_pa_wr;
    snd_nmi      <= ppi0_pa_wr & ~ppi0_pa_wr_d;   // rising edge -> 1-clk pulse
end

// ---- PPI1 -----------------------------------------------------------------
jt8255 u_ppi1(
    .rst      ( rst      ), .clk ( clk ),
    .addr     ( addr     ),
    .din      ( cpu_dout ),
    .dout     ( ppi1_c   ),
    .rdn      ( ~(ppi1_cs & rnw) ),
    .wrn      ( ~(ppi1_cs & wr ) ),
    .csn      ( ~ppi1_cs ),
    .porta_din( 8'hff    ), .portb_din( 8'hff ),
    .portc_din( ppi1_portc ),        // bit6 = ADC0804 /INTR (conversion done)
    .porta_dout( ppi1_a  ), .portb_dout( ), .portc_dout( )
);
// sub control (polarity per MAME sub_control_adc_w):
//   bit5=1 asserts RESET  -> sub_rstn = ~bit5
assign sub_rstn = ~ppi1_a[5];
assign sub_irqn =  ppi1_a[6];
wire [1:0] adc_ch = ppi1_a[3:2];

// ---- ADC (flight stick) ----------------------------------------------------
// Channel map from segahang.cpp INPUT_PORTS: ADC0 = X axis, ADC1 = Y axis,
// both IPT_AD_STICK with PORT_MINMAX(0x20,0xe0) and a 0x80 centre.
//
wire [7:0] adc_val = adc_ch[1] ? 8'h00 :        // ch2/ch3: not populated
                     adc_ch[0] ? an_y : an_x;   // ch0 = X, ch1 = Y

// ADC0804 /INTR on PPI1 port C bit6. Space Harrier never reads it -- the MCU
// writes the channel, strobes a conversion and takes the result without
// polling. Modelled anyway for the other games on this board.
reg       adc_intr_n;      // 1 = converting (busy), 0 = done
reg [8:0] adc_cnt;
always @(posedge clk) begin
    if( rst ) begin
        adc_intr_n <= 1'b0;
        adc_cnt    <= 9'd0;
    end else if( cen ) begin
        if( adc_cs & wr ) begin        // conversion start
            adc_intr_n <= 1'b1;
            adc_cnt    <= 9'd320;      // ~conversion time (arbitrary, non-zero)
        end else if( adc_cnt != 0 ) begin
            adc_cnt <= adc_cnt - 1'b1;
            if( adc_cnt == 9'd1 ) adc_intr_n <= 1'b0;   // done
        end
    end
end
wire [7:0] ppi1_portc = { 1'b1, adc_intr_n, 6'h3f };   // bit6 = /INTR, rest pulled high

// ---- main-side read mux ---------------------------------------------------
always @(*) begin
    io_data = 8'hff;
    if( ppi0_cs ) io_data = ppi0_c;   // jt8255 dout reflects selected register
    if( ppi1_cs ) io_data = ppi1_c;
    // sharrier_inputs_r @0x140010-17: addr[2:1] selects SERVICE/UNKNOWN/COINAGE/DSW.
    // The DSW read must return the real dips: bit0 (Cabinet) reads 0=Upright, else
    // the boot runs the moving-cabinet motor warm-up and stalls waiting on hydraulics.
    if( inp_cs ) case( addr[2:1] )
        2'd0: io_data = cab_in;    // SERVICE: coin/service/start/fire (active low)
        2'd1: io_data = 8'hff;     // UNKNOWN
        2'd2: io_data = dip_swa;   // COINAGE (SWA)
        2'd3: io_data = dip_swb;   // DSW (SWB)
    endcase
    if( adc_cs  ) io_data = adc_val;
end

endmodule
