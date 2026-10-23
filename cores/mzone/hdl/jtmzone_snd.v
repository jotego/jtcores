// SPDX-License-Identifier: GPL-3.0-or-later

module jtmzone_snd(
    input               rst,
    input               clk,
    // ROM
    output      [12:0]  rom_addr,
    output reg          rom_cs,
    input       [ 7:0]  rom_data,
    input               rom_ok,
    output      [11:0]  mcu_rom_addr,
    output              mcu_rom_cs,
    input       [ 7:0]  mcu_rom_data,
    input               mcu_rom_ok,

    // Cabinet inputs, same Konami ports used by MAME
    input       [ 1:0]  cab_1p,
    input       [ 1:0]  coin,
    input       [ 5:0]  joystick1,
    input       [ 5:0]  joystick2,
    input               service,
    input       [ 7:0]  dipsw_a,
    input       [ 7:0]  dipsw_b,
    input               LVBL,
    input       [ 8:0] hdump,
    input               intsnd,

    // Shared RAM with the main CPU
    output      [10:0]  shared_addr,
    output      [ 7:0]  shared_dout,
    output              shared_we,
    input       [ 7:0]  shared_din,
    output              intmain_n,

    // Sound output
    output       [7:0] psg0a, psg0b, psg0c,
    output       [3:0] psg0a_rcen, psg0b_rcen, psg0c_rcen,
    output       [7:0] dac
);
// Keep the Z80, cabinet I/O and shared RAM active with NOSOUND.
// jtmzone_snd_dev bypasses only the AY and 8039 audio devices.

wire        [ 7:0] cpu_dout, ay_dout;
wire        [15:0] A;
wire               mreq_n, rd_n, wr_n, rfsh_n;
wire               ay_rd;
wire        [ 7:0] dipsw_dout = A[0] ? dipsw_a : dipsw_b;
reg         [ 7:0] cpu_din, cabinet;
reg                latch_cs, ior_cs, dipsw_cs;
reg                shared_cs, mcu_irq_cs, mcu_wdog_cs;

assign rom_addr      = A[12:0];
assign shared_addr   = A[10:0];
assign shared_dout   = cpu_dout;
assign shared_we     = shared_cs && !wr_n;
// B_B7 output 5: active-low INTMAIN decode for A000-BFFF.
assign intmain_n     = mreq_n || !rfsh_n || A[15:13] != 3'b101;

always @(*) begin
    rom_cs        = 0;
    latch_cs      = 0;
    ior_cs        = 0;
    dipsw_cs      = 0;
    shared_cs     = 0;
    mcu_irq_cs    = 0;
    mcu_wdog_cs   = 0;

    if( !mreq_n && rfsh_n ) begin
        case( A[15:13] )
            0: rom_cs = !rd_n;                                      // 0000-1fff
            1: mcu_irq_cs = !wr_n && A[12:0] == 13'd0;              // 2000, write only
            2: latch_cs = !wr_n && A[12:0] == 13'd0;                // 4000, write only
            3: ior_cs = A[12:2] == 11'd0 && A[1:0] != 2'd3;        // 6000-6002
            4: dipsw_cs = A[12:1] == 12'd0;                         // 8000-8001
            6: mcu_wdog_cs = !wr_n && A[12:0] == 13'd1;            // c001, write only
            7: shared_cs = A[12:11] == 2'd0;                        // e000-e7ff
            default: ;                                              // a000-bfff: INTMAIN
        endcase
    end
end

always @(posedge clk) begin
    case( A[1:0] )
        0: cabinet <= { 3'b111, cab_1p[1:0], service, coin[1:0] };
        1: cabinet <= { 2'b11, joystick1[5:0] };
        2: cabinet <= { 2'b11, joystick2[5:0] };
        3: cabinet <= 8'hff;
    endcase
    cpu_din <= rom_cs    ? rom_data          :
               shared_cs ? shared_din        :
               ay_rd     ? ay_dout           :
               ior_cs    ? cabinet           :
               dipsw_cs  ? dipsw_dout        : 8'hff;
end

jtmzone_snd_dev u_dev(
    .rst            ( rst               ),
    .clk            ( clk               ),
    .LVBL           ( LVBL              ),
    .hdump          ( hdump             ),
    .intsnd         ( intsnd            ),
    .A              ( A                 ),
    .cpu_din        ( cpu_din           ),
    .cpu_dout       ( cpu_dout          ),
    .mreq_n         ( mreq_n            ),
    .rd_n           ( rd_n              ),
    .wr_n           ( wr_n              ),
    .rfsh_n         ( rfsh_n            ),
    .rom_cs         ( rom_cs            ),
    .rom_ok         ( rom_ok            ),
    .shared_cs      ( shared_cs         ),
    .latch_cs       ( latch_cs          ),
    .mcu_irq_cs     ( mcu_irq_cs        ),
    .mcu_wdog_cs    ( mcu_wdog_cs       ),
    .ay_dout        ( ay_dout           ),
    .ay_rd          ( ay_rd             ),
    .mcu_rom_addr   ( mcu_rom_addr      ),
    .mcu_rom_cs     ( mcu_rom_cs        ),
    .mcu_rom_data   ( mcu_rom_data      ),
    .mcu_rom_ok     ( mcu_rom_ok        ),
    .psg0a          ( psg0a             ),
    .psg0b          ( psg0b             ),
    .psg0c          ( psg0c             ),
    .psg0a_rcen     ( psg0a_rcen        ),
    .psg0b_rcen     ( psg0b_rcen        ),
    .psg0c_rcen     ( psg0c_rcen        ),
    .dac            ( dac               )
);

endmodule
