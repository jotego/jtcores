/*  This file is part of JTFRAME.
    JTFRAME program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTFRAME program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTFRAME.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 7-8-2021 */

module test;

wire vblank;
wire clk_74a, clk_74b;

wire [15:0] sdram_dq;
wire [12:0] sdram_a;
wire [ 1:0] sdram_ba, sdram_dqm;
wire sdram_nwe,  sdram_ncas,
     sdram_nras, sdram_clk,  sdram_cke;

wire [1:0]  spi_dio;
wire        spi_clk, spi_ss, brg_1wire;

wire [11:0] scal_vid;
wire        scal_clk, scal_de, scal_skip, scal_vs,
            scal_hs, scal_audmclk, scal_audadc, scal_auddac, scal_audlrck;
/* verilator lint_off PINMISSING */
test_harness u_harness(
    .clk_74a        ( clk_74a           ),
    .clk_74b        ( clk_74b           ),
    // scaler
    .vblank         ( vblank            ),
    .scal_vid       ( scal_vid          ),
    .scal_clk       ( scal_clk          ),
    .scal_de        ( scal_de           ),
    .scal_skip      ( scal_skip         ),
    .scal_vs        ( scal_vs           ),
    .scal_hs        ( scal_hs           ),
    .scal_audmclk   ( scal_audmclk      ),
    .scal_audadc    ( scal_audadc       ),
    .scal_auddac    ( scal_auddac       ),
    .scal_audlrck   ( scal_audlrck      ),
    // SPI
    .spi_dio        ( spi_dio           ),
    .spi_clk        ( spi_clk           ),
    .spi_ss         ( spi_ss            ),
    .brg_1wire      ( brg_1wire         ),
    // SDRAM
    .sdram_dq       ( sdram_dq          ),
    .sdram_a        ( sdram_a           ),
    .sdram_dqm      ( sdram_dqm         ),
    .sdram_nwe      ( sdram_nwe         ),
    .sdram_ncas     ( sdram_ncas        ),
    .sdram_nras     ( sdram_nras        ),
    .sdram_ba       ( sdram_ba          ),
    .sdram_clk      ( sdram_clk         ),
    .sdram_cke      ( sdram_cke         )
);
/* verilator lint_on PINMISSING */
jtframe_pocket_top UUT(
    .clk_74a        ( clk_74a           ),
    .clk_74b        ( clk_74b           ),
    // scaler
    .scal_vid       ( scal_vid          ),
    .scal_clk       ( scal_clk          ),
    .scal_de        ( scal_de           ),
    .scal_skip      ( scal_skip         ),
    .scal_vs        ( scal_vs           ),
    .scal_hs        ( scal_hs           ),
    .scal_audmclk   ( scal_audmclk      ),
    .scal_audadc    ( scal_audadc       ),
    .scal_auddac    ( scal_auddac       ),
    .scal_audlrck   ( scal_audlrck      ),
    // SPI
    .spi_dio        ( spi_dio           ),
    .spi_clk        ( spi_clk           ),
    .spi_ss         ( spi_ss            ),
    .bridge_1wire   ( brg_1wire         ),
    // SDRAM interface
    .dram_dq        ( sdram_dq          ),
    .dram_a         ( sdram_a           ),
    .dram_dqm       ( sdram_dqm         ),
    .dram_we_n      ( sdram_nwe         ),
    .dram_cas_n     ( sdram_ncas        ),
    .dram_ras_n     ( sdram_nras        ),
    .dram_ba        ( sdram_ba          ),
    .dram_clk       ( sdram_clk         ),
    .dram_cke       ( sdram_cke         ),
    .vblank         ( vblank            ),
    // not simulated functions
    // GBA
    .cart_tran_bank2        (           ),
    .cart_tran_bank2_dir    (           ),
    .cart_tran_bank3        (           ),
    .cart_tran_bank3_dir    (           ),
    .cart_tran_bank1        (           ),
    .cart_tran_bank1_dir    (           ),
    .cart_tran_bank0        (           ),
    .cart_tran_bank0_dir    (           ),
    .cart_tran_pin30        (           ),
    .cart_tran_pin30_dir    (           ),
    .cart_pin30_pwroff_reset(           ),
    .cart_tran_pin31        (           ),
    .cart_tran_pin31_dir    (           ),
    // Infrared
    .port_ir_rx         (               ),
    .port_ir_tx         (               ),
    .port_ir_rx_disable (               ),
    // GBA link port
    .port_tran_si       (               ),
    .port_tran_si_dir   (               ),
    .port_tran_so       (               ),
    .port_tran_so_dir   (               ),
    .port_tran_sck      (               ),
    .port_tran_sck_dir  (               ),
    .port_tran_sd       (               ),
    .port_tran_sd_dir   (               ),
    // Cellular RAM
    .cram0_a        (                   ),
    .cram0_dq       (                   ),
    .cram0_wait     (                   ),
    .cram0_clk      (                   ),
    .cram0_adv_n    (                   ),
    .cram0_cre      (                   ),
    .cram0_ce0_n    (                   ),
    .cram0_ce1_n    (                   ),
    .cram0_oe_n     (                   ),
    .cram0_we_n     (                   ),
    .cram0_ub_n     (                   ),
    .cram0_lb_n     (                   ),

    .cram1_a        (                   ),
    .cram1_dq       (                   ),
    .cram1_wait     (                   ),
    .cram1_clk      (                   ),
    .cram1_adv_n    (                   ),
    .cram1_cre      (                   ),
    .cram1_ce0_n    (                   ),
    .cram1_ce1_n    (                   ),
    .cram1_oe_n     (                   ),
    .cram1_we_n     (                   ),
    .cram1_ub_n     (                   ),
    .cram1_lb_n     (                   ),
    // SRAM
    .sram_a         (                   ),
    .sram_dq        (                   ),
    .sram_oe_n      (                   ),
    .sram_we_n      (                   ),
    .sram_ub_n      (                   ),
    .sram_lb_n      (                   ),
    .dbg_tx         (                   ),
    .dbg_rx         ( 1'b0              ),
    .bist           (                   ),
    .vpll_feed      (                   ),
    .aux_sda        (                   ),
    .aux_scl        (                   )
);

endmodule