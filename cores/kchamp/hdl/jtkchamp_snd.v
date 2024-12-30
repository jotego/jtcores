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
    Date: 2-9-2022 */

module jtkchamp_snd(
    input              rst,
    input              clk,
    input              cen_3,
    input              pcm_cen,
    input              psg_cen,

    input              enc,
    input              v6,

    input       [ 7:0] snd_latch,
    input              snd_req,
    input              snd_rstn,

    // ROM access
    output reg         rom_cs,
    output      [15:0] rom_addr,
    input       [ 7:0] rom_data,
    input              rom_ok,

    output     signed [11:0] pcm,
    output reg signed [ 7:0] dac,
    output            [ 7:0] psg0a,
    output            [ 8:0] psg0bc,
    output            [ 9:0] psg1
);
`ifndef NOSOUND
// localparam [7:0] PSG_GAIN = 8'h04,
//                  PCM_GAIN = 8'h0c,
//                  DAC_GAIN = 8'h02;

wire        m1_n, mreq_n, iorq_n, rd_n, wr_n,
            wcen, vcen, int_n, tempo_n;
reg         nmi_on, iord_cs, iowr_cs, pcm_cs, ctrl_cs,
            latch_cs, dac_cs, pcm_nmin;
reg  [ 7:0] cpu_din, pcm_data;
wire [ 7:0] psg0_dout, psg1_dout, psg0b, psg0c;
reg  [ 1:0] ctrl;
wire [15:0] A;
wire [ 7:0] ram_dout, cpu_dout;
wire [ 3:0] pcm_din;
reg         ram_cs, pcm_sel, tempo_en;
reg  [ 1:0] bdir, bc1;
// sound signals
wire        nmi_n;
reg         reset;

always @(posedge clk) reset <= rst | ~snd_rstn;

assign rom_addr = A;
assign pcm_din  = pcm_sel ? pcm_data[7:4] : pcm_data[3:0];
assign nmi_n    = enc ? pcm_nmin : tempo_n;
assign psg0bc   = {1'b0,psg0b}+{1'b0,psg0c};

always @* begin
    iord_cs   = !iorq_n && !rd_n;
    iowr_cs   = !iorq_n && !wr_n;
    if( enc ) begin
        rom_cs    = !mreq_n && A[14:13]!=3;
        ram_cs    = !mreq_n && A[14:13]==3;
        latch_cs  = iord_cs && A[1:0]==1;
        dac_cs    = 0;
        bc1[0]    = (iowr_cs && A[2:0]==1) || (iord_cs && A[1:0]==0);
        bc1[1]    = (iowr_cs && A[2:0]==3) || (iord_cs && A[1:0]==2);
    end else begin
        rom_cs    = !mreq_n && A[15:13]!=7;
        ram_cs    = !mreq_n && A[15:13]==7;
        latch_cs  = iord_cs && A[2:0]==6;
        dac_cs    = iowr_cs && A[2:0]==4;
        bc1[0]    = iowr_cs && A[2:0]==1;
        bc1[1]    = iowr_cs && A[2:0]==3;
    end
    bdir[0]   = iowr_cs && A[2:1]==0;
    bdir[1]   = iowr_cs && A[2:1]==1;

    pcm_cs    = iowr_cs && A[2:0]==4;
    ctrl_cs   = iowr_cs && A[2:0]==5;
end

always @(posedge clk, posedge reset) begin
    if( reset ) begin
        ctrl     <= 0;
        pcm_data <= 0;
        pcm_sel  <= 0;
        pcm_nmin <= 1;
        tempo_en <= 0;
    end else begin
        // dac_gain <=  enc ? 8'h0 : DAC_GAIN;
        // pcm_gain <= !enc ? 8'h0 : PCM_GAIN;
        if( dac_cs ) dac <= cpu_dout-8'd127;
        if( pcm_cs  ) pcm_data <= cpu_dout;
        if( ctrl_cs ) begin
            ctrl     <= cpu_dout[1:0];
            tempo_en <= cpu_dout[7];
        end
        if( vcen    ) begin
            pcm_sel <= ~pcm_sel;
            if( !pcm_sel ) pcm_nmin <= 0;
        end
        if( !ctrl[1] ) pcm_nmin <= 1;
    end
end

always @* begin
    cpu_din = rom_cs   ? rom_data  :
              ram_cs   ? ram_dout  :
              bc1[0]   ? psg0_dout :
              bc1[1]   ? psg1_dout :
              latch_cs ? snd_latch : 8'hff;
end

jtframe_ff u_int (
    .clk    (clk     ),
    .rst    (reset   ),
    .cen    (1'b1    ),
    .din    (1'b1    ),
    .q      (        ),
    .qn     (int_n   ),
    .set    (        ),
    .clr    (latch_cs),
    .sigedge(snd_req )
);

jtframe_ff u_nmi (
    .clk    (clk     ),
    .rst    (reset   ),
    .cen    (1'b1    ),
    .din    (1'b1    ),
    .q      (        ),
    .qn     ( tempo_n),
    .set    (        ),
    .clr    (~tempo_en),
    .sigedge( v6     )
);

jtframe_sysz80 #(.RAM_AW(11),.RECOVERY(1)) u_cpu(
    .rst_n      ( ~reset    ),
    .clk        ( clk       ),
    .cen        ( cen_3     ),
    .cpu_cen    (           ),
    .int_n      ( int_n     ),
    .nmi_n      ( nmi_n     ), // tempo
    .busrq_n    ( 1'b1      ),
    .m1_n       ( m1_n      ),
    .mreq_n     ( mreq_n    ),
    .iorq_n     ( iorq_n    ),
    .rd_n       ( rd_n      ),
    .wr_n       ( wr_n      ),
    .rfsh_n     (           ),
    .halt_n     (           ),
    .busak_n    (           ),
    .A          ( A         ),
    .cpu_din    ( cpu_din   ),
    .cpu_dout   ( cpu_dout  ),
    .ram_dout   ( ram_dout  ),
    // ROM access
    .ram_cs     ( ram_cs    ),
    .rom_cs     ( rom_cs    ),
    .rom_ok     ( rom_ok    )
);

jt49_bus u_psg0(
    .rst_n      (  ~reset   ),
    .clk        (   clk     ),
    .clk_en     (   psg_cen ),
    // bus control pins of original chip
    .bdir       (   bdir[0] ),
    .bc1        (   bc1[0]  ),
    .din        ( cpu_dout  ),

    .sel        ( 1'b1      ), // if sel is low, the clock is divided by 2
    .dout       ( psg0_dout ),
    .A          ( psg0a     ),
    .B          ( psg0b     ),
    .C          ( psg0c     ),

    // Unused
    .sound      (           ),  // combined channel output
    .sample     (           ),
    .IOA_in     ( 8'd0      ),
    .IOA_out    (           ),
    .IOA_oe     (           ),
    .IOB_in     ( 8'd0      ),
    .IOB_out    (           ),
    .IOB_oe     (           )
);

jt49_bus u_psg1(
    .rst_n      (  ~reset   ),
    .clk        (   clk     ),
    .clk_en     (   psg_cen ),
    // bus control pins of original chip
    .bdir       (   bdir[1] ),
    .bc1        (   bc1[1]  ),
    .din        ( cpu_dout  ),

    .sel        ( 1'b1      ), // if sel is low, the clock is divided by 2
    .dout       ( psg1_dout ),
    .sound      ( psg1      ),  // combined channel output
    .sample     (           ),

    // Unused
    .A          (           ),
    .B          (           ),
    .C          (           ),
    .IOA_in     ( 8'd0      ),
    .IOA_out    (           ),
    .IOA_oe     (           ),
    .IOB_in     ( 8'd0      ),
    .IOB_out    (           ),
    .IOB_oe     (           )
);

jt5205 u_pcm(
    .rst        ( ~ctrl[0]  ),
    .clk        ( clk       ),
    .cen        ( pcm_cen   ),
    .sel        ( 2'd0      ),
    .din        ( pcm_din   ),
    .sound      ( pcm       ),
    .sample     (           ),
    .vclk_o     ( vcen      ),
    .irq        (           )
);
`else
    assign rom_cs   = 0;
    assign rom_addr = 0;
    assign pcm      = 0;
    assign dac      = 0;
    assign psg0a    = 0;
    assign psg0bc   = 0;
    assign psg1     = 0;
`endif
endmodule