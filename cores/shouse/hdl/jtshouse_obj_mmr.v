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

module jtshouse_obj_mmr(
    input             rst,
    input             clk,

    input             cs,
    input       [2:0] addr,
    input             rnw,
    input       [7:0] din,
    output reg  [7:0] dout,

    output      [8:0] xoffset,
    output      [7:0] yoffset,

    output reg        dma_on,

    // IOCTL dump
    input      [ 2:0] ioctl_addr,
    output reg [ 7:0] ioctl_din,
    // Debug
    input      [ 7:0] debug_bus,
    output reg [ 7:0] st_dout
);

parameter SIMFILE="rest.bin",
          SEEK=32;

reg  [ 7:0] mmr[0:7];
integer     i;

assign xoffset = { mmr[4][0], mmr[5] };
assign yoffset =   mmr[7];

always @(posedge clk, posedge rst) begin
    if( rst ) begin
    `ifndef SIMULATION
        mmr['o00]<=0; mmr['o01]<=0; mmr['o02]<=0; mmr['o03]<=0; mmr['o04]<=0; mmr['o05]<=0; mmr['o06]<=0; mmr['o07]<=0;
    `else
        for(i=0;i<8;i++) mmr[i] <= mmr_init[i];
    `endif
        dma_on    <= 0;
    end else begin
        dma_on    <= 0;
        dout      <= mmr[addr];
        st_dout   <= mmr[debug_bus[2:0]];
        ioctl_din <= mmr[ioctl_addr];
        if( cs & ~rnw ) begin
            mmr[addr]<=din;
            if(addr==2) dma_on <= 1;
        end
    end
end

`ifdef SIMULATION
/* verilator tracing_off */
integer f, fcnt, err;
reg [7:0] mmr_init[0:7];
initial begin
    f=$fopen(SIMFILE,"rb");
    err=$fseek(f,SEEK,0);
    if( f!=0 ) begin
        fcnt=$fread(mmr_init,f);
        $display("INFO: Read %d bytes for %m.mmr",fcnt);
    end
    $fclose(f);
end
`endif

endmodule    