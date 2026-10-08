/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 21-8-2020 */

module jtsf_sound #(
    parameter SND1W = 15,
    parameter SND2W = 18
)(
    input              rst,
    input              clk,
    // Interface with main CPU
    input       [ 7:0] snd_latch,
    input              snd_nmi_n,
    // ROM
    output [SND1W-1:0] rom_addr,
    output             rom_cs,
    input       [ 7:0] rom_data,
    input              rom_ok,
    // ADPCM ROM
    output [SND2W-1:0] rom2_addr,
    output             rom2_cs,
    input       [ 7:0] rom2_data,
    input              rom2_ok,

    // Sound output
    output signed [15:0] fm_l, fm_r,
    output signed [11:0] pcm0, pcm1
);
`ifndef NOSOUND
wire               cen1p5, adpcm_sample;
wire               cen_fm, cen_fm2, cenp384;
wire               cen3, cen3p5, cen1p7;
reg         [ 7:0] pcm_gain;

//assign cen_fm  = cen3;
//assign cen_fm2 = cen1p5;
assign cen_fm  = cen3p5;
assign cen_fm2 = cen1p7;

/* verilator lint_off PINMISSING */
jtframe_cen48 u_cenalt(
    .clk    ( clk       ),
    .cen12  (           ),
    .cen12b (           ),
    .cen8   (           ),
    .cen6   (           ),
    .cen6b  (           ),
    .cen4   (           ),
    .cen3   ( cen3      ),
    .cen3q  (           ),
    .cen3b  (           ),
    .cen3qb (           ),
    .cen1p5 ( cen1p5    ),
    .cen1p5b(           )
);
/* verilator lint_on PINMISSING */

jtframe_cen3p57 u_cen (
    .clk        ( clk       ),
    .cen_3p57   ( cen3p5    ),
    .cen_1p78   ( cen1p7    )
);

jtframe_cenp384 u_cenp384(
    .clk      ( clk       ),
    .cen_p384 ( cenp384   )
);

jtbiocom_sound #(.LAYOUT(9),.RECOVERY(1)) u_fmcpu(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cen_fm     ( cen_fm    ),
    .cen_fm2    ( cen_fm2   ),
    // Interface with main CPU
    .snd_latch  ( snd_latch ),
    .nmi_n      ( snd_nmi_n ),
    // Interface with MCU - Used by Bionic Commando only
    .snd_din    (           ),
    .snd_dout   (           ),
    .snd_mcu_wr (           ),
    .snd_mcu_rd (           ),
    // ROM
    .rom_addr   ( rom_addr  ),
    .rom_cs     ( rom_cs    ),
    .rom_data   ( rom_data  ),
    .rom_ok     ( rom_ok    ),

    // Sound output
    .fm_l       ( fm_l      ),
    .fm_r       ( fm_r      )
);

jtsf_adpcm u_adpcmcpu(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cpu_cen    ( cen_fm        ),
    .cenp384    ( cenp384       ),
    // Interface with second CPU
    .snd_latch  ( snd_latch     ),
    // ADPCM ROM
    .rom2_addr  ( rom2_addr     ),
    .rom2_cs    ( rom2_cs       ),
    .rom2_data  ( rom2_data     ),
    .rom2_ok    ( rom2_ok       ),
    // Sound output
    .pcm0       ( pcm0          ),
    .pcm1       ( pcm1          ),
    .sample     ( adpcm_sample  )
);
`else
    assign rom_addr  = 0;
    assign rom_cs    = 0;
    assign rom2_addr = 0;
    assign rom2_cs   = 0;
    assign fm_l      = 0;
    assign fm_r      = 0;
    assign pcm0      = 0;
    assign pcm1      = 0;
`endif
endmodule