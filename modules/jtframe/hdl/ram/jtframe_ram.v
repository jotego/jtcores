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

// Generic RAM with clock enable
// parameters:
//      DW      => Data bit width, 8 for byte-based memories
//      AW      => Address bit width, 10 for 1kB
//      SIMFILE => binary file to load during simulation
//      SIMHEXFILE => hexadecimal file to load during simulation
//      SYNFILE => hexadecimal file to load for synthesis
//      CEN_RD  => Use clock enable for reading too, by default it is used
//                 only for writting.


module jtframe_ram #(parameter DW=8, AW=10,
        SIMFILE="", SIMHEXFILE="",
        SIMFILE_BYTE=0, FULL_DW=8,
        SYNFILE="", SYNBINFILE="",
        VERBOSE=0,          // set to 1 to display memory writes to screen
        VERBOSE_OFFSET=0,   // value added to the address when displaying
        CEN_RD=0
)(
    input   clk,
    input   cen /* direct_enable */,
    input   [DW-1:0] data,
    input   [AW-1:0] addr,
    input   we,
    output reg [DW-1:0] q
);

(* ramstyle = "no_rw_check" *) reg [DW-1:0] mem[0:(2**AW)-1];

`ifdef SIMULATION
generate
    if( VERBOSE==1 ) begin
        reg [AW-1:0] al;
        reg [DW-1:0] dl;
        reg          wel;
        always @(posedge clk) begin
            al  <= addr;
            dl  <= data;
            wel <= we;
            if( al!=addr || dl!=data || wel!=we ) begin
                if(we) $display("%m %0X=%X", { {32-AW{1'b0}}, addr}+VERBOSE_OFFSET,data);
            end
        end
    end
endgenerate
`endif

`ifdef SIMULATION
localparam FULL_BYTES = FULL_DW==32 ? 4 : (FULL_DW==16 ? 2 : 1);
integer f, readcnt, loadcnt, loadpos;
reg [7:0] file_data[0:(2**AW)*4-1];
initial
begin
    if( FULL_DW!=8 && FULL_DW!=16 && FULL_DW!=32 ) begin
        $display("ERROR: %m invalid FULL_DW=%0d", FULL_DW);
        $finish;
    end
    if( FULL_DW==16 && (SIMFILE_BYTE<0 || SIMFILE_BYTE>1) ) begin
        $display("ERROR: %m invalid SIMFILE_BYTE=%0d for FULL_DW=16", SIMFILE_BYTE);
        $finish;
    end
    if( FULL_DW==32 && (SIMFILE_BYTE<0 || SIMFILE_BYTE>3) ) begin
        $display("ERROR: %m invalid SIMFILE_BYTE=%0d for FULL_DW=32", SIMFILE_BYTE);
        $finish;
    end
    if( FULL_DW!=8 && DW!=8 ) begin
        $display("ERROR: %m partial SIMFILE loading requires DW=8");
        $finish;
    end
    if( SIMFILE != 0 ) begin
        f=$fopen(SIMFILE,"rb");
        if( f != 0 ) begin
            if( FULL_DW==8 ) begin
                readcnt=$fread( mem, f );
            end else begin
                readcnt=$fread( file_data, f );
                loadcnt = 0;
                for( loadpos=SIMFILE_BYTE; loadpos<readcnt && loadcnt<(2**AW); loadpos=loadpos+FULL_BYTES ) begin
                    /* verilator lint_off WIDTHTRUNC */
                    /* verilator lint_off WIDTHEXPAND */
                    mem[loadcnt] = file_data[loadpos];
                    /* verilator lint_on WIDTHEXPAND */
                    /* verilator lint_on WIDTHTRUNC */
                    loadcnt = loadcnt+1;
                end
                if( readcnt%FULL_BYTES != 0 )
                    $display("WARNING: %m ignored %0d trailing bytes from %s", readcnt%FULL_BYTES, SIMFILE);
            end
            $display("INFO: Read %14s (%4d bytes) for %m",SIMFILE, readcnt/(FULL_DW/8));
            $fclose(f);
        end else begin
            $display("WARNING: %m cannot open file: %s", SIMFILE);
        end
    end else begin
        if( SIMHEXFILE != 0 ) begin
            $readmemh(SIMHEXFILE,mem);
            $display("INFO: Read %14s (hex) for %m", SIMHEXFILE);
        end else begin
            if( SYNFILE != 0 ) begin
                $readmemh(SYNFILE,mem);
                $display("INFO: Read %14s for %m", SYNFILE);
            end else
                for( readcnt=0; readcnt<(2**AW)-1; readcnt=readcnt+1 )
                    mem[readcnt] = {DW{1'b0}};
        end
    end
end
`else
// file for synthesis:
initial if(SYNFILE!=0 )$readmemh(SYNFILE,mem);
initial if(SYNBINFILE!=0 )$readmemb(SYNBINFILE,mem);
`endif

always @(posedge clk) begin
    if( !CEN_RD || cen ) q <= mem[addr];
    if( cen && we) mem[addr] <= data;
end

endmodule
