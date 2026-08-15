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
    Date: 5-2026

    Reference for protocol semantics:
      - MAME taito/taitosnd.cpp  (mirrored in cores/superman/doc/)
      - Arcade-TaitoF2_MiSTer rtl/tc0140syt.sv (read-only reference,
        see cores/superman/doc/tc0140syt.sv.ref). Written fresh here;
        no verbatim copy of GPLv2 code into this GPLv3 file.
*/

// Taito TC0140SYT — sound communication chip between 68000 main CPU and
// Z80 sound CPU. The real silicon also owns the Z80 memory decoder
// (ROM/RAM/YM CS signals) and a 3-bit ROM bank register written at 0xF200.
//
// Master (68k) side is 4-bit data, register-port at A0=0, data-port at A0=1.
// Slave  (Z80) side is 8-bit data, memory-mapped at 0xE200-0xE201
// (register-port at A0=0, data-port at A0=1) and 0xF200 (bank register).
//
// Index semantics — verified against MAME src/mame/shared/taitosnd.cpp:
//
//   MASTER (68k) side (master_port_w sets mainmode; only 0..4 valid):
//     idx 0..3 : nibbles of slave_data (master->slave) word.
//                comm_w at idx 1 sets status[0] = PORT01_FULL (NMI source).
//                comm_w at idx 3 sets status[1] = PORT23_FULL (NMI source).
//                comm_r at idx 1 clears status[2] = PORT01_FULL_MASTER.
//                comm_r at idx 3 clears status[3] = PORT23_FULL_MASTER.
//     idx 4    : comm_w drives slave (Z80) reset:
//                  hi-lo transition releases Z80. data!=0 asserts reset,
//                  data==0 clears it. comm_r returns the 4-bit status:
//                    bit 0 PORT01_FULL        (slave rx pending — NMI src)
//                    bit 1 PORT23_FULL        (slave rx pending — NMI src)
//                    bit 2 PORT01_FULL_MASTER (master rx pending)
//                    bit 3 PORT23_FULL_MASTER (master rx pending)
//
//   SLAVE  (Z80) side (slave_port_w sets submode; only 0..6 valid):
//     idx 0..3 : nibbles of master_data (slave->master) word.
//                comm_w at idx 1 sets status[2] = PORT01_FULL_MASTER.
//                comm_w at idx 3 sets status[3] = PORT23_FULL_MASTER.
//                comm_r at idx 1 clears status[0] = PORT01_FULL.
//                comm_r at idx 3 clears status[1] = PORT23_FULL.
//     idx 4    : status read on comm_r (same 4 bits as master idx 4 read).
//                comm_w at idx 4 is a NOP in MAME.
//     idx 5    : comm_w disables NMI.
//     idx 6    : comm_w enables  NMI.
//
// NMI to Z80 is asserted iff nmi_enabled && (status[1:0] != 0).

module jtsuperman_syt(
    input               rst,
    input               clk,

    // 68k master interface — main CPU sound port (e.g. 0x800000-0x800003)
    input               main_cs,      // decoded externally
    input               main_addr,    // 68k A1 (selects register vs data port)
    input         [3:0] main_dout,    // low nibble of main data bus
    output        [3:0] main_din,
    input               main_we,      // active high: 68k is writing

    // Z80 slave interface — full Z80 address space (chip owns the decode)
    input        [15:0] snd_addr,
    input         [7:0] snd_dout,
    output        [7:0] snd_din,      // 4 nibbles + status in low bits, hi=0
    input               snd_mreq_n,
    input               snd_rd_n,
    input               snd_wr_n,

    // Z80 memory decode (real chip emits these)
    output              snd_rom_cs,   // 0x0000-0x7FFF, banked at 0x4000+
    output reg    [1:0] snd_rom_a16,  // extra ROM address bits when in bank window
    output              snd_ram_cs,   // 0xC000-0xDFFF
    output              snd_ym_cs,    // 0xE000-0xE0FF (-> YM2610)
    output              snd_syt_sel,  // exposed for debug / external bus mux

    // Slave control
    output              snd_rst,      // software reset (idx 7 write)
    output              snd_nmi_n     // NMI to Z80 (active low)
);

    // ----------------------------------------------------------------
    // Z80 memory decoder — replicated from the real chip
    // ----------------------------------------------------------------
    wire       in_bank   = snd_addr[15:14] == 2'b01;        // 0x4000-0x7FFF
    wire       in_lowrom = snd_addr[15]    == 1'b0;         // 0x0000-0x7FFF
    wire       in_ram    = snd_addr[15:13] == 3'b110;       // 0xC000-0xDFFF
    wire       in_ym     = snd_addr[15:8]  == 8'hE0;        // 0xE000-0xE0FF
    wire       in_self   = snd_addr[15:8]  == 8'hE2;        // 0xE200-0xE2FF
    wire       in_bankw  = snd_addr[15:8]  == 8'hF2;        // 0xF200 bank reg

    // TC0140SYT is purely memory-mapped, so only MREQ matters.
    wire       z80_mem    = ~snd_mreq_n;
    // z80_rd was declared for symmetry but no state changes on read;
    // dropped to silence Quartus warning 10036.
    wire       z80_wr     = z80_mem & ~snd_wr_n;

    assign snd_rom_cs = z80_mem & in_lowrom;
    assign snd_ram_cs = z80_mem & in_ram;
    assign snd_ym_cs  = z80_mem & in_ym;
    assign snd_syt_sel = z80_mem & in_self;

    // ----------------------------------------------------------------
    // ROM bank register at 0xF200 (write any value, low 3 bits matter)
    //   bit[2]: when set, the 0x4000-0x7FFF window selects the ROM region
    //           beyond 32KB (vs reading the static low half)
    //   bit[1:0]: A14/A15 of the external ROM during the banked window
    // ----------------------------------------------------------------
    reg  [2:0] rom_bank;
    always @(posedge clk) begin
        if (rst) begin
            rom_bank    <= 3'd0;
            snd_rom_a16 <= 2'd0;
        end else begin
            if (z80_wr & in_bankw)
                rom_bank <= snd_dout[2:0];
            // Drive A14/A15 only when reading the banked window
            snd_rom_a16 <= in_bank ? rom_bank[1:0] : 2'b00;
        end
    end

    // ----------------------------------------------------------------
    // Shared state — two 16-bit data words + 4-bit status + control flags
    // ----------------------------------------------------------------
    reg [15:0] master_data;  // slave -> master  (read by 68k, written by Z80)
    reg [15:0] slave_data;   // master -> slave  (written by 68k, read by Z80)
    reg [ 3:0] master_idx;   // 68k-side auto-incrementing index pointer
    reg [ 3:0] slave_idx;    // Z80-side auto-incrementing index pointer
    reg [ 3:0] status_reg;
    reg        nmi_en;
    reg        reset_reg;    // captured at idx 7 write

    assign snd_rst   = reset_reg;
    // NMI to Z80 asserts when nmi_en is set AND any slave-rx-pending bit
    // is set in status (bit 0 = PORT01_FULL, bit 1 = PORT23_FULL).
    // MAME's update_nmi() uses the same predicate.
    assign snd_nmi_n = ~(nmi_en & (status_reg[0] | status_reg[1]));

    // Data outputs — COMBINATIONAL so the 68k / Z80 see the correct
    // nibble DURING their read cycle.  Earlier (registered) version
    // updated on the falling edge of *_cs, by which point the CPU had
    // already sampled the bus → reads consistently returned the
    // previous bus cycle's value.  This is the rastan pattern
    // (cores/rastan/hdl/jtrastan_pc060.v: `main_din = main_ptr[2] ? status : main_ram`).
    assign main_din = (master_idx == 4'd0) ? master_data[ 3: 0] :
                      (master_idx == 4'd1) ? master_data[ 7: 4] :
                      (master_idx == 4'd2) ? master_data[11: 8] :
                      (master_idx == 4'd3) ? master_data[15:12] :
                      (master_idx == 4'd4) ? status_reg          :
                                             4'h0;
    assign snd_din  = (slave_idx == 4'd0) ? {4'h0, slave_data[ 3: 0]} :
                      (slave_idx == 4'd1) ? {4'h0, slave_data[ 7: 4]} :
                      (slave_idx == 4'd2) ? {4'h0, slave_data[11: 8]} :
                      (slave_idx == 4'd3) ? {4'h0, slave_data[15:12]} :
                      (slave_idx == 4'd4) ? {4'h0, status_reg}         :
                                            8'h00;

    // Edge detection — FALLING edge on both sides, modelled after Jose's
    // jtrastan_pc060_unit (cores/rastan/hdl/jtrastan_pc060.v lines 170-198).
    // We act when the bus cycle ENDS: all of we, addr, data are guaranteed
    // stable by then.  Detecting on the rising edge of the chip-select
    // is unsafe because:
    //   * 68k bus: ASn (→ main_cs) goes low in S2 but LDSn (gating
    //     main_we) doesn't go low until S4.  Sampling at the rising
    //     main_cs edge sees main_we==0 on a real write → the code
    //     takes the read branch and fires a phantom master_comm_r
    //     that auto-increments master_idx and clears status_reg[2]
    //     right after the Z80 has set it.
    //   * Z80 bus: MREQ (→ snd_syt_sel) goes low in T1 but WR doesn't
    //     go low until T2.  Same problem in reverse — slave writes can
    //     be missed entirely because snd_wr_n is still high at the
    //     rising slave-select edge.
    // Latching we/addr/data inside the chip-select-high window and
    // acting on the falling edge sidesteps both races.
    reg main_cs_d, snd_syt_sel_d;
    reg main_we_d, main_addr_d;
    reg [3:0] main_dout_d;
    reg snd_wr_n_d, snd_rd_n_d, snd_addr0_d;
    reg [7:0] snd_dout_d;

    wire main_edge  =  ~main_cs    &  main_cs_d;       // 68k bus cycle ENDING
    wire slave_edge =  ~snd_syt_sel & snd_syt_sel_d;   // Z80 bus cycle ENDING

    always @(posedge clk) begin
        main_cs_d     <= main_cs;
        snd_syt_sel_d <= snd_syt_sel;
        // Latch the bus-side inputs while the cycle is in progress so
        // they're stable at the falling edge.
        if (main_cs) begin
            main_we_d   <= main_we;
            main_addr_d <= main_addr;
            main_dout_d <= main_dout;
        end
        if (snd_syt_sel) begin
            snd_wr_n_d  <= snd_wr_n;
            snd_rd_n_d  <= snd_rd_n;
            snd_addr0_d <= snd_addr[0];
            snd_dout_d  <= snd_dout;
        end
    end

    // ----------------------------------------------------------------
    // Unified state-update block — single driver for every reg.
    // 68k master events take priority over Z80 slave events on the same
    // cycle (in practice they never collide because edge detection makes
    // each one a one-cycle pulse, but priority is defined explicitly).
    //
    // Master (68k) side: main_addr=0 selects index port, =1 selects data.
    // Slave  (Z80) side: snd_addr[0]=0 selects index port, =1 selects data.
    // ----------------------------------------------------------------
    always @(posedge clk) begin
        if (rst) begin
            master_idx  <= 4'd0;
            slave_idx   <= 4'd0;
            master_data <= 16'h0;
            slave_data  <= 16'h0;
            status_reg  <= 4'h0;
            nmi_en      <= 1'b0;
            reset_reg   <= 1'b0;
            // main_din / snd_din are now combinational — no reset needed.
        end else begin
            // ---- 68k master access ----
            // Acts on falling main_cs edge using the latched main_we_d /
            // main_addr_d / main_dout_d snapshots so the 68k's LDSn vs ASn
            // timing skew can't fire a phantom read in the address-setup
            // phase of a write.
            if (main_edge) begin
                if (main_we_d) begin
                    if (!main_addr_d) begin
                        master_idx <= main_dout_d;            // load pointer
                    end else begin
                        case (master_idx)
                            4'd0: begin slave_data[3:0]   <= main_dout_d; master_idx <= master_idx + 4'd1; end
                            4'd1: begin slave_data[7:4]   <= main_dout_d; master_idx <= master_idx + 4'd1;
                                        status_reg[0] <= 1'b1;            end
                            4'd2: begin slave_data[11:8]  <= main_dout_d; master_idx <= master_idx + 4'd1; end
                            4'd3: begin slave_data[15:12] <= main_dout_d; master_idx <= master_idx + 4'd1;
                                        status_reg[1] <= 1'b1;            end
                            // Slave (Z80) reset — hi-lo transition releases.
                            // MAME: m_reset_cb(data ? ASSERT_LINE : CLEAR_LINE).
                            // Index does NOT auto-increment on this access.
                            4'd4: reset_reg <= (main_dout_d != 4'd0);
                            default: ;
                        endcase
                    end
                end else if (main_addr_d) begin
                    // Data output is COMBINATIONAL (see main_din assign
                    // below) so the 68k sees the right nibble DURING
                    // the read cycle.  Here we only update the side
                    // effects of the read: pointer advance + status
                    // clears, latched on the falling main_cs edge.
                    case (master_idx)
                        4'd0: master_idx <= master_idx + 4'd1;
                        4'd1: begin master_idx <= master_idx + 4'd1;
                                    status_reg[2] <= 1'b0;          end
                        4'd2: master_idx <= master_idx + 4'd1;
                        4'd3: begin master_idx <= master_idx + 4'd1;
                                    status_reg[3] <= 1'b0;          end
                        default: ;  // idx 4 + others: no auto-increment
                    endcase
`ifdef SIMULATION
                    $display("[%0t] MASTER COMM_R  mainmode=%0d  master_data=%04x  status=%01x  -> data=%01x",
                             $time, master_idx, master_data, status_reg,
                             (master_idx==4'd0) ? master_data[3:0] :
                             (master_idx==4'd1) ? master_data[7:4] :
                             (master_idx==4'd2) ? master_data[11:8] :
                             (master_idx==4'd3) ? master_data[15:12] :
                             (master_idx==4'd4) ? status_reg : 4'h0);
`endif
                end
            end

            // ---- Z80 slave access ----
            // Falling-edge + latched snapshots, same rationale as the 68k
            // side: Z80 MREQ goes low before WR, so detecting on the
            // rising chip-select edge can miss the write entirely.
            if (slave_edge) begin
                if (~snd_wr_n_d) begin
                    if (snd_addr0_d == 1'b0) begin
                        slave_idx <= snd_dout_d[3:0];
`ifdef SIMULATION
                        $display("[%0t] SLAVE PORT_W  data=%02x  submode<=%0d", $time, snd_dout_d, snd_dout_d[3:0]);
`endif
                    end else begin
                        case (slave_idx)
                            4'd0: begin master_data[3:0]   <= snd_dout_d[3:0]; slave_idx <= slave_idx + 4'd1; end
                            4'd1: begin master_data[7:4]   <= snd_dout_d[3:0]; slave_idx <= slave_idx + 4'd1;
                                        status_reg[2] <= 1'b1;                 end
                            4'd2: begin master_data[11:8]  <= snd_dout_d[3:0]; slave_idx <= slave_idx + 4'd1; end
                            4'd3: begin master_data[15:12] <= snd_dout_d[3:0]; slave_idx <= slave_idx + 4'd1;
                                        status_reg[3] <= 1'b1;                 end
                            4'd5: nmi_en <= 1'b0;
                            4'd6: nmi_en <= 1'b1;
                            default: ;
                        endcase
`ifdef SIMULATION
                        $display("[%0t] SLAVE COMM_W  submode=%0d  data=%02x", $time, slave_idx, snd_dout_d);
`endif
                    end
                end
                if (~snd_rd_n_d && snd_addr0_d == 1'b1) begin
                    // Same fix as master side: snd_din is COMBINATIONAL,
                    // we only update side effects (pointer + status
                    // clears) here.
                    case (slave_idx)
                        4'd0: slave_idx <= slave_idx + 4'd1;
                        4'd1: begin slave_idx <= slave_idx + 4'd1;
                                    status_reg[0] <= 1'b0;                end
                        4'd2: slave_idx <= slave_idx + 4'd1;
                        4'd3: begin slave_idx <= slave_idx + 4'd1;
                                    status_reg[1] <= 1'b0;                end
                        default: ;
                    endcase
                end
            end
        end
    end

endmodule
