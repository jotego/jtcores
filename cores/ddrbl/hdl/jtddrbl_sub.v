/*  jtddrbl_sub.v — SUB CPU (MC6809E) for Double Dribble (Konami GX690)
    GPL3 — see jtcores LICENSE

    Hardware on schematic page 1 (sub CPU + sound CPU + I/O):
      - MC6809E at designator A12 (top-left area of page 1), full 6809E pinout
        visible pins: HALT, NMI, IRQ, FIRQ, RESET, BS, BA, R/W,
                      CLKE (pin 34), CLKQ (pin 35), AVMA, BUSY, TSC,
                      A0..A15, D0..D7
      - Konami 007553 PAL at C11 — confirmed sub-side address decoder.
        JEDEC + decoded equations + pin-label mapping live in:
          cores/ddrbl/doc/Konami_007553_equations.txt
      - LS245 J9  bus transceiver between sub-CPU data bus and shared SRAM
      - LS157 C14 address mux (CPU-side vs main-side select for shared SRAM)
      - LS244 G14 buffer (same chip that buffers CK18 and SCLK — different gates)
      - LS04  H8 inverter, LS74 D15 flip-flop, glue
      - 32 KB program EPROM (27256) somewhere near A19 — TBD which designator
*/

module jtddrbl_sub(
    input               rst,
    input               clk,
    input               cen,           // 1.5 MHz CPU clock-enable

    // CPU bus (exposed for downstream BRAM address routing in game.v)
    output      [15:0]  cpu_addr,
    output              cpu_rnw,
    output      [ 7:0]  cpu_dout,

    // BRAM chip-selects + read-back data (active high)
    output reg          shared_ms_cs,  // 0x0000-0x1FFF  shared with MAIN  [007553 /CRAM, pin 13]
    output reg          shared_sa_cs,  // 0x2000-0x27FF  shared with SOUND
    input       [ 7:0]  shared_ms_dout,
    input       [ 7:0]  shared_sa_dout,

    input  [`JTFRAME_BUTTONS+3:0] joystick1, joystick2,
    input       [ 3:0]  cab_1p,
    input       [ 3:0]  coin,
    input               service,
    input       [31:0]  dipsw,

    input               cpu_irqn,
    input               cpu_nmin,
    input               cpu_firqn,

    output      [14:0]  rom_addr,
    output reg          rom_cs,
    input       [ 7:0]  rom_data,
    input               rom_ok
);

wire [15:0] A;
reg  [ 7:0] cpu_din;
wire        RnW, VMA;
reg         coin_cs, dsw1_cs, dsw2_cs, dsw3_cs,
            p1_cs, p2_cs, sys_cs;

wire [7:0] p1_input = { 1'b1, joystick1[5], joystick1[6], joystick1[4:0] };
wire [7:0] p2_input = { 1'b1, joystick2[5], joystick2[6], joystick2[4:0] };
wire [7:0] system_input = { 3'b111, cab_1p[1:0], service, coin[1:0]};

assign cpu_addr = A;
assign cpu_rnw  = RnW;
assign rom_addr = A[14:0];          // 32 KB ROM, MSB always 1 in CPU view

// /o12 /ROM fires 0x4000-0xFFFF; the 27512 /CE is narrowed by a downstream A15 gate
wire pal_rom = VMA & (A[15] | (~A[15] & A[14]));
wire ioin_cs = VMA & ~A[15] & ~A[14] & A[13] & ~A[12] & A[11] & ~A[10]; // /o18 0x2800-0x2BFF

always @(*) begin
    rom_cs       = pal_rom & A[15];                                  // /ROM  0x8000-0xFFFF
    shared_ms_cs = VMA & ~A[15] & ~A[14] & ~A[13];                   // /CRAM 0x0000-0x1FFF
    shared_sa_cs = VMA & ~A[15] & ~A[14] &  A[13] & ~A[12] & ~A[11]; // /SRAM 0x2000-0x27FF
    dsw2_cs      = VMA & ~A[15] & ~A[14] &  A[13] & ~A[12] &  A[11] &  A[10];  // /DIP2 0x2C00-0x2FFF
    dsw3_cs      = VMA & ~A[15] & ~A[14] &  A[13] &  A[12] & ~A[11] & ~A[10];  // /DIP3 0x3000-0x33FF
    coin_cs      = VMA & ~A[15] & ~A[14] &  A[13] &  A[12] & ~A[11] &  A[10] & ~RnW; // /SET 0x3400-0x37FF (write)
    dsw1_cs      = ioin_cs & (A[1:0]==2'b00);                 // /IOIN + A[1:0]=00
    p1_cs        = ioin_cs & (A[1:0]==2'b01);                 // /IOIN + A[1:0]=01
    p2_cs        = ioin_cs & (A[1:0]==2'b10);                 // /IOIN + A[1:0]=10
    sys_cs       = ioin_cs & (A[1:0]==2'b11);                 // /IOIN + A[1:0]=11
end

always @(*) begin
    cpu_din = 0;
    if      (rom_cs)        cpu_din = rom_data;
    else if (shared_ms_cs)  cpu_din = shared_ms_dout;
    else if (shared_sa_cs)  cpu_din = shared_sa_dout;
    else if (dsw1_cs)       cpu_din = dipsw[ 0+:8];
    else if (dsw2_cs)       cpu_din = dipsw[ 8+:8];
    else if (dsw3_cs)       cpu_din = dipsw[16+:8];
    else if (p1_cs)         cpu_din = p1_input;
    else if (p2_cs)         cpu_din = p2_input;
    else if (sys_cs)        cpu_din = system_input;
end

jtframe_sys6809 #(.RAM_AW(0)) u_cpu(
    .rstn       ( ~rst      ),
    .clk        ( clk       ),
    .cen        ( cen       ),
    .cpu_cen    (           ),
    .nIRQ       ( cpu_irqn  ),
    .nFIRQ      ( cpu_firqn ),
    .nNMI       ( cpu_nmin  ),
    .irq_ack    (           ),
    .bus_busy   ( 1'b0      ),
    .A          ( A         ),
    .RnW        ( RnW       ),
    .VMA        ( VMA       ),
    .ram_cs     ( 1'b0      ),
    .rom_cs     ( rom_cs    ),
    .rom_ok     ( rom_ok    ),
    .ram_dout   (           ),
    .cpu_dout   ( cpu_dout  ),
    .cpu_din    ( cpu_din   )
);

endmodule