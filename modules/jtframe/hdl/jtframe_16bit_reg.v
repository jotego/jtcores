/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 1-1-2025 */

/* verilator tracing_off */
module jtframe_16bit_reg #(
    parameter SIMFILE="" // use to apply a different reset value during sims
)(
    // do not change port order
    // as this module is intended for direct instantiation
    input             rst,
    input             clk,
    input             wr_n,
    input      [ 1:0] dsn,
    input      [15:0] din,
    input             cs,
    output reg [15:0] dout
);

`ifdef SIMULATION
reg [15:0] sim_rst;
reg [ 7:0] sim_load[0:1];
integer    f, rdcnt;

initial begin
    sim_rst     = 0;
    sim_load[0] = 0;
    sim_load[1] = 0;
    if( SIMFILE != "" ) begin
        f = $fopen(SIMFILE,"rb");
        if( f != 0 ) begin
            rdcnt = $fread(sim_load, f);
            $fclose(f);
            sim_rst = { sim_load[1], sim_load[0] };
            $display("INFO: %m %s (%0d bytes)", SIMFILE, rdcnt);
            if( rdcnt < 2 ) begin
                $display("WARNING: SIMFILE %s is short for %m", SIMFILE);
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
            if(!dsn[0]) dout[ 7:0] <= din[ 7:0];
            if(!dsn[1]) dout[15:8] <= din[15:8];
        end
    end
end

endmodule
