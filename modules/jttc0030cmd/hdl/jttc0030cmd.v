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

    Author: Andrea Bogazzi <andreabogazzi79@gmail.com>
    Version: 1.0
    Date: 21-7-2026 */
module jttc0030cmd (
    input             rst,
    input             clk,
    input             cen,

    // ---- Host (68k) side: real C-chip external pins ----
    input             cs,         // active high (parent inverts /CS)
    input      [10:0] addr,       // A10..A0
    input      [ 7:0] din,
    output reg [ 7:0] dout,
    input             rnw,        // 1 = read, 0 = write
    output            dtack_n,

    // ---- MCU interrupt inputs ----
    input             int1,       // INT1 request (vblank). Edge-triggered: assert
                                  // (rising edge) to request one IRQ. Wire the
                                  // raw vblank in as-is — pulse OR level, any
                                  // width; the module conditions it internally
                                  // (see INT1_HOLD). No pulse shaper needed.
    input             nmi_n,      // /NMI pin

    // ---- MCU GPIO (PA/PB/PC bidirectional; direction is game-controlled) ----
    input      [ 7:0] pa_in,
    input      [ 7:0] pb_in,
    input      [ 7:0] pc_in,
    output     [ 7:0] pa_out,
    output     [ 7:0] pb_out,
    output     [ 7:0] pc_out,

    // ---- ADC / digital AN inputs (an[x]=1 reads back as 0xFF) ----
    input      [ 7:0] an,

    // ---- ROM read ports: wire to external BRAMs owned by the parent (declare
    //      them in mem.yaml `bram:` — the two 4 KB / 8 KB ROMs load themselves
    //      from the download; see the README wiring section) ----
    output     [11:0] mrom_addr,   // 4 KB common mask ROM
    input      [ 7:0] mrom_data,
    output     [12:0] eprom_addr,  // 8 KB game EPROM
    input      [ 7:0] eprom_data,

    // ---- debug taps (sim) ----
    output     [15:0] dbg_pc,     // MCU bus address (= PC during opcode fetch)
    output            dbg_fetch   // opcode-fetch cycle (M1)
);

    wire [15:0] mcu_addr;
    wire [ 7:0] mcu_dout;
    wire        mcu_wr_n, mcu_m1_n;
    reg  [ 7:0] mcu_din;
    wire        mcu_wr = ~mcu_wr_n;

    assign dbg_pc    = mcu_addr;
    assign dbg_fetch = ~mcu_m1_n;

    wire mcu_mask = mcu_addr <  16'h1000;                     // 0x0000-0x0FFF
    wire mcu_sram = mcu_addr[15:10]==6'b0001_00;              // 0x1000-0x13FF
    wire mcu_asic = mcu_addr[15:10]==6'b0001_01;              // 0x1400-0x17FF
    wire mcu_epr  = mcu_addr[15:13]==3'b001;                  // 0x2000-0x3FFF
    wire mcu_iram = &mcu_addr[15:8];                          // 0xFF00-0xFFFF
    wire mcu_asic_off = mcu_addr[9];                          // 1 => 0x1600-0x17FF
    wire mcu_bank_we  = mcu_wr & mcu_asic & (mcu_addr[9:0]==10'h200);

    wire k68_sram    = cs & ~addr[10];                        // 0x000-0x3FF
    wire k68_asic    = cs &  addr[10];                        // 0x400-0x7FF
    wire k68_wr      = cs & ~rnw;
    wire k68_bank_we = k68_wr & k68_asic & (addr[9:0]==10'h200); // byte 0x600

    reg [2:0] bank_mcu, bank_68k;
    reg [7:0] asic_ram[0:3];

    always @(posedge clk) begin
        if( rst ) begin
            bank_mcu    <= 3'd0;
            bank_68k    <= 3'd0;
            asic_ram[0] <= 8'd0; asic_ram[1] <= 8'd0;
            asic_ram[2] <= 8'd0; asic_ram[3] <= 8'd0;
        end else begin
            // 68k wins a same-cycle ASIC-reg write collision with the MCU
            if     ( k68_wr & k68_asic & ~k68_bank_we ) asic_ram[addr[1:0]]     <= din;
            else if( mcu_wr & mcu_asic & ~mcu_bank_we ) asic_ram[mcu_addr[1:0]] <= mcu_dout;
            if( k68_bank_we ) bank_68k <= din[2:0];
            if( mcu_bank_we ) bank_mcu <= mcu_dout[2:0];
        end
    end

    // bank-register offset reads back as 0 (write-only)
    wire [7:0] mcu_asic_rd = mcu_asic_off ? 8'h00 : asic_ram[mcu_addr[1:0]];
    wire [7:0] k68_asic_rd = addr[9]      ? 8'h00 : asic_ram[addr[1:0]];

    wire [7:0] iram_q;
    wire [7:0] sram_qmcu, sram_q68;

    assign mrom_addr  = mcu_addr[11:0];
    assign eprom_addr = mcu_addr[12:0];

    jtframe_dual_ram #(.DW(8),.AW(13)) u_sram(
        .clk0   ( clk                         ),
        .data0  ( mcu_dout                    ),
        .addr0  ( {bank_mcu, mcu_addr[9:0]}   ),
        .we0    ( mcu_wr & mcu_sram           ),
        .q0     ( sram_qmcu                   ),
        .clk1   ( clk                         ),
        .data1  ( din                         ),
        .addr1  ( {bank_68k, addr[9:0]}       ),
        .we1    ( k68_wr & k68_sram           ),
        .q1     ( sram_q68                    )
    );

    jtframe_dual_ram #(.DW(8),.AW(8)) u_iram(
        .clk0   ( clk                 ),
        .data0  ( mcu_dout            ),
        .addr0  ( mcu_addr[7:0]       ),
        .we0    ( mcu_wr & mcu_iram   ),
        .q0     ( iram_q              ),
        .clk1   ( clk                 ),
        .data1  ( 8'd0                ),
        .addr1  ( 8'd0                ),
        .we1    ( 1'b0                ),
        .q1     (                     )
    );

    always @* begin
        case( 1'b1 )
            mcu_mask: mcu_din = mrom_data;
            mcu_sram: mcu_din = sram_qmcu;
            mcu_asic: mcu_din = mcu_asic_rd;
            mcu_epr:  mcu_din = eprom_data;
            mcu_iram: mcu_din = iram_q;
            default:  mcu_din = 8'hFF;
        endcase
    end

    always @* begin
        if     ( k68_sram ) dout = sram_q68;
        else if( k68_asic ) dout = k68_asic_rd;
        else                dout = 8'hFF;
    end

    // /DTACK: one wait-state after cs, enough for the SRAM read latency.
    reg dtack;
    always @(posedge clk) begin
        if( rst ) dtack <= 1'b0;
        else      dtack <= cs;
    end
    assign dtack_n = ~dtack;

    wire [2:0] adc_ch;
    wire [7:0] adc_data = an[adc_ch] ? 8'hFF : 8'h00;

    localparam [8:0] INT1_HOLD = 9'd192;   // > 3 sample windows + phase margin
    reg  [8:0] int1_cnt;
    reg        int1_held, int1_l;
    always @(posedge clk) begin
        if( rst ) begin
            int1_cnt  <= 9'd0;
            int1_held <= 1'b0;
            int1_l    <= 1'b0;
        end else begin
            int1_l <= int1;
            if( int1 & ~int1_l ) begin          // arm once, on the rising edge
                int1_held <= 1'b1;
                int1_cnt  <= INT1_HOLD;
            end else if( cen && int1_cnt != 9'd0 ) begin
                int1_cnt <= int1_cnt - 9'd1;
                if( int1_cnt == 9'd1 ) int1_held <= 1'b0;
            end
        end
    end

    IKA87AD u_mcu(
        .i_EMUCLK           ( clk           ),
        .i_MCUCLK_PCEN      ( cen           ),
        .i_RESET_n          ( ~rst          ),
        .i_STOP_n           ( 1'b1          ),

        .o_M1_n             ( mcu_m1_n      ),
        .o_IO_n             (               ),
        .o_ALE              (               ),
        .o_RD_n             (               ),
        .o_WR_n             ( mcu_wr_n      ),
        .o_A                ( mcu_addr      ),
        .i_DI               ( mcu_din       ),
        .o_DO               ( mcu_dout      ),
        .o_PD_DO_OE         (               ),
        .o_D_nA_SEL         (               ),
        .o_DO_OE            (               ),
        .o_REG_MM           (               ),

        .i_NMI_n            ( nmi_n         ),
        .i_INT1             ( int1_held     ),   // conditioned (see INT1_HOLD)
        .i_INT2_n           ( 1'b1          ),

        .i_TI               ( 1'b0          ),
        .o_TO               (               ),
        .o_TO_PCEN          (               ),
        .o_TO_NCEN          (               ),
        .i_CI               ( 1'b0          ),

        .i_PA_I             ( pa_in         ),
        .o_PA_O             ( pa_out        ),
        .o_PA_OE            (               ),
        .i_PB_I             ( pb_in         ),
        .o_PB_O             ( pb_out        ),
        .o_PB_OE            (               ),
        .i_PC_I             ( pc_in         ),
        .o_PC_O             ( pc_out        ),
        .o_PC_OE            (               ),
        .o_REG_MCC          (               ),
        .i_PD_I             ( 8'd0          ),
        .o_PD_O             (               ),
        .o_PD_OE            (               ),
        .i_PF_I             ( 8'd0          ),
        .o_PF_O             (               ),
        .o_PF_OE            (               ),

        .i_ANx_DIGITAL      ( an[7:4]       ),
        .o_ANx_ANALOG_CH    ( adc_ch        ),
        .i_ANx_ANALOG_DATA  ( adc_data      ),
        .o_ANx_ANALOG_RD_n  (               )
    );

endmodule
