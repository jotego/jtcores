/* SPDX-License-Identifier: GPL-3.0-or-later */
// Graphics microsequencer. Pixel/field datapaths remain shared with the CPU.
// The YAML ROM supplies addresses, ALU controls and conditional flow; this
// module contains no per-instruction state machine.
module jttms10_gfx(
    input clk, rst, cen, step,
    input enter, resume, interrupt_take,
    input [7:0] family,
    input [15:0] ir,
    input [31:0] rf_qs, rf_qd,
    input [15:0] psize, convsp, convdp, control,
    input alu_n, alu_z, alu_v,
    input need_dest, word_fill, irq_pending,
    input transparent,
    input [31:0] last_pixel_addr,
    output reg active, checkpoint,
    output done, end_pending,
    output [5:0] rf_sa, rf_da, rf_wa,
    output load_a, load_b,
    output reg [31:0] a_data, b_data,
    output reg [3:0] alu_op,
    output dst_a, dst_b, dst_md, dst_ea, dst_tmp, dst_rf, dst_ir,
    output md_to_rf,
    output bus_read, bus_write, bus_pixel, bus_sync,
    output [5:0] bus_size,
    output pix_source, pix_visible, pix_process, pix_test, pix_word,
    output product, product_y, packed_xy,
    output flag_z, flag_nz, flag_nvzc, flag_vclip,
           flag_vpix, flag_vclear, flag_wvp,
    output reg clip
);
    /* verilator lint_off UNUSEDPARAM */
    `include "tms10_gfx_param.vh"
    /* verilator lint_on UNUSEDPARAM */

    // The generated template declares uaddr/ucode_data and clocks the ROM
    // while cen=0, matching the main sequencer's prime/execute cadence.
    wire sa0,sa1,sa2,sa3,sa4,sa5;
    wire da0,da1,da2,da3,da4,da5;
    wire t4,t5,t6,t7,t8,t9,t10,t11;
    wire [1:0] gas_sel,gbs_sel,gsize_sel,gmath_sel;
    wire [2:0] gam_sel,gbm_sel,gdst_sel,gbus_sel,gpix_sel,
               gflg_sel,gflow_sel,gclip_sel;
    wire [3:0] galu_sel;
    wire [4:0] gcond_sel;
    wire mdrf;
    reg [11:0] uaddr;
    /* verilator lint_off BLKSEQ */
    `include "tms10_gfx.vh"
    /* verilator lint_on BLKSEQ */
    wire [1:0] gas=gas_sel, gbs=gbs_sel, gsize=gsize_sel;
    wire [2:0] gam=gam_sel, gbm=gbm_sel, gdst=gdst_sel,
               gbus=gbus_sel, gpix=gpix_sel, gflg=gflg_sel,
               gflow=gflow_sel, gclip=gclip_sel;
    wire [3:0] galu=galu_sel;
    wire [4:0] gcond=gcond_sel;

    wire [5:0] next_sa={sa5,sa4,sa3,sa2,sa1,sa0};
    wire unused_conv_upper = &{1'b0,convsp[15:5],convdp[15:5]};
    wire unused_pixel_addr_low = &{1'b0,last_pixel_addr[3:0]};
    wire unused_control_nonwindow = &{1'b0,control[15:10],
                                      control[5:0]};
    wire [5:0] next_da={da5,da4,da3,da2,da1,da0};
    wire [11:0] target={t11,t10,t9,t8,t7,t6,t5,t4,4'd0};
    reg [5:0] sa_q, da_q;
    // 60..63 are the only dynamic RF addresses. 32..52 are independent
    // whole-word scratch locations; B0..B14 stay at architectural 16..30.
    function [5:0] physical_addr;
        input [5:0] encoded;
        input [8:0] opcode;
        begin
            case(encoded)
                6'd60: physical_addr={1'b0,opcode[4],opcode[8:5]};
                6'd61: physical_addr={1'b0,opcode[4],opcode[3:0]};
                6'd62: physical_addr={1'b0,opcode[4],opcode[8:5]+4'd1};
                6'd63: physical_addr={1'b0,opcode[4],opcode[3:0]+4'd1};
                default: physical_addr=encoded;
            endcase
        end
    endfunction
    assign rf_sa=physical_addr(sa_q,ir[8:0]);
    assign rf_da=physical_addr(da_q,ir[8:0]);
    assign rf_wa=physical_addr(next_da,ir[8:0]);

    wire [5:0] source_chunk_size = rf_qs>=32'd32 ? 6'd32 :
                                   {1'b0,rf_qs[4:0]};

    // Number of pixels in an aligned physical word. No divider or new ALU.
    wire [31:0] fill_pixels = psize==16'd1 ? 32'd16 :
                              psize==16'd2 ? 32'd8 :
                              psize==16'd4 ? 32'd4 :
                              psize==16'd8 ? 32'd2 : 32'd1;
    wire [31:0] ka = gam==M1_GAM ? 32'd1 :
                     gam==M2_GAM ? {16'd0,psize} :
                     gam==M3_GAM ? 32'd32 :
                     gam==M4_GAM ? {27'd0,convsp[4:0]} :
                     gam==M5_GAM ? {27'd0,convdp[4:0]} :
                     gam==M6_GAM ? {26'd0,source_chunk_size} :
                     gam==M7_GAM ? {16'd0,ir} : 32'd0;
    wire [31:0] kb = gbm==M1_GBM ? 32'd1 :
                     gbm==M2_GBM ? (word_fill ? 32'd16 : {16'd0,psize}) :
                     gbm==M3_GBM ? 32'd32 :
                     gbm==M4_GBM ? {27'd0,convsp[4:0]} :
                     gbm==M5_GBM ? {27'd0,convdp[4:0]} :
                     gbm==M6_GBM ? {26'd0,source_chunk_size} :
                     gbm==M7_GBM ? {16'd0,ir} : 32'd0;
    function [31:0] format_rf;
        input [31:0] raw;
        input [2:0] mode;
        begin
            case(mode)
                3'd1: format_rf={{16{raw[15]}},raw[15:0]};
                3'd2: format_rf={16'd0,raw[15:0]};
                3'd3: format_rf={{16{raw[31]}},raw[31:16]};
                3'd4: format_rf={16'd0,raw[31:16]};
                3'd5: format_rf={27'd0,raw[4:0]};
                3'd6: format_rf={raw[15:0],16'd0};
                3'd7: format_rf={raw[15:0],raw[31:16]};
                default: format_rf=raw;
            endcase
        end
    endfunction
    assign load_a=active && (gas!=0 || gpix==STRIDE_GPIX);
    assign load_b=active && gbs!=0;
    always @* begin
        case(gas)
            QS_GAS: a_data=format_rf(rf_qs,gam);
            QD_GAS: a_data=format_rf(rf_qd,gam);
            K_GAS: a_data=ka;
            default: a_data=32'd0;
        endcase
        if(gpix==STRIDE_GPIX) a_data=word_fill ? fill_pixels : 32'd1;
        case(gbs)
            QS_GBS: b_data=format_rf(rf_qs,gbm);
            QD_GBS: b_data=format_rf(rf_qd,gbm);
            K_GBS: b_data=kb;
            default: b_data=32'd0;
        endcase
    end
    always @* begin
        case(galu)
            ADD_GALU: alu_op=4'd1;
            ADC_GALU: alu_op=4'd2;
            SUB_GALU: alu_op=4'd3;
            SBC_GALU: alu_op=4'd4;
            AND_GALU: alu_op=4'd5;
            ANDN_GALU: alu_op=4'd6;
            OR_GALU:  alu_op=4'd7;
            XOR_GALU: alu_op=4'd8;
            NOT_GALU: alu_op=4'd9;
            NEG_GALU: alu_op=4'd10;
            ABS_GALU: alu_op=4'd11;
            SHL_GALU: alu_op=4'd12;
            SHR_GALU: alu_op=4'd13;
            SAR_GALU: alu_op=4'd14;
            ROL_GALU: alu_op=4'd15;
            default: alu_op=4'd0;
        endcase
    end
    assign dst_a=active && gdst==A_GDST;
    assign dst_b=active && gdst==B_GDST;
    assign dst_md=active && gdst==MD_GDST;
    assign dst_ea=active && gdst==EA_GDST;
    assign dst_tmp=active && gdst==TMP_GDST;
    assign dst_rf=active && gdst==RF_GDST;
    assign dst_ir=active && gdst==IR_GDST;
    assign md_to_rf=active && mdrf;
    assign bus_read=active &&
        (gbus==RD_GBUS || gbus==RDPX_GBUS);
    assign bus_write=active &&
        (gbus==WR_GBUS || gbus==WRPX_GBUS);
    assign bus_sync=active && gbus==SYNC_GBUS;
    assign bus_pixel=active &&
        (gbus==RDPX_GBUS || gbus==WRPX_GBUS);
    assign bus_size=word_fill ? 6'd16 : gsize==WORD_GSIZE ? 6'd32 :
                    gsize==HALF_GSIZE ? 6'd16 :
                    gsize==CHUNK_GSIZE ? source_chunk_size :
                    {1'b0,psize[4:0]};
    assign pix_source=active && gpix==SOURCE_GPIX;
    assign pix_visible=active && gpix==VISIBLE_GPIX;
    assign pix_process=active && gpix==PROCESS_GPIX;
    assign pix_test=active && gpix==TEST_GPIX;
    assign pix_word=active && gpix==WORD_GPIX;
    // All branch targets are 16-word aligned. Reclaiming their four
    // constant-zero low bits keeps these shared arithmetic controls in BRAM.
    assign product=active && (gmath_sel==YPRODUCT_GMATH || gmath_sel==XPRODUCT_GMATH);
    assign product_y=active && gmath_sel==YPRODUCT_GMATH;
    assign packed_xy=active && gmath_sel==PACKED_GMATH;
    assign flag_z=active && gflg==Z_GFLG;
    assign flag_nz=active && gflg==NZ_GFLG;
    assign flag_nvzc=active && gflg==NVZC_GFLG;
    assign flag_vclip=active && gflg==VCLIP_GFLG;
    assign flag_vpix=active && gflg==VPIX_GFLG;
    assign flag_vclear=active && gflg==VCLEAR_GFLG;
    assign flag_wvp=active && gflg==WVP_GFLG;

    wire signed_lt=alu_n ^ alu_v;
    reg condition;
    always @* begin
        case(gcond)
            WORD_GCOND: condition=word_fill;
            SHORTWORD_GCOND: condition=!word_fill || need_dest || control[5] ||
                                       rf_qs[3:0]!=0 || rf_qd<fill_pixels;
            TWOWORD_GCOND: condition=rf_qd=={fill_pixels[30:0],1'b0};
            IRQ_GCOND: condition=irq_pending;
            Z_GCOND: condition=alu_z;
            NZ_GCOND: condition=!alu_z;
            N_GCOND: condition=alu_n;
            NN_GCOND: condition=!alu_n;
            CLIP_GCOND: condition=clip;
            NCLIP_GCOND: condition=!clip;
            NEED_GCOND: condition=need_dest;
            TRANSPARENT_GCOND: condition=transparent;
            W1_GCOND: condition=control[7:6]==2'd1;
            W2_GCOND: condition=control[7:6]==2'd2;
            W3_GCOND: condition=control[7:6]==2'd3;
            LT_GCOND: condition=signed_lt;
            GT_GCOND: condition=!signed_lt && !alu_z;
            FILL_GCOND: condition=ir[8:5]==4'b1110 ||
                                   ir[8:5]==4'b1111;
            BINARY_GCOND: condition=ir[8:5]==4'b1100 ||
                                     ir[8:5]==4'b1101;
            SRCXY_GCOND: condition=ir[8:5]==4'b1010 ||
                                    ir[8:5]==4'b1011;
            DSTXY_GCOND: condition=ir[5];
            PBH_GCOND: condition=control[8] &&
                ir!=16'h0f80 && ir!=16'h0fa0 &&
                ir!=16'h0fc0 && ir!=16'h0fe0;
            PBV_GCOND: condition=control[9] &&
                ir!=16'h0f80 && ir!=16'h0fa0 &&
                ir!=16'h0fc0 && ir!=16'h0fe0;
            WORDBOUNDARY_GCOND:
                condition=rf_qs[31:4]!=last_pixel_addr[31:4];
            LINEDIAG_GCOND:
                condition=!alu_n && (!alu_z || ir[7]);
            default: condition=1'b1;
        endcase
    end
    assign end_pending=active && gflow==END_GFLOW;
    assign done=step && end_pending;
    reg [11:0] ret1,ret2;
    reg [1:0] depth;
    always @(posedge clk) begin
        if(rst) begin
            active<=0;
            checkpoint<=0;
            clip<=0;
            uaddr<=0;
            sa_q<=0;
            da_q<=0;
            ret1<=0;
            ret2<=0;
            depth<=0;
        end else if(enter || resume) begin
            active<=1;
            checkpoint<=0;
            clip<=0;
            depth<=0;
            case(family)
                8'd103: uaddr<=GCPW_SEQA;
                8'd104: uaddr<=GCVXYL_SEQA;
                8'd106: uaddr<=GPIXT_RXY_SEQA;
                8'd107: uaddr<=GPIXT_XYREG_SEQA;
                8'd108: uaddr<=GPIXT_XYXY_SEQA;
                8'd109: uaddr<=GDRAV_SEQA;
                8'd110: uaddr<=GPIXT_RLIN_SEQA;
                8'd111: uaddr<=GPIXT_LINREG_SEQA;
                8'd112: uaddr<=GPIXT_LINLIN_SEQA;
                8'd117: uaddr<=GARRAY_SEQA;
                8'd139: uaddr<=GARRAY_SEQA;
                8'd140: uaddr<=GARRAY_SEQA;
                8'd141: uaddr<=GARRAY_SEQA;
                8'd155: uaddr<=GFILLXYFAST_SEQA;
                8'd142: uaddr<=GARRAY_SEQA;
                8'd143,8'd144,8'd145,8'd146: uaddr<=GARRAY_SEQA;
                8'd131: uaddr<=GLINE_SEQA;
                default: uaddr<=GFXIDLE_SEQA;
            endcase
            if(resume) uaddr<=GARRAYREBASE_SEQA;
        end else if(interrupt_take) begin
            active<=0;
            checkpoint<=0;
        end else if(step && active) begin
            sa_q<=next_sa;
            da_q<=next_da;
            checkpoint<=gflow==CHECK_GFLOW;
            case(gclip)
                CLEAR_GCLIP: clip<=0;
                LT_GCLIP: clip<=clip || signed_lt;
                LE_GCLIP: clip<=clip || signed_lt || alu_z;
                GT_GCLIP: clip<=clip || (!signed_lt && !alu_z);
                GE_GCLIP: clip<=clip || !signed_lt;
                default:;
            endcase
            uaddr<=uaddr+12'd1;
            if(gflow==JUMP_GFLOW && condition) uaddr<=target;
            if(gflow==CALL_GFLOW && condition) begin
                if(depth==0) ret1<=uaddr+12'd1;
                else ret2<=uaddr+12'd1;
                if(depth!=2) depth<=depth+2'd1;
                uaddr<=target;
            end
            if(gflow==RET_GFLOW) begin
                uaddr<=depth==2 ? ret2 : ret1;
                if(depth!=0) depth<=depth-2'd1;
            end
            if(gflow==END_GFLOW) active<=0;
        end
    end
endmodule
