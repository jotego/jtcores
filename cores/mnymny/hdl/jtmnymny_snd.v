/*  jtmnymny_snd.v — Zaccaria 1B11142 sound board
    Melody 6802 + PIA + 2x AY-3-8910, speech/effects 6802 + PIA + MC1408 DAC.
    TMS5200 not modelled yet: PIA port A reads 0, READY high, /INT high.
    GPL3 — see jtcores LICENSE
*/

module jtmnymny_snd(
    input               rst,
    input               clk,
    input               mcpu_cen,     // 3.5795 MHz (jt680x cen = 4x E)
    input               psg_cen,      // 1.7898 MHz
    input               ressound,     // from main LS259 (active high = reset)
    input       [ 7:0]  snd_latch,    // S0..S7 from the I/O board
    output              acs,
    // melody program ROM (SDRAM)
    output reg          melody_cs,
    output      [13:0]  melody_addr,
    input       [ 7:0]  melody_data,
    input               melody_ok,
    // speech program ROM (SDRAM)
    output reg          speech_cs,
    output      [13:0]  speech_addr,
    input       [ 7:0]  speech_data,
    input               speech_ok,
    // sound channels (filtering done at the top level)
    output      [ 7:0]  ay4g_a, ay4g_b, ay4g_c,
    output      [ 7:0]  ay4h_a, ay4h_b, ay4h_c,
    output reg  [ 7:0]  dac,
    output      [ 4:0]  ioa,          // tromba vol 2:0, cassa gate 3, rullante gate 4
    output              level, levelt, sw1
);

wire srst = rst | ressound;

// ---------------------------------------------------------------- melody CPU
wire [15:0] mA;
wire [ 7:0] m_dout, mpia_dout, ay4g_dout, ay4h_dout;
wire        m_wr;
reg  [ 7:0] m_din, m_ram[0:127];
reg  [ 7:0] melody_cmd;              // 2G LS374 on the speech CPU side
reg  [12:0] timebase;                // 4040 + LS74: E/8192 on CB1
wire        mpia_cs, m_ram_cs, mpia_irqa_n, mpia_irqb_n;
wire [ 7:0] mpia_pa_out, mpia_pb_out, mpia_pa_in;
reg  [ 7:0] m_ram_dout;

assign mpia_cs     = mA[15:13]==3'b010 && mA[3:2]==2'b11;   // 6I LS156, 400C
assign m_ram_cs    = mA[15:7]==0;                           // 6802 internal RAM
assign melody_addr = { mA[14], mA[12:0] };                  // 13=ROM13(8000), 9=ROM9(C000)

always @* begin
    melody_cs = mA[15];              // /CS4A + /CS5A
    m_din = melody_cs ? melody_data :
            mpia_cs   ? mpia_dout   :
            m_ram_cs  ? m_ram_dout  : 8'hff;
end

always @(posedge clk) if( mcpu_cen ) begin
    timebase <= timebase + 1'd1;
    if( m_ram_cs && m_wr ) m_ram[mA[6:0]] <= m_dout;
    m_ram_dout <= m_ram[mA[6:0]];
end

// PIA port A talks to both AYs, port B carries BC1/BDIR pairs
assign mpia_pa_in = ( mpia_pb_out[1:0]==2'b01 ? ay4g_dout : 8'hff ) &
                    ( mpia_pb_out[3:2]==2'b01 ? ay4h_dout : 8'hff );

jtmnymny_6821 u_mpia(
    .rst    ( srst          ),
    .clk    ( clk           ),
    .cen    ( mcpu_cen      ),
    .cs     ( mpia_cs       ),
    .rs     ( mA[1:0]       ),
    .rnw    ( ~m_wr         ),
    .din    ( m_dout        ),
    .dout   ( mpia_dout     ),
    .pa_in  ( mpia_pa_in    ),
    .pa_out ( mpia_pa_out   ),
    .pa_oe  (               ),
    .pb_in  ( 8'hff         ),
    .pb_out ( mpia_pb_out   ),
    .pb_oe  (               ),
    .ca1    ( melody_cmd[7] ),
    .ca2_in ( 1'b1          ),
    .ca2_out(               ),
    .cb1    ( timebase[12]  ),
    .cb2_in ( 1'b1          ),
    .cb2_out(               ),
    .irqa_n ( mpia_irqa_n   ),
    .irqb_n ( mpia_irqb_n   )
);

jt680x u_mcpu(
    .rst      ( srst        ),
    .clk      ( clk         ),
    .cen      ( mcpu_cen    ),
    .wr       ( m_wr        ),
    .addr     ( mA          ),
    .din      ( m_din       ),
    .dout     ( m_dout      ),
    .ext_halt ( 1'b0        ),
    .ba       (             ),
    .irq      ( ~mpia_irqb_n),
    .nmi      ( ~mpia_irqa_n),
    .irq_icf  ( 1'b0        ),
    .irq_ocf  ( 1'b0        ),
    .irq_tof  ( 1'b0        ),
    .irq_sci  ( 1'b0        ),
    .irq_cmf  ( 1'b0        ),
    .irq2     ( 1'b0        )
);

wire [7:0] ay4g_ioa, ay4h_ioa, ay4h_iob;
assign ioa    = ay4g_ioa[4:0];
assign level  = ay4h_ioa[0];
assign levelt = ay4h_ioa[1];
assign sw1    = ay4h_iob[0];

jt49_bus u_ay4g(   // melodypsg1: music + melody_cmd readback on port B
    .rst_n   ( ~srst             ),
    .clk     ( clk               ),
    .clk_en  ( psg_cen           ),
    .bdir    ( mpia_pb_out[1]    ),
    .bc1     ( mpia_pb_out[0]    ),
    .din     ( mpia_pa_out       ),
    .sel     ( 1'b1              ),
    .dout    ( ay4g_dout         ),
    .sound   (                   ),
    .A       ( ay4g_a            ),
    .B       ( ay4g_b            ),
    .C       ( ay4g_c            ),
    .sample  (                   ),
    .IOA_in  ( 8'hff             ),
    .IOA_out ( ay4g_ioa          ),
    .IOA_oe  (                   ),
    .IOB_in  ( melody_cmd        ),
    .IOB_out (                   ),
    .IOB_oe  (                   )
);

jt49_bus u_ay4h(   // melodypsg2: music + level/filter controls
    .rst_n   ( ~srst             ),
    .clk     ( clk               ),
    .clk_en  ( psg_cen           ),
    .bdir    ( mpia_pb_out[3]    ),
    .bc1     ( mpia_pb_out[2]    ),
    .din     ( mpia_pa_out       ),
    .sel     ( 1'b1              ),
    .dout    ( ay4h_dout         ),
    .sound   (                   ),
    .A       ( ay4h_a            ),
    .B       ( ay4h_b            ),
    .C       ( ay4h_c            ),
    .sample  (                   ),
    .IOA_in  ( 8'hff             ),
    .IOA_out ( ay4h_ioa          ),
    .IOA_oe  (                   ),
    .IOB_in  ( 8'hff             ),
    .IOB_out ( ay4h_iob          ),
    .IOB_oe  (                   )
);

// ----------------------------------------------------------------- speech CPU
wire [15:0] sA;
wire [ 7:0] s_dout, spia_dout;
wire        s_wr;
reg  [ 7:0] s_din, s_ram[0:127];
reg  [ 7:0] s_ram_dout;
wire        spia_cs, s_ram_cs, dac_wr, mcmd_wr, host_rd;
wire        spia_irqa_n, spia_irqb_n;
wire [ 7:0] spia_pb_out;

assign spia_cs     = sA[14:12]==0 && sA[7] && sA[4];        // 0090, 4E LS139 + gates
assign s_ram_cs    = sA[15:7]==0;
assign dac_wr      = sA[14:12]==3'b001 && !sA[11] && !sA[10]; // 1000
assign mcmd_wr     = sA[13:12]==2'b01 && !sA[11] &&  sA[10];  // 1400
assign host_rd     = sA[13:12]==2'b01 &&  sA[11] && !sA[10];  // 1800
assign speech_addr = { sA[12], sA[14], sA[11:0] };          // ROM8/ROM7, A12 pin = A14

always @* begin
    speech_cs = sA[13];              // /CS0A + /CS1A
    s_din = speech_cs ? speech_data :
            spia_cs   ? spia_dout   :
            host_rd   ? snd_latch   :
            s_ram_cs  ? s_ram_dout  : 8'hff;
end

always @(posedge clk, posedge srst) begin
    if( srst ) begin
        dac        <= 0;
        melody_cmd <= 0;
    end else if( mcpu_cen ) begin
        if( s_wr && dac_wr  ) dac        <= s_dout;
        if( s_wr && mcmd_wr ) melody_cmd <= s_dout;
    end
end

always @(posedge clk) if( mcpu_cen ) begin
    if( s_ram_cs && s_wr ) s_ram[sA[6:0]] <= s_dout;
    s_ram_dout <= s_ram[sA[6:0]];
end

assign acs = ~spia_pb_out[3];

// TMS5200 stub on port A / CB1 / CA2
jtmnymny_6821 u_spia(
    .rst    ( srst          ),
    .clk    ( clk           ),
    .cen    ( mcpu_cen      ),
    .cs     ( spia_cs       ),
    .rs     ( sA[1:0]       ),
    .rnw    ( ~s_wr         ),
    .din    ( s_dout        ),
    .dout   ( spia_dout     ),
    .pa_in  ( 8'h00         ),
    .pa_out (               ),
    .pa_oe  (               ),
    .pb_in  ( 8'hff         ),
    .pb_out ( spia_pb_out   ),
    .pb_oe  (               ),
    .ca1    ( 1'b0          ),
    .ca2_in ( 1'b1          ),
    .ca2_out(               ),
    .cb1    ( 1'b1          ),
    .cb2_in ( 1'b1          ),
    .cb2_out(               ),
    .irqa_n ( spia_irqa_n   ),
    .irqb_n ( spia_irqb_n   )
);

jt680x u_scpu(
    .rst      ( srst        ),
    .clk      ( clk         ),
    .cen      ( mcpu_cen    ),
    .wr       ( s_wr        ),
    .addr     ( sA          ),
    .din      ( s_din       ),
    .dout     ( s_dout      ),
    .ext_halt ( 1'b0        ),
    .ba       (             ),
    .irq      ( ~snd_latch[7] | ~spia_irqb_n | ~spia_irqa_n ),
    .nmi      ( 1'b0        ),
    .irq_icf  ( 1'b0        ),
    .irq_ocf  ( 1'b0        ),
    .irq_tof  ( 1'b0        ),
    .irq_sci  ( 1'b0        ),
    .irq_cmf  ( 1'b0        ),
    .irq2     ( 1'b0        )
);

endmodule
