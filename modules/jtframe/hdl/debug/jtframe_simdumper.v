/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 16-5-2025 */

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