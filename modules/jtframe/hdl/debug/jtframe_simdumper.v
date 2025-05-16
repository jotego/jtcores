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
    Date: 16-5-2025 */

`ifdef SIMULATION
`ifdef NOMAIN
`define JTFRAME_SIMDUMPER_RESTORE
`endif
`endif

module jtframe_simdumper #(parameter
    SIMFILE="rest.bin",
    SEEK=0,
    DW=32,
    SIZE=(DW>>3)+(DW[2:0]!=0?1:0), // size in bytes
    AW=$clog2(SIZE)
)(
    input             clk,
`ifdef JTFRAME_SIMDUMPER_RESTORE
    output reg [DW-1:0] data,
`else    
    input  [DW-1:0]   data,
`endif    
    // IOCTL dump
    input   [AW-1:0] ioctl_addr,
    output reg [7:0] ioctl_din
);

`ifndef JTFRAME_SIMDUMPER_RESTORE
reg [AW-1:0] addr;
integer aux;

always @(posedge clk) begin
    addr <= ioctl_addr;
    for(aux=0;aux<8;aux=aux+1) begin
        ioctl_din[aux] <= data[{addr,aux[2:0]}];
    end        
end
`endif

`ifdef JTFRAME_SIMDUMPER_RESTORE
reg [DW-1:0] mirrored;
initial ioctl_din=0;

integer aux,aux2,index;
always @* begin
    for(aux=0;aux<SIZE;aux=aux+1)
        for(aux2=0;aux2<8;aux2=aux2+1) begin
            data[{aux[28:0],aux2[2:0]}] = mirrored[{SIZE[28:0]-28'd1-aux[28:0],aux2[2:0]}];
        end
end

integer f,fcnt,err;
initial begin
    f=$fopen(SIMFILE,"rb");
    err=$fseek(f,SEEK,0);
    if( f!=0 && err!=0 ) begin
        $display("Cannot seek file rest.bin to offset 0x%0X (%0d)",SEEK,SEEK);
    end
    if( f!=0 ) begin
        fcnt=$fread(mirrored,f);
        $display("MMR %m - read %0d bytes from offset %0d",fcnt,SEEK);
        if( fcnt!=SIZE ) begin
            $display("WARNING: Missing %d bytes for %m.mmr",SIZE-fcnt);
        end 
    end
    $fclose(f);    
end
`endif

endmodule