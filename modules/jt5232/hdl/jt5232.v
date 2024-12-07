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

// the ' means feet in an organ pipe length
// output  2' = 4*f
// output  4' = 2*f
// output  8' is the base pitch = f
// output 16' = f/2

module jt5232(
    input         rst,
    input         clk,
    input         cen1,
    input         cen2,
    input  [7:0]  din,
    input  [3:0]  addr,
    input         we,
    output [15:0] snd1, // unsigned!
    output [15:0] snd2
);

// TG configuration
reg  [ 8:0] step[0:7];
wire [ 8:0] pgcnt;
wire [ 2:0] pgbit;
reg  [ 2:0] pitch_sel;
reg  [ 2:0] bsel[0:7];
reg  [ 6:0] pitch;
reg  [ 7:0] gf;
reg  [ 2:0] attack[0:1];
reg  [ 3:0] decay[0:1];
reg  [ 3:0] oen[0:1];         // 2' 4' 8' 16' output enable
reg         sf;               // solo flag (group 2 only)
reg  [ 1:0] ege,              // envelope generator enable
            arm;              // attack-release mode
wire        no_en;            // noise enable
// sound
wire [12*8-1:0] eg;
wire [ 3*8-1:0] organ;

// clock divider
reg [6:0] div1=0, div2=0;
reg [6:0] div3=0;       // A divider for each group
reg [4:0] duty=0;
reg [1:0] cen_tg;
reg       cen256=0;

localparam [6:0] CNTOVER={4'd10,3'd7};

always @(posedge clk) begin
    cen_tg <= 0;
    if(cen1) {cen_tg[0],div1} <= div1 == CNTOVER ? {1'b1,7'd0} : {1'b0,div1+1'd1};
    if(cen2) {cen_tg[1],div2} <= div2 == CNTOVER ? {1'b1,7'd0} : {1'b0,div2+1'd1};
    {cen256,div3} <= {1'b0,div3}+7'd1;
    duty <= duty+{4'd0,cen256};
end

// CPU interface
always @(posedge clk) begin
    if(rst) begin
        gf     <= 0;
        attack[0] <= 0; attack[1] <= 0;
        decay [0] <= 0; decay [1] <= 0;
        oen   [0] <= 0; oen   [1] <= 0;
        pitch <= 0; pitch_sel <= 0;
        step[0] <= 0; step[1] <= 0; step[2] <= 0; step[3] <= 0;
        step[4] <= 0; step[5] <= 0; step[6] <= 0; step[7] <= 0;
        bsel[0] <= 0; bsel[1] <= 0; bsel[2] <= 0; bsel[3] <= 0;
        bsel[4] <= 0; bsel[5] <= 0; bsel[6] <= 0; bsel[7] <= 0;
        {sf,ege,arm} <= 0;
    end else begin
        if(we) casez(addr)
          4'b0???: {pitch_sel, gf[addr[2:0]], pitch} <= {addr[2:0],din};
             8, 9: attack[addr[0]] <= din[2:0];
            10,11: decay [addr[0]] <= din[3:0];
               12: {   ege[0],arm[0],oen[0]} <= din[5:0];
               13: {sf,ege[1],arm[1],oen[1]} <= din[6:0];
          default:;
        endcase
        {step[pitch_sel],bsel[pitch_sel]}<={pgcnt,pgbit};
    end
end

// envelope generators
jt5232_eg u_eg0(rst,clk,cen256,duty,gf[0],ege[0],arm[0],attack[0],decay[0],eg[0*12+:12]);
jt5232_eg u_eg1(rst,clk,cen256,duty,gf[1],ege[0],arm[0],attack[0],decay[0],eg[1*12+:12]);
jt5232_eg u_eg2(rst,clk,cen256,duty,gf[2],ege[0],arm[0],attack[0],decay[0],eg[2*12+:12]);
jt5232_eg u_eg3(rst,clk,cen256,duty,gf[3],ege[0],arm[0],attack[0],decay[0],eg[3*12+:12]);
jt5232_eg u_eg4(rst,clk,cen256,duty,gf[4],ege[1],arm[1],attack[1],decay[1],eg[4*12+:12]);
jt5232_eg u_eg5(rst,clk,cen256,duty,gf[5],ege[1],arm[1],attack[1],decay[1],eg[5*12+:12]);
jt5232_eg u_eg6(rst,clk,cen256,duty,gf[6],ege[1],arm[1],attack[1],decay[1],eg[6*12+:12]);
jt5232_eg u_eg7(rst,clk,cen256,duty,gf[7],ege[1],arm[1],attack[1],decay[1],eg[7*12+:12]);
// tone generators
// group 1
jt5232_tg u_tg0( rst, clk, cen_tg[0], step[0], bsel[0], oen[0], gf[0],organ[0*3+:3] );
jt5232_tg u_tg1( rst, clk, cen_tg[0], step[1], bsel[1], oen[0], gf[1],organ[1*3+:3] );
jt5232_tg u_tg2( rst, clk, cen_tg[0], step[2], bsel[2], oen[0], gf[2],organ[2*3+:3] );
jt5232_tg u_tg3( rst, clk, cen_tg[0], step[3], bsel[3], oen[0], gf[3],organ[3*3+:3] );
// group 2
jt5232_tg u_tg4( rst, clk, cen_tg[1], step[4], bsel[4], oen[1], gf[4],organ[4*3+:3] );
jt5232_tg u_tg5( rst, clk, cen_tg[1], step[5], bsel[5], oen[1], gf[5],organ[5*3+:3] );
jt5232_tg u_tg6( rst, clk, cen_tg[1], step[6], bsel[6], oen[1], gf[6],organ[6*3+:3] );
jt5232_tg u_tg7( rst, clk, cen_tg[1], step[7], bsel[7], oen[1], gf[7],organ[7*3+:3] );
// accumulator
jt5232_acc u_acc(
    .clk    ( clk       ),
    .cen    ( cen256    ),
    .eg     ( eg        ),
    .organ  ( organ     ),
    .snd1   ( snd1      ),
    .snd2   ( snd2      )
);

jt5232_rom u_rom(
    .clk  ( clk       ),
    .addr ( pitch     ),
    .pgcnt( pgcnt     ),
    .bsel ( pgbit     ),
    .noise( no_en     )
);

endmodule