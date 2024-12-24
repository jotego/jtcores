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
    Version: 1.0
    Date: 16-3-2021 */

`ifndef NOSOUND

module jts16_pcm(
    input                rst,
    input                clk,

    input                cen_pcm,   // 6 MHz

    input                soft_rstn,
    input         [ 7:0] ctrl,
    input                irqn,
    // PROM
    input         [ 9:0] prog_addr,
    input                prom_we,
    input         [ 7:0] prog_data,

    // PCM ROM
    output        [16:0] pcm_addr,
    output               pcm_cs,
    input         [ 7:0] pcm_data,
    input                pcm_ok,

    // Sound output
    output reg signed [ 7:0] snd
);

reg  [ 1:0] bank;
wire [ 7:0] rom_data, ram_dout, ram_din, ram_addr,
            p2_dout, raw;
wire [ 3:0] pext2, pext4, pext5, pext6, pext7;
wire [11:0] rom_addr;
wire        ram_we, rd_n, wr_n, prog_n;
wire [ 7:0] p2_din;
wire        pext2_en;

assign pcm_addr = { bank, ctrl[0], pext7[1:0], pext6, pext5, pext4 };
assign p2_din   = { 1'b1, ctrl[7:5], pext2_en ? pext2[3:0] : 4'hf };
assign pcm_cs   = 1;

always @(*) begin
    casez( ~ctrl[4:1] )
        4'b1???: bank = 2'd3;
        4'b01??: bank = 2'd2;
        4'b001?: bank = 2'd1;
        default: bank = 2'd0;
    endcase
end

// local reset
reg rstn_t48;
always @(posedge clk) rstn_t48 <= ~rst & soft_rstn;

wire       xtal3, ale, psen_n, db_dir;
wire [7:0] mcu_dout;
reg        first;

always @(posedge clk, negedge rstn_t48 ) begin
    if( !rstn_t48 ) begin
        snd   <= 0;
        first <= 1; // prevents the sound glitch at reset exit
    end else begin
        if(!first) snd <= raw - 8'h80;
        if(!rd_n) first <= 0;
    end
end

t48_core u_mcu(
    .reset_i        ( rstn_t48  ),
    .xtal_i         ( clk       ),
    .xtal_en_i      ( cen_pcm   ),
    .clk_i          ( clk       ),
    .en_clk_i       ( xtal3     ),
    .xtal3_o        ( xtal3     ),
    // Unused test signals
    .t0_i           ( 1'b0      ),
    .t1_i           ( 1'b0      ),
    .t0_o           (           ),
    .t0_dir_o       (           ),
    // Interrupt
    .int_n_i        ( irqn      ),
    // Bus control
    .ea_i           ( 1'b0      ),  // external access
    .rd_n_o         ( rd_n      ),
    .wr_n_o         ( wr_n      ),
    .psen_n_o       ( psen_n    ),
    .ale_o          ( ale       ),
    .db_i           ( pcm_data  ), // input data
    .db_o           ( mcu_dout  ), // output data
    .db_dir_o       ( db_dir    ), // direction of DB pads, 0=input
    // Port 2 (interfaces with 8243)
    .p2_i           ( p2_din    ),
    .p2_o           ( p2_dout   ),
    .p2l_low_imp_o  (           ),
    .p2h_low_imp_o  (           ),
    // Port 1
    .p1_i           ( 8'd0      ),
    .p1_o           ( raw       ),
    .p1_low_imp_o   (           ),
    // output strobe for 8243
    .prog_n_o       ( prog_n    ),
    // Program
    .pmem_addr_o    ( rom_addr  ),
    .pmem_data_i    ( rom_data  ),
    // RAM
    .dmem_addr_o    ( ram_addr  ),
    .dmem_we_o      ( ram_we    ),
    .dmem_data_i    ( ram_dout  ),
    .dmem_data_o    ( ram_din   )
);

t8243_sync_notri u_8243(
    .clk_i          ( clk       ),
    .reset_n_i      ( rstn_t48  ),
    .clk_en_i       ( cen_pcm   ),

    .cs_n_i         ( 1'b0      ),
    .prog_n_i       ( prog_n    ),

    .p2_i           ( p2_dout[3:0] ),
    .p2_o           ( pext2     ),
    .p2_en_o        ( pext2_en  ),

    .p4_i           ( 4'd0      ),
    .p4_o           ( pext4     ),
    .p4_en_o        (           ),

    .p5_i           ( 4'd0      ),
    .p5_o           ( pext5     ),
    .p5_en_o        (           ),

    .p6_i           ( 4'd0      ),
    .p6_o           ( pext6     ),
    .p6_en_o        (           ),

    .p7_i           ( 4'd0      ),
    .p7_o           ( pext7     ),
    .p7_en_o        (           )
);

jtframe_prom #(.SIMFILE("7751.bin")) u_prom(
    .clk    ( clk           ),
    .cen    ( 1'b1          ),
    .data   ( prog_data     ),
    .rd_addr( rom_addr[9:0] ),
    .wr_addr( prog_addr     ),
    .we     ( prom_we       ),
    .q      ( rom_data      )
);

jtframe_ram #(.AW(8)) u_ram(
    .clk    ( clk           ),
    .cen    ( 1'b1          ),
    .data   ( ram_din       ),
    .addr   ( ram_addr      ),
    .we     ( ram_we        ),
    .q      ( ram_dout      )
);

endmodule

`endif