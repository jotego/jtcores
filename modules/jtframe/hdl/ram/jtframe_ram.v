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
//      LATCH_IN  => Register address, data, cen and we before the RAM. Adds
//                   one clock cycle of latency.
//      LATCH_OUT => Register output data after the RAM. Adds one clock cycle
//                   of latency.


module jtframe_ram #(parameter DW=8, AW=10,
        SIMFILE="", SIMHEXFILE="",
        SIMFILE_BYTE=0, FULL_DW=8,
        SYNFILE="", SYNBINFILE="",
        VERBOSE=0,          // set to 1 to display memory writes to screen
        VERBOSE_OFFSET=0,   // value added to the address when displaying
        CEN_RD=0,
        LATCH_IN=0,         // latch: inputs; adds one clock cycle
        LATCH_OUT=0         // latch: outputs; adds one clock cycle
)(
    input   clk,
    input   cen /* direct_enable */,
    input   [DW-1:0] data,
    input   [AW-1:0] addr,
    input   we,
    output  [DW-1:0] q
);

(* ramstyle = "no_rw_check" *) reg [DW-1:0] mem[0:(2**AW)-1];

wire [DW-1:0] data_m;
wire [AW-1:0] addr_m;
wire          cen_m, we_m;
reg  [DW-1:0] data_l, q_m;
reg  [AW-1:0] addr_l;
reg           cen_l, we_l;

generate
    if( LATCH_IN!=0 ) begin : gen_latch_input
        always @(posedge clk) begin
            data_l <= data;
            addr_l <= addr;
            cen_l  <= cen;
            we_l   <= we;
        end
        assign data_m = data_l;
        assign addr_m = addr_l;
        assign cen_m  = cen_l;
        assign we_m   = we_l;
    end else begin : gen_no_latch_input
        assign data_m = data;
        assign addr_m = addr;
        assign cen_m  = cen;
        assign we_m   = we;
    end
endgenerate

generate
    if( LATCH_OUT!=0 ) begin : gen_latch_output
        reg [DW-1:0] q_l;
        assign q = q_l;
        always @(posedge clk) q_l <= q_m;
    end else begin : gen_no_latch_output
        assign q = q_m;
    end
endgenerate

`ifdef SIMULATION
generate
    if( VERBOSE==1 ) begin
        reg [AW-1:0] al;
        reg [DW-1:0] dl;
        reg          wel;
        always @(posedge clk) begin
            al  <= addr_m;
            dl  <= data_m;
            wel <= we_m;
            if( al!=addr_m || dl!=data_m || wel!=we_m ) begin
                if(we_m) $display("%m %0X=%X", { {32-AW{1'b0}}, addr_m}+VERBOSE_OFFSET,data_m);
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
    if( !CEN_RD || cen_m ) q_m <= mem[addr_m];
    if( cen_m && we_m) mem[addr_m] <= data_m;
end

endmodule
