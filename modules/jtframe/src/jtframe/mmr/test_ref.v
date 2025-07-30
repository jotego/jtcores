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
    Date: 20-10-2023 */

module jtshouse_cus30_mmr(
    input             rst,
    input             clk,

    input             cs,
    input       [5:0] addr,
    input             rnw,
    input       [7:0] din, 
    
    output    [31:0] lvol,
    output    [31:0] rvol,
    output    [7:0] no_en,
    output    [31:0] wsel,
    output    [159:0] freq,

    // IOCTL dump
    input      [5:0] ioctl_addr,
    output reg [7:0] ioctl_din,
    // Debug
    input      [7:0] debug_bus,
    output reg [7:0] st_dout
);

parameter SIMFILE="rest.bin",
          SEEK=0;
parameter [SIZE*8-1:0] INIT=0; // from high to low regs {mmr[3],mmr[2],mmr[1],mmr[0]}

localparam SIZE=63;

reg  [ 7:0] mmr[0:SIZE-1];
integer     i;

assign lvol = { 
    mmr[0][3:0],
    mmr[8][3:0],
    mmr[16][3:0],
    mmr[24][3:0],
    mmr[32][3:0],
    mmr[40][3:0],
    mmr[48][3:0],
    mmr[56][3:0], {0{1'b0}}  // finish off without a comma
    };

assign rvol = { 
    mmr[4][3:0],
    mmr[12][3:0],
    mmr[20][3:0],
    mmr[28][3:0],
    mmr[36][3:0],
    mmr[44][3:0],
    mmr[52][3:0],
    mmr[60][3:0], {0{1'b0}}  // finish off without a comma
    };

assign no_en = { 
    mmr[60][7],
    mmr[4][7],
    mmr[12][7],
    mmr[20][7],
    mmr[28][7],
    mmr[36][7],
    mmr[44][7],
    mmr[52][7], {0{1'b0}}  // finish off without a comma
    };

assign wsel = { 
    mmr[1][7:4],
    mmr[9][7:4],
    mmr[17][7:4],
    mmr[25][7:4],
    mmr[33][7:4],
    mmr[41][7:4],
    mmr[49][7:4],
    mmr[57][7:4], {0{1'b0}}  // finish off without a comma
    };

assign freq = { 
    mmr[1][3:0],
    mmr[2][7:0],
    mmr[3][7:0],
    mmr[9][3:0],
    mmr[10][7:0],
    mmr[11][7:0],
    mmr[17][3:0],
    mmr[18][7:0],
    mmr[19][7:0],
    mmr[25][3:0],
    mmr[26][7:0],
    mmr[27][7:0],
    mmr[33][3:0],
    mmr[34][7:0],
    mmr[35][7:0],
    mmr[41][3:0],
    mmr[42][7:0],
    mmr[43][7:0],
    mmr[49][3:0],
    mmr[50][7:0],
    mmr[51][7:0],
    mmr[57][3:0],
    mmr[58][7:0],
    mmr[59][7:0], {0{1'b0}}  // finish off without a comma
    };


always @(posedge clk, posedge rst) begin
    if( rst ) begin
    `ifndef SIMULATION
        for(i=0;i<SIZE;i=i+1) mmr[i] <= INIT[i*8+:8];
    `else
        for(i=0;i<SIZE;i=i+1) mmr[i] <= mmr_init[i];
    `endif 
    end else begin
        st_dout   <= mmr[debug_bus[5:0]];
        ioctl_din <= mmr[ioctl_addr];
        if( cs & ~rnw ) begin
            mmr[addr]<=din;
        end
        i = 0; // for Quartus linter
    end
end

`ifdef SIMULATION
/* verilator tracing_off */
integer f, fcnt, err;
reg [7:0] mmr_init[0:SIZE-1];
initial begin
    f=$fopen(SIMFILE,"rb");
    err=$fseek(f,SEEK,0);
    if( f!=0 && err!=0 ) begin
        $display("Cannot seek file rest.bin to offset 0x%0X (%0d)",SEEK,SEEK);
    end
    if( f!=0 ) begin
        fcnt=$fread(mmr_init,f);
        $display("MMR %m - read %0d bytes from offset %0d",fcnt,SEEK);
        if( fcnt!=SIZE ) begin
            $display("WARNING: Missing %d bytes for %m.mmr",SIZE-fcnt);
        end else begin
            $display("\tlvol = %X",{  mmr_init[0][3:0], mmr_init[8][3:0], mmr_init[16][3:0], mmr_init[24][3:0], mmr_init[32][3:0], mmr_init[40][3:0], mmr_init[48][3:0], mmr_init[56][3:0],{0{1'b0}}});
            $display("\trvol = %X",{  mmr_init[4][3:0], mmr_init[12][3:0], mmr_init[20][3:0], mmr_init[28][3:0], mmr_init[36][3:0], mmr_init[44][3:0], mmr_init[52][3:0], mmr_init[60][3:0],{0{1'b0}}});
            $display("\tno_en = %X",{  mmr_init[60][7], mmr_init[4][7], mmr_init[12][7], mmr_init[20][7], mmr_init[28][7], mmr_init[36][7], mmr_init[44][7], mmr_init[52][7],{0{1'b0}}});
            $display("\twsel = %X",{  mmr_init[1][7:4], mmr_init[9][7:4], mmr_init[17][7:4], mmr_init[25][7:4], mmr_init[33][7:4], mmr_init[41][7:4], mmr_init[49][7:4], mmr_init[57][7:4],{0{1'b0}}});
            $display("\tfreq = %X",{  mmr_init[1][3:0], mmr_init[2][7:0], mmr_init[3][7:0], mmr_init[9][3:0], mmr_init[10][7:0], mmr_init[11][7:0], mmr_init[17][3:0], mmr_init[18][7:0], mmr_init[19][7:0], mmr_init[25][3:0], mmr_init[26][7:0], mmr_init[27][7:0], mmr_init[33][3:0], mmr_init[34][7:0], mmr_init[35][7:0], mmr_init[41][3:0], mmr_init[42][7:0], mmr_init[43][7:0], mmr_init[49][3:0], mmr_init[50][7:0], mmr_init[51][7:0], mmr_init[57][3:0], mmr_init[58][7:0], mmr_init[59][7:0],{0{1'b0}}});
        end
    end else begin
        for(i=0;i<SIZE;i++) mmr_init[i] = 0;
    end
    $fclose(f);
end
`endif

endmodule
