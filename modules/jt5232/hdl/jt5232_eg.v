/*  This file is part of JTCORES.
    JTCORES program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTCORES program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTCORES.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 6-12-2024 */

// envelope generator

module jt5232_eg(
    input         rst,
    input         clk,
    input         cen256,   // 1 in 256 clk's
    input  [ 4:0] duty,     // divide cen256 following atime and dtime
    input         gf,
    input         kon,
    input         en,
    input         arm,      // attack-release mode
    input  [ 2:0] atime,    // attack time configuration
    input  [ 3:0] dtime,    // decay  time configuration
    output [11:0] env
);

// resistor values from MAME
localparam real CLK=`JTFRAME_MCLK/256,
               CAP=1e-6,
               RA = 870,    // attack resistor
               R2 = 5800,  // release/damping
               R1 = 37000;  // decay
`ifdef SIMULATION
/* verilator lint_off REALCVT */
localparam real DA=1.0-$pow(2.71828,-1.0/(CLK*CAP*RA)),
                D1=1.0-$pow(2.71828,-1.0/(CLK*CAP*R1)),
                D2=1.0-$pow(2.71828,-1.0/(CLK*CAP*R2)),
                P9=0.9;
localparam [EW-1:0] DAB=DA*(48'd1<<EW),
                    D1B=D1*(48'd1<<EW),
                    D2B=D2*(48'd1<<EW),
                    P9B=P9*(48'd1<<EW);
`else
// These values must be updated manually because Quartus does not support $pow
localparam [25:0] DAB=26'h0064219,
                  D1B=26'h00025c9,
                  D2B=26'h000f0f1,
                  P9B=26'h399999a;
`endif
localparam EW=26;
/* verilator lint_off REALCVT */
localparam [1:0] ATTACK=0,
                  DECAY=1,
                RELEASE=2;

initial begin
    // $display("DAB=%X",DAB);
    // $display("D1B=%X",D1B);
    // $display("D2B=%X",D2B);
    // $display("P9B=%X",P9B);
    if( |DAB==0 || |D1B==0 || |D2B==0 || |P9B==0 ) begin
        $fatal(1,"Only values !=0 are valid");
    end
end

reg  [EW-1:0] eg=1;
reg  [EW  :0] sub;
reg  [EW-1:0] mux;
reg  [EW*2:0] egmulr, egmulf;
reg  [EW-1:0] egrise,egfall;
reg  [   1:0] sel=0;
reg           attack=0, cen_eff;
wire [   2:0] duty_sel; // duty cycle
// wire [EW-1:0] p9b = P9B;
assign env    = eg[EW-1-:12];

assign duty_sel = attack ? atime : dtime[2:0];

// This assumes that there are plenty of clocks in between two cen strobes
// All these signals must be calculated in the time between two cen_eff
always @(posedge clk) begin
    mux    <= sel==DECAY ? D1B : sel==RELEASE ? D2B : DAB;
    sub    <= {1'b1,{EW{1'b0}}}-{1'b0,eg};
    egmulr <= sub*mux;
    egmulf <= eg*mux;
    egrise <= eg+egmulr[EW*2-:EW];
    egfall <= eg-egmulf[EW*2-:EW];
end

always @(posedge clk) begin
    cen_eff <= 0;
    if(cen256) begin
        cen_eff <= 1; // release has 100% duty cycle
        if(attack || !arm) casez(duty_sel)
            3'd0:   cen_eff <= 1;
            3'd1:   cen_eff <= duty[0];
            3'd2:   cen_eff <= duty[1:0]==1;
            3'd3:   cen_eff <= duty[2:0]==1;
            3'b1?0: cen_eff <= duty[3:0]==1;
            3'b1?1: cen_eff <= duty[4:0]==1;
        endcase
    end
    if(!en) cen_eff <= 0; // keep the current capacitor voltage
end

always @(posedge clk) begin
    if(rst) begin
        eg     <= 0;
        attack <= 0;
        sel    <= 0;
    end else begin
        if(kon) attack<=1;
        if(!gf) attack<=0;
        if(cen_eff) begin
            if(attack) begin
                sel <= ATTACK;
                eg  <= egrise;
                if( eg>P9B && !arm ) attack<=0;
            end else begin
                sel <= ((!arm && dtime[3]) && gf)  ? DECAY : RELEASE;
                eg  <= egfall;
            end
        end
        if(eg==0) eg <= 1;
    end
end

endmodule