/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 27-10-2017 */

// Generic read/write dual port RAM with clock enable
// parameters:
//      DW      => Data bit width, 8 for byte-based memories
//      AW      => Address bit width, 10 for 1kB
// Using jtframe_dual_ram instead of this one fails to infer
// MLAB RAM (at least in MiSTer)
// This coding style gets the memory inferred correctly

module jtframe_rpwp_ram #(parameter DW=8, AW=10, SIMFILE="")(
    input               clk,
    // Read Port
    input      [AW-1:0] rd_addr,
    output reg [DW-1:0] dout,
    // Write Port
    input      [AW-1:0] wr_addr,
    input      [DW-1:0] din,
    input      we
);

(* ramstyle = "no_rw_check, m9k" *) reg [DW-1:0] mem[0:(2**AW)-1];

`ifdef SIMULATION
integer f, readcnt;
initial
if( SIMFILE != 0 ) begin
    f=$fopen(SIMFILE,"rb");
    if( f != 0 ) begin
        readcnt=$fread( mem, f );
        $display("INFO: Read %14s (%4d bytes) for %m",SIMFILE, readcnt);
        $fclose(f);
    end else begin
        $display("WARNING: %m cannot open file: %s", SIMFILE);
    end
end
`endif

always @(posedge clk) begin
    if( we ) mem[wr_addr] <= din;
    dout <= mem[rd_addr];
end

endmodule
