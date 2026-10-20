/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * One right-justified pixel operation. Arithmetic uses the shared CPU ALU.
 */
module jttms10_pixel(
    input [4:0] psize,
    input [4:0] ppop,
    input word_arithmetic,
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
    wire packed_sub;
    reg [15:0] packed_result;
    integer lane;
    genvar bit_index;
    generate for(bit_index=0;bit_index<16;bit_index=bit_index+1) begin: g_boolean
        assign boolean_result[bit_index]=boolean_truth[{s[bit_index],d[bit_index]}];
    end endgenerate
    wire [15:0] masked_result=result_pixel & field_mask & ~dest_pmask;
    assign alu_req=valid && (ppop>=5'd16);
    assign packed_sub=ppop>=5'd18;
    assign visible_source=source_pixel & field_mask &
                          (source_is_register ? 16'hffff : ~source_pmask);
    assign transparent=valid && transparency && (masked_result==16'd0);
    assign write_mask=(valid && !transparent) ? (field_mask & ~dest_pmask) : 16'd0;
    assign write_pixel=(dest_pixel & ~write_mask) | (masked_result & write_mask);

    assign field_mask = word_arithmetic ? 16'hffff :
                        psize==5'd1  ? 16'h0001 :
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
        if(word_arithmetic) begin
            valid=(psize==5'd4 || psize==5'd8 || psize==5'd16) &&
                  ppop>=5'd16 && ppop<=5'd21;
            // A spacer absorbs each lane's carry. Subtraction starts each
            // destination lane at 2**PSIZE+D, so no borrow crosses lanes;
            // its spacer result is the independent D>=S comparison.
            case(psize)
                5'd4: begin
                    alu_a={12'd0,1'b0,s[15:12],1'b0,s[11:8],1'b0,s[7:4],1'b0,s[3:0]};
                    alu_b={12'd0,packed_sub,d[15:12],packed_sub,d[11:8],packed_sub,d[7:4],packed_sub,d[3:0]};
                end
                5'd8: begin
                    alu_a={14'd0,1'b0,s[15:8],1'b0,s[7:0]};
                    alu_b={14'd0,packed_sub,d[15:8],packed_sub,d[7:0]};
                end
                default: begin
                    alu_a={16'd0,s};
                    alu_b={15'd0,packed_sub,d};
                end
            endcase
        end
    end

    // Result selection is separate from ALU operand formation. This is
    // wiring and muxes around the existing shared adder, not another ALU.
    always @* begin
        packed_result=16'd0;
        case(psize)
            5'd4: for(lane=0;lane<4;lane=lane+1) begin
                case(ppop)
                    5'd17: packed_result[4*lane+:4]=alu_result[5*lane+4] ? 4'hf : alu_result[5*lane+:4];
                    5'd19: packed_result[4*lane+:4]=alu_result[5*lane+4] ? alu_result[5*lane+:4] : 4'd0;
                    5'd20: packed_result[4*lane+:4]=alu_result[5*lane+4] ? d[4*lane+:4] : s[4*lane+:4];
                    5'd21: packed_result[4*lane+:4]=alu_result[5*lane+4] ? s[4*lane+:4] : d[4*lane+:4];
                    default: packed_result[4*lane+:4]=alu_result[5*lane+:4];
                endcase
            end
            5'd8: for(lane=0;lane<2;lane=lane+1) begin
                case(ppop)
                    5'd17: packed_result[8*lane+:8]=alu_result[9*lane+8] ? 8'hff : alu_result[9*lane+:8];
                    5'd19: packed_result[8*lane+:8]=alu_result[9*lane+8] ? alu_result[9*lane+:8] : 8'd0;
                    5'd20: packed_result[8*lane+:8]=alu_result[9*lane+8] ? d[8*lane+:8] : s[8*lane+:8];
                    5'd21: packed_result[8*lane+:8]=alu_result[9*lane+8] ? s[8*lane+:8] : d[8*lane+:8];
                    default: packed_result[8*lane+:8]=alu_result[9*lane+:8];
                endcase
            end
            default: case(ppop)
                5'd17: packed_result=alu_result[16] ? 16'hffff : alu_result[15:0];
                5'd19: packed_result=alu_result[16] ? alu_result[15:0] : 16'd0;
                5'd20: packed_result=alu_result[16] ? d : s;
                5'd21: packed_result=alu_result[16] ? s : d;
                default: packed_result=alu_result[15:0];
            endcase
        endcase
    end

    always @* begin
        result_pixel=16'd0;
        if(word_arithmetic) result_pixel=packed_result;
        else if(!ppop[4]) result_pixel=boolean_result;
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
