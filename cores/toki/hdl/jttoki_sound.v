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
    input             fm_cen, fm2_cen, msm_cen, oki_cen,

    input       [1:0]  coin,

    output reg signed [15:0] fm,
    output reg signed [13:0] pcm0,
    output reg signed [13:0] pcm1,

    input       [7:0] rom_data,
    input             rom_ok,
    output     [12:0] rom_addr,
    output            rom_cs,

    input       [7:0] bank_rom_data,
    input             bank_rom_ok,
    output     [15:0] bank_rom_addr,
    output            bank_rom_cs,

    // OKI 6295 ADPCM
    input       [7:0] pcm_data,
    input             pcm_ok,
    output     [16:0] pcm_addr,
    output reg        pcm_cs,

    // Cabal MSM5205 ADPCM
    input       [7:0] adpcm1_data,
    input             adpcm1_ok,
    output     [15:0] adpcm1_addr,
    output            adpcm1_cs,

    input       [7:0] adpcm2_data,
    input             adpcm2_ok,
    output     [15:0] adpcm2_addr,
    output            adpcm2_cs,

    input             m68k_sound_wr_2,
    input             main_irq_trig,
    input             m68k_sound_wr_6,

    input      [15:0] m68k_sound_latch_0,
    input      [15:0] m68k_sound_latch_1,

    output reg [15:0] cpu_sound_latch_0,
    output reg [15:0] cpu_sound_latch_1,
    output reg [15:0] cpu_sound_latch_2
);

`ifndef NOSOUND

wire        [17:0] adpcm_rom_addr;
wire        [15:0] cpu_addr, sei80bu_addr;
wire signed [15:0] opl_snd, jt51_l, jt51_r, cabal_fm_snd;
wire signed [13:0] oki_snd;
wire        [ 7:0] cpu_dout, ram_dout, dec_data, im0_opcode,
                    ym3812_dout, oki_dout, jt51_dout;
wire signed [11:0] cabal_adpcm0_snd, cabal_adpcm1_snd;
wire               ram_cs, ym_cs_0, ym_cs_1,
                   pending_set_wr, irq_clear_wr, fm_eoi_wr,
                   main_eoi_wr, cpu_rd_n, cpu_wr_n, mem_acc, mem_wr,
                   ym_rd, ym_wr, oki_rd, oki_wr, wait_cs, wait_ok,
                   cpu_m1_n, cpu_mreq_n, cpu_rfsh_n, m1, rst_n, irq_n, cpu_iorq_n,
                   ym3812_irq_n, jt51_irq_n, irq_ack, oki_wrn,
                   fm_irq_n, main_eoi, ym_cs_n,
                   opl_wr_n, jt51_wr_n, adpcm_addr_hi,
                   adpcm0_addr_we, adpcm1_addr_we, adpcm0_ctl_we,
                   adpcm1_ctl_we;
reg         [ 7:0] din;
reg                rom_addr_cs, bank_rom_addr_cs, ram_addr_cs, ym0_cs, ym1_cs,
                   m68k_latch0_cs, m68k_latch1_cs, pending_set_cs,
                   main2sub_cs, read_coin_cs, bank_switch_cs,
                   sound_latch0_cs, sound_latch1_cs, oki_cs,
                   adpcm0_addr_cs, adpcm1_addr_cs, adpcm0_ctl_cs,
                   adpcm1_ctl_cs, irq_clear_cs, fm_eoi_cs, main_eoi_cs,
                   bank_selected, sub2main_pending;

assign mem_acc           = ~cpu_mreq_n & cpu_rfsh_n;
assign mem_wr            = mem_acc & ~cpu_wr_n;

assign rom_cs          = cpu_rfsh_n & rom_addr_cs;
assign ram_cs          = cpu_rfsh_n & ram_addr_cs;
assign bank_rom_cs     = cpu_rfsh_n & bank_rom_addr_cs;
assign pending_set_wr  = mem_wr & pending_set_cs;
assign irq_clear_wr    = mem_wr & irq_clear_cs;
assign fm_eoi_wr       = mem_wr & fm_eoi_cs;
assign main_eoi_wr     = mem_wr & main_eoi_cs;
assign ym_cs_0         = cpu_rfsh_n & ym0_cs;
assign ym_cs_1         = cpu_rfsh_n & ym1_cs;
assign ym_rd           = (ym0_cs | (cabal & ym1_cs)) & ~cpu_rd_n;
assign ym_wr           = mem_wr & (ym0_cs | ym1_cs);
assign oki_rd          = oki_cs & ~cpu_rd_n;
assign oki_wr          = mem_wr & oki_cs;
assign wait_cs         = mem_acc & (rom_addr_cs | bank_rom_addr_cs);
assign wait_ok         = rom_addr_cs ? rom_ok : bank_rom_ok;
assign irq_ack         = ~cpu_iorq_n & ~cpu_m1_n;
assign main_eoi        = irq_clear_wr | main_eoi_wr;

assign m1              = ~cpu_m1_n;
assign rst_n           = ~rst;
assign sei80bu_addr    = {3'd0, rom_addr};
assign rom_addr        = cpu_addr[12:0];
assign bank_rom_addr   = bank_selected ? cpu_addr : cpu_addr - 16'h8000;
assign oki_wrn         = ~oki_wr;
assign ym_cs_n         = ~(ym_cs_0 | ym_cs_1);
assign opl_wr_n        = ~(ym_wr & !cabal);
assign jt51_wr_n       = ~(ym_wr & cabal);
assign fm_irq_n        = cabal ? jt51_irq_n : ym3812_irq_n;
assign adpcm_addr_hi   = ~cpu_addr[0];
assign adpcm0_addr_we  = mem_wr & adpcm0_addr_cs;
assign adpcm1_addr_we  = mem_wr & adpcm1_addr_cs;
assign adpcm0_ctl_we   = mem_wr & adpcm0_ctl_cs;
assign adpcm1_ctl_we   = mem_wr & adpcm1_ctl_cs;

// PCM ROM address bits 13 and 15 are swapped, possibly as simple encryption.
assign pcm_addr = {adpcm_rom_addr[16], adpcm_rom_addr[13], adpcm_rom_addr[14],
                   adpcm_rom_addr[15], adpcm_rom_addr[12:0]};

assign cabal_fm_snd = (jt51_l >>> 1) + (jt51_r >>> 1);

always @(posedge clk) begin
    fm   <= cabal ? cabal_fm_snd : opl_snd;
    pcm0 <= cabal ? {cabal_adpcm0_snd[11], cabal_adpcm0_snd, 1'b0} : oki_snd;
    pcm1 <= cabal ? {cabal_adpcm1_snd[11], cabal_adpcm1_snd, 1'b0} : 14'sd0;
end

always @* begin
    rom_addr_cs           = cpu_addr < 16'h2000;
    ram_addr_cs           = cpu_addr >= 16'h2000 && cpu_addr < 16'h2800;
    pending_set_cs        = !cabal && cpu_addr == 16'h4000;
    irq_clear_cs          = cpu_addr == 16'h4001;
    fm_eoi_cs             = cpu_addr == 16'h4002;
    main_eoi_cs           = cpu_addr == 16'h4003;
    bank_switch_cs        = !cabal && cpu_addr == 16'h4007;
    ym0_cs                = cpu_addr == 16'h4008;
    ym1_cs                = cpu_addr == 16'h4009;
    m68k_latch0_cs        = cpu_addr == 16'h4010;
    m68k_latch1_cs        = cpu_addr == 16'h4011;
    main2sub_cs           = cpu_addr == 16'h4012;
    read_coin_cs          = cpu_addr == 16'h4013;
    sound_latch0_cs       = cpu_addr == 16'h4018;
    sound_latch1_cs       = cpu_addr == 16'h4019;
    adpcm0_ctl_cs         = cabal && cpu_addr == 16'h401a;
    adpcm0_addr_cs        = cabal && (cpu_addr == 16'h4005 || cpu_addr == 16'h4006);
    oki_cs                = !cabal && cpu_addr == 16'h6000;
    adpcm1_ctl_cs         = cabal && cpu_addr == 16'h601a;
    adpcm1_addr_cs        = cabal && (cpu_addr == 16'h6005 || cpu_addr == 16'h6006);
    bank_rom_addr_cs      = cpu_addr >= 16'h8000;
end

always @(posedge clk) begin
    if (rst)
        bank_selected <= 1'b0;
    else if (mem_wr & bank_switch_cs)
        bank_selected <= cpu_dout[0];
end

always @(posedge clk) begin //XXX speed must be same than 68k din ?
    if (rst) begin
        cpu_sound_latch_0 <= 16'b0;
        cpu_sound_latch_1 <= 16'b0;
        cpu_sound_latch_2 <= 16'b0;
        sub2main_pending  <= 1'b0;
    end else begin
        // send z80 data to 68k cpu
        if (mem_wr & sound_latch0_cs)
            cpu_sound_latch_0 <= {8'b0, cpu_dout};
        if (mem_wr & sound_latch1_cs)
            cpu_sound_latch_1 <= {8'b0, cpu_dout};

        // data from z80 is pending read from 68k
        if (pending_set_wr) begin
            cpu_sound_latch_2 <= 16'b0;
            sub2main_pending  <= 1'b1;
        end else if (m68k_sound_wr_6 == 1'b1 || m68k_sound_wr_2 == 1'b1) begin
            cpu_sound_latch_2 <= 16'b1;
            sub2main_pending  <= 1'b0;
        end
    end
end

always @(posedge clk) begin
    if (rst) begin
        din <= 8'hff;
    end else begin
        din <= irq_ack                             ? im0_opcode :
                   main2sub_cs &  sub2main_pending ? 8'b1  :
                   main2sub_cs & ~sub2main_pending ? 8'b0  :
                   ym_rd                           ? (cabal ? jt51_dout : ym3812_dout) :
                   oki_rd                          ? oki_dout :
                   bank_rom_addr_cs                ? bank_rom_data :
                   m68k_latch0_cs                  ? m68k_sound_latch_0[7:0] :
                   m68k_latch1_cs                  ? m68k_sound_latch_1[7:0] :
                   read_coin_cs                    ? {6'b0, ~coin[1], ~coin[0]} :
                   ram_addr_cs                     ? ram_dout :
                   rom_addr_cs                     ? dec_data : 8'hff;
    end
end

always @(posedge clk) begin
    pcm_cs <= ~cabal;
end

jttoki_irq u_irq(
    .rst           ( rst           ),
    .clk           ( clk           ),
    .fm_irq_n      ( fm_irq_n      ),
    .main_irq_trig ( main_irq_trig ),
    .cpu_irq_ack   ( irq_ack       ),
    .fm_eoi        ( fm_eoi_wr     ),
    .main_eoi      ( main_eoi      ),
    .cpu_irq_n     ( irq_n         ),
    .im0_opcode    ( im0_opcode    )
);

sei80bu u_sei80bu(
    .clk      ( clk          ),
    .rom_addr ( sei80bu_addr ),
    .rom_data ( rom_data     ),
    .rom_ok   ( rom_ok       ),
    .rom_cs   ( rom_cs       ),
    .z80_m1   ( m1           ),
    .dec_data ( dec_data     ),
    .dec_ok   (              )
);

jt6295 #(.INTERPOL(1)) u_adpcm(
    .rst      ( rst            ),
    .clk      ( clk            ),
    .cen      ( oki_cen        ),
    .ss       ( 1'b1           ), // pin 7 high: low sample rate
    .wrn      ( oki_wrn        ),
    .din      ( cpu_dout        ),
    .dout     ( oki_dout       ),
    .rom_addr ( adpcm_rom_addr ),
    .rom_data ( pcm_data       ),
    .rom_ok   ( pcm_ok         ),
    .sound    ( oki_snd        ),
    .sample   (                )
);

jttoki_cabal_adpcm u_cabal_adpcm0(
    .rst      ( rst                  ),
    .clk      ( clk                  ),
    .cen      ( msm_cen              ),
    .cpu_dout ( cpu_dout             ),
    .addr_we  ( adpcm0_addr_we       ),
    .addr_hi  ( adpcm_addr_hi        ),
    .ctl_we   ( adpcm0_ctl_we        ),
    .rom_addr ( adpcm1_addr          ),
    .rom_cs   ( adpcm1_cs            ),
    .rom_data ( adpcm1_data          ),
    .rom_ok   ( adpcm1_ok            ),
    .snd      ( cabal_adpcm0_snd     )
);

jttoki_cabal_adpcm u_cabal_adpcm1(
    .rst      ( rst                  ),
    .clk      ( clk                  ),
    .cen      ( msm_cen              ),
    .cpu_dout ( cpu_dout             ),
    .addr_we  ( adpcm1_addr_we       ),
    .addr_hi  ( adpcm_addr_hi        ),
    .ctl_we   ( adpcm1_ctl_we        ),
    .rom_addr ( adpcm2_addr          ),
    .rom_cs   ( adpcm2_cs            ),
    .rom_data ( adpcm2_data          ),
    .rom_ok   ( adpcm2_ok            ),
    .snd      ( cabal_adpcm1_snd     )
);

jtopl2 u_opl2(
    .rst    ( rst           ),
    .clk    ( clk           ),
    .cen    ( fm_cen        ),
    .din    ( cpu_dout      ),
    .addr   ( ym_cs_1       ), // cmd addr
    .cs_n   ( ym_cs_n       ),
    .wr_n   ( opl_wr_n      ),
    .dout   ( ym3812_dout   ),
    .irq_n  ( ym3812_irq_n  ),
    .snd    ( opl_snd       ),
    .sample (               )
);

jt51 u_jt51(
    .rst    ( rst                  ),
    .clk    ( clk                  ),
    .cen    ( fm_cen               ),
    .cen_p1 ( fm2_cen              ),
    .cs_n   ( ym_cs_n              ),
    .wr_n   ( jt51_wr_n            ),
    .a0     ( ym1_cs               ),
    .din    ( cpu_dout            ),
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

jtframe_sysz80 #(.RAM_AW(11)) u_z80(
    .rst_n    ( rst_n        ),
    .clk      ( clk          ),
    .cen      ( fm_cen       ),
    .cpu_cen  (              ),
    .int_n    ( irq_n        ),
    .nmi_n    ( 1'b1         ),
    .busrq_n  ( 1'b1         ),
    .m1_n     ( cpu_m1_n     ),
    .mreq_n   ( cpu_mreq_n   ),
    .iorq_n   ( cpu_iorq_n   ),
    .rd_n     ( cpu_rd_n     ),
    .wr_n     ( cpu_wr_n     ),
    .rfsh_n   ( cpu_rfsh_n   ),
    .halt_n   (              ),
    .busak_n  (              ),
    .A        ( cpu_addr     ),
    .cpu_din  ( din          ),
    .cpu_dout ( cpu_dout     ),
    .ram_dout ( ram_dout     ),
    .ram_cs   ( ram_cs       ),
    .rom_cs   ( wait_cs      ),
    .rom_ok   ( wait_ok      )
);

`else

assign rom_addr          = 13'd0;
assign rom_cs            = 1'b0;
assign bank_rom_addr     = 16'd0;
assign bank_rom_cs       = 1'b0;
assign pcm_addr          = 17'd0;
assign adpcm1_addr       = 16'd0;
assign adpcm1_cs         = 1'b0;
assign adpcm2_addr       = 16'd0;
assign adpcm2_cs         = 1'b0;

initial begin
    pcm_cs            = 1'b0;
    fm                = 16'sd0;
    pcm0              = 14'sd0;
    pcm1              = 14'sd0;
    cpu_sound_latch_0 = 16'd0;
    cpu_sound_latch_1 = 16'd0;
    cpu_sound_latch_2 = 16'd0;
end

`endif

endmodule
