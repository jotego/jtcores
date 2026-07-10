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
    Date: 1-7-2025 */

module jttoki_sound(
    input             rst,
    input             clk,

    input             cabal,
    input             cen_fm, cen_fm2, msm_cen, oki_cen,

    input       [1:0] coin,

    output signed [15:0] fm,
    output signed [13:0] pcm0,
    output signed [13:0] pcm1,

    input       [7:0] rom_data,
    input             rom_ok,
    output     [12:0] rom_addr,
    output            rom_cs,

    input       [7:0] bank_rom_data,
    input             bank_rom_ok,
    output reg [15:0] bank_rom_addr,
    output            bank_rom_cs,

    // OKI 6295 ADPCM
    input       [7:0] pcm_data,
    input             pcm_ok,
    output     [16:0] pcm_addr,
    output            pcm_cs,

    // Cabal MSM5205 ADPCM
    input       [7:0] adpcm1_data,
    input             adpcm1_ok,
    output     [15:0] adpcm1_addr,
    output            adpcm1_cs,

    input       [7:0] adpcm2_data,
    input             adpcm2_ok,
    output     [15:0] adpcm2_addr,
    output            adpcm2_cs,

    input             m68k_sound_cs_2,
    input             m68k_sound_cs_4,
    input             m68k_sound_cs_6,

    input      [15:0] m68k_sound_latch_0,
    input      [15:0] m68k_sound_latch_1,

    output reg   [15:0] z80_sound_latch_0,
    output reg   [15:0] z80_sound_latch_1,
    output reg   [15:0] z80_sound_latch_2
);

wire [15:0] z80_addr, sei80bu_addr;
wire [ 7:0] ym3812_dout, z80_dout;
wire        rom_sel, bank_rom_sel, z80_ram_sel, ym_sel_0, ym_sel_1,
            m68k_latch0_sel, m68k_latch1_sel, pending_set_sel,
            main_data_pending_sel, read_coin_sel, bank_switch_sel, sound_latch0_sel,
            sound_latch1_sel, oki_sel, adpcm0_addr_sel, adpcm1_addr_sel,
            adpcm0_ctl_sel, adpcm1_ctl_sel;
wire        z80_ram_cs, ym_cs_0, ym_cs_1, pending_set_cs;
wire        z80_rd_n, z80_wr_n, z80_mem_acc, z80_mem_wr,
            ym_rd, ym_wr, oki_rd, oki_wr;
wire        z80_wait_cs, z80_wait_ok;

assign z80_mem_acc           = ~z80_mreq_n & z80_rfsh_n;
assign z80_mem_wr            = z80_mem_acc & ~z80_wr_n;
assign rom_sel               = z80_addr[15:0] < 16'h2000;
assign z80_ram_sel           = z80_addr[15:0] >= 16'h2000 && z80_addr[15:0] < 16'h2800;
assign pending_set_sel       = z80_addr[15:0] == 16'h4000;
assign main_data_pending_sel = z80_addr[15:0] == 16'h4012;
assign bank_switch_sel       = z80_addr[15:0] == 16'h4007;
assign ym_sel_0              = z80_addr[15:0] == 16'h4008;
assign ym_sel_1              = z80_addr[15:0] == 16'h4009;
assign m68k_latch0_sel       = z80_addr[15:0] == 16'h4010;
assign m68k_latch1_sel       = z80_addr[15:0] == 16'h4011;
assign read_coin_sel         = z80_addr[15:0] == 16'h4013;
assign sound_latch0_sel      = z80_addr[15:0] == 16'h4018;
assign sound_latch1_sel      = z80_addr[15:0] == 16'h4019;
assign oki_sel               = !cabal && z80_addr[15:0] == 16'h6000;
assign adpcm0_addr_sel       =  cabal && (z80_addr[15:0] == 16'h4005 || z80_addr[15:0] == 16'h4006);
assign adpcm1_addr_sel       =  cabal && (z80_addr[15:0] == 16'h6005 || z80_addr[15:0] == 16'h6006);
assign adpcm0_ctl_sel        =  cabal && z80_addr[15:0] == 16'h401a;
assign adpcm1_ctl_sel        =  cabal && z80_addr[15:0] == 16'h601a;
assign bank_rom_sel          = z80_addr[15:0] >= 16'h8000;
assign ym_rd                 = (ym_sel_0 | (cabal & ym_sel_1)) & ~z80_rd_n;
assign oki_rd                = oki_sel  & ~z80_rd_n;

assign rom_cs                = z80_rfsh_n & rom_sel;
assign z80_ram_cs            = z80_rfsh_n & z80_ram_sel;
assign bank_rom_cs           = z80_rfsh_n & bank_rom_sel;
assign pending_set_cs        = z80_mem_wr  & pending_set_sel;
assign ym_cs_0               = z80_rfsh_n & ym_sel_0;
assign ym_cs_1               = z80_rfsh_n & ym_sel_1;
assign ym_wr                 = z80_mem_wr & (ym_sel_0 | ym_sel_1);
assign oki_wr                = z80_mem_wr & oki_sel;
assign z80_wait_cs           = z80_mem_acc & (rom_sel | bank_rom_sel);
assign z80_wait_ok           = rom_sel ? rom_ok : bank_rom_ok;
assign sei80bu_addr          = {3'd0, rom_addr};
assign rom_addr              = z80_addr[12:0];

wire [7:0] dec_data;
wire       dec_ok;

wire       z80_m1_n;   //m1 low => opcode
wire       z80_mreq_n;
wire       z80_rfsh_n;
wire       z80_m1, z80_rst_n, z80_int_n;

assign z80_m1    = ~z80_m1_n;
assign z80_rst_n = ~rst;
assign z80_int_n = ~(irq_rst10 | irq_rst18);

sei80bu u_sei80bu(
    .clk      ( clk             ),
    .rom_addr ( sei80bu_addr    ),
    .rom_data ( rom_data        ),
    .rom_ok   ( rom_ok          ),
    .rom_cs   ( rom_cs          ),
    .z80_m1   ( z80_m1          ),
    .dec_data ( dec_data        ),
    .dec_ok   ( dec_ok          )
);

reg bank_selected = 1'b0; // switch to data bank

always @(posedge clk) begin
    if (z80_mem_wr & bank_switch_sel)
        bank_selected <= z80_dout[0];
end

always @(*) begin
    if (!bank_selected)
        bank_rom_addr = z80_addr[15:0] - 16'h8000;
    else
        bank_rom_addr = z80_addr[15:0];
end

reg  [7:0] z80_din;
wire z80_iorq_n;
wire ym3812_irq_n;
wire [7:0] z80_ram_dout;

jtframe_sysz80 #(.RAM_AW(11)) u_z80(
    .rst_n    ( z80_rst_n    ),
    .clk      ( clk          ),
    .cen      ( cen_fm       ),
    .cpu_cen  (              ),
    .int_n    ( z80_int_n    ),
    .nmi_n    ( 1'b1         ),
    .busrq_n  ( 1'b1         ),
    .m1_n     ( z80_m1_n     ),
    .mreq_n   ( z80_mreq_n   ),
    .iorq_n   ( z80_iorq_n   ),
    .rd_n     ( z80_rd_n     ),
    .wr_n     ( z80_wr_n     ),
    .rfsh_n   ( z80_rfsh_n   ),
    .halt_n   (              ),
    .busak_n  (              ),
    .A        ( z80_addr     ),
    .cpu_din  ( z80_din      ),
    .cpu_dout ( z80_dout     ),
    .ram_dout ( z80_ram_dout ),
    .ram_cs   ( z80_ram_cs   ),
    .rom_cs   ( z80_wait_cs  ),
    .rom_ok   ( z80_wait_ok  )
);

reg oki6295_irq_n;
reg sub2main_pending;

always @(posedge clk) begin //XXX speed must be same than 68k din ?
    if (rst) begin
        z80_sound_latch_0 <= 16'b0;
        z80_sound_latch_1 <= 16'b0;
        sub2main_pending  <= 1'b0;
        oki6295_irq_n     <= 1'b1;
    end else begin
        // send z80 data to 68k cpu
        if (z80_mem_wr & sound_latch0_sel)
            z80_sound_latch_0 <= {8'b0, z80_dout[7:0]};
        if (z80_mem_wr & sound_latch1_sel)
            z80_sound_latch_1 <= {8'b0, z80_dout[7:0]};

        // data from z80 is pending read from 68k
        if (pending_set_cs) begin
            z80_sound_latch_2 <= 16'b0;
            sub2main_pending <= 1'b1;
        end else if (m68k_sound_cs_6 == 1'b1 || m68k_sound_cs_2 == 1'b1) begin
            z80_sound_latch_2 <= 16'b1;
            sub2main_pending <= 1'b0;
        end

        // main cpu assert irq for oki6295
        if (m68k_sound_cs_4 == 1'b1)
            oki6295_irq_n <= 1'b0;
        else
            oki6295_irq_n <= 1'b1;
    end
end

////// Z80 databus input   ///////////////////////
//
//  IRQ use z80 interrupt mode 0 :
//  After interrupt is asserted, the cpu signal it's
//  ready by putting iorq and m1 high
//  it then read on the databus
//  this data is directly executed by the cpu as an opcode
//
//  - ym3821 assert irq and put 0xd7 (rst10) on the bus
//  - 68k main cpu assert irq and put 0xdf (rst18) on the bus
//
//  both interrupt are needed to handle sound and coin input
//
reg irq_rst10;
reg irq_rst18;
reg stop_irq_10;
reg stop_irq_18;
wire irq_ack;
assign irq_ack = ~z80_iorq_n & ~z80_m1_n;

always @(posedge clk) begin
    if (rst) begin
        z80_din     <= 8'hff;
        irq_rst10   <= 1'b0;
        irq_rst18   <= 1'b0;
        stop_irq_10 <= 1'b0;
        stop_irq_18 <= 1'b0;
    end else begin
        if (~irq_ack & stop_irq_10) begin
            irq_rst10   <= 1'b0;
            stop_irq_10 <= 1'b0;
        end else if (~irq_ack & stop_irq_18) begin
            irq_rst18   <= 1'b0;
            stop_irq_18 <= 1'b0;
        end else if ((cabal ? jt51_irq_n : ym3812_irq_n) == 1'b0)
            irq_rst10 <= 1'b1;
        else if (oki6295_irq_n == 1'b0) //~m68k_sound_cs_4
            irq_rst18 <= 1'b1;

        if (!irq_ack && (cabal ? jt51_irq_n : ym3812_irq_n) == 1'b1)
            irq_rst10 <= 1'b0;

        if (irq_ack & irq_rst10)
            stop_irq_10 <= 1'b1;
        else if (irq_ack & irq_rst18)
            stop_irq_18 <= 1'b1;

        z80_din <= irq_ack & irq_rst10                      ? 8'hd7 :
                   irq_ack & irq_rst18                      ? 8'hdf :
                   main_data_pending_sel &  sub2main_pending ? 8'b1  :
                   main_data_pending_sel & ~sub2main_pending ? 8'b0  :
                   ym_rd                                    ? (cabal ? cabal_jt51_dout : ym3812_dout) :
                   oki_rd                                   ? oki_dout :
                   bank_rom_sel                             ? bank_rom_data :
                   m68k_latch0_sel                          ? m68k_sound_latch_0[7:0] :
                   m68k_latch1_sel                          ? m68k_sound_latch_1[7:0] :
                   read_coin_sel                            ? {6'b0, ~coin[1], ~coin[0]} :
                   z80_ram_sel                              ? z80_ram_dout :
                   rom_sel                                  ? dec_data : 8'hff;
    end
end

wire [7:0] oki_dout;
wire       oki_sample;
wire signed [13:0] oki_snd;
wire [17:0] adpcm_rom_addr;
wire        oki_wrn;

assign pcm_cs = 1'b1;
assign oki_wrn    = ~oki_wr;

// pcm rom byte 13 and 15 are swapped, that could be a simple encryption
assign pcm_addr = { adpcm_rom_addr[16], adpcm_rom_addr[13], adpcm_rom_addr[14] ,adpcm_rom_addr[15] , adpcm_rom_addr[12:0]};

jt6295 #(.INTERPOL(1))  u_adpcm(
    .rst      ( rst            ),
    .clk      ( clk            ),
    .cen      ( oki_cen        ),
    .ss       ( 1'b1           ), // pin7 high, select low sample rate
    .wrn      ( oki_wrn        ),
    .din      ( z80_dout       ),
    .dout     ( oki_dout       ),
    .rom_addr ( adpcm_rom_addr ),
    .rom_data ( pcm_data       ),
    .rom_ok   ( pcm_ok         ),
    .sound    ( oki_snd[13:0]  ),
    .sample   ( oki_sample     )
);

////////// Cabal ADPCM //////////////////////////////

wire signed [11:0] cabal_adpcm0_snd, cabal_adpcm1_snd;

jttoki_cabal_adpcm u_cabal_adpcm0(
    .rst      ( rst                          ),
    .clk      ( clk                          ),
    .cen      ( msm_cen                      ),
    .cpu_dout ( z80_dout                     ),
    .addr_we  ( z80_mem_wr & adpcm0_addr_sel ),
    .addr_hi  ( ~z80_addr[0]                 ),
    .ctl_we   ( z80_mem_wr & adpcm0_ctl_sel  ),
    .rom_addr ( adpcm1_addr                  ),
    .rom_cs   ( adpcm1_cs                    ),
    .rom_data ( adpcm1_data                  ),
    .rom_ok   ( adpcm1_ok                    ),
    .snd      ( cabal_adpcm0_snd             )
);

jttoki_cabal_adpcm u_cabal_adpcm1(
    .rst      ( rst                          ),
    .clk      ( clk                          ),
    .cen      ( msm_cen                      ),
    .cpu_dout ( z80_dout                     ),
    .addr_we  ( z80_mem_wr & adpcm1_addr_sel ),
    .addr_hi  ( ~z80_addr[0]                 ),
    .ctl_we   ( z80_mem_wr & adpcm1_ctl_sel  ),
    .rom_addr ( adpcm2_addr                  ),
    .rom_cs   ( adpcm2_cs                    ),
    .rom_data ( adpcm2_data                  ),
    .rom_ok   ( adpcm2_ok                    ),
    .snd      ( cabal_adpcm1_snd             )
);

wire signed [15:0] opl_snd;
wire        ym_cs_n, ym_wr_n, opl_sample;
wire [ 7:0] jt51_dout, cabal_jt51_dout;
wire        jt51_irq_n;
wire signed [15:0] jt51_l, jt51_r, cabal_fm_snd;

assign ym_cs_n = ~(ym_cs_0 | ym_cs_1);
assign ym_wr_n = ~(ym_wr & !cabal);
assign cabal_jt51_dout = {1'b0, jt51_dout[6:0]};

jtopl2 u_opl2(
    .rst    ( rst           ),
    .clk    ( clk           ),
    .cen    ( cen_fm        ),
    .din    ( z80_dout      ),
    .addr   ( ym_cs_1       ), // cmd addr
    .cs_n   ( ym_cs_n       ),
    .wr_n   ( ym_wr_n       ),
    .dout   ( ym3812_dout   ),
    .irq_n  ( ym3812_irq_n  ),
    .snd    ( opl_snd[15:0] ),
    .sample ( opl_sample    )
);

jt51 u_jt51(
    .rst    ( rst                  ),
    .clk    ( clk                  ),
    .cen    ( cen_fm               ),
    .cen_p1 ( cen_fm2              ),
    .cs_n   ( ~(ym_cs_0 | ym_cs_1) ),
    .wr_n   ( ~(ym_wr & cabal)     ),
    .a0     ( ym_sel_1             ),
    .din    ( z80_dout             ),
    .dout   ( jt51_dout            ),
    .ct1    (                      ),
    .ct2    (                      ),
    .irq_n  ( jt51_irq_n           ),
    .sample (                      ),
    .left   (                      ),
    .right  (                      ),
    .xleft  ( jt51_l               ),
    .xright ( jt51_r               )
);

assign cabal_fm_snd = (jt51_l >>> 1) + (jt51_r >>> 1);

assign fm   = cabal ? cabal_fm_snd : opl_snd;
assign pcm0 = cabal ? {cabal_adpcm0_snd, 2'd0} : oki_snd;
assign pcm1 = cabal ? {cabal_adpcm1_snd, 2'd0} : 14'sd0;

endmodule
