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
    Date: 11-10-2023 */

module jtshouse_scr_mmr(
    input             rst,
    input             clk,

    input             cs,
    input       [4:0] addr,
    input             rnw,
    input       [7:0] din,
    output reg  [7:0] dout,

    output [4*16-1:0] hscr, vscr,

    output  [6*3-1:0] pal, prio,
    output      [5:0] enb,

    // IOCTL dump
    input      [ 4:0] ioctl_addr,
    output     [ 7:0] ioctl_din,
    // Debug
    input      [ 7:0] debug_bus,
    output reg [ 7:0] st_dout
);

// MMR
// 0~F scroll positions
// tilemap 3 bits - scroll X/Y 1 bit - upper/lower byte sel 1 bit
// 10~17 priority
// 18~1F color

reg  [ 7:0] mmr[0:31]; // upper bits probably did not exist for the upper half of the MMR
integer     i;

assign hscr = { mmr[{3'd3,2'd0}], mmr[{3'd3,2'd1}],
                mmr[{3'd2,2'd0}], mmr[{3'd2,2'd1}],
                mmr[{3'd1,2'd0}], mmr[{3'd1,2'd1}],
                mmr[{3'd0,2'd0}], mmr[{3'd0,2'd1}] };

assign vscr = { mmr[{3'd3,2'd2}], mmr[{3'd3,2'd3}],
                mmr[{3'd2,2'd2}], mmr[{3'd2,2'd3}],
                mmr[{3'd1,2'd2}], mmr[{3'd1,2'd3}],
                mmr[{3'd0,2'd2}], mmr[{3'd0,2'd3}]};

assign prio = {
  mmr[{2'b10,3'd5}][2:0],
  mmr[{2'b10,3'd4}][2:0],
  mmr[{2'b10,3'd3}][2:0],
  mmr[{2'b10,3'd2}][2:0],
  mmr[{2'b10,3'd1}][2:0],
  mmr[{2'b10,3'd0}][2:0] };

assign enb = {
  mmr[{2'b10,3'd5}][3],
  mmr[{2'b10,3'd4}][3],
  mmr[{2'b10,3'd3}][3],
  mmr[{2'b10,3'd2}][3],
  mmr[{2'b10,3'd1}][3],
  mmr[{2'b10,3'd0}][3] };

assign pal = {
  mmr[{2'b11,3'd5}][2:0],
  mmr[{2'b11,3'd4}][2:0],
  mmr[{2'b11,3'd3}][2:0],
  mmr[{2'b11,3'd2}][2:0],
  mmr[{2'b11,3'd1}][2:0],
  mmr[{2'b11,3'd0}][2:0] };

assign ioctl_din = mmr[ioctl_addr];

always @(posedge clk, posedge rst) begin
    if( rst ) begin
    `ifndef SIMULATION
        mmr['o00]<=0; mmr['o01]<=0; mmr['o02]<=0; mmr['o03]<=0; mmr['o04]<=0; mmr['o05]<=0; mmr['o06]<=0; mmr['o07]<=0;
        mmr['o10]<=0; mmr['o11]<=0; mmr['o12]<=0; mmr['o13]<=0; mmr['o14]<=0; mmr['o15]<=0; mmr['o16]<=0; mmr['o17]<=0;
        mmr['o20]<=0; mmr['o21]<=0; mmr['o22]<=0; mmr['o23]<=0; mmr['o24]<=0; mmr['o25]<=0; mmr['o26]<=0; mmr['o27]<=0;
        mmr['o30]<=0; mmr['o31]<=0; mmr['o32]<=0; mmr['o33]<=0; mmr['o34]<=0; mmr['o35]<=0; mmr['o36]<=0; mmr['o37]<=0;
    `else
        for(i=0;i<32;i++) mmr[i] <= mmr_init[i];
    `endif
    end else begin
        dout    <= mmr[addr];
        st_dout <= mmr[debug_bus[4:0]];
        if( cs & ~rnw ) mmr[addr]<=din;
    end
end

`ifdef SIMULATION
/* verilator tracing_off */
integer f, fcnt;
reg [7:0] mmr_init[0:31];
initial begin
    f=$fopen("rest.bin","rb");
    if( f!=0 ) begin
        fcnt=$fread(mmr_init,f);
        $display("INFO: Read %d bytes for %m.mmr",fcnt);
    end
    $fclose(f);
end
`endif

endmodule    