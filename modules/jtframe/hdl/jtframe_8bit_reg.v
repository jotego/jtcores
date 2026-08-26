/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 8-7-2025 */
/* verilator tracing_off */
module jtframe_8bit_reg #(
    parameter SIMFILE="", // use to apply a different reset value during sims
    parameter OFFSET=0    // applied to the simulation file
)(
    // do not change port order
    // as this module is intended for direct instantiation
    input             rst,
    input             clk,
    input             wr_n,
    input      [ 7:0] din,
    input             cs,
    output reg [ 7:0] dout
);

`ifdef SIMULATION
reg [7:0] sim_rst, sim_load[0:0];
integer   f, rdcnt, err;

initial begin
    sim_rst     = 0;
    sim_load[0] = 0;
    if( SIMFILE != "" ) begin
        f = $fopen(SIMFILE,"rb");
        if( f != 0 ) begin
            err = $fseek(f,OFFSET,0);
            if( err != 0 ) begin
                $display("ERROR: cannot seek %m %s to offset %0d", SIMFILE, OFFSET);
                $finish;
            end
            rdcnt = $fread(sim_load, f);
            $fclose(f);
            sim_rst = sim_load[0];
            $display("INFO: %m %s offset %0d (%0d bytes)", SIMFILE, OFFSET, rdcnt);
            if( rdcnt < 1 ) begin
                $display("WARNING: SIMFILE %s is empty for %m", SIMFILE);
            end
        end else begin
            $display("ERROR: cannot load file %s for %m", SIMFILE);
            $finish;
        end
    end
end
`endif

always @(posedge clk) begin
    if(rst) begin
    `ifdef SIMULATION
        dout <= sim_rst;
    `else
        dout <= 0;
    `endif
    end else begin
        if( cs && !wr_n ) begin
            dout[ 7:0] <= din[ 7:0];
        end
    end
end

endmodule
