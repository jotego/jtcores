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

// Generic dual port RAM with clock enable
// parameters:
//      DW      => Data bit width, 8 for byte-based memories
//      AW      => Address bit width, 10 for 1kB
//      SIMFILE => binary file to load during simulation
//      SIMHEXFILE => hexadecimal file to load during simulation
//      SYNFILE => hexadecimal file to load for synthesis

/* verilator lint_off MULTIDRIVEN */

module jtframe_dual_ram #(parameter DW=8, AW=10,
    SIMFILE="", SIMHEXFILE="",
    SYNFILE="",
    ASCII_BIN=0,  // set to 1 to read the ASCII file as binary
    DUMPFILE="dump.hex"
)(
    // Port 0
    input   clk0,
    input   [DW-1:0] data0,
    input   [AW-1:0] addr0,
    input   we0,
    output  [DW-1:0] q0,
    // Port 1
    input   clk1,
    input   [DW-1:0] data1,
    input   [AW-1:0] addr1,
    input   we1,
    output  [DW-1:0] q1
    `ifdef JTFRAME_DUAL_RAM_DUMP
    ,input dump
    `endif
);

    jtframe_dual_ram_cen #(
        .DW         ( DW        ),
        .AW         ( AW        ),
        .SIMFILE    ( SIMFILE   ),
        .SIMHEXFILE ( SIMHEXFILE),
        .SYNFILE    ( SYNFILE   ),
        .ASCII_BIN  ( ASCII_BIN ),
        .DUMPFILE   ( DUMPFILE  )
    ) u_ram (
        .clk0   ( clk0  ),
        .cen0   ( 1'b1  ),
        .clk1   ( clk1  ),
        .cen1   ( 1'b1  ),
        // Port 0
        .data0  ( data0 ),
        .addr0  ( addr0 ),
        .we0    ( we0   ),
        .q0     ( q0    ),
        // Port 1
        .data1  ( data1 ),
        .addr1  ( addr1 ),
        .we1    ( we1   ),
        .q1     ( q1    )
        `ifdef JTFRAME_DUAL_RAM_DUMP
        ,.dump  ( dump  )
        `endif
    );
endmodule



module jtframe_dual_ram_cen #(parameter DW=8, AW=10,
    SIMFILE="", SIMHEXFILE="",
    SYNFILE="",
    ASCII_BIN=0,  // set to 1 to read the ASCII file as binary
    DUMPFILE="dump" // do not add an extension to the name
)(
    input   clk0,
    input   cen0,
    input   clk1,
    input   cen1,
    // Port 0
    input   [DW-1:0] data0,
    input   [AW-1:0] addr0,
    input   we0,
    output [DW-1:0] q0,
    // Port 1
    input   [DW-1:0] data1,
    input   [AW-1:0] addr1,
    input   we1,
    output [DW-1:0] q1
    `ifdef JTFRAME_DUAL_RAM_DUMP
    ,input dump
    `endif
);

`ifdef SIMULATION
localparam SIMULATION=1;
`else
localparam SIMULATION=0;
`endif

`ifdef POCKET
localparam POCKET=1;
`else
localparam POCKET=0;
`endif

// generate
//     if( !SIMULATION && POCKET && AW<13 && DW<=8 ) begin
//             jtframe_pocket_dualram u_pocket_ram(
//                 .address_a( { {AW-13{1'b0}}, addr0} ),
//                 .address_b( { {AW-13{1'b0}}, addr1} ),
//                 .clock_a  ( clk0    ),
//                 .clock_b  ( clk1    ),
//                 .data_a   ( data0   ),
//                 .data_b   ( data1   ),
//                 .enable_a ( cen0    ),
//                 .enable_b ( cen1    ),
//                 .wren_a   ( we0     ),
//                 .wren_b   ( we1     ),
//                 .q_a      ( q0      ),
//                 .q_b      ( q1      )
//             );
//         end else begin
            reg [DW-1:0] qq0, qq1;
            (* ramstyle = "no_rw_check" *) reg [DW-1:0] mem[0:(2**AW)-1];

            assign { q0, q1 } = { qq0, qq1 };

            always @(posedge clk0) if(cen0) begin
                qq0 <= mem[addr0];
                if(we0) mem[addr0] <= data0;
            end

            always @(posedge clk1) if(cen1) begin
                qq1 <= mem[addr1];
                if(we1) mem[addr1] <= data1;
            end

            /* verilator lint_off WIDTH */
            `ifdef SIMULATION
                // Content dump for simulation debugging
                `ifdef JTFRAME_DUAL_RAM_DUMP
                    integer fdump=0, dumpcnt, fcnt=32'h30303030;
                    reg dumpl;



                    always @(posedge clk1) begin
                        dumpl <= dump;
                        if( dump & ~dumpl ) begin
                            $display("INFO: %m contents dumped to %s", DUMPFILE );
                            fdump=$fopen( {DUMPFILE, "_", fcnt[23:0],".hex"},"w");
                            for( dumpcnt=0; dumpcnt<2**AW; dumpcnt=dumpcnt+1 )
                                $fdisplay(fdump,"%0X", mem[dumpcnt]);
                            $fclose(fdump);
                            // increment fcnt
                            fcnt[7:0] <= fcnt[7:0]==8'h39 ? 8'h30 : fcnt[7:0]+1'd1;
                            if( fcnt[7:0]==8'h39 ) begin
                                fcnt[15-:8] <= fcnt[15-:8]==8'h39 ? 8'h30 : fcnt[15-:8]+1'd1;
                                if( fcnt[15-:8]==8'h39 ) begin
                                    fcnt[23-:8] <= fcnt[23-:8]==8'h39 ? 8'h30 : fcnt[23-:8]+1'd1;
                                end
                            end
                        end
                    end
                `endif

                integer f, readcnt;
                initial begin
                    for( f=0; f<(2**AW)-1;f=f+1) begin
                        mem[f] = 0;
                    end
                    if( SIMFILE != "" ) begin
                        f=$fopen(SIMFILE,"rb");
                        if( f != 0 ) begin
                            readcnt=$fread( mem, f );
                            $display("-%-10s (%4d bytes) %m",
                                SIMFILE, readcnt);
                            if( readcnt != 2**AW && readcnt!=0)
                                $display("\tthe memory was not filled by the file data");
                            $fclose(f);
                        end else begin
                            f=$fopen(SIMFILE,"wb");
                            if( f!=0 ) begin
                                for( readcnt=0; readcnt<(2**AW)-1; readcnt=readcnt+2) begin
                                    $fwrite(f,"%u",32'hffff);
                                end
                                $fclose(f);
                                $display("Blank %s created",SIMFILE);
                            end else begin
                                $display("WARNING: %m cannot open file: %s", SIMFILE);
                            end
                        end
                        end
                    else begin
                        if( SIMHEXFILE != "" ) begin
                            $readmemh(SIMHEXFILE,mem);
                            $display("INFO: Read %14s (hex) for %m", SIMHEXFILE);
                        end else begin
                            if( SYNFILE!= "" ) begin
                                if( ASCII_BIN==1 )
                                    $readmemb(SYNFILE,mem);
                                else
                                    $readmemh(SYNFILE,mem);
                                $display("INFO: Read %14s (hex) for %m", SYNFILE);
                            end else
                                for( readcnt=0; readcnt<2**AW; readcnt=readcnt+1 )
                                    mem[readcnt] = {DW{1'b0}};
                        end
                    end
                end
            `else
                // file for synthesis:
                initial if(SYNFILE!="" ) begin
                    if( ASCII_BIN==1 )
                        $readmemb(SYNFILE,mem);
                    else
                        $readmemh(SYNFILE,mem);
                end
            `endif
//         end
// endgenerate

/* verilator lint_on WIDTH */
endmodule
/* verilator lint_on MULTIDRIVEN */