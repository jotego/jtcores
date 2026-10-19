/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * One right-justified pixel operation. Arithmetic uses the shared CPU ALU.
 */
module jttms10_pixel(
    input [4:0] psize,
    input [4:0] ppop,
    input transparency,
    input [15:0] pmask,
    input source_is_register,
    input [3:0] src_addr_lo, dst_addr_lo,
    input [15:0] source_pixel, dest_pixel,
    output reg [31:0] alu_a, alu_b,
    output reg [3:0] alu_op,
    output alu_req,
    input [31:0] alu_result,
    input alu_borrow,
    output reg valid,
    output [15:0] visible_source,
    output reg [15:0] result_pixel,
    output [15:0] write_mask,
    output [15:0] write_pixel,
    output transparent
);
    localparam [3:0] ALU_ADD=4'd1, ALU_SUB=4'd3;
    wire [15:0] field_mask;
    wire [15:0] source_pmask=(pmask >> src_addr_lo) & field_mask;
    wire [15:0] dest_pmask=(pmask >> dst_addr_lo) & field_mask;
    wire [15:0] s=visible_source;
    wire [15:0] d=dest_pixel & field_mask & ~dest_pmask;
    // TI's Boolean PPOP encoding is the four truth-table bits, reordered:
    // index {S,D}=00,01,10,11 selects PPOP[2],PPOP[3],~PPOP[0],~PPOP[1].
    wire [3:0] boolean_truth={~ppop[1:0],ppop[3:2]};
    wire [15:0] boolean_result;
    genvar bit_index;
    generate for(bit_index=0;bit_index<16;bit_index=bit_index+1) begin: g_boolean
        assign boolean_result[bit_index]=boolean_truth[{s[bit_index],d[bit_index]}];
    end endgenerate
    wire [15:0] masked_result=result_pixel & field_mask & ~dest_pmask;
    assign alu_req=valid && (ppop>=5'd16);
    assign visible_source=source_pixel & field_mask &
                          (source_is_register ? 16'hffff : ~source_pmask);
    assign transparent=valid && transparency && (masked_result==16'd0);
    assign write_mask=(valid && !transparent) ? (field_mask & ~dest_pmask) : 16'd0;
    assign write_pixel=(dest_pixel & ~write_mask) | (masked_result & write_mask);

    assign field_mask = psize==5'd1  ? 16'h0001 :
                        psize==5'd2  ? 16'h0003 :
                        psize==5'd4  ? 16'h000f :
                        psize==5'd8  ? 16'h00ff :
                        psize==5'd16 ? 16'hffff : 16'd0;

    // ALU selection depends only on the operation and masked operands.
    // Keep it separate from result selection, which consumes ALU feedback.
    always @* begin
        valid=(field_mask!=0) &&
              ((ppop<5'd16) || ((ppop<=5'd21) && psize>=5'd4));
        alu_a={16'd0,s};
        alu_b={16'd0,d};
        alu_op=(ppop==5'd16 || ppop==5'd17) ? ALU_ADD :
               ((ppop>=5'd18 && ppop<=5'd21) ? ALU_SUB : 4'd0);
    end

    always @* begin
        result_pixel=16'd0;
        if(!ppop[4]) result_pixel=boolean_result;
        else case (ppop)
            5'd16: result_pixel=alu_result[15:0];
            5'd17: result_pixel=(alu_result & ~{16'd0,field_mask})!=0
                                 ? field_mask : alu_result[15:0];
            5'd18: result_pixel=alu_result[15:0];
            5'd19: result_pixel=alu_borrow ? 16'd0 : alu_result[15:0];
            5'd20: result_pixel=alu_borrow ? s : d;
            5'd21: result_pixel=alu_borrow ? d : s;
            default: result_pixel=16'd0;
        endcase
        result_pixel=result_pixel & field_mask;
    end
endmodule
