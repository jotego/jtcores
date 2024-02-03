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
    OS1=(AW0==0 ? OS0 : OS0+(1<<AW0)),
    OS2=(AW1==0 ? OS1 : OS1+(1<<AW1)),
    OS3=(AW2==0 ? OS2 : OS2+(1<<AW2)),
    OS4=(AW3==0 ? OS3 : OS3+(1<<AW3)),
    OS5=(AW4==0 ? OS4 : OS4+(1<<AW4)),
    OS6=(AW5==0 ? OS5 : OS5+(1<<AW5))
)(
    input   clk,

    input   [DW0-1:0] dout0,
    input   [DW1-1:0] dout1,
    input   [DW2-1:0] dout2,
    input   [DW3-1:0] dout3,
    input   [DW4-1:0] dout4,
    input   [DW5-1:0] dout5,

    input   [DW0-1:0] din0,
    input   [DW1-1:0] din1,
    input   [DW2-1:0] din2,
    input   [DW3-1:0] din3,
    input   [DW4-1:0] din4,
    input   [DW5-1:0] din5,

    output  [DW0-1:0] din0_mx,
    output  [DW1-1:0] din1_mx,
    output  [DW2-1:0] din2_mx,
    output  [DW3-1:0] din3_mx,
    output  [DW4-1:0] din4_mx,
    output  [DW5-1:0] din5_mx,

    input   [(AW0==0?0:AW0-1):(AW0==0?0:DW0>>4)] addr0,
    input   [(AW1==0?0:AW1-1):(AW1==0?0:DW1>>4)] addr1,
    input   [(AW2==0?0:AW2-1):(AW2==0?0:DW2>>4)] addr2,
    input   [(AW3==0?0:AW3-1):(AW3==0?0:DW3>>4)] addr3,
    input   [(AW4==0?0:AW4-1):(AW4==0?0:DW4>>4)] addr4,
    input   [(AW5==0?0:AW5-1):(AW5==0?0:DW5>>4)] addr5,

    output  [(AW0==0?0:AW0-1):(AW0==0?0:DW0>>4)] addr0_mx,
    output  [(AW1==0?0:AW1-1):(AW1==0?0:DW1>>4)] addr1_mx,
    output  [(AW2==0?0:AW2-1):(AW2==0?0:DW2>>4)] addr2_mx,
    output  [(AW3==0?0:AW3-1):(AW3==0?0:DW3>>4)] addr3_mx,
    output  [(AW4==0?0:AW4-1):(AW4==0?0:DW4>>4)] addr4_mx,
    output  [(AW5==0?0:AW5-1):(AW5==0?0:DW5>>4)] addr5_mx,

    input      [ 1:0] we0, we1, we2, we3, we4, we5,
    output     [ 1:0] we0_mx, we1_mx, we2_mx, we3_mx, we4_mx, we5_mx,

    input      [23:0] ioctl_addr,
    input             ioctl_ram,
    input             ioctl_wr,
    input      [ 7:0] ioctl_aux, ioctl_dout,
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

reg  [ 5:0] sel;
wire [23:0] part_addr;
reg  [23:0] offset;

assign part_addr = ioctl_addr - offset;

assign addr0_mx = sel[0] ? ioctl_addr[(AW0!=0?AW0-1:0):(AW0!=0?DW0>>4:0)] : addr0;
assign addr1_mx = sel[1] ?  part_addr[(AW1!=0?AW1-1:0):(AW1!=0?DW1>>4:0)] : addr1;
assign addr2_mx = sel[2] ?  part_addr[(AW2!=0?AW2-1:0):(AW2!=0?DW2>>4:0)] : addr2;
assign addr3_mx = sel[3] ?  part_addr[(AW3!=0?AW3-1:0):(AW3!=0?DW3>>4:0)] : addr3;
assign addr4_mx = sel[4] ?  part_addr[(AW4!=0?AW4-1:0):(AW4!=0?DW4>>4:0)] : addr4;
assign addr5_mx = sel[5] ?  part_addr[(AW5!=0?AW5-1:0):(AW5!=0?DW5>>4:0)] : addr5;

assign ioctl_din =
    sel[0] ? ( (DW0==16 && ioctl_addr[0]) ? dout0[DW0-1 -:8] : dout0[7:0]) :
    sel[1] ? ( (DW1==16 && ioctl_addr[0]) ? dout1[DW1-1 -:8] : dout1[7:0]) :
    sel[2] ? ( (DW2==16 && ioctl_addr[0]) ? dout2[DW2-1 -:8] : dout2[7:0]) :
    sel[3] ? ( (DW3==16 && ioctl_addr[0]) ? dout3[DW3-1 -:8] : dout3[7:0]) :
    sel[4] ? ( (DW4==16 && ioctl_addr[0]) ? dout4[DW4-1 -:8] : dout4[7:0]) :
    sel[5] ? ( (DW5==16 && ioctl_addr[0]) ? dout5[DW5-1 -:8] : dout5[7:0]) :
               ioctl_aux;

assign we0_mx = ioctl_ram ? {2{ioctl_wr & sel[0]}} & { ioctl_addr[0], ~ioctl_addr[0] || DW0==8 } : we0;
assign we1_mx = ioctl_ram ? {2{ioctl_wr & sel[1]}} & { ioctl_addr[0], ~ioctl_addr[0] || DW1==8 } : we1;
assign we2_mx = ioctl_ram ? {2{ioctl_wr & sel[2]}} & { ioctl_addr[0], ~ioctl_addr[0] || DW2==8 } : we2;
assign we3_mx = ioctl_ram ? {2{ioctl_wr & sel[3]}} & { ioctl_addr[0], ~ioctl_addr[0] || DW3==8 } : we3;
assign we4_mx = ioctl_ram ? {2{ioctl_wr & sel[4]}} & { ioctl_addr[0], ~ioctl_addr[0] || DW4==8 } : we4;
assign we5_mx = ioctl_ram ? {2{ioctl_wr & sel[5]}} & { ioctl_addr[0], ~ioctl_addr[0] || DW5==8 } : we5;

assign din0_mx = ioctl_ram ? {DW0==16?2:1{ioctl_dout}} : din0;
assign din1_mx = ioctl_ram ? {DW1==16?2:1{ioctl_dout}} : din1;
assign din2_mx = ioctl_ram ? {DW2==16?2:1{ioctl_dout}} : din2;
assign din3_mx = ioctl_ram ? {DW3==16?2:1{ioctl_dout}} : din3;
assign din4_mx = ioctl_ram ? {DW4==16?2:1{ioctl_dout}} : din4;
assign din5_mx = ioctl_ram ? {DW5==16?2:1{ioctl_dout}} : din5;

always @(posedge clk) begin
    sel    <= 0;
    offset <= 0;
    if( ioctl_ram ) begin
        if     ( ioctl_addr < OS1 && AW0!=0) begin sel[0] <= 1; offset <= 0; end
        else if( ioctl_addr < OS2 && AW1!=0) begin sel[1] <= 1; offset <= OS1[23:0]; end
        else if( ioctl_addr < OS3 && AW2!=0) begin sel[2] <= 1; offset <= OS2[23:0]; end
        else if( ioctl_addr < OS4 && AW3!=0) begin sel[3] <= 1; offset <= OS3[23:0]; end
        else if( ioctl_addr < OS5 && AW4!=0) begin sel[4] <= 1; offset <= OS4[23:0]; end
        else if( ioctl_addr < OS6 && AW5!=0) begin sel[5] <= 1; offset <= OS5[23:0]; end
    end
end

endmodule