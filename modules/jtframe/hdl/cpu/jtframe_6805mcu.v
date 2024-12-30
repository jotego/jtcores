/*  This file is part of JTFRAME.
      JTFRAME program is free software: you can redistribute it and/or modify
      it under the terms of the GNU General Public License as published by
      the Free Software Foundation, either version 3 of the License, or
      (at your option) any later version.

      JTFRAME program is distributed in the hope that it will be useful,
      but WITHOUT ANY WARRANTY; without even the implied warranty of
      MERCHANTABILITY or FITNESS FOR addr PARTICULAR PURPOSE.  See the
      GNU General Public License for more details.

      You should have received a copy of the GNU General Public License
      along with JTFRAME.  If not, see <http://www.gnu.org/licenses/>.

      Author: Jose Tejada Gomez. Twitter: @topapate
      Version: 1.0
      Date: 4-12-2022 */

module jtframe_6805mcu #( parameter ROMW = 11)(
    input              clk,
    input              rst,
    input              cen,
    output             wr,
    output      [12:0] addr,
    output      [ 7:0] dout,
    input              irq,
    input              timer,
    // Ports
    input      [ 7:0]  pa_in,
    output reg [ 7:0]  pa_out,
    input      [ 7:0]  pb_in,
    output reg [ 7:0]  pb_out,
    input      [ 3:0]  pc_in,       // present in MC68705P5, but not in MC146805E2
    output reg [ 3:0]  pc_out,
    // ROM interface
    output [ROMW-1:0]  rom_addr,
    input      [ 7:0]  rom_data,
    output reg         rom_cs
);
/* verilator coverage_off */
localparam MAXPORT  = 13'd12,
           MOR_ADDR = 13'h784,
           TIR      = 7,
           TIM      = 6,
           TIN      = 5,
           TIE      = 4,
           TOPT     = 6;

wire        ram_we;
reg  [ 7:0] din;
wire [ 7:0] ram_dout;
reg  [ 7:0] pa_ddr, pb_ddr, tdr, tcr, mor,
            pa_latch, pb_latch;
reg  [ 6:0] pres;
reg  [ 1:0] cendiv;
reg  [ 3:0] pc_ddr, pc_latch;
reg         port_cs, ram_cs, prmx_l, mor_l, fpin_l;
wire        fpin, mcu_i, tirq, prmx, tstop;
wire [ 7:0] nx_tdr, prfull;

integer k;

assign rom_addr = rst ? MOR_ADDR[ROMW-1:0] : addr[ROMW-1:0];
assign ram_we   = ram_cs & wr;
assign fpin     = (cendiv[1] | tcr[TIN]) & (timer | ~|{tcr[TIE],mor[TOPT]});
assign nx_tdr   = tdr-1'd1;
assign tirq     = tcr[TIR] & ~tcr[TIM]; // 6 => mask
assign prfull   = { pres, fpin };
assign prmx     = prfull[tcr[2:0]];

// Address decoder
always @(*) begin
    rom_cs    = addr>=128;
    ram_cs    = addr>=16 && addr<128;
    port_cs   = addr<MAXPORT;
end

// Ports
always @(posedge clk) if(rst) mor <= rom_data;

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        pa_latch <= 0; pa_ddr <= 0;
        pb_latch <= 0; pb_ddr <= 0;
        pc_latch <= 0; pa_ddr <= 0;
        tdr    <= 8'hff;
        tcr    <= 8'h40;
        pres <= 7'h7f;
        cendiv <= 0;
        mor_l  <= 0;
    end else begin
        if( !mor_l ) begin
            mor_l <= 1;
            tcr[5:0] <= {mor[5],2'b11,mor[2:0]};
        end
        // timer
        if( cen & ~tstop ) cendiv <= cendiv+2'd1;
        fpin_l <= fpin;
        prmx_l <= prmx;
        if( fpin & ~fpin_l ) pres <= pres+1'd1;
        if( prmx & ~prmx_l ) begin
            tdr <= nx_tdr;
            if( nx_tdr==0 ) tcr[TIR]<=1; // timer IRQ
        end
        // ports
        if(port_cs && wr && cen) case( addr[3:0] )
             0: pa_latch <= dout;
             1: pb_latch <= dout;
             2: pc_latch <= dout[3:0];
             4: pa_ddr   <= dout;
             5: pb_ddr   <= dout;
             6: pc_ddr   <= dout[3:0];
             8: tdr      <= dout;
             9: begin
                tcr    <= { dout[7:6], mor[TOPT] ? mor[5:0] : dout[5:0] };
                if( dout[3] ) pres <= 7'h7f;
            end
        endcase
    end
end

always @(posedge clk) begin
    pa_out <= (pa_latch & pa_ddr) | (pa_in & ~pa_ddr);
    pb_out <= (pb_latch & pb_ddr) | (pb_in & ~pb_ddr);
    pc_out <= (pc_latch & pc_ddr) | (pc_in & ~pc_ddr);
end

always @(*) begin
    case(1'b1)
        default: din = rom_data;
        ram_cs:  din = ram_dout;
        port_cs: begin
            case( addr[4:0] )
                0: din = pa_out;
                1: din = pb_out;
                2: din = {4'hf,pc_out};
                8: din = tdr;
                9: din = {tcr[7:6], {2{mor[TOPT]}}|tcr[5:4],mor[TOPT],{3{mor[TOPT]}}|tcr[2:0]};
                default: din = 8'hff;
            endcase
        end
    endcase
end

jtframe_ram #(.AW(7)) u_intram(
    .clk    ( clk         ),
    .cen    ( cen         ),
    .data   ( dout        ),
    .addr   ( addr[6:0]   ),
    .we     ( ram_we      ),
    .q      ( ram_dout    )
);

jt6805 u_mcu(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .cen    ( cen       ),
    .wr     ( wr        ),
    .tstop  ( tstop     ),
    .addr   ( addr      ),
    .din    ( din       ),
    .dout   ( dout      ),
    .irq    ( irq       ),
    .tirq   ( tirq      )
);

endmodule