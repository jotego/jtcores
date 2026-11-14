/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 14-11-2026 */
`timescale 1ns/1ps
module test;
reg [31:0] ir=0, a=0, b=0, ac=0;
wire [31:0] res, ac_nx;
wire res_we, bad;
reg [31:0] edge_value[0:15];
reg [7:0] major[0:15];
reg [3:0] minor[0:15];
integer i, j, k, n, checks=0;

jt960_alu uut(
    .ir     ( ir     ),
    .t1     ( a      ),
    .t2     ( b      ),
    .t3     ( 32'd0  ),
    .ac     ( ac     ),
    .res    ( res    ),
    .res_we ( res_we ),
    .ac_nx  ( ac_nx  ),
    .bad    ( bad    )
);

task check_op(input [7:0] mj, input [3:0] sb,
              input [31:0] src1, src2, flags);
    reg [31:0] expected_res, expected_ac;
    reg expected_we, overflow;
    reg [2:0] cc;
    reg [32:0] wide;
    reg signed [63:0] sa, ss, signed_result;
begin
    ir={mj,13'd0,sb,7'd0}; a=src1; b=src2; ac=flags;
    expected_res=0; expected_ac=flags; expected_we=0;
    sa={{32{src1[31]}},src1}; ss={{32{src2[31]}},src2};
    cc=src1<src2 ? 3'b100 : src1==src2 ? 3'b010 : 3'b001;
    if((mj==8'h5a && sb[0]) || mj==8'h39)
        cc=sa<ss ? 3'b100 : sa==ss ? 3'b010 : 3'b001;
    case(mj)
    8'h59: begin
        expected_we=1;
        expected_res=sb[1] ? src2-src1 : src2+src1;
    end
    8'h5a: begin
        if(sb==4'h2 || sb==4'h3) begin
            if(!flags[2]) expected_ac={flags[31:3],1'b0,cc[2] || cc[1],cc[0]};
        end else begin
            expected_ac={flags[31:3],cc};
            if(sb>=4'h4) begin
                expected_we=1;
                expected_res=sb[1] ? src2-32'd1 : src2+32'd1;
            end
        end
    end
    8'h5b: begin
        expected_we=1;
        if(sb==4'h0) begin
            wide={1'b0,src2}+{1'b0,src1}+{32'd0,flags[1]};
            signed_result=ss+sa+{63'd0,flags[1]};
        end else begin
            wide={1'b0,src2}-{1'b0,src1}-33'd1+{32'd0,flags[1]};
            signed_result=ss-sa-64'sd1+{63'd0,flags[1]};
        end
        expected_res=wide[31:0];
        overflow=signed_result>64'sh7fff_ffff || signed_result < -64'sh8000_0000;
        expected_ac={flags[31:2],sb==0 ? wide[32] : !wide[32],overflow};
        if(sb==4'h2) expected_ac[2]=0;
    end
    8'h31,8'h39: expected_ac={flags[31:3],cc};
    endcase
    #1;
    if(bad || res_we!==expected_we || res!==expected_res || ac_nx!==expected_ac)
        $fatal(1,"ALU %02x.%x a=%08x b=%08x ac=%08x got=%08x/%08x/%b expected=%08x/%08x/%b",
               mj,sb,a,b,ac,res,ac_nx,res_we,expected_res,expected_ac,expected_we);
    checks=checks+1;
end
endtask

initial begin
    edge_value[0]=0; edge_value[1]=1; edge_value[2]=2; edge_value[3]=3;
    edge_value[4]=31; edge_value[5]=32; edge_value[6]=63; edge_value[7]=64;
    edge_value[8]=32'h7fff_fffe; edge_value[9]=32'h7fff_ffff;
    edge_value[10]=32'h8000_0000; edge_value[11]=32'h8000_0001;
    edge_value[12]=32'hffff_fffe; edge_value[13]=32'hffff_ffff;
    edge_value[14]=32'h5555_5555; edge_value[15]=32'haaaa_aaaa;
    for(i=0;i<4;i=i+1) begin major[i]=8'h59; minor[i]=i[3:0]; end
    for(i=0;i<8;i=i+1) begin major[i+4]=8'h5a; minor[i+4]=i[3:0]; end
    major[12]=8'h5b; minor[12]=0; major[13]=8'h5b; minor[13]=2;
    major[14]=8'h31; minor[14]=0; major[15]=8'h39; minor[15]=0;
    for(n=0;n<16;n=n+1) begin
        for(i=0;i<16;i=i+1)
            for(j=0;j<16;j=j+1)
                for(k=0;k<8;k=k+1)
                    check_op(major[n],minor[n],edge_value[i],edge_value[j],32'ha5a5_5a58|k);
        for(i=0;i<4000;i=i+1)
            check_op(major[n],minor[n],$random,$random,$random);
    end
    $display("PASS: %0d ALU arithmetic, carry, overflow and comparison cases",checks);
    $finish;
end
endmodule
