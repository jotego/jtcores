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
    Date: 30-8-2023 */

// Use with BRAM blocks to dump them to ioctl_din
// only works with DW=8 or 16

module jtframe_ioctl_dump #(parameter
    DW0=8, DW1=8, DW2=8, DW3=8, DW4=8, DW5=8,
    AW0=8, AW1=8, AW2=8, AW3=8, AW4=8, AW5=8,
    // offset for each section
    OS0=0,
    OS1=OS0+(1<<AW0),
    OS2=OS1+(1<<AW1),
    OS3=OS2+(1<<AW2),
    OS4=OS3+(1<<AW3),
    OS5=OS4+(1<<AW4),
    OS6=OS5+(1<<AW5)
)(
    input   clk,

    input   [DW0-1:0] din0,
    input   [DW1-1:0] din1,
    input   [DW2-1:0] din2,
    input   [DW3-1:0] din3,
    input   [DW4-1:0] din4,
    input   [DW5-1:0] din5,

    input   [(AW0==0?0:AW0-1):(AW0==0?0:DW0>>4)] addrin_0,
    input   [(AW1==0?0:AW1-1):(AW1==0?0:DW1>>4)] addrin_1,
    input   [(AW2==0?0:AW2-1):(AW2==0?0:DW2>>4)] addrin_2,
    input   [(AW3==0?0:AW3-1):(AW3==0?0:DW3>>4)] addrin_3,
    input   [(AW4==0?0:AW4-1):(AW4==0?0:DW4>>4)] addrin_4,
    input   [(AW5==0?0:AW5-1):(AW5==0?0:DW5>>4)] addrin_5,

    output  [(AW0==0?0:AW0-1):(AW0==0?0:DW0>>4)] addrout_0,
    output  [(AW1==0?0:AW1-1):(AW1==0?0:DW1>>4)] addrout_1,
    output  [(AW2==0?0:AW2-1):(AW2==0?0:DW2>>4)] addrout_2,
    output  [(AW3==0?0:AW3-1):(AW3==0?0:DW3>>4)] addrout_3,
    output  [(AW4==0?0:AW4-1):(AW4==0?0:DW4>>4)] addrout_4,
    output  [(AW5==0?0:AW5-1):(AW5==0?0:DW5>>4)] addrout_5,

    input      [23:0] ioctl_addr,
    input             ioctl_ram,
    output     [ 7:0] ioctl_din
);

`ifdef SIMULATION
initial begin // assertions
    if( DW0!=8 && DW0!=16 ) begin $display("Bad DW0 size in %m"); $finish; end
    if( DW1!=8 && DW1!=16 ) begin $display("Bad DW1 size in %m"); $finish; end
    if( DW2!=8 && DW2!=16 ) begin $display("Bad DW2 size in %m"); $finish; end
    if( DW3!=8 && DW3!=16 ) begin $display("Bad DW3 size in %m"); $finish; end
    if( DW4!=8 && DW4!=16 ) begin $display("Bad DW4 size in %m"); $finish; end
    if( DW5!=8 && DW5!=16 ) begin $display("Bad DW5 size in %m"); $finish; end
end
`endif

reg [5:0] sel;

assign addrout_0 = sel[0] ? ioctl_addr[(AW0!=0?AW0-1:0):(AW0!=0?DW0>>4:0)] : addrin_0;
assign addrout_1 = sel[1] ? ioctl_addr[(AW1!=0?AW1-1:0):(AW1!=0?DW1>>4:0)] : addrin_1;
assign addrout_2 = sel[2] ? ioctl_addr[(AW2!=0?AW2-1:0):(AW2!=0?DW2>>4:0)] : addrin_2;
assign addrout_3 = sel[3] ? ioctl_addr[(AW3!=0?AW3-1:0):(AW3!=0?DW3>>4:0)] : addrin_3;
assign addrout_4 = sel[4] ? ioctl_addr[(AW4!=0?AW4-1:0):(AW4!=0?DW4>>4:0)] : addrin_4;
assign addrout_5 = sel[5] ? ioctl_addr[(AW5!=0?AW5-1:0):(AW5!=0?DW5>>4:0)] : addrin_5;

assign ioctl_din =
    sel[0] ? ( (DW0==16 && ioctl_addr[0]) ? din0[DW0-1 -:8] : din0[7:0]) :
    sel[1] ? ( (DW1==16 && ioctl_addr[0]) ? din1[DW1-1 -:8] : din1[7:0]) :
    sel[2] ? ( (DW2==16 && ioctl_addr[0]) ? din2[DW2-1 -:8] : din2[7:0]) :
    sel[3] ? ( (DW3==16 && ioctl_addr[0]) ? din3[DW3-1 -:8] : din3[7:0]) :
    sel[4] ? ( (DW4==16 && ioctl_addr[0]) ? din4[DW4-1 -:8] : din4[7:0]) :
             ( (DW5==16 && ioctl_addr[0]) ? din5[DW5-1 -:8] : din5[7:0]);

always @(posedge clk) begin
    sel <= 0;
    if( ioctl_ram ) begin
        if( ioctl_addr < OS1 ) sel[0] <= 1;
        else if( ioctl_addr < OS2 ) sel[1] <= 1;
        else if( ioctl_addr < OS3 ) sel[2] <= 1;
        else if( ioctl_addr < OS4 ) sel[3] <= 1;
        else if( ioctl_addr < OS5 ) sel[4] <= 1;
        else if( ioctl_addr < OS6 ) sel[5] <= 1;
    end
end

endmodule