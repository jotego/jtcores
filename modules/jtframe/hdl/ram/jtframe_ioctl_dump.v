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
// only works with DW=8, 16 or 32

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

    input      [(DW0>>3)-1:0] we0,
    input      [(DW1>>3)-1:0] we1,
    input      [(DW2>>3)-1:0] we2,
    input      [(DW3>>3)-1:0] we3,
    input      [(DW4>>3)-1:0] we4,
    input      [(DW5>>3)-1:0] we5,

    output     [(DW0>>3)-1:0] we0_mx,
    output     [(DW1>>3)-1:0] we1_mx,
    output     [(DW2>>3)-1:0] we2_mx,
    output     [(DW3>>3)-1:0] we3_mx,
    output     [(DW4>>3)-1:0] we4_mx,
    output     [(DW5>>3)-1:0] we5_mx,

    input      [23:0] ioctl_addr,
    input             ioctl_ram,
    input             ioctl_wr,
    input      [ 7:0] ioctl_aux, ioctl_dout,
    output reg [ 7:0] ioctl_din
);

`ifdef SIMULATION
initial begin // assertions
    if( DW0!=8 && DW0!=16 && DW0!=32 ) begin $display("Bad DW0 size in %m"); $finish; end
    if( DW1!=8 && DW1!=16 && DW1!=32 ) begin $display("Bad DW1 size in %m"); $finish; end
    if( DW2!=8 && DW2!=16 && DW2!=32 ) begin $display("Bad DW2 size in %m"); $finish; end
    if( DW3!=8 && DW3!=16 && DW3!=32 ) begin $display("Bad DW3 size in %m"); $finish; end
    if( DW4!=8 && DW4!=16 && DW4!=32 ) begin $display("Bad DW4 size in %m"); $finish; end
    if( DW5!=8 && DW5!=16 && DW5!=32 ) begin $display("Bad DW5 size in %m"); $finish; end
end
`endif

reg  [(DW0>>3)-1:0] we0_io;
reg  [(DW1>>3)-1:0] we1_io;
reg  [(DW2>>3)-1:0] we2_io;
reg  [(DW3>>3)-1:0] we3_io;
reg  [(DW4>>3)-1:0] we4_io;
reg  [(DW5>>3)-1:0] we5_io;
reg  [ 5:0] sel;
reg  [23:0] part_addr, ioctl_adl;
reg  [23:0] offset;
wire [31:0] dout0_full, dout1_full, dout2_full,
            dout3_full, dout4_full, dout5_full;
wire [ 7:0] dout0_byte = byte_sel( dout0_full, ioctl_addr[1:0], DW0 ),
            dout1_byte = byte_sel( dout1_full, ioctl_addr[1:0], DW1 ),
            dout2_byte = byte_sel( dout2_full, ioctl_addr[1:0], DW2 ),
            dout3_byte = byte_sel( dout3_full, ioctl_addr[1:0], DW3 ),
            dout4_byte = byte_sel( dout4_full, ioctl_addr[1:0], DW4 ),
            dout5_byte = byte_sel( dout5_full, ioctl_addr[1:0], DW5 );
wire [ 3:0] we0_next = byte_we( ioctl_addr[1:0], DW0 ),
            we1_next = byte_we( ioctl_addr[1:0], DW1 ),
            we2_next = byte_we( ioctl_addr[1:0], DW2 ),
            we3_next = byte_we( ioctl_addr[1:0], DW3 ),
            we4_next = byte_we( ioctl_addr[1:0], DW4 ),
            we5_next = byte_we( ioctl_addr[1:0], DW5 );

assign dout0_full[DW0-1:0] = dout0;
assign dout1_full[DW1-1:0] = dout1;
assign dout2_full[DW2-1:0] = dout2;
assign dout3_full[DW3-1:0] = dout3;
assign dout4_full[DW4-1:0] = dout4;
assign dout5_full[DW5-1:0] = dout5;

generate
    if( DW0<32 ) begin : gen_dout0_extend
        assign dout0_full[31:DW0] = 0;
    end
    if( DW1<32 ) begin : gen_dout1_extend
        assign dout1_full[31:DW1] = 0;
    end
    if( DW2<32 ) begin : gen_dout2_extend
        assign dout2_full[31:DW2] = 0;
    end
    if( DW3<32 ) begin : gen_dout3_extend
        assign dout3_full[31:DW3] = 0;
    end
    if( DW4<32 ) begin : gen_dout4_extend
        assign dout4_full[31:DW4] = 0;
    end
    if( DW5<32 ) begin : gen_dout5_extend
        assign dout5_full[31:DW5] = 0;
    end
endgenerate

function [7:0] byte_sel;
    input [31:0] data;
    input [ 1:0] byte_addr;
    input integer dw;
begin
    byte_sel = dw==32 && byte_addr==2'd3 ? data[31:24] :
               dw==32 && byte_addr==2'd2 ? data[23:16] :
               dw>=16 && byte_addr[0]    ? data[15: 8] : data[ 7:0];
end
endfunction

function [3:0] byte_we;
    input [ 1:0] byte_addr;
    input integer dw;
begin
    byte_we = dw==32 ? (4'b0001 << byte_addr) :
              dw==16 ? (byte_addr[0] ? 4'b0010 : 4'b0001) : 4'b0001;
end
endfunction

always @(posedge clk) begin
    ioctl_adl <= ioctl_addr;
    part_addr <= ioctl_addr - offset;
end

assign addr0_mx = ioctl_ram ?  ioctl_adl[(AW0!=0?AW0-1:0):(AW0!=0?DW0>>4:0)] : addr0;
assign addr1_mx = ioctl_ram ?  part_addr[(AW1!=0?AW1-1:0):(AW1!=0?DW1>>4:0)] : addr1;
assign addr2_mx = ioctl_ram ?  part_addr[(AW2!=0?AW2-1:0):(AW2!=0?DW2>>4:0)] : addr2;
assign addr3_mx = ioctl_ram ?  part_addr[(AW3!=0?AW3-1:0):(AW3!=0?DW3>>4:0)] : addr3;
assign addr4_mx = ioctl_ram ?  part_addr[(AW4!=0?AW4-1:0):(AW4!=0?DW4>>4:0)] : addr4;
assign addr5_mx = ioctl_ram ?  part_addr[(AW5!=0?AW5-1:0):(AW5!=0?DW5>>4:0)] : addr5;

assign we0_mx   = ioctl_ram ?  we0_io : we0;
assign we1_mx   = ioctl_ram ?  we1_io : we1;
assign we2_mx   = ioctl_ram ?  we2_io : we2;
assign we3_mx   = ioctl_ram ?  we3_io : we3;
assign we4_mx   = ioctl_ram ?  we4_io : we4;
assign we5_mx   = ioctl_ram ?  we5_io : we5;

always @(posedge clk)  begin
    we0_io <= 0;       we1_io <= 0;       we2_io <= 0;
    we3_io <= 0;       we4_io <= 0;       we5_io <= 0;
    ioctl_din <= sel[0] ? dout0_byte :
                 sel[1] ? dout1_byte :
                 sel[2] ? dout2_byte :
                 sel[3] ? dout3_byte :
                 sel[4] ? dout4_byte :
                 sel[5] ? dout5_byte :
                 ioctl_aux;
    if(ioctl_ram && ioctl_wr) begin
        if(sel[0]) we0_io <= we0_next[(DW0>>3)-1:0];
        if(sel[1]) we1_io <= we1_next[(DW1>>3)-1:0];
        if(sel[2]) we2_io <= we2_next[(DW2>>3)-1:0];
        if(sel[3]) we3_io <= we3_next[(DW3>>3)-1:0];
        if(sel[4]) we4_io <= we4_next[(DW4>>3)-1:0];
        if(sel[5]) we5_io <= we5_next[(DW5>>3)-1:0];
    end
end

assign din0_mx = ioctl_ram ? {(DW0>>3){ioctl_dout}} : din0;
assign din1_mx = ioctl_ram ? {(DW1>>3){ioctl_dout}} : din1;
assign din2_mx = ioctl_ram ? {(DW2>>3){ioctl_dout}} : din2;
assign din3_mx = ioctl_ram ? {(DW3>>3){ioctl_dout}} : din3;
assign din4_mx = ioctl_ram ? {(DW4>>3){ioctl_dout}} : din4;
assign din5_mx = ioctl_ram ? {(DW5>>3){ioctl_dout}} : din5;

always @(*) begin
    sel    = 0;
    offset = 0;
    if( ioctl_ram ) begin
        if     ( ioctl_addr < OS1 && AW0!=0) begin sel[0] = 1; offset = 0; end
        else if( ioctl_addr < OS2 && AW1!=0) begin sel[1] = 1; offset = OS1[23:0]; end
        else if( ioctl_addr < OS3 && AW2!=0) begin sel[2] = 1; offset = OS2[23:0]; end
        else if( ioctl_addr < OS4 && AW3!=0) begin sel[3] = 1; offset = OS3[23:0]; end
        else if( ioctl_addr < OS5 && AW4!=0) begin sel[4] = 1; offset = OS4[23:0]; end
        else if( ioctl_addr < OS6 && AW5!=0) begin sel[5] = 1; offset = OS5[23:0]; end
    end
end

endmodule
