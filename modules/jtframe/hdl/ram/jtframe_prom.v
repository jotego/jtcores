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
    Date: 27-10-2017 */

/* verilator tracing_off*/
module jtframe_prom #(parameter
    DW      = 8,
    AW      = 10,
    SIMFILE = "",
    SIMHEX  = "",
    SYNHEX  = "",
    OFFSET  = 0,
    ASYNC   = 0     // makes the read asynchronous (will not map as BRAM)
)(
    input   clk,
    input   cen,
    input   [DW-1:0] data,
    input   [AW-1:0] rd_addr,
    input   [AW-1:0] wr_addr,
    input   we,
    output reg [DW-1:0] q
);

(* ramstyle = "no_rw_check" *) reg [DW-1:0] mem[0:(2**AW)-1];

`ifdef SIMULATION
/* verilator lint_off WIDTH */
integer f, readcnt;
`ifndef LOADROM
// load the file only when SPI load is not simulated
initial begin
    if( SIMFILE != "" ) begin
        f=$fopen(SIMFILE,"rb");
        if( f != 0 ) begin
            readcnt=$fseek( f, OFFSET, 0 );
            readcnt=$fread( mem, f );
            $display("INFO: Read %14s (%4d bytes) for %m",SIMFILE, readcnt);
            $fclose(f);
        end else begin
            $display("WARNING: %m cannot open %s", SIMFILE);
        end
    end else if( SIMHEX != "" ) begin
        $display("INFO: reading %14s (hex) for %m", SIMHEX );
        $readmemh( SIMHEX, mem );
    end else begin
        for( readcnt=0; readcnt<(2**AW)-1; readcnt=readcnt+1 )
            mem[readcnt] = {DW{1'b0}};
    end
end
`endif
`ifdef MEM_CHECK_TIME
    // check contents after 80ms
    reg [DW-1:0] mem_check[0:(2**AW)-1];
    reg check_ok=1'b1;
    initial begin
        #(`MEM_CHECK_TIME);
        if( SIMFILE != "" ) begin
            f=$fopen(SIMFILE,"rb");
            if( f!= 0 ) begin
                readcnt = $fseek( f, OFFSET, 0 );   // return value assigned to readcnt to avoid a warning
                readcnt = $fread( mem_check, f );
                $fclose(f);
                for( readcnt=readcnt-1;readcnt>=0; readcnt=readcnt-1) begin
                    if( mem_check[readcnt] != mem[readcnt] ) begin
                        $display("ERROR: memory content check failed for file %s (%m) @ 0x%x", SIMFILE, readcnt );
                        check_ok = 1'b0;
                        //`ifndef IVERILOG
                        //break;
                        //`else
                            readcnt = 0; // force a break
                        //`endif
                    end
                end
                if( check_ok ) $display("INFO: %m memory check succedded");
            end
            else begin
                $display("ERROR: Cannot find file %s to check memory %m", SIMFILE );
            end
        end
    end
`endif
/* verilator lint_on WIDTH */
`else
    // Not simulation
    initial begin
        if( SYNHEX != "" ) begin
            $readmemh(SYNHEX, mem);
        end
    end
`endif

generate
    if( ASYNC ) begin
        always @(posedge clk) begin
            if( we ) mem[wr_addr] <= data;
        end

        always @(*) begin
            q = mem[rd_addr];
        end
    end else begin
        // no clock enable for writtings to allow correct operation during SPI downloading.
        always @(posedge clk) begin
            if( cen ) q <= mem[rd_addr];
            if( we ) mem[wr_addr] <= data;
        end
    end
endgenerate


endmodule // jtframe_ram