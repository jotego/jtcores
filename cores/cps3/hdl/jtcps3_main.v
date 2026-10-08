/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 7-2-2026 */

`ifdef CPS3_CPU_TEST
`include "../ver/cputest/jtcps3_cputest_status.v"
`endif

module jtcps3_main(
    input               clk,
    input               clk48,
    input               rst, rst48,
    input               cen_r,
    input       [31:0]  cps3_key1,
    input       [31:0]  cps3_key2,
    input       [ 2:0]  cps3_crypt_mode,
    input       [ 2:0]  cps3_region,
    input               cps3_region_redearth,
    // SH7604 external bus
    output      [26:0]  A,
    output      [31:0]  cpu_dout,
    output              wr_n,
    output      [ 3:0]  we_n,
    output              bs_n,
    output              rd_n,
    // CPU bank 0 cache lane
    output reg  [23:2]  cpuba0_addr,
    output reg          cpuba0_rd,
    input       [31:0]  cpuba0_data,
    input               cpuba0_ok,
    output reg          cpuba0_we,
    output reg  [31:0]  cpuba0_din,
    output reg  [ 3:0]  cpuba0_dsn,
    // SIMM 2 cache lane
    output      [22:2]  simm2_addr,
    output              simm2_rd,
    input       [31:0]  simm2_data,
    input               simm2_ok,
    output              simm2_we,
    output      [31:0]  simm2_din,
    output      [ 3:0]  simm2_dsn,
    // Area 1 decoded chip selects
    output reg          fram_cs, // ferroelectric NVRAM only used in test mode
    input       [ 7:0]  fram_dout,
    // Area 2 - Graphics subsystem
    output reg          cram_cs,
    input       [31:0]  cram_data,
    output reg          ppu_cs,
    output reg          snd_cs,
    input       [31:0]  snd_data,
    output reg          charram_cs,
    output              charram_rd,
    output              charram_we,
    output      [19:2]  charram_addr,
    output      [31:0]  charram_din,
    output      [ 3:0]  charram_dsn,
    input       [31:0]  charram_data,
    input               charram_ok,
    output reg          gfxflash_cs,
    input       [15:0]  gfxflash_bank,
    output reg          gfxflash_rd,
    output reg  [25:2]  gfxflash_addr,
    input       [31:0]  gfxflash_data,
    input               gfxflash_ok,
    // Area 2 - I/O subsystem
    output reg          input_cs,
    input       [ 3:0]  cab_1p,
    input       [ 3:0]  coin,
    input       [ 9:0]  joystick1,
    input       [ 9:0]  joystick2,
    input               service,
    input               dip_test,
    input               dip_pause,
    output reg          dipsw_cs,
    output reg          eeprom_cs,
    output      [ 6:2]  eeprom_addr,
    output      [31:0]  eeprom_din,
    output      [ 3:0]  eeprom_we,
    input       [31:0]  eeprom_dout,
    output reg          ssram_cs,
    output reg          ssreg_cs,
    output reg          scsi_cs,
    // Area 3 decoded chip selects
    output reg          flash2_cs,
    // SS RAM
    output      [13:1]  sschar_addr,
    output      [15:0]  sschar_din,
    input       [15:0]  sschar_dout,
    output      [ 1:0]  sschar_we,
    output      [12:1]  ssmap_addr,
    output      [15:0]  ssmap_din,
    input       [15:0]  ssmap_dout,
    output      [ 1:0]  ssmap_we,
    output      [12:1]  ssscr_addr,
    output      [15:0]  ssscr_din,
    input       [15:0]  ssscr_dout,
    output      [ 1:0]  ssscr_we,
    // Interrupts
    input               lvbl,
    input       [ 2:0]  dma_busy,
    input       [ 1:0]  dma_done
`ifdef CPS3_CPU_TEST
    , output      [2:0] cputest_crypt_mode
`endif
);
`ifndef NOMAIN
wire         cs0_n, cs1_n, cs2_n, cs3_n, wait_n, cache_ok, cache_ok_raw;
wire         cache_req;
reg          cache_req_l, cache_ok_l;
wire         sh_cache_cs, sh_cache_rd;
reg          bios_cs, ram_cs, sprite_cs, flash1_cs;
reg  [31:0]  cpu_din, cab_dout;
reg  [31:0]  scsi_data_l;
wire [31:0]  cab_lo;
wire [31:0]  cab_hi;
wire [31:0]  cpuba0_data16;
wire [31:0]  cpuba0_din_cpu;
wire [23:2]  cpuba0_addr_nx;
wire [31:0]  cpuba0_din_nx;
wire [ 3:0]  cpuba0_dsn_nx;
wire         cpuba0_rd_nx, cpuba0_we_nx, cpuba0_req_match, cpuba0_ok_match;
wire         flash1_mem_match;
wire         flash1_mem_ok;
wire [31:0]  cpuba0_data_flash1;
wire [31:0]  cpuba0_data_flash2;
wire [21:0]  flash1_mem_addr;
wire [21:0]  flash2_mem_addr;
wire         flash1_mem_rd;
wire         flash2_mem_rd;
wire         flash1_mem_we;
wire         flash2_mem_we;
wire [31:0]  flash1_mem_din;
wire [31:0]  gfxflash_dout, gfxflash_dout_eff, gfxflash_din, gfxflash_data16;
wire [25:2]  gfxflash_addr_nx;
wire [25:0]  gfxflash_user5_addr;
wire [20:0]  gfxflash_chip_addr;
reg  [15:0]  gfxflash_bank_adj;
wire [ 3:0]  gfxflash_dsn;
wire         gfxflash_mem_rd, gfxflash_rd_nx, gfxflash_flash_ok, gfxflash_ok_eff;
// Hold the flash ack until the CPU bus drops the read request. The SH-2 wait
// pipeline samples cache_ok one cycle later, so a one-cycle flash pulse is too
// narrow here.
reg          gfxflash_ok_l;
reg          gfxflash_bank_valid;
wire         cpu_rd_bus, cpu_wr_bus;
wire [ 3:0]  cpuba0_dsn_cpu;
wire [ 3:0]  flash1_mem_dsn;
wire         flash1_ok;
wire         flash2_ok;
reg          flash1_cs_l, flash2_cs_l;
reg          flash_rd_l, flash_wr_l;
reg  [20:0]  flash_addr_l;
reg  [31:0]  flash_din_l;
reg  [ 3:0]  flash_dsn_l;
wire [31:0]  charram_data16;
wire [31:0]  cab_data16;
wire [31:0]  eeprom_data;
wire [31:0]  scsi_data;
wire [31:0]  ssram_data;
wire [15:0]  ssram_dout;
wire [ 7:0]  ssram_byte_data;
wire [ 1:0]  ssram_byte_we;
wire         bram_rd_req, bram_rd_ok;
reg  [ 1:0]  bram_rd_wait;
wire [11:0]  eeprom_cpu_addr;
wire [ 7:0]  scsi_din;
wire [ 1:0]  scsi_addr;
wire         cpuba0_bus_cs, cpuba0_word_cs;
reg          ssmap_cs, ssscr_cs, sschar_cs;

// IRQ signals
wire        vbl_irq, dma_irq;
wire [ 3:0] irl_n;
reg         vbl_clr, dma_clr;

// Unused SH7604 outputs
wire ce_n, oe_n, ivecf_n, rfs, bgr_n;
wire ftoa, ftob, txd, scko, wdtovf_n;
wire dack0, dack1;

// SH7604 mode pins: Master, 32-bit Area 0 bus width
// MD[5]=0 master, MD[4:3]=2'b10 A0_SZ=longword, MD[2:0]=3'b100
localparam [5:0] MD_CFG = 6'b010100;

localparam [15:0] GFXFLASH_BANK_FIRST = 16'h0002;
localparam [15:0] GFXFLASH_BANK_LAST  = 16'h0021;

assign cache_req    = sh_cache_cs;
assign cache_ok     = !cache_req ? 1'b1 : (cache_req_l & cache_ok_l);
assign cache_ok_raw = flash1_cs     ? flash1_ok       :
                      flash2_cs     ? flash2_ok       :
                      gfxflash_cs   ? (cpu_rd_bus ? gfxflash_ok_l : gfxflash_ok_eff) :
                      cpuba0_bus_cs ? cpuba0_ok_match :
                      charram_cs    ? charram_ok      :
                      bram_rd_req   ? bram_rd_ok      : 1'b1;

always @(posedge clk) begin
    if (rst) begin
        cache_req_l <= 1'b0;
        cache_ok_l  <= 1'b0;
        gfxflash_ok_l <= 1'b0;
    end else begin
        cache_req_l <= cache_req;
        cache_ok_l  <= cache_ok_raw;
        if (!gfxflash_cs || !cpu_rd_bus) begin
            gfxflash_ok_l <= 1'b0;
        end else if (gfxflash_ok_eff) begin
            gfxflash_ok_l <= 1'b1;
        end
    end
end

// Address decoding: A[26:25] selects area, lower bits select sub-region
always @* begin
    fram_cs     = 0;
    cram_cs     = 0;
    ppu_cs      = 0;
    snd_cs      = 0;
    charram_cs  = 0;
    gfxflash_cs = 0;
    input_cs    = 0;
    dipsw_cs    = 0;
    eeprom_cs   = 0;
    ssram_cs    = 0;
    ssreg_cs    = 0;
    vbl_clr     = 0;
    dma_clr     = 0;
    scsi_cs     = 0;
    flash1_cs   = 0;
    flash2_cs   = 0;
    bios_cs     = 0;
    ram_cs      = 0;
    sprite_cs   = 0;

    if(!cs0_n) begin // Area 0: 0x00000000-0x01FFFFFF
        bios_cs = ~|A[24:19]; // 0x00000000-0x0007FFFF (512KB)
    end
    if(!cs1_n) begin // Area 1: 0x02000000-0x03FFFFFF
        ram_cs  = ~|A[24:19];       // 0x02000000-0x0207FFFF (512KB)
        fram_cs = A[24] & ~|A[23:10]; // 0x03000000-0x030003FF (1KB)
    end
    if(!cs2_n) begin // Area 2: 0x04000000-0x05FFFFFF
        if(!A[24]) begin // 0x04000000-0x04FFFFFF Graphics
            sprite_cs   = ~|A[23:19];          // 0x04000000-0x0407FFFF
            cram_cs     = A[23:18]==6'b000010;  // 0x04080000-0x040BFFFF
            ppu_cs      = A[23:16]==8'h0C;      // 0x040C0000-0x040CFFFF
            snd_cs      = A[23:16]==8'h0E;      // 0x040E0000-0x040EFFFF
            charram_cs  = A[23:20]==4'h1;       // 0x04100000-0x041FFFFF
            gfxflash_cs = A[23:21]==3'b001;     // 0x04200000-0x043FFFFF
        end else begin // 0x05000000-0x05FFFFFF I/O
            case(A[23:16])
                8'h00: begin // 0x05000000-0x0500FFFF
                    input_cs  = A[15:12]==4'h0 && !A[11];  // 0x05000000-0x050007FF
                    dipsw_cs  = A[15:5]==11'b0000_1010_000; // 0x05000A00-0x05000A1F
                    eeprom_cs = A[15:12]==4'h1;            // 0x05001000-0x05001FFF
                end
                8'h04: ssram_cs  = 1; // 0x05040000-0x0504FFFF
                8'h05: ssreg_cs  = A[15:6]==10'd0 && A[5:0] <= 6'h2b; // 0x05050000-0x0505002B
                8'h10: vbl_clr   = A[15:2]==14'd0; // 0x05100000-0x05100003 IRQ12 ack
                8'h11: dma_clr   = A[15:2]==14'd0; // 0x05110000-0x05110003 IRQ10 ack
                8'h14: scsi_cs   = A[15:2]==14'd0; // 0x05140000-0x05140003
                default: ;
            endcase
        end
    end
    if(!cs3_n) begin // Area 3: 0x06000000-0x07FFFFFF
        flash1_cs = ~A[24] & ~A[23]; // 0x06000000-0x067FFFFF (SIMM 1)
        flash2_cs = ~A[24] &  A[23]; // 0x06800000-0x06FFFFFF (SIMM 2)
    end

    ssmap_cs  = ssram_cs & ~A[15] & ~A[14];
    ssscr_cs  = ssram_cs & ~A[15] &  A[14];
    sschar_cs = ssram_cs &  A[15];
end

wire [31:0] fram_d32 = {8'd0, fram_dout, 8'd0, fram_dout};

assign cpuba0_addr_nx = bios_cs   ? { 5'd0,  A[18:2] } :
                        flash1_cs ? flash1_mem_addr + 22'h020000 :
                        sprite_cs ? { 5'h11, A[18:2] } :
                                    { 5'h12, A[18:2] } ; /* ram_cs */
assign cpuba0_bus_cs  = bios_cs | flash1_cs | sprite_cs | ram_cs;
assign cpuba0_word_cs = ram_cs | sprite_cs;
assign cpuba0_rd_nx   = flash1_cs ? flash1_mem_rd : (cpuba0_bus_cs &  wr_n & ~rd_n);
assign cpuba0_we_nx   = flash1_cs ? flash1_mem_we : (cpuba0_bus_cs & ~wr_n);
assign cpuba0_din_nx  = flash1_cs ? flash1_mem_din : cpuba0_din_cpu;
assign cpuba0_dsn_nx  = flash1_cs ? flash1_mem_dsn : cpuba0_dsn_cpu;
assign cpuba0_req_match = cpuba0_addr == cpuba0_addr_nx &&
                          cpuba0_rd   == cpuba0_rd_nx   &&
                          cpuba0_we   == cpuba0_we_nx   &&
                          (!cpuba0_we_nx ||
                           (cpuba0_din == cpuba0_din_nx && cpuba0_dsn == cpuba0_dsn_nx));
assign cpuba0_ok_match = cpuba0_req_match & cpuba0_ok;
assign flash1_mem_match = cpuba0_addr == flash1_mem_addr + 22'h020000 &&
                          cpuba0_rd   == flash1_mem_rd &&
                          cpuba0_we   == flash1_mem_we &&
                          (!flash1_mem_we ||
                           (cpuba0_din == flash1_mem_din && cpuba0_dsn == flash1_mem_dsn));
assign flash1_mem_ok   = flash1_mem_match & cpuba0_ok;
assign charram_rd     = charram_cs &  wr_n & ~rd_n;
assign charram_we     = charram_cs & ~wr_n;
assign charram_addr   = A[19:2];
assign charram_din    = A[1] ? {16'd0, cpu_dout[15:0]} : {cpu_dout[15:0], 16'd0};
assign charram_dsn    = charram_we ? (A[1] ? {2'b11, we_n[1:0]} : {we_n[1:0], 2'b11}) : 4'hf;
assign charram_data16 = A[1] ? {16'd0, charram_data[15:0]} : {16'd0, charram_data[31:16]};
assign cpu_rd_bus     = wr_n & ~rd_n;
assign cpu_wr_bus     = ~wr_n;
assign eeprom_cpu_addr = A[11:0];
assign scsi_addr      = A[1:0];
assign scsi_din       = cpu_dout[7:0];

assign gfxflash_chip_addr  = { gfxflash_bank_adj[0], A[20:2], A[1] };
assign gfxflash_user5_addr = { gfxflash_bank_adj[4:0], 21'd0 } + { 5'd0, A[20:2], 2'b00 };
assign gfxflash_addr_nx    = gfxflash_user5_addr[25:2];
assign gfxflash_rd_nx      = gfxflash_bank_valid & gfxflash_mem_rd;
assign gfxflash_din        = A[1] ? {16'd0, cpu_dout[15:0]} : {cpu_dout[15:0], 16'd0};
assign gfxflash_dsn        = cpu_wr_bus ? (A[1] ? {2'b11, we_n[1:0]} : {we_n[1:0], 2'b11}) : 4'hf;
assign gfxflash_ok_eff     = gfxflash_bank_valid ? gfxflash_flash_ok :
                             (gfxflash_cs & (cpu_rd_bus | cpu_wr_bus));
assign gfxflash_dout_eff   = gfxflash_bank_valid ? gfxflash_dout : 32'hffff_ffff;
assign gfxflash_data16     = A[1] ? {16'd0, gfxflash_dout_eff[15:0]} : {16'd0, gfxflash_dout_eff[31:16]};

always @(posedge clk) begin
    if (rst) begin
        flash1_cs_l  <= 1'b0;
        flash2_cs_l  <= 1'b0;
        flash_rd_l   <= 1'b0;
        flash_wr_l   <= 1'b0;
        flash_addr_l <= 21'd0;
        flash_din_l  <= 32'd0;
        flash_dsn_l  <= 4'hf;
    end else begin
        flash1_cs_l  <= flash1_cs;
        flash2_cs_l  <= flash2_cs;
        flash_rd_l   <= wr_n & ~rd_n;
        flash_wr_l   <= ~wr_n;
        flash_addr_l <= A[22:2];
        flash_din_l  <= cpuba0_din_cpu;
        flash_dsn_l  <= cpuba0_dsn_cpu;
    end
end

always @(posedge clk) begin
    if (rst) begin
        gfxflash_bank_valid <= 1'b0;
        gfxflash_bank_adj   <= 16'd0;
        gfxflash_addr       <= 24'd0;
        gfxflash_rd         <= 1'b0;
    end else begin
        gfxflash_bank_valid <= gfxflash_bank >= GFXFLASH_BANK_FIRST &&
                               gfxflash_bank <= GFXFLASH_BANK_LAST;
        gfxflash_bank_adj   <= gfxflash_bank - GFXFLASH_BANK_FIRST;
        gfxflash_addr       <= gfxflash_addr_nx;
        gfxflash_rd         <= gfxflash_rd_nx;
    end
end

jtcps3_main_ram_adapter u_ram_adapter(
    .word_cs     ( cpuba0_word_cs ),
    .A           ( A[1:0]         ),
    .cpu_dout    ( cpu_dout       ),
    .we_n        ( we_n           ),
    .cpuba0_data ( cpuba0_data    ),
    .cpuba0_din  ( cpuba0_din_cpu ),
    .cpuba0_dsn  ( cpuba0_dsn_cpu ),
    .word_data   ( cpuba0_data16 )
);

jtcps3_simm_flash u_flash1(
    .rst      ( rst                 ),
    .clk      ( clk                 ),
    // CPU interface
    .cs       ( flash1_cs_l         ),
    .rd       ( flash_rd_l          ),
    .wr       ( flash_wr_l          ),
    .addr     ( flash_addr_l        ),
    .din      ( flash_din_l         ),
    .dsn      ( flash_dsn_l         ),
    .dout     ( cpuba0_data_flash1  ),
    .ok       ( flash1_ok           ),
    // interface to SDRAM (via cache mux)
    .mem_addr ( flash1_mem_addr     ),
    .mem_rd   ( flash1_mem_rd       ),
    .mem_we   ( flash1_mem_we       ),
    .mem_data ( cpuba0_data         ),
    .mem_ok   ( flash1_mem_ok       ),
    .mem_din  ( flash1_mem_din      ),
    .mem_dsn  ( flash1_mem_dsn      )
);

jtcps3_simm_flash u_flash2(
    .rst      ( rst                 ),
    .clk      ( clk                 ),
    // CPU interface
    .cs       ( flash2_cs_l         ),
    .rd       ( flash_rd_l          ),
    .wr       ( flash_wr_l          ),
    .addr     ( flash_addr_l        ),
    .din      ( flash_din_l         ),
    .dsn      ( flash_dsn_l         ),
    .dout     ( cpuba0_data_flash2  ),
    .ok       ( flash2_ok           ),
    // interface to SDRAM (via cache mux)
    .mem_addr ( flash2_mem_addr     ),
    .mem_rd   ( flash2_mem_rd       ),
    .mem_we   ( flash2_mem_we       ),
    .mem_data ( simm2_data          ),
    .mem_ok   ( simm2_ok            ),
    .mem_din  ( simm2_din           ),
    .mem_dsn  ( simm2_dsn           )
);

assign simm2_addr = flash2_mem_addr[20:0];
assign simm2_rd   = flash2_mem_rd;
assign simm2_we   = flash2_mem_we;

jtcps3_simm_flash #(
    .WRITE_ENABLE( 0 ),
    .PAIR_LANES  ( 1 )
) u_gfxflash(
    .rst      ( rst                 ),
    .clk      ( clk                 ),
    // CPU interface
    .cs       ( gfxflash_cs & gfxflash_bank_valid ),
    .rd       ( cpu_rd_bus          ),
    .wr       ( cpu_wr_bus          ),
    .addr     ( gfxflash_chip_addr  ),
    .din      ( gfxflash_din        ),
    .dsn      ( gfxflash_dsn        ),
    .dout     ( gfxflash_dout       ),
    .ok       ( gfxflash_flash_ok   ),
    // read-only interface to the shared GFX/user5 SDRAM lane
    .mem_addr (                     ),
    .mem_rd   ( gfxflash_mem_rd     ),
    .mem_we   (                     ),
    .mem_data ( gfxflash_data       ),
    .mem_ok   ( gfxflash_ok         ),
    .mem_din  (                     ),
    .mem_dsn  (                     )
);

jtcps3_eeprom u_eeprom(
    .rst      ( rst         ),
    .clk      ( clk         ),
    .cs       ( eeprom_cs   ),
    .rd       ( cpu_rd_bus  ),
    .wr       ( cpu_wr_bus  ),
    .addr     ( eeprom_cpu_addr  ),
    .din      ( cpu_dout    ),
    .we_n     ( we_n        ),
    .mem_addr ( eeprom_addr ),
    .mem_din  ( eeprom_din  ),
    .mem_we   ( eeprom_we   ),
    .mem_dout ( eeprom_dout ),
    .dout     ( eeprom_data )
);

jtcps3_wd33c93 u_wd33c93(
    .rst      ( rst           ),
    .clk      ( clk           ),
    .cs       ( scsi_cs       ),
    .wr       ( cpu_wr_bus    ),
    .addr     ( scsi_addr     ),
    .din      ( scsi_din      ),
    .we_n     ( we_n          ),
    .dout     ( scsi_data     )
);

assign cab_lo = {
    2'b11, cab_1p[1:0], 1'b1, joystick2[9], coin[1:0],
    6'h3f, dip_test, service, 1'b1, joystick2[6:0], 1'b1, joystick1[6:0]
};
assign cab_hi = { 10'h3ff, joystick2[8:7], joystick1[7], joystick1[8], joystick1[9], 17'h1ffff };

assign ssram_dout      = ssscr_cs ? ssscr_dout :
                         sschar_cs ? sschar_dout : ssmap_dout;
assign ssram_byte_data = A[1] ? ssram_dout[15:8] : ssram_dout[7:0];
assign ssram_data      = { 24'd0, ssram_byte_data };
assign ssram_byte_we   = ssram_cs & ~wr_n & ~we_n[0] ? (A[1] ? 2'b10 : 2'b01) : 2'b00;
assign bram_rd_req     = (ssram_cs | cram_cs | scsi_cs) & sh_cache_cs & sh_cache_rd;
assign bram_rd_ok      = bram_rd_wait[1];
assign sschar_addr     = A[14:2];
assign sschar_din      = {2{cpu_dout[7:0]}};
assign sschar_we       = sschar_cs ? ssram_byte_we : 2'b00;
assign ssmap_addr      = A[13:2];
assign ssmap_din       = {2{cpu_dout[7:0]}};
assign ssmap_we        = ssmap_cs ? ssram_byte_we : 2'b00;
assign ssscr_addr      = A[13:2];
assign ssscr_din       = {2{cpu_dout[7:0]}};
assign ssscr_we        = ssscr_cs ? ssram_byte_we : 2'b00;

always @(posedge clk) begin
    if (rst) begin
        bram_rd_wait <= 2'b00;
    end else if (bram_rd_req && bram_rd_wait == 2'b00) begin
        bram_rd_wait <= 2'b01;
    end else begin
        bram_rd_wait <= { bram_rd_wait[0], 1'b0 };
    end
end

always @(posedge clk) begin
    if (rst) begin
        cpuba0_addr <= 22'd0;
        cpuba0_rd   <= 1'b0;
        cpuba0_we   <= 1'b0;
        cpuba0_din  <= 32'd0;
        cpuba0_dsn  <= 4'hf;
    end else begin
        cpuba0_addr <= cpuba0_addr_nx;
        cpuba0_rd   <= cpuba0_rd_nx;
        cpuba0_we   <= cpuba0_we_nx;
        cpuba0_din  <= cpuba0_din_nx;
        cpuba0_dsn  <= cpuba0_dsn_nx;
    end
end

always @(posedge clk) begin
    cab_dout    <= (A[2] ? cab_hi : cab_lo);
    scsi_data_l <= scsi_data;
end

assign cab_data16 = { 16'd0, A[1] ? cab_dout[15:0] : cab_dout[31:16] };

wire [31:0] cpuba0_mux = cpuba0_word_cs ? cpuba0_data16      :
                         flash1_cs             ? cpuba0_data_flash1 :
                         cpuba0_data;

always @* begin
    cpu_din = cpuba0_bus_cs ? cpuba0_mux    :
              flash2_cs     ? cpuba0_data_flash2 :
              fram_cs       ? fram_d32      :
              ppu_cs        ? (A[7:1] == 7'h06 ? { 29'd0, dma_busy } : 32'd0) :
              cram_cs       ? cram_data     :
              snd_cs        ? snd_data      :
              charram_cs    ? charram_data16:
              gfxflash_cs   ? gfxflash_data16:
              input_cs      ? cab_data16    :
              dipsw_cs      ? 32'hffff_ffff :
              eeprom_cs     ? eeprom_data   :
              ssram_cs      ? ssram_data    :
              scsi_cs       ? scsi_data_l   : 32'd0;
end

`ifdef CPS3_CPU_TEST
    jtcps3_cputest_status u_cputest_status(
        .clk        ( clk       ),
        .rst        ( rst       ),
        .cs3_n      ( cs3_n     ),
        .wr_n       ( wr_n      ),
        .A          ( A         ),
        .cpu_dout   ( cpu_dout  ),
        .crypt_mode   ( cputest_crypt_mode )
    );
`endif

// IRL_N priority encoding: lower value = higher priority
// Level 12 (vblank) > Level 10 (DMA)
assign irl_n = vbl_irq & dip_pause ? ~4'd12 :
               dma_irq             ? ~4'd10 : 4'hf;

jtframe_edge u_vbl(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .edgeof (~lvbl      ),
    .clr    ( vbl_clr   ),
    .q      ( vbl_irq   )
);

jtframe_edge u_dma(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .edgeof ( |dma_done ),
    .clr    ( dma_clr   ),
    .q      ( dma_irq   )
);

// Big endian
// long words are DO/DI = {addr+0,addr+1,addr+2,addr+3}
// 16-bit/8-bit operations only use DO[15:0] or DO[7:0]
`ifdef VERILATOR_KEEP_CPU
/* verilator tracing_on */
`endif
reg cen_f;

always @(posedge clk48) cen_f <= cen_r;

jtsh7604 #(
    .UBC_DISABLE( 1'b1 ),
    .SCI_DISABLE( 1'b1 ),
    .WDT_DISABLE( 1'b1 )
) u_sh7604(
    .rst        ( rst48      ),
    .clk        ( clk48      ),
    .ce_r       ( cen_r      ),
    .ce_f       ( cen_f      ),
    .nmi_n      ( 1'b1       ),
    .irl_n      ( irl_n      ),
    .cpu_din    ( cpu_din    ),
    .cps3_key1             ( cps3_key1             ),
    .cps3_key2             ( cps3_key2             ),
    .cps3_crypt_mode       ( cps3_crypt_mode       ),
    .cps3_region           ( cps3_region           ),
    .cps3_region_redearth ( cps3_region_redearth ),
    .cache_ok   ( cache_ok   ),
    .A          ( A          ),
    .cpu_dout   ( cpu_dout   ),
    .BS_N       ( bs_n       ),
    .CS0_N      ( cs0_n      ),
    .CS1_N      ( cs1_n      ),
    .CS2_N      ( cs2_n      ),
    .CS3_N      ( cs3_n      ),
    .RD_WR_N    ( wr_n       ),
    .CE_N       ( ce_n       ),
    .OE_N       ( oe_n       ),
    .WE_N       ( we_n       ),
    .RD_N       ( rd_n       ),
    .IVECF_N    ( ivecf_n    ),
    .RFS        ( rfs        ),
    .BGR_N      ( bgr_n      ),
    .WAIT_N     ( wait_n     ),
    .cache_cs   ( sh_cache_cs ),
    .cache_we   (            ),
    .cache_rd   ( sh_cache_rd ),
    .cache_wr   (            ),
    .cache_addr (            ),
    .cache_din  (            ),
    .cache_dsn  (            )
    );
/* verilator tracing_off */
`else
    assign A=0, cpu_dout=0, wr_n=1, we_n=4'hf, bs_n=1, rd_n=1;
    assign sschar_addr   = 13'd0, sschar_din = 16'd0, sschar_we = 2'd0,
    ssmap_addr    = 12'd0, ssmap_din = 16'd0, ssmap_we = 2'd0,
    ssscr_addr = 12'd0, ssscr_din = 16'd0, ssscr_we = 2'd0,
    charram_rd = 0, charram_we = 0, charram_addr = 0,
    charram_din = 0, charram_dsn = 0,
    simm2_rd = 0, simm2_we = 0, simm2_din = 0, simm2_dsn = 15, simm2_addr = 0,
    eeprom_addr = 0, eeprom_din = 0, eeprom_we = 0;
    initial begin
        cpuba0_addr = 22'd0;
        cpuba0_rd   = 1'b0;
        cpuba0_we   = 1'b0;
        cpuba0_din  = 32'd0;
        cpuba0_dsn  = 4'hf;
        fram_cs     = 0;
        cram_cs     = 0;
        ppu_cs      = 0;
        snd_cs      = 0;
        charram_cs  = 0;
        gfxflash_cs = 0;
        gfxflash_rd = 0;
        gfxflash_addr = 24'd0;
        input_cs    = 0;
        dipsw_cs    = 0;
        eeprom_cs   = 0;
        ssram_cs    = 0;
        ssreg_cs    = 0;
        scsi_cs     = 0;
        flash2_cs   = 0;
    end
`endif
endmodule
