/*  This file is part of JTCORES. GPLv3. See jtcninja_game.v header.

    jtcninja_deco16ic - Data East deco16ic tile generator (custom chips 55/56/74).

    One chip = two playfields. Per MAME (deco16ic.cpp device_start) the chip owns
    its own state, so it is modelled here:
        m_pf1_data     0x2000 bytes -> u_pf1 (AW=12)
        m_pf2_data     0x2000 bytes -> u_pf2
        m_pf12_control 0x10   bytes -> ctrl[0:7]
    The row/column scroll table (the driver's m_pf_rowscroll, reached through
    pf_update) is held here as ONE BRAM shared by both playfields: the renderers
    only address [9:0], so bit 10 selects the playfield's half when the driver
    passes two distinct pointers (rs_split). Boards that pass the same pointer
    to both playfields, like darkseal, leave it low.

    Control register map (16-bit words, deco16ic::pf_control_w):
        [1]/[2] pf1 scroll X/Y      [3]/[4] pf2 scroll X/Y
        [5] control0: pf1 = low byte, pf2 = high byte
        [6] control1: pf1 = low byte, pf2 = high byte
        [7] bank register -> the driver's bank callback (bank_ctl output)

    pfN_pswap / pfN_rowmajor describe how the gfx ROM was packed by the download,
    not chip behaviour, so they are per-playfield board inputs.
*/
module jtcninja_deco16ic #(
    parameter SIMFILE1 = "",    // scene-replay preload for the pf1 RAM
              SIMFILE2 = "",    // ... and pf2
              CTRLHEX  = ""     // ... and the control registers
)(
    input             rst,
    input             clk,
    input             pxl_cen,
    input             hs,
    input      [ 8:0] vrender,
    input      [ 8:0] hdump,
    input             flip,
    input             fullheight,     // DECO_64x64 (both maps 64 rows)

    // CPU side. The board decodes the selects and passes a word offset, the
    // same shape as deco16ic::pf1_data_w(offset)/pf_control_w(offset).
    input      [11:0] cpu_addr,
    input      [15:0] cpu_dout,
    input      [ 1:0] pf1_we,
    input      [ 1:0] pf2_we,
    input      [ 2:0] ctrl_addr,
    input             ctrl_we,
    output     [15:0] pf1_dout,
    output     [15:0] pf2_dout,
    output     [15:0] bank_ctl,       // control[7] -> board bank callback

    // gfx packing + bank (board/download properties)
    input             pf1_pswap,
    input             pf2_pswap,
    input             pf1_rowmajor,
    input             pf2_rowmajor,
    input      [ 2:0] pf1_bank,
    input      [ 2:0] pf2_bank,

    // row/column scroll table. pf_update() hands the chip one pointer per
    // playfield; rs_split says whether those are two distinct tables (the
    // playfield then selects the half) or the same one, as on darkseal.
    input             rs_split,
    input      [10:0] rs_addr,
    input      [ 1:0] rs_we,
    output     [15:0] rs_dout,

    output     [ 7:0] pf1_pxl,
    output     [ 7:0] pf2_pxl,

    output            pf1_romcs,
    output     [19:2] pf1_roma,
    input      [31:0] pf1_romdata,
    input             pf1_romok,
    output            pf2_romcs,
    output     [19:2] pf2_roma,
    input      [31:0] pf2_romdata,
    input             pf2_romok
);

// ---- m_pf12_control ----
reg [15:0] ctrl[0:7];
integer ci;
initial begin
    for( ci=0; ci<8; ci=ci+1 ) ctrl[ci]=0;
    if( CTRLHEX != "" ) $readmemh( CTRLHEX, ctrl );
end
always @(posedge clk) if( ctrl_we ) ctrl[ctrl_addr] <= cpu_dout;

assign bank_ctl = ctrl[7];

// ---- m_pf1_data / m_pf2_data ----
wire [11:0] pf1_vaddr, pf2_vaddr;
wire [15:0] pf1_vq, pf2_vq;

jtframe_dual_ram16 #(.AW(12), .ENDIAN(1), .SIMFILE(SIMFILE1)) u_pf1(
    .clk0(clk), .addr0(cpu_addr),  .data0(cpu_dout), .we0(pf1_we), .q0(pf1_dout),
    .clk1(clk), .addr1(pf1_vaddr), .data1(16'd0),    .we1(2'b0),   .q1(pf1_vq)
);

jtframe_dual_ram16 #(.AW(12), .ENDIAN(1), .SIMFILE(SIMFILE2)) u_pf2(
    .clk0(clk), .addr0(cpu_addr),  .data0(cpu_dout), .we0(pf2_we), .q0(pf2_dout),
    .clk1(clk), .addr1(pf2_vaddr), .data1(16'd0),    .we1(2'b0),   .q1(pf2_vq)
);

// ---- row/column scroll table ----
// One physical BRAM shared by both renderers. They read through a single port
// that alternates every clock; each has its own hold register. The renderers
// hold rsram_addr for four cycles, so whichever phase comes first is captured
// in time (see the XW*/CW* wait states in jtcninja_deco16).
wire [10:0] pf1_rsaddr, pf2_rsaddr;
wire [15:0] rs_q;
reg  [15:0] rs_hold1, rs_hold2;
reg         rs_ph, rs_ph_l;

always @(posedge clk) begin
    rs_ph   <= ~rs_ph;
    rs_ph_l <=  rs_ph;                  // phase that produced the current rs_q
    if( !rs_ph_l ) rs_hold1 <= rs_q; else rs_hold2 <= rs_q;
end

// bit 10 picks the playfield's half when the two tables are distinct
wire [10:0] rs_rda = rs_ph ? { rs_split, pf2_rsaddr[9:0] } : { 1'b0, pf1_rsaddr[9:0] };

jtframe_dual_ram16 #(.AW(11), .ENDIAN(1)) u_rs(
    .clk0(clk), .addr0(rs_addr), .data0(cpu_dout), .we0(rs_we), .q0(rs_dout),
    .clk1(clk), .addr1(rs_rda),  .data1(16'd0),    .we1(2'b0),  .q1(rs_q)
);

// ---- the two playfield renderers ----
jtcninja_deco16 u_pf1_gen(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .pxl_cen    ( pxl_cen       ),
    .hs         ( hs            ),
    .vrender    ( vrender       ),
    .hdump      ( hdump         ),
    .flip       ( flip          ),
    .fullheight ( fullheight    ),
    .scrollx    ( ctrl[1]       ),
    .scrolly    ( ctrl[2]       ),
    .control0   ( ctrl[5][ 7:0] ),
    .control1   ( ctrl[6][ 7:0] ),
    .bank       ( pf1_bank      ),
    .pswap      ( pf1_pswap     ),
    .rowmajor   ( pf1_rowmajor  ),
    .ram_addr   ( pf1_vaddr     ),
    .ram_data   ( pf1_vq        ),
    .rsram_addr ( pf1_rsaddr    ),
    .rsram_data ( rs_hold1      ),
    .rom_cs     ( pf1_romcs     ),
    .rom_addr   ( pf1_roma      ),
    .rom_data   ( pf1_romdata   ),
    .rom_ok     ( pf1_romok     ),
    .pxl        ( pf1_pxl       )
);

jtcninja_deco16 u_pf2_gen(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .pxl_cen    ( pxl_cen       ),
    .hs         ( hs            ),
    .vrender    ( vrender       ),
    .hdump      ( hdump         ),
    .flip       ( flip          ),
    .fullheight ( fullheight    ),
    .scrollx    ( ctrl[3]       ),
    .scrolly    ( ctrl[4]       ),
    .control0   ( ctrl[5][15:8] ),
    .control1   ( ctrl[6][15:8] ),
    .bank       ( pf2_bank      ),
    .pswap      ( pf2_pswap     ),
    .rowmajor   ( pf2_rowmajor  ),
    .ram_addr   ( pf2_vaddr     ),
    .ram_data   ( pf2_vq        ),
    .rsram_addr ( pf2_rsaddr    ),
    .rsram_data ( rs_hold2      ),
    .rom_cs     ( pf2_romcs     ),
    .rom_addr   ( pf2_roma      ),
    .rom_data   ( pf2_romdata   ),
    .rom_ok     ( pf2_romok     ),
    .pxl        ( pf2_pxl       )
);

endmodule
