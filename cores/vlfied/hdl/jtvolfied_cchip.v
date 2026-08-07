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

    ===========================================================================
    Volfied C-chip (TC0030CMD) wrapper.

    The TC0030CMD is a hybrid ASIC: a NEC uPD78C11 microcontroller + 8 KB
    external EPROM (c04 23, dumped as cchip:cchip_eprom) + 8 KB DRAM. It is
    THE SAME protection device family already brought up for Superman.

    Reuse plan (the whole point of doing Volfied now):
      - CPU core:  jtsuperman_upd78c11.v   (3987-line uPD78C11, shared verbatim)
      - glue:      jtsuperman_cchip.v      (SRAM/ASIC/bank/IRQ subsystem)
      The 68k-side memory map of jtsuperman_cchip is ALREADY what Volfied needs:
          $000-$7FF -> shared SRAM   (Volfied f00000-f007ff, mem68)
          $800-$FFF -> ASIC regs     (Volfied f00800-f00fff, asic68)
      Differences to resolve when wiring REAL_MCU=1:
          - load Volfied's EPROM instead of Superman's b61_11 (use the external
            cchip SDRAM/PROM bus added in cfg/mem.yaml, not the baked .mem)
          - feed port_pa..pd from the cabinet inputs (Volfied routes start/coin/
            joystick/cocktail through the MCU ports — see header of volfied.cpp)
          - confirm int_n wiring to the 68k (currently stubbed high in superman)

    Until that drop-in lands, this file is a STUB so the rest of the core can
    boot and the bitmap/sprite video can be brought up against MAME traces:
      - 68k reads/writes hit a plain 1 KB dual RAM ($000-$7FF window)
      - ASIC reads return 0x00, DTACK is immediate
      - cabinet inputs are injected at PLACEHOLDER byte offsets (NOT verified
        against the real MCU RAM layout — controls will not be correct yet)
    ===========================================================================
*/

module jtvolfied_cchip #(
    parameter [0:0] REAL_MCU = 1'b1      // 0 = stub, 1 = real jtsuperman_cchip MCU
)(
    input             rst,
    input             clk,

    // 68k side (lower byte only, umask 0x00ff)
    input             cs,
    input      [11:1] addr,
    input      [ 7:0] din,
    output     [ 7:0] dout,
    input             rnw,
    input      [ 1:0] dsn,
    output            dtackn,
    input             ext_tick,        // VBL pulse -> MCU external interrupt

    // C-chip EPROM (bank 3) — unused: the 8 KB EPROM is baked into the MCU
    // wrapper via $readmemh(cchip_eprom.mem), same as Superman.
    output     [12:0] eprom_addr,
    input      [ 7:0] eprom_data,
    output            eprom_cs,
    input             eprom_ok,

    // cabinet inputs (routed through the MCU ports on real HW). Active LOW
    // (idle = 1), matching JTFRAME/MAME convention.
    input      [ 4:0] joystick1,       // [3:0]=U/D/L/R, [4]=button1
    input      [ 4:0] joystick2,
    input      [ 1:0] start_button,    // [0]=1P, [1]=2P
    input      [ 1:0] coin,
    input             service,
    input             tilt
);

assign dtackn    = 0;        // main paces via jtframe_68kdtack_cen
assign eprom_cs  = 0;        // EPROM baked into the MCU wrapper
assign eprom_addr= 0;

generate
if( REAL_MCU ) begin : g_real
    // -------------------------------------------------------------------
    // Real Taito C-chip = uPD78C11 + 4KB internal mask ROM + 8KB EPROM.
    // Reuses jtsuperman_cchip (which $readmemh's mask_rom.mem + cchip_eprom.mem
    // from the working dir). 68k map matches Volfied: $000-$7FF SRAM (f00000),
    // $800-$FFF ASIC (f00800). Port map from volfied.cpp machine config:
    //   PA: bit5=START2 bit6=START1 bit7=SERVICE1
    //   PB: bit0=COIN1  bit1=COIN2
    //   PC: bit0=TILT   bit2..5=U/D/L/R  bit6=BUTTON1
    //   PD/AD: P2 cocktail (idle = 0xFF, upright)
    // -------------------------------------------------------------------
    // Idle byte values verified against MAME's C-chip port reads:
    //   PA(F00007)=FF  PB(F00009)=FC  PC(F0000B)=FF  PD(F0000D)=FF
    // The coin bits on PB are ACTIVE-HIGH at the port (idle=0), opposite to
    // JTFRAME's active-low coin (idle=1) -> invert them, else the C-chip sees
    // two coins stuck inserted and shows "COIN ERROR".
    wire [7:0] port_pa = { service, start_button[0], start_button[1], 5'h1f };
    wire [7:0] port_pb = { 6'h3f, ~coin[1], ~coin[0] };
    // P1 joystick on MCU port C (MAME F0000B, active-low):
    //   pc2=0x04 Up, pc3=0x08 Down, pc4=0x10 Left, pc5=0x20 Right, pc6=0x40 B1.
    // jtframe gives joystick1[3:0]={Up,Down,Left,Right}; the four direction bits
    // go in REVERSED into pc[5:2] (feeding them straight swapped Up<->Right and
    // Down<->Left).
    wire [7:0] port_pc = { 1'b1, joystick1[4],
                           joystick1[0], joystick1[1], joystick1[2], joystick1[3],
                           1'b1, tilt };
    wire [7:0] port_pd = 8'hFF;

    jtsuperman_cchip #( .BRING_UP(1'b0) ) u_cchip(
        .clk        ( clk       ),
        .rstn       ( ~rst      ),
        .cs         ( cs        ),
        .addr       ( addr      ),
        .din        ( din       ),
        .dout       ( dout      ),
        .we         ( ~rnw      ),
        .uds_n      ( dsn[1]    ),
        .lds_n      ( dsn[0]    ),
        .dtack_n    (           ),
        .int_n      (           ),   // Volfied does not route a C-chip IRQ to 68k
        .com_res_n  ( 1'b1      ),
        .port_pa    ( port_pa   ),
        .port_pb    ( port_pb   ),
        .port_pc    ( port_pc   ),
        .port_pd    ( port_pd   ),
        .port_cr0   ( 8'hFF     ),   // AD channels (cocktail) — idle
        .port_cr1   ( 8'hFF     ),
        .port_cr2   ( 8'hFF     ),
        .port_cr3   ( 8'hFF     ),
        .port_pa_out(           ),
        .port_pb_out(           ),   // out_pb = coin lockout/counters (unused)
        .port_pc_out(           ),
        .port_pd_out(           ),
        .port_pf_out(           ),
        .ext_tick   ( ext_tick  ),
        .dbg_pc(),.dbg_pc_next(),.dbg_a(),.dbg_v(),.dbg_bc(),.dbg_de(),
        .dbg_hl(),.dbg_ea(),.dbg_sp(),.dbg_psw(),.dbg_iff(),.dbg_ap(),
        .dbg_vp(),.dbg_bcp(),.dbg_dep(),.dbg_hlp(),.dbg_eap(),.dbg_mm(),
        .dbg_mkh(),.dbg_mkl(),.dbg_retire(),.dbg_trap()
    );
end else begin : g_stub
    reg  [ 7:0] dout_s;
    wire [ 7:0] ram_q;
    wire        we = cs & ~rnw & ~dsn[0];   // low byte writes
    wire        asic = addr[11];            // word-index >=0x400 = ASIC window
    assign dout = dout_s;

    // ---------------------------------------------------------------
    // Faithful replay of what MAME's C-chip returns during attract.
    // Verified against /tmp/volfied_main.tr (6 s headless boot):
    //   device RAM index 3 (68k F00006) -> 0xFD   (system)
    //   device RAM index 4 (68k F00008) -> 0x3C   (P1 / status)
    //   device RAM index 5 (68k F0000B) -> 0xFF   (P2, all idle)
    //   ASIC  index 1 (68k F00803)      -> 0x01   (ready handshake)
    // These are the IDLE values; live inputs get OR-masked in later
    // when the real MCU (REAL_MCU=1) replaces this block. For now the
    // joystick/coin inputs are accepted but unused so attract runs.
    // ---------------------------------------------------------------
    reg [7:0] inject;
    always @* begin
        if( asic ) begin
            inject = (addr[10:1]==10'd1) ? 8'h01 : 8'h00;
        end else begin
            case( addr[10:1] )
                10'd3: inject = 8'hFD;
                10'd4: inject = 8'h3C;
                10'd5: inject = 8'hFF;
                default: inject = ram_q;
            endcase
        end
    end

    always @(posedge clk) dout_s <= inject;

    // keep inputs from being optimised away in stub mode
    wire _unused = &{ joystick1, joystick2, start_button, coin, service, tilt, ext_tick, 1'b0 };

    jtframe_dual_ram #(.AW(10)) u_ram(
        .clk0 ( clk         ),
        .data0( din         ),
        .addr0( addr[10:1]  ),
        .we0  ( we & ~asic  ),
        .q0   ( ram_q       ),
        .clk1 ( clk         ),
        .data1( 8'd0        ),
        .addr1( 10'd0       ),
        .we1  ( 1'b0        ),
        .q1   (             )
    );
end
endgenerate

endmodule
