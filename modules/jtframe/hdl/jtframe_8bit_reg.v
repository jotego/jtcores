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
    Date: 8-7-2025 */
/* verilator tracing_off */
module jtframe_8bit_reg #(
    parameter SIMFILE="" // use to apply a different reset value during sims
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
integer   f, rdcnt;

initial begin
    sim_rst     = 0;
    sim_load[0] = 0;
    if( SIMFILE != "" ) begin
        f = $fopen(SIMFILE,"rb");
        if( f != 0 ) begin
            rdcnt = $fread(sim_load, f);
            $fclose(f);
            sim_rst = sim_load[0];
            $display("INFO: %m %s (%0d bytes)", SIMFILE, rdcnt);
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
