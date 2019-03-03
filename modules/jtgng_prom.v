/*  This file is part of JT_GNG.
    JT_GNG program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JT_GNG program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JT_GNG.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 27-10-2017 */

module jtgng_prom #(parameter dw=8, aw=10, simfile="", cen_rd=0 )(
    input   clk,
    input   cen,
    input   [dw-1:0] data,
    input   [aw-1:0] rd_addr,
    input   [aw-1:0] wr_addr,
    input   we,
    output reg [dw-1:0] q
);

reg [dw-1:0] mem[0:(2**aw)-1];

`ifdef SIMULATION
integer f, readcnt;
`ifndef LOADROM
// load the file only when SPI load is not simulated
initial begin
    if( simfile != "" ) begin
        f=$fopen(simfile,"rb");
        if( f != 0 ) begin
            readcnt=$fread( mem, f );
            $display("INFO: %m file %s loaded",simfile);
            $fclose(f);
        end else begin
            $display("WARNING: %m cannot open %s", simfile);
        end
        end
    else begin
        for( readcnt=0; readcnt<(2**aw)-1; readcnt=readcnt+1 )
            mem[readcnt] = {dw{1'b0}};
        end
end
`endif
// check contents after 80ms
reg [dw-1:0] mem_check[0:(2**aw)-1];
initial begin
    #(`MEM_CHECK_TIME);
    f=$fopen(simfile,"rb");
    if( f!= 0 ) begin
        readcnt = $fread( mem_check, f );
        $fclose(f);
        for( readcnt=readcnt-1;readcnt>0; readcnt=readcnt-1) begin
            if( mem_check[readcnt] != mem[readcnt] ) begin
                $display("ERROR: memory content check failed for file %s (%m)", simfile );
                //$finish;
            end
        end
        $display("INFO: %m memory check succedded");
    end
end
`endif

always @(posedge clk) begin
    if( !cen_rd || cen ) q <= mem[rd_addr];
    if( we) mem[wr_addr] <= data; // no clock enable for writtings to allow correct operation during SPI downloading.
end

endmodule // jtgng_ram