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
    Date: 30-11-2020 */

module jtframe_sdram_bank #(
    parameter AW=22,
              HF=1,     // 1 for HF operation (idle cycles), 0 for LF operation
                        // HF operation starts at 66.6MHz (1/15ns)
              SHIFTED=0
)(
    input               rst,
    input               clk,

    // Bank 0: allows R/W
    input      [AW-1:0] ba0_addr,
    input               ba0_rd,
    input               ba0_wr,
    input      [  15:0] ba0_din,
    input      [   1:0] ba0_din_m,  // write mask
    output              ba0_rdy,
    output              ba0_ack,

    // Bank 1: Read only
    input      [AW-1:0] ba1_addr,
    input               ba1_rd,
    output              ba1_rdy,
    output              ba1_ack,

    // Bank 2: Read only
    input      [AW-1:0] ba2_addr,
    input               ba2_rd,
    output              ba2_rdy,
    output              ba2_ack,

    // Bank 3: Read only
    input      [AW-1:0] ba3_addr,
    input               ba3_rd,
    output              ba3_rdy,
    output              ba3_ack,

    // ROM downloading
    input               prog_en,
    input      [AW-1:0] prog_addr,
    input      [   1:0] prog_ba,     // bank
    input               prog_rd,
    input               prog_wr,
    input      [  15:0] prog_din,
    input      [   1:0] prog_din_m,  // write mask
    output              prog_rdy,
    output              prog_ack,

    // SDRAM interface
    // SDRAM_A[12:11] and SDRAM_DQML/H are controlled in a way
    // that can be joined together thru an OR operation at a
    // higher level. This makes it possible to short the pins
    // of the SDRAM, as done in the MiSTer 128MB module
    inout       [15:0]  sdram_dq,       // SDRAM Data bus 16 Bits
    output      [12:0]  sdram_a,        // SDRAM Address bus 13 Bits
    output              sdram_dqml,     // SDRAM Low-byte Data Mask
    output              sdram_dqmh,     // SDRAM High-byte Data Mask
    output      [ 1:0]  sdram_ba,       // SDRAM Bank Address
    output              sdram_nwe,      // SDRAM Write Enable
    output              sdram_ncas,     // SDRAM Column Address Strobe
    output              sdram_nras,     // SDRAM Row Address Strobe
    output              sdram_ncs,      // SDRAM Chip Select
    output              sdram_cke,      // SDRAM Clock Enable

    // Common signals
    input               rfsh_en,   // ok to refresh
    output     [  31:0] dout
);

// Signals to SDRAM controller
wire [AW-1:0] ctl_addr;
wire          ctl_rd;
wire          ctl_wr;
wire          ctl_rfsh_en;   // ok to refresh
wire [   1:0] ctl_ba_rq;
wire          ctl_ack;
wire          ctl_rdy;
wire [   1:0] ctl_ba_rdy;
wire [  15:0] ctl_din;
wire [   1:0] ctl_din_m;  // write mask
wire [  31:0] ctl_dout;
reg           local_rst, rst_latch;

always @(negedge clk) begin
    rst_latch <= rst;
    local_rst <= rst_latch;
end

jtframe_sdram_bank_mux #(.AW(AW),.HF(HF)) u_mux(
    .rst        ( local_rst     ),
    .clk        ( clk           ),

    // Bank 0: allows R/W
    .ba0_addr   ( ba0_addr      ),
    .ba0_rd     ( ba0_rd        ),
    .ba0_wr     ( ba0_wr        ),
    .ba0_din    ( ba0_din       ),
    .ba0_din_m  ( ba0_din_m     ),  // write mask
    .ba0_rdy    ( ba0_rdy       ),
    .ba0_ack    ( ba0_ack       ),

    // Bank 1: Read only
    .ba1_addr   ( ba1_addr      ),
    .ba1_rd     ( ba1_rd        ),
    .ba1_rdy    ( ba1_rdy       ),
    .ba1_ack    ( ba1_ack       ),

    // Bank 2: Read only
    .ba2_addr   ( ba2_addr      ),
    .ba2_rd     ( ba2_rd        ),
    .ba2_rdy    ( ba2_rdy       ),
    .ba2_ack    ( ba2_ack       ),

    // Bank 3: Read only
    .ba3_addr   ( ba3_addr      ),
    .ba3_rd     ( ba3_rd        ),
    .ba3_rdy    ( ba3_rdy       ),
    .ba3_ack    ( ba3_ack       ),

    // ROM downloading
    .prog_en    ( prog_en       ),
    .prog_addr  ( prog_addr     ),
    .prog_ba    ( prog_ba       ),     // bank
    .prog_rd    ( prog_rd       ),
    .prog_wr    ( prog_wr       ),
    .prog_din   ( prog_din      ),
    .prog_din_m ( prog_din_m    ),  // write mask
    .prog_rdy   ( prog_rdy      ),
    .prog_ack   ( prog_ack      ),

    // Signals to SDRAM controller
    .ctl_addr   ( ctl_addr      ),
    .ctl_rd     ( ctl_rd        ),
    .ctl_wr     ( ctl_wr        ),
    .ctl_rfsh_en( ctl_rfsh_en   ),   // ok to refresh
    .ctl_ba_rq  ( ctl_ba_rq     ),
    .ctl_ack    ( ctl_ack       ),
    .ctl_rdy    ( ctl_rdy       ),
    .ctl_ba_rdy ( ctl_ba_rdy    ),
    .ctl_din    ( ctl_din       ),
    .ctl_din_m  ( ctl_din_m     ),  // write mask
    .ctl_dout   ( ctl_dout      ),

    // Common signals
    .rfsh_en    ( rfsh_en       ),   // ok to refresh
    .dout       ( dout          )
);

jtframe_sdram_bank_core #(.AW(AW),.HF(HF),.SHIFTED(SHIFTED)) u_core(
    .rst        ( local_rst     ),
    .clk        ( clk           ),
    .addr       ( ctl_addr      ),
    .rd         ( ctl_rd        ),
    .wr         ( ctl_wr        ),
    .rfsh_en    ( ctl_rfsh_en   ),
    .ba_rq      ( ctl_ba_rq     ),
    .ack        ( ctl_ack       ),
    .rdy        ( ctl_rdy       ),
    .ba_rdy     ( ctl_ba_rdy    ),
    .din        ( ctl_din       ),
    .din_m      ( ctl_din_m     ),
    .dout       ( ctl_dout      ),
    // SDRAM pins
    .sdram_dq   ( sdram_dq      ),
    .sdram_a    ( sdram_a       ),
    .sdram_dqml ( sdram_dqml    ),
    .sdram_dqmh ( sdram_dqmh    ),
    .sdram_ba   ( sdram_ba      ),
    .sdram_nwe  ( sdram_nwe     ),
    .sdram_ncas ( sdram_ncas    ),
    .sdram_nras ( sdram_nras    ),
    .sdram_ncs  ( sdram_ncs     ),
    .sdram_cke  ( sdram_cke     )
);


endmodule