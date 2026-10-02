/*  This file is part of JTCORES. GPLv3. See jtosman_game.v header.
    Author: Andrea Bogazzi.

    Osman sound: two OKI M6295 (jt6295), driven directly by the main ARM (no sound CPU).
    Both run at 28MHz/28 = 1 MHz with PIN7 HIGH (ss=1) per mitchell156.
      okisfx   @0x100000 — SFX/voice, no banking.
      okimusic @0x140000 — music, bank[2:0] from eeprom_w + a ROM address descramble.

    okimusic descramble: init_simpl156 permutes the ROM at load — buf1[bitswap(x)] = rom[x],
    with bitswap<24>(x, 23,22,21, 0,20, 19..1) moving the true low address line up to bit 20
    ("low line goes to the banking chip"). The SDRAM holds the raw ROM, so the inverse is
    applied to the read address: for A = {bank[2:0], oki_addr[17:0]}, x = {A[19:0], A[20]}.
*/
module jtosman_snd(
    input             rst,
    input             clk,
    input             cen_oki1,
    input             cen_oki2,

    input    [ 7:0]   din,
    input             oki1_wr,       // 1-clk pulse (main is_okisfx write)
    input             oki2_wr,       // 1-clk pulse (main is_okimus write)
    input    [ 2:0]   oki2_bank,
    output   [ 7:0]   oki1_dout,     // status read: {4'hf, busy|start} per channel
    output   [ 7:0]   oki2_dout,

    // OKI #1 sample ROM (SDRAM)
    output            rom1_cs,
    output   [17:0]   rom1_addr,
    input    [ 7:0]   rom1_data,
    input             rom1_ok,
    // OKI #2 sample ROM (SDRAM)
    output            rom2_cs,
    output   [20:0]   rom2_addr,
    input    [ 7:0]   rom2_data,
    input             rom2_ok,

    output signed [13:0] pcm1,
    output signed [13:0] pcm2
);

assign rom1_cs = 1'b1;   // jt6295 fetches ROM continuously
assign rom2_cs = 1'b1;

// OKI #2 banked + descrambled read address
wire [17:0] oki2_a;
wire [20:0] oki2_banked = { oki2_bank, oki2_a };
assign rom2_addr = { oki2_banked[19:0], oki2_banked[20] };

jt6295 u_okisfx(
    .rst     ( rst       ),
    .clk     ( clk       ),
    .cen     ( cen_oki1  ),
    .ss      ( 1'b1      ),
    .wrn     ( ~oki1_wr  ),
    .din     ( din       ),
    .dout    ( oki1_dout ),
    .rom_addr( rom1_addr ),
    .rom_data( rom1_data ),
    .rom_ok  ( rom1_ok   ),
    .sound   ( pcm1      ),
    .sample  (           )
);

jt6295 u_okimus(
    .rst     ( rst       ),
    .clk     ( clk       ),
    .cen     ( cen_oki2  ),
    .ss      ( 1'b1      ),
    .wrn     ( ~oki2_wr  ),
    .din     ( din       ),
    .dout    ( oki2_dout ),
    .rom_addr( oki2_a    ),
    .rom_data( rom2_data ),
    .rom_ok  ( rom2_ok   ),
    .sound   ( pcm2      ),
    .sample  (           )
);

endmodule
