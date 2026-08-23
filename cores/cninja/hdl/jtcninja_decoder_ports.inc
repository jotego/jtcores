/*  Port list shared by the four board decoders (jt<game>_decoder.v).

    One decoder per board, all four instantiated in jtcninja_main and merged:
    outputs OR together, IPLn ANDs (idle = 3'b111), because a disabled decoder
    (en=0) drives every output to its idle value. `en` is the board boolean
    coming from the MRA header.

    The decoder owns everything that differs per board: the address map, the
    read mux (including the maincpu data-line descramble), the cabinet port
    layout, the soundlatch strobe, the interrupt level and its acknowledge.
    jtcninja_main owns the 68000, DTACK, and the vblank latch.

    This file is included in the port list, so it holds no logic. */

    input             rst,
    input             clk,
    input             en,           // board select, from jtcninja_header

    // 68000 bus. busn = no valid memory cycle (see jtcninja_main).
    input      [23:1] A,
    input      [15:0] cpu_dout,
    input             RnW,
    input             UDSn,
    input             LDSn,
    input             busn,

    // beam position, for raster interrupts and the vblank input bit
    input      [ 8:0] vdump,
    input             LVBL,
    input             LHBL,

    // Interrupts. main holds the vblank latch; the board maps it to an IPL
    // level and says when the CPU acknowledged it.
    input             vbl_irq,
    output            vbl_ack,
    output reg [ 2:0] IPLn,

    // Address decode
    output            rom_cs,
    output            ram_cs,       // 68000 work RAM (mem.yaml bram)
    output            pal_cs,
    output            objram_cs,
    output            pf0_cs,       // tilegen[0] footprint; video.v sub-decodes
    output            pf1_cs,       // tilegen[1] footprint
    output            prot_cs,      // DECO 104 (cninja only)
    output            obj_copy,     // sprite RAM -> display buffer DMA

    // Read mux
    input      [15:0] rom_data,
    input      [15:0] work_dout,
    input      [15:0] pf0_dout,
    input      [15:0] pf1_dout,
    input      [15:0] pal_dout,
    input      [15:0] obj_dout,
    input      [15:0] prot_dout,
    output     [15:0] cpu_din,

    // Cabinet. Already active-low (idle=1), matching MAME's IP_ACTIVE_LOW:
    // do NOT invert. cninja reads all of this through the DECO 104 instead.
    input      [`JTFRAME_BUTTONS+3:0] joystick1,
    input      [`JTFRAME_BUTTONS+3:0] joystick2,
    input      [ 3:0] cab_1p,
    input      [ 3:0] coin,
    input      [15:0] dipsw,

    // Sound latch written straight from the main bus (not on cninja)
    output            snd_wr,
    output     [ 7:0] snd_dout,

    // Board registers the colour mixer needs
    output            prot_pri,     // cbuster TC-4 m_pri
    output     [15:0] vprio0,       // vaportra m_priority[0]
    output     [15:0] vprio1        // vaportra m_priority[1]
