/* SPDX-License-Identifier: GPL-3.0-or-later */
// Microcoded TMS34010 execution datapath. Addresses are BIT addresses and
// requests describe 1..32-bit fields. Peripheral/bus integration is separate.
module jttms10 #(
    parameter integer CLKS_PER_STATE=8,
    // Timed word clients retain read data before Q4 completion, allowing
    // the dispatch ROM to decode a branch's following opcode before ACK.
    parameter integer TIMED_PROGRAM=0
)(
`ifdef JTTMS10_REGRESSION
    // Synthesizable observation only; sampled before this clock's writes.
    output            obs_decode, obs_rf_we,
    output     [31:0] obs_decode_pc, obs_rf_data,
    output     [15:0] obs_decode_ir,
    output     [ 5:0] obs_rf_addr,
    output    [169:0] obs_work,
`endif
    input             rst, clk, cen,
    input             irq_req,
    input      [31:0] irq_vector,
    input             nmi_req, nmi_nostack, halt_req, emu_run,
    input      [15:0] psize, convsp, convdp, control, pmask,
    output reg        nmi_clear, emu_ack,
    output reg        wvp_set,
    output            mem_req, mem_we, mem_iaq, mem_program, mem_pixel, mem_post, mem_fast, mem_overlap,
    output     [31:0] mem_addr, mem_wdata,
    output     [5:0]  mem_size,
    input      [31:0] mem_rdata,
    input             mem_ack, mem_cached, mem_slot, mem_busy,
    input      [31:0] mem_next_data,
    input             mem_next_valid,
    input             mem_next_first_valid,
    input      [$clog2(CLKS_PER_STATE)-1:0] mem_phase,
    output reg [31:0] pc, st,
    output reg [15:0] ir,
    output reg        retire, fault
);
    // The shared generated header also contains the sequencer's constants.
    /* verilator lint_off UNUSEDPARAM */
    `include "tms10_param.vh"
    /* verilator lint_on UNUSEDPARAM */
    wire step, vector, fetch, imm, pcinc, ld_ir, ni, ni_word, halt, active;
    wire wr_reg, bsrc, wrsrc, stld, wr_sp;
    wire shiftkinit, shiftrinit, shift_finish;
    wire setf, exgf, btstfinish, lmoinit, lmofinish;
    wire multiinit, multiadvance, ptrwr, listwr;
    wire mulinit, mulstep, mulcorrq, mulcorrm, mulfinish, mulwrhi, mulwrlo;
    wire divinit, divload, divnega, divnegmd, divnegb, divcheck, divstep;
    wire dsjfinish, xy_finish;
    wire gfx_active, gfx_checkpoint, gfx_done, gfx_enter, gfx_resume,
         gfx_take, gfx_clip, gfx_end_pending;
    wire [7:0] gfx_family;
    wire [5:0] gfx_rf_sa, gfx_rf_da, gfx_rf_wa, gfx_bus_size;
    wire gfx_load_a,gfx_load_b,gfx_dst_a,gfx_dst_b,gfx_dst_md,
         gfx_dst_ea,gfx_dst_tmp,gfx_dst_rf,gfx_dst_ir,gfx_mdrf;
    wire gfx_bus_read,gfx_bus_write,gfx_bus_pixel,gfx_bus_sync,gfx_bus_post,gfx_bus_skip;
    wire gfx_pix_source,gfx_pix_visible,gfx_pix_process,gfx_pix_test,gfx_pix_word;
    wire gfx_product,gfx_product_y,gfx_packed_xy,gfx_alu_capture;
    reg fill_word;
    wire gfx_flag_z,gfx_flag_nz,gfx_flag_nvzc,gfx_flag_vclip,
         gfx_flag_vpix,gfx_flag_vclear,gfx_flag_wvp;
    wire [31:0] gfx_a_data,gfx_b_data;
    wire [3:0] gfx_alu_op;
    wire hw_take, reserved_opcode, push_entry, push_active, emu_step;
    wire [3:0] cc_sel;
    wire [3:0] alu_sel;
    wire [4:0] a_sel;
    wire [2:0] pc_sel;
    wire [1:0] b_sel, md_sel, mem_sel, stack_sel, tmp_sel, st_sel;
    wire [2:0] ea_sel;
    wire [31:0] rs_data, rd_data, result;
    wire [15:0] pixel_visible_source;
    wire [15:0] pixel_write_pixel;
    wire n,z,c,v;
    reg condition;
    reg [31:0] md, a, b, ea, tmp, bus_data;
    reg [31:0] vector_latched;
    reg push_high, hw_entry;
    reg [3:0] pix_src_addr;
    reg pix_transparent;
    reg pbx_push, line_hw_push;
    reg shift_zero;
    reg [4:0] mul_count;
    reg div_pairread, div_dvdneg, div_dvsneg, div_lowzero;
    reg div_phase, div_early, div_error;
    reg [4:0] lmo_count;
    reg [14:0] multi_mask;
    wire [15:0] immediate_word;
    wire [4:0] lmo_code;
    reg [3:0] multi_index;
    reg [4:0] multi_steps;
    wire multi_ir = ir[15:5]==11'h04c || ir[15:5]==11'h04d;
    wire multi_load=multi_ir && ir[5];
    wire [15:0] multi_candidate=multiinit ? immediate_word : {multi_mask,1'b0};
    wire [14:0] multi_aligned=multi_candidate[14:0] << lmo_code[3:0];
    wire multi_done=(multiinit && immediate_word==0) || (multiadvance && multi_steps<=1);
    assign ni=ni_word || multi_done;
    wire mul_ir = ir[15:10]==6'b010111;
    wire div_ir = ir[15:10]==6'b010110 || ir[15:10]==6'b011011;
    wire div_mod = ir[15:10]==6'b011011;
    wire div_signed = !ir[9];
    wire div_pair = !div_mod && !ir[0];
    wire div_qneg = div_dvdneg ^ div_dvsneg;
    wire div_range = div_signed &&
        (div_qneg ? md>32'h8000_0000 : md>=32'h8000_0000);
    wire dsjs_ir = ir[15:11]==5'b00111;
    wire dsj_ir = ir[15:7]==9'h01b && ir[6:5]!=2'b11;
    wire dsj_allow = ir[15:5]==11'h06d ? st[29] :
                     ir[15:5]==11'h06e ? !st[29] : 1'b1;
    wire signed [9:0] dsjs_disp = ir[10] ?
        -$signed({1'b0,ir[9:5],4'd0}) : $signed({1'b0,ir[9:5],4'd0});
    wire [31:0] dsj_delta = dsjs_ir ? {{22{dsjs_disp[9]}},dsjs_disp} :
                                      {{12{md[15]}},md[15:0],4'd0};
    wire xy_add = ir[15:9]==7'b1110000;
    wire xy_sub = ir[15:9]==7'b1110001;
    wire xy_op = xy_add || xy_sub;
    wire xy_cmp = ir[15:9]==7'b1110010;
    wire cpw_ir = ir[15:9]==7'b1110011;
    wire cvxyl_ir = ir[15:9]==7'b1110100;
    wire pix_rxy = ir[15:9]==7'b1111000;
    wire pixel_xy_store=pix_rxy && gfx_family==8'd152;
    wire drav_ir = ir[15:9]==7'b1111011;
    wire pixel_draw_store=drav_ir && gfx_family==8'd153;
    wire pixel_xy_address_store=pixel_xy_store || pixel_draw_store;
    wire xy_packed = xy_op || xy_cmp || cpw_ir || (pixel_draw_store && mulfinish);
    wire line_ir = ir==16'hdf1a || ir==16'hdf9a;
    wire pixel_linear_load=ir[15:9]==7'b1111101;
    wire pixel_xy_load=ir[15:9]==7'b1111001;
    reg reti_second;
    wire pixel_xy_copy=ir[15:9]==7'b1111010 && gfx_family==8'd154;
    wire pixel_load=pixel_linear_load || pixel_xy_load;
    wire fill_xy_convert;
    assign fill_xy_convert=ir==16'h0fe0 && gfx_family==8'd155;
    wire convert_ir=cvxyl_ir || pixel_xy_load || pixel_xy_address_store || pixel_xy_copy || fill_xy_convert;
    wire pix_rlin = ir[15:9]==7'b1111100;
    wire pixel_simple=control[14:10]==0 && !control[5] && pmask==0;
    wire pixel_xy_simple=pixel_simple && control[7:6]==0;
    wire line_native=TIMED_PROGRAM!=0 && line_ir && pixel_simple && control[7:6]!=2'd1;
    assign mem_overlap=line_native && gfx_active;
    wire pixel_boolean=!control[14] && control[13:10]!=0 && !control[5] && pmask==0;
    // The selected native microprogram owns the mode until retirement.
    wire pixel_process=pix_rlin && gfx_family==8'd150;
    wire pixel_linear_copy=ir[15:9]==7'b1111110 && gfx_family==8'd151;
    wire pixel_copy=pixel_linear_copy || pixel_xy_copy;
    wire pixel_store=(pix_rlin && (gfx_family==8'd149 || gfx_family==8'd150)) || pixel_copy || pixel_xy_address_store;
    wire array_ir = ir==16'h0f00 || ir==16'h0f20 ||
                    ir==16'h0f40 || ir==16'h0f60 ||
                    ir==16'h0f80 || ir==16'h0fa0 ||
                    ir==16'h0fc0 || ir==16'h0fe0;
    wire array_fill = ir==16'h0fc0 || ir==16'h0fe0;
    wire [31:0] fill_pixels = psize==16'd1 ? 32'd16 :
                              psize==16'd2 ? 32'd8 :
                              psize==16'd4 ? 32'd4 :
                              psize==16'd8 ? 32'd2 : 32'd1;
    wire fill_word_eligible = array_fill && pixel_simple &&
        (!ir[5] || control[7:6]==0) && result[3:0]==0 &&
        (psize==16'd1 || psize==16'd2 || psize==16'd4 ||
         psize==16'd8 || psize==16'd16) && rd_data>=fill_pixels;
    wire array_binary = ir==16'h0f80 || ir==16'h0fa0;
    wire reti_pbx = ir==16'h0940 && tmp[25];
    wire pix_register_source = pix_rxy || pix_rlin || drav_ir || line_ir ||
                               (array_ir && array_fill);
    wire unused_convdp_high = &convdp[15:5];
    wire unused_convsp_high = &convsp[15:5];
    wire unused_control_bits = &{control[15],control[9:8],control[4:0]};
    wire [4:0] btst_index = ir[15:10]==6'b000111 ? ~ir[9:5] : b[4:0];
    wire [5:0] old_field = ir[9] ? st[11:6] : st[5:0];
    // The two encoding families use the same five operation numbers.
    wire [2:0] shift_kind = ir[15:13]==3'b001 ? ir[12:10] : ir[11:9];
    wire shift_right = shift_kind==3'd2 || shift_kind==3'd3;
    wire [4:0] shift_raw = shiftkinit ? ir[9:5] : rs_data[4:0];
    wire [4:0] factor_index=gfx_product_y ? ~convdp[4:0] : convert_ir ? ~((pixel_xy_load || (pixel_xy_copy && !reti_second)) ? convsp[4:0] : convdp[4:0]) : shift_raw;
    wire [31:0] shift_factor=32'd1 << factor_index;
    // A one-hot operand shifts into both product halves. Right encodings
    // already contain 32-count, so both directions share this decoder/DSP.
    wire [31:0] product_a=gfx_product ? gfx_a_data : a;
    wire [31:0] product_b=gfx_product ? (gfx_product_y ? shift_factor : {16'd0,psize}) : tmp;
    (* multstyle = "dsp" *) wire [63:0] mul_product = product_a * product_b;
    wire [31:0] shift_mask=tmp-32'd1;
    wire [31:0] shift_result=shift_zero ? a :
        shift_kind==3'd4 ? mul_product[31:0] | mul_product[63:32] :
        shift_right ? mul_product[63:32] |
            ((shift_kind==3'd2 && a[31]) ? ~shift_mask : 32'd0) : mul_product[31:0];
    wire shift_carry=!shift_zero && (shift_right ? mul_product[31] : mul_product[32]);
    // SLA detects every sign transition, including a return to the old sign:
    // the exact signed product must fit in the retained 32-bit result.
    wire shift_overflow=!shift_zero &&
        ((mul_product[63:32] != (a[31] ? shift_mask : 32'd0)) ||
         (mul_product[31] != a[31]));
    // Hierarchical leading-bit encoder, TI p.12-108. Each mux halves the
    // operand, bounding the path to five levels rather than a serial scan.
    wire [31:0] lmo_input=multi_ir ? {multi_candidate,16'd0} : rs_data;
    wire lmo_z16=lmo_input[31:16]==0;
    wire [15:0] lmo16=lmo_z16 ? lmo_input[15:0] : lmo_input[31:16];
    wire lmo_z8=lmo16[15:8]==0;
    wire [7:0] lmo8=lmo_z8 ? lmo16[7:0] : lmo16[15:8];
    wire lmo_z4=lmo8[7:4]==0;
    wire [3:0] lmo4=lmo_z4 ? lmo8[3:0] : lmo8[7:4];
    wire lmo_z2=lmo4[3:2]==0;
    wire [1:0] lmo2=lmo_z2 ? lmo4[1:0] : lmo4[3:2];
    // The final low bit cannot affect the count once the full zero word
    // has been detected separately.
    wire unused_lmo_low=lmo2[0];
    assign lmo_code=lmo_input==0 ? 5'd0 :
                        {lmo_z16,lmo_z8,lmo_z4,lmo_z2,!lmo2[1]};
    reg completed;
    wire [31:0] read_data = completed ? bus_data : mem_rdata;
    // Fold source-level SUBI/CMPI complement decoding into operand capture.
    // No extra microinstruction or second arithmetic unit is needed.
    wire immediate_short=a_sel==IMMSE_A || a_sel==IMMSEINV_A;
    wire immediate_invert=a_sel==IMMSEINV_A || a_sel==IMMHIINV_A;
    assign immediate_word=imm ? read_data[15:0] : md[15:0];
    wire [31:0] immediate_value=immediate_short ? {{16{immediate_word[15]}},immediate_word} :
                                                         {immediate_word,a[15:0]};
    reg timing_active, immediate_last, load_pending, load_started, load_address_ready;
    reg store_pending,store_started;
    reg branch_pending,branch_taken;
    wire branch_relative=ir[15:12]==4'hc;
    wire branch_short=branch_relative && ir[7:0]!=0 && ir[7:0]!=8'h80;
    wire branch_will_take=(dsj_ir || dsjs_ir) ? dsj_allow && rd_data!=32'd1 :
                          !branch_relative || condition;
    wire branch_shorter=dsjs_ir ? branch_will_take : dsj_ir ? !branch_will_take :
                        branch_relative && (branch_short ? !branch_will_take : branch_will_take);
    wire branch_long_untaken=branch_relative && ir[7:0]==0 && !condition;
    wire [15:0] branch_cut_clocks=(branch_long_untaken ? 16'd2 : 16'd1)*CLKS_PER_STATE[15:0];
    wire [15:0] dsj_tail_clocks=(branch_taken ? 16'd3 : 16'd2)*CLKS_PER_STATE[15:0];
    wire copy_offset_post=ir[15:10]==6'b110100;
    wire copy_absolute_post=(ir & 16'hfde0)==16'hd400;
    wire copy_offset_pair=ir[15:10]==6'b101110 || ir[15:9]==7'b1011110;
    wire copy_absolute_pair=(ir & 16'hfdff)==16'h05c0 || ir==16'h0340;
    wire copy_packet=copy_offset_pair || copy_absolute_pair;
    wire copy_extension=copy_offset_post || copy_absolute_post || copy_packet;
    reg [2:0] copy_operand_left;
    wire copy_post=ir[15:10]==6'b100110;
    wire copy_pre=ir[15:10]==6'b101010;
    wire copy_ir=ir[15:10]==6'b100010 || ir[15:9]==7'b1001110 || copy_post || copy_pre || copy_extension;
    wire call_register=ir[15:5]==11'h049;
    wire call_absolute=ir==16'h0d5f;
    wire call_relative=ir==16'h0d3f;
    wire call_ir=call_register || call_absolute || call_relative;
    wire trap_ir=ir[15:5]==11'h048;
    wire trap_zero=ir==16'h0900;
    wire stack_push=ir==16'h01e0 || call_ir;
    wire store_absolute=(ir & 16'hfde0)==16'h0580 || (ir & 16'hffe0)==16'h05e0;
    wire store_offset=ir[15:10]==6'b101100 || ir[15:9]==7'b1010110;
    wire store_direct=!pixel_xy_copy && !pixel_xy_address_store && !multi_ir && !stack_push && ir[15:10]!=6'b101000 && !store_absolute && !store_offset;
    wire [31:0] store_target=copy_packet ? tmp : rd_data;
    wire [31:0] store_source=pixel_draw_store ? {16'd0,(rs_data[15:0] >> ea[3:0])} : multi_ir ? md : call_ir ? md : stack_push ? st : (copy_ir || pixel_process || pixel_copy) ? md : store_absolute ? rd_data : rs_data;
    localparam integer LOAD_IW=$clog2(11*CLKS_PER_STATE+1);
    localparam integer LOAD_LEAD_I=2*CLKS_PER_STATE;
    localparam integer LOAD_FIRST_LIMIT_I=CLKS_PER_STATE+3;
    localparam [LOAD_IW-1:0] LOAD_LEAD=LOAD_LEAD_I[LOAD_IW-1:0];
    localparam [LOAD_IW-1:0] LOAD_PRE=CLKS_PER_STATE[LOAD_IW-1:0];
    localparam [LOAD_IW-1:0] LOAD_FIRST_LIMIT=LOAD_FIRST_LIMIT_I[LOAD_IW-1:0];
    localparam [LOAD_IW-1:0] LOAD_NEXT_LIMIT=3;
    // FILL L retains its four setup and two transfer-prefix states before
    // the first word. XY retains two more conversion setup states in the
    // same issue counter; both paths preserve that work across CEN pauses.
    localparam integer FILL_LEAD_I=6*CLKS_PER_STATE-1;
    localparam [LOAD_IW-1:0] FILL_LEAD=FILL_LEAD_I[LOAD_IW-1:0];
    localparam integer FILL_XY_LEAD_I=8*CLKS_PER_STATE-1;
    localparam [LOAD_IW-1:0] FILL_XY_LEAD=FILL_XY_LEAD_I[LOAD_IW-1:0];
    localparam integer COPY_FOUR_I=4*CLKS_PER_STATE;
    localparam [LOAD_IW-1:0] COPY_FOUR=COPY_FOUR_I[LOAD_IW-1:0];
    reg [LOAD_IW-1:0] load_issue_left;
    wire copy_first_operand=copy_operand_left==(copy_absolute_pair ? 3'd4 : 3'd2);
    wire [LOAD_IW-1:0] copy_remaining_clocks={{(LOAD_IW-3){1'b0}},copy_operand_left}*LOAD_PRE;
    // A cached prefix can precede the first missing operand. Its bus slot
    // follows that operand's index, while CD restarts after each response.
    wire copy_miss_ready=load_issue_left<=
        ((control[15] && !copy_first_operand) ? LOAD_NEXT_LIMIT-1'b1 :
         copy_remaining_clocks-LOAD_PRE+LOAD_NEXT_LIMIT-1'b1);

    wire [LOAD_IW-1:0] multi_first_lead=(ir[5] ? 2 : control[15] ? 7 : rd_data[3:0]==0 ? 4 : 10)*LOAD_PRE;
    wire early_store=store_pending && load_address_ready && load_issue_left==0 &&
                     (!(copy_ir || pixel_process || pixel_copy) || active) && (!multi_ir || stack_sel==WRITE_STACK);
    wire early_load=load_pending && load_address_ready && load_issue_left==0 &&
                    (!copy_packet || copy_operand_left==0) && (!multi_ir || active || load_started);
    wire load_offset=ir[15:10]==6'b101101 || ir[15:9]==7'b1010111;
    wire stack_pop=ir==16'h01c0;
    wire stack_return=(ir & 16'hffe0)==16'h0960;
    wire stack_irq=ir==16'h0940;
    wire stack_read=stack_pop || stack_return || stack_irq || trap_zero || multi_load;
    wire load_direct=pixel_linear_copy || pixel_process || pixel_linear_load || (stack_read && !multi_ir) || ir[15:13]==3'b100; // Plain/post forms within the timed-load set.
    reg [15:0] time_left, fetch_wait;
    wire [15:0] decode_opcode=read_data[15:0];
    wire decode_native_line=TIMED_PROGRAM!=0 && (decode_opcode==16'hdf1a || decode_opcode==16'hdf9a) && pixel_simple && control[7:6]!=2'd1;
    wire decode_multiply=decode_opcode[15:10]==6'b010111;
    wire decode_shiftk=decode_opcode[15:13]==3'b001 && decode_opcode[12:10]<=3'd4;
    wire decode_shiftr=decode_opcode[15:12]==4'h6 && decode_opcode[11:9]<=3'd4;
    wire decode_shift=decode_shiftk || decode_shiftr;
    wire [2:0] decode_shift_kind=decode_shiftk ? decode_opcode[12:10] : decode_opcode[11:9];
    wire decode_lmo=decode_opcode[15:9]==7'b0110101;
    wire decode_divide=decode_opcode[15:10]==6'b010110 || decode_opcode[15:10]==6'b011011;
    wire decode_mod=decode_opcode[15:10]==6'b011011;
    wire [5:0] decode_div_states=decode_mod ? (decode_opcode[9] ? 6'd35 : 6'd40) :
                                decode_opcode[9] ? 6'd37 : decode_opcode[0] ? 6'd39 : 6'd40;
    // General scalar classes. Unlisted memory and graphics forms retain
    // their old schedule until their event rules are independently covered.
    wire decode_copy_offset_post=decode_opcode[15:10]==6'b110100;
    wire decode_copy_absolute_post=(decode_opcode & 16'hfde0)==16'hd400;
    wire decode_copy_offset_pair=decode_opcode[15:10]==6'b101110 || decode_opcode[15:9]==7'b1011110;
    wire decode_copy_absolute_pair=(decode_opcode & 16'hfdff)==16'h05c0 || decode_opcode==16'h0340;
    wire decode_copy_extension=decode_copy_offset_post || decode_copy_absolute_post ||
                               decode_copy_offset_pair || decode_copy_absolute_pair;
    wire decode_copy_post=decode_opcode[15:10]==6'b100110;
    wire decode_copy_pre=decode_opcode[15:10]==6'b101010;
    wire decode_copy=decode_opcode[15:10]==6'b100010 || decode_opcode[15:9]==7'b1001110 ||
                     decode_copy_post || decode_copy_pre || decode_copy_extension;
    wire decode_call_register=decode_opcode[15:5]==11'h049;
    wire decode_call_absolute=decode_opcode==16'h0d5f;
    wire decode_call_relative=decode_opcode==16'h0d3f;
    wire decode_call=decode_call_register || decode_call_absolute || decode_call_relative;
    wire decode_multi=decode_opcode[15:5]==11'h04c || decode_opcode[15:5]==11'h04d;
    wire decode_trap=decode_opcode[15:5]==11'h048;
    wire decode_stack_push=decode_opcode==16'h01e0;
    wire decode_store_post=decode_opcode[15:10]==6'b100100;
    wire decode_store_pre=decode_stack_push || decode_opcode[15:10]==6'b101000;
    wire decode_store_offset=decode_opcode[15:10]==6'b101100 || decode_opcode[15:9]==7'b1010110;
    wire decode_store_absolute=(decode_opcode & 16'hfde0)==16'h0580 || (decode_opcode & 16'hffe0)==16'h05e0;
    wire decode_store_extension=decode_store_offset || decode_store_absolute;
    wire decode_byte_packet=(decode_opcode & 16'hffe0)==16'h05e0 &&
                            !control[15] && mem_next_valid && mem_next_data[3:0]<=4'd8;
    wire decode_byte_first=(decode_opcode & 16'hffe0)==16'h05e0 &&
                           !control[15] && mem_next_first_valid && !mem_next_valid &&
                           mem_next_data[3:0]<=4'd8;
    wire byte_abs=(ir & 16'hffe0)==16'h05e0 && !control[15];
    wire byte_finish=byte_abs && imm &&
                     (immediate_last ? a[3:0]<=4'd8 : mem_next_valid && read_data[3:0]<=4'd8);
    wire decode_pixel_xy_store=decode_opcode[15:9]==7'b1111000 && pixel_xy_simple;
    wire decode_pixel_draw_store=decode_opcode[15:9]==7'b1111011 && pixel_xy_simple;
    wire decode_pixel_xy_address_store=decode_pixel_xy_store || decode_pixel_draw_store;
    wire decode_fill_xy=decode_opcode==16'h0fe0 && pixel_xy_simple;
    wire decode_pixel_xy_copy=decode_opcode[15:9]==7'b1111010 && pixel_xy_simple;
    wire decode_pixel_copy=decode_opcode[15:9]==7'b1111110 && pixel_simple;
    wire decode_pixel_process=decode_opcode[15:9]==7'b1111100 && pixel_boolean;
    wire decode_pixel_readpost=decode_pixel_process || decode_pixel_copy || decode_pixel_xy_copy;
    wire decode_pixel_store=decode_pixel_xy_copy || decode_pixel_xy_address_store || decode_pixel_copy || (decode_opcode[15:9]==7'b1111100 && (pixel_simple || pixel_boolean));
    wire decode_store=decode_pixel_store || decode_call || decode_store_extension || decode_opcode[15:10]==6'b100000 ||
        decode_opcode[15:9]==7'b1000110 || decode_store_post || decode_store_pre;
    wire decode_load_post=decode_opcode[15:10]==6'b100101;
    wire decode_load_pre=decode_opcode[15:10]==6'b101001;
    wire decode_load_offset=decode_opcode[15:10]==6'b101101 || decode_opcode[15:9]==7'b1010111;
    wire decode_load_absolute=(decode_opcode & 16'hfde0)==16'h05a0 ||
                              (decode_opcode & 16'hffe0)==16'h07e0;
    wire decode_load_extension=decode_load_offset || decode_load_absolute;
    wire decode_pixel_linear_load=decode_opcode[15:9]==7'b1111101;
    wire decode_pixel_xy_load=decode_opcode[15:9]==7'b1111001;
    wire decode_pixel_load=decode_pixel_linear_load || decode_pixel_xy_load;
    wire decode_stack_pop=decode_opcode==16'h01c0;
    wire decode_stack_return=(decode_opcode & 16'hffe0)==16'h0960;
    wire decode_stack_irq=decode_opcode==16'h0940;
    wire decode_stack_read=decode_stack_pop || decode_stack_return || decode_stack_irq || decode_opcode==16'h0900;
    wire decode_load_direct=decode_pixel_linear_load || decode_stack_read || decode_opcode[15:10]==6'b100001 ||
                           decode_opcode[15:9]==7'b1000111 || decode_load_post;
    wire decode_load=decode_pixel_xy_load || decode_load_direct || decode_load_pre || decode_load_extension;
    wire [5:0] decode_load_states=decode_pixel_xy_load ? 6'd6 : decode_pixel_load ? 6'd4 : decode_stack_pop ? 6'd8 : decode_stack_return ? 6'd7 : decode_stack_irq ? 6'd11 : decode_load_pre ? 6'd4 : decode_load_extension ? 6'd5 : 6'd3;
    wire decode_immediate_word=decode_opcode[15:5]==11'h04e ||
        decode_opcode[15:5]==11'h058 || decode_opcode[15:5]==11'h05a ||
        decode_opcode[15:5]==11'h05f;
    wire decode_immediate_long=decode_opcode[15:5]==11'h04f ||
        decode_opcode[15:5]==11'h059 || decode_opcode[15:5]==11'h05b ||
        (decode_opcode[15:7]==9'h017 && decode_opcode[6:5]!=2'b11) ||
        decode_opcode[15:5]==11'h068;
    wire decode_scalar_rr=decode_opcode[15:12]==4'h4 ||
                          decode_opcode[15:11]==5'b01010 ||
                          decode_opcode[15:10]==6'b111011;
    wire decode_constant=decode_opcode[15:12]==4'h1 && decode_opcode[11:10]!=2'b11;
    wire decode_unary=decode_opcode[15:7]==9'b000000111;
    wire decode_extension=decode_opcode[15:10]==6'b000001 && decode_opcode[8:6]==3'b100;
    wire decode_setf=decode_opcode[15:10]==6'b000001 && decode_opcode[8:6]==3'b101;
    wire decode_exgf=decode_opcode[15:10]==6'b110101 && decode_opcode[8:5]==4'b1000;
    wire decode_getpc=decode_opcode[15:5]==11'h00a;
    wire decode_getst=decode_opcode[15:5]==11'h00c;
    wire decode_putst=decode_opcode[15:5]==11'h00d;
    wire decode_rev=decode_opcode[15:5]==11'h001;
    wire decode_carry=decode_opcode==16'h0320 || decode_opcode==16'h0de0;
    wire decode_ie=decode_opcode==16'h0360 || decode_opcode==16'h0d60;
    wire decode_pc_register=decode_opcode[15:5]==11'h009 || decode_opcode[15:5]==11'h00b;
    wire decode_dsjs=decode_opcode[15:11]==5'b00111;
    wire decode_dsj=decode_opcode[15:7]==9'h01b && decode_opcode[6:5]!=2'b11;
    wire decode_relative=decode_opcode[15:12]==4'hc;
    wire decode_relative_short=decode_relative && decode_opcode[7:0]!=0 && decode_opcode[7:0]!=8'h80;
    wire decode_control=decode_pc_register || decode_dsjs || decode_dsj || decode_relative;
    wire decode_btstr=decode_opcode[15:9]==7'b0100101;
    wire decode_xy=decode_opcode[15:9]==7'b1110000 ||
                   decode_opcode[15:9]==7'b1110001 || decode_opcode[15:9]==7'b1110010;
    wire decode_xy_cmp=decode_opcode[15:9]==7'b1110010;
    wire decode_cpw=decode_opcode[15:9]==7'b1110011;
    wire decode_cvxyl=decode_opcode[15:9]==7'b1110100;
    wire decode_emu=decode_opcode==16'h0100;
    wire decode_timed=decode_multi || decode_trap || decode_emu || decode_copy || decode_cpw || decode_cvxyl || decode_xy || decode_control || decode_store || decode_opcode==16'h0300 || decode_scalar_rr ||
                      decode_constant || decode_unary || decode_extension ||
                      decode_setf || decode_exgf || decode_getpc || decode_getst ||
                      decode_putst || decode_rev || decode_carry || decode_ie ||
                      decode_immediate_word || decode_immediate_long || decode_load ||
                      decode_opcode[15:10]==6'b000111 ||
                      (decode_multiply && !st[6]) || decode_shift || decode_lmo || decode_divide;
    wire [5:0] multiply_half=st[10:6]==0 ? 6'd16 : {2'd0,st[10:7]};
    // Start control flow at its longer path. The original flags and primed
    // destination read select its shorter path during the first ROM prime.
    wire [5:0] decode_states=decode_multi ? (decode_opcode[5] ? 6'd3 : 6'd2) : decode_trap ? (rd_data[3:0]==0 ? 6'd16 : 6'd30) : decode_control ?
                            (decode_dsj || decode_dsjs ? 6'd3 : decode_relative && !decode_relative_short ? 6'd4 : 6'd2) :
                            decode_emu ? 6'd6 : decode_copy ? (decode_copy_absolute_pair ? 6'd7 : decode_copy_extension ? 6'd5 : decode_copy_post || decode_copy_pre ? 6'd4 : 6'd3) : decode_store ? (decode_call ? (decode_call_absolute ? 6'd4 : 6'd3) : decode_pixel_store ? (decode_pixel_xy_copy ? 6'd7 : (decode_pixel_readpost || decode_pixel_xy_address_store) ? 6'd4 : 6'd2) : decode_store_extension ? (decode_byte_packet ? 6'd1 : 6'd3) : decode_store_pre ? 6'd2 : 6'd1) : decode_divide ? decode_div_states : decode_load ? decode_load_states : decode_multiply ? 6'd5+multiply_half :
                            (decode_shift && decode_shift_kind==0) ||
                            decode_xy_cmp || decode_ie || decode_putst || decode_immediate_long || decode_cvxyl ||
                            (decode_extension && !decode_opcode[5]) ? 6'd3 :
                            decode_btstr || decode_immediate_word ||
                            (decode_setf && decode_opcode[9]) ? 6'd2 : 6'd1;
    wire [15:0] immediate_tail_clocks=(immediate_last ? 16'd2 : 16'd3)*CLKS_PER_STATE[15:0];
    wire [15:0] decode_clocks={10'd0,decode_states} * CLKS_PER_STATE[15:0];
    // DIV/MOD begin with the normal budget. The operand check removes the
    // omitted iterations on early exit; the completed magnitude identifies
    // TI's special 41-state signed candidate (both DIV destination parities).
    wire [5:0] div_normal_states=div_mod ? (div_signed ? 6'd40 : 6'd35) :
                                  !div_signed ? 6'd37 : div_pair ? 6'd40 : 6'd39;
    wire [5:0] div_early_states=div_mod ? 6'd3 : div_signed ? 6'd7 : 6'd5;
    wire [15:0] div_cut_clocks={10'd0,div_normal_states-div_early_states} * CLKS_PER_STATE[15:0];
    wire [15:0] div_extra_clocks=(div_mod || div_pair ? 16'd1 : 16'd2) * CLKS_PER_STATE[15:0];
    // Four clocks cover the NI boundary, ROM prime, synchronous cache hit,
    // and the fetch/dispatch response latch. Execution finishes early enough
    // for that fetch to overlap its last TI machine state (UG §5.4.3/§5.5).
    localparam [15:0] FETCH_OVERLAP=16'd4;
    localparam integer LINE_SETUP_I=4*CLKS_PER_STATE-1;
    localparam integer LINE_PIXEL_I=5*CLKS_PER_STATE-1;
    localparam [15:0] LINE_SETUP_CLKS=LINE_SETUP_I[15:0];
    localparam [15:0] LINE_PIXEL_CLKS=LINE_PIXEL_I[15:0];
    localparam [31:0] GFX_END_PHASE=CLKS_PER_STATE-32'd4;
    wire field_op = mem_sel!=0 || stack_sel!=0 ||
                    gfx_bus_read || gfx_bus_write;
    wire bus_op = vector || fetch || imm || field_op;
    wire gfx_skip_write = gfx_active && gfx_bus_write &&
                          gfx_bus_pixel && !fill_word && pix_transparent;
    // Fetch uses the response latch so the synchronous dispatch ROM has a
    // full clock to decode the returned opcode before fetch/dispatch commits.
    // The completed graphics state hands off four clocks before the next
    // state boundary, matching the existing cached fetch/dispatch overlap.
    wire operation_ready=line_native && gfx_bus_skip ? time_left==0 :
                         gfx_active && gfx_bus_sync && TIMED_PROGRAM!=0 ?
                         !mem_busy && (!line_native || time_left<=FETCH_OVERLAP) &&
                         (!(gfx_end_pending || line_native) || (line_native && !store_started) || mem_phase==GFX_END_PHASE[$clog2(CLKS_PER_STATE)-1:0]) : multiadvance && multi_steps==1 ? completed : (copy_packet || byte_finish) && imm ? (completed || (mem_ack && (copy_packet || TIMED_PROGRAM!=0 || mem_cached))) : (fetch || imm) ? (completed && fetch_wait==0) ||
                         (fetch && mem_fast && mem_ack) :
                         !bus_op || completed || mem_ack || gfx_skip_write;
    wire ready=operation_ready && (!ni || !timing_active || time_left<=FETCH_OVERLAP);
    // CALLR has one operand state before its posted stack field. Its CD
    // operand must retain that state when a short CEN pause moves the CPU
    // past the original bus boundary; a fast request cannot absorb it.
    // Only the execution phase owns the bus; this prevents a completed
    // microinstruction from being presented again while the ROM is primed.
    assign mem_req = ((early_load && (cen || load_started)) || (early_store && (cen || store_started)) ||
                      (active && bus_op && !(load_pending && (mem_sel==READ_MEM || (multi_load && stack_sel==READ_STACK))) && !(store_pending && (mem_sel==WRITE_MEM || ((stack_push || multi_ir) && stack_sel==WRITE_STACK))))) &&
                     !completed && !rst && !fault && !gfx_skip_write &&
                     !(line_native && gfx_bus_post && (time_left!=0 || mem_phase!=0)) &&
                     !(TIMED_PROGRAM!=0 && array_fill && fill_word && gfx_bus_write &&
                       !store_started && (load_issue_left!=0 || mem_phase!=0)) &&
                     !(multi_ir && imm && load_issue_left>multi_first_lead-LOAD_PRE+LOAD_NEXT_LIMIT) &&
                     !(dsj_ir && imm && load_issue_left>LOAD_NEXT_LIMIT) &&
                     !(call_relative && control[15] && imm && load_issue_left>LOAD_NEXT_LIMIT) &&
                     !((load_pending || store_pending) && imm && !copy_packet && ((!immediate_last && load_issue_left>LOAD_FIRST_LIMIT) ||
                       (immediate_last && !(load_offset || store_offset) && load_issue_left>LOAD_NEXT_LIMIT)));
    // MOVB always uses an 8-bit signed field. Ordinary MOVE selects one of
    // the two independent FS/FE fields; a size encoding of zero means 32.
    wire byte_op = ir[15:10]==6'b100011 || ir[15:10]==6'b101011 ||
                   ir[15:9]==7'b1001110 || ir[15:9]==7'b1011110 ||
                   ir[15:5]==11'h02f || ir[15:5]==11'h03f || ir==16'h0340;
    wire [4:0] fs = mul_ir ? st[10:6] : ir[9] ? st[10:6] : st[4:0];
    wire [5:0] field_size = (pixel_load || pixel_store) ? {1'b0,psize[4:0]} : byte_op ? 6'd8 : fs==0 ? 6'd32 : {1'b0,fs};
    wire field_signed = !pixel_load && !pixel_store && (byte_op || (ir[9] ? st[11] : st[5]));
    wire [31:0] field_mask;
    genvar field_bit;
    generate for (field_bit=0; field_bit<32; field_bit=field_bit+1) begin : g_field_mask
        assign field_mask[field_bit] = field_size > field_bit;
    end endgenerate
    wire [5:0] copy_source_span={2'd0,ea[3:0]}+field_size;
    wire [5:0] copy_dest_span={2'd0,store_target[3:0]}+field_size;
    wire copy_long_finish=copy_ir && copy_source_span>6'd32 && copy_dest_span>6'd32;
    wire [15:0] load_finish_clocks=((pixel_load || pixel_process || pixel_copy) ? 16'd1 : multi_load ? (control[15] ? (rd_data[3:0]==0 ? 16'd3 : 16'd5) : 16'd1) : trap_zero ? (rd_data[3:0]==0 ? 16'd12 : 16'd26) : stack_pop ? 16'd4 : stack_return ? 16'd3 : stack_irq ? 16'd2 : copy_long_finish ? (copy_post ? 16'd4 : 16'd3) : copy_post ? 16'd2 : !copy_ir && field_signed && !byte_op && field_size!=6'd32 ?
                                  16'd2 : 16'd1)*CLKS_PER_STATE[15:0] + (pixel_xy_copy ? CLKS_PER_STATE[15:0] : 16'd0);
    wire [4:0] field_msb = field_size[4:0]-5'd1;
    // Field extension has three mutually exclusive consumers: memory-load
    // EXT_A, register SEXT/ZEXT, and multiply's source-field capture.
    wire [31:0] field_ext_input = mulinit ? rs_data :
                                  a_sel==EXT_A ? (mem_sel==READ_MEM ? read_data : md) : rd_data;
    wire field_ext_signed = mulinit ? !ir[9] :
                            a_sel==EXT_A ? field_signed :
                            a_sel==SEXT_A;
    wire field_ext_fill = field_ext_signed && field_ext_input[field_msb];
    wire [31:0] field_extended = pixel_load ? {16'd0,pixel_visible_source} : (field_ext_input & field_mask) |
                                 ({32{field_ext_fill}} & ~field_mask);
    // The post tag can advertise the next eligible clock before address
    // capture. No field is accepted until mem_req supplies the valid EA.
    assign mem_post=gfx_bus_post || (gfx_active && fill_word && gfx_bus_write) || early_store || (stack_push && store_pending && load_issue_left<=1);
    assign mem_we = early_store ? 1'b1 : early_load ? 1'b0 : gfx_active ? gfx_bus_write :
                    mem_sel==WRITE_MEM || stack_sel==WRITE_STACK;
    assign mem_addr = early_store ? (store_direct && !store_started ? store_target : ea) : early_load ? (load_direct && !load_started ? (trap_zero ? 32'hffffffe0 : (stack_irq || pixel_process) ? rd_data : rs_data) : ea) : field_op ? ea : vector ? 32'hffffffe0 : pc;
    assign mem_size = early_store ? ((stack_push || multi_ir) ? 6'd32 : field_size) : early_load ? (stack_read ? 6'd32 : field_size) : gfx_active ? gfx_bus_size :
                      push_active && stack_sel==WRITE_STACK ? 6'd16 :
                      (stack_sel!=0 || vector) ? 6'd32 :
                      field_op ? field_size : 6'd16;
    assign mem_wdata = early_store ? (store_started ? md : store_source) : gfx_active ? md :
                       push_active && stack_sel==WRITE_STACK ?
                       {16'd0, push_high ? md[31:16] : md[15:0]} :
                       md;
    assign mem_iaq = fetch && !early_load && !early_store;
    // The cache accepts every PC-directed word, including extension words.
    // IAQ remains the separate opcode bus-status signal.
    assign mem_program = (fetch || imm) && !early_load && !early_store;
    // Extended taken jumps stream CD words through the timed port. Cached
    // words retain normal cache handling. Generic/raw memory clients leave
    // TIMED_PROGRAM disabled and need no pre-ACK data-valid guarantee.
    assign mem_fast=TIMED_PROGRAM!=0 && control[15] && branch_relative &&
                    !branch_short && condition && mem_program ||
                    (copy_packet && imm && mem_program && copy_miss_ready) ||
                    (pixel_store && (early_load || early_store)) || (gfx_active && fill_word && gfx_bus_write) || gfx_bus_post;
    // PIXT will assert this for its logical pixel field transaction. CPW
    // and CVXYL are register-only operations and never tag memory cycles.
    assign mem_pixel = (pixel_store && (early_store || early_load)) || (pixel_load && early_load) || (gfx_active && gfx_bus_pixel);

`ifdef JTTMS10_REGRESSION
    wire [11:0] obs_uaddr;
    assign obs_decode    = step && ld_ir;
    assign obs_decode_pc = fetch ? pc : pc-32'd16;
    assign obs_decode_ir = fetch ? read_data[15:0] : md[15:0];
    assign obs_work      = {obs_uaddr,active,a,b,md,tmp,mul_count,
                            multi_mask,multi_index,multi_steps};
`endif

    jttms10_ctrl u_ctrl(
`ifdef JTTMS10_REGRESSION
        .obs_uaddr ( obs_uaddr ),
`endif
        .rst(rst), .clk(clk), .enable(cen), .ready(ready),
        .byte_packet(decode_byte_packet),
        .byte_finish(byte_finish),
        .byte_first(decode_byte_first),
        .md(fetch ? read_data[15:0] : md[15:0]),
        .pixel_simple(pixel_simple), .pixel_boolean(pixel_boolean), .pixel_xy_simple(pixel_xy_simple),
        .multi_steps(multi_steps),
        .multi_load(ir[5]), .multi_done(multi_done),
        .mul_count(mul_count),
        .div_early_cond(a==0 || !c),
        .reti_pbx(reti_pbx),
        .gfx_active(gfx_active), .gfx_done(gfx_done),
        .gfx_checkpoint(gfx_checkpoint),
        .gfx_pbx_ir(rs_data[15:0]),
        .irq_req(irq_req), .nmi_req(nmi_req),
        .nmi_nostack(nmi_nostack), .halt_req(halt_req),
        .emu_run(emu_run), .ie(st[21]), .branch_condition(condition),
        .hw_take(hw_take), .reserved_opcode(reserved_opcode),
        .push_entry(push_entry), .push_active(push_active), .emu_step(emu_step),
        .execute(step), .active(active), .vector(vector), .fetch(fetch), .imm(imm),
        .gfx_enter(gfx_enter), .gfx_resume(gfx_resume),
        .gfx_take(gfx_take), .gfx_family(gfx_family),
        .pcinc(pcinc), .ld_ir(ld_ir), .ni(ni_word), .halt(halt),
        .b_sel(b_sel), .wr_reg(wr_reg), .a_sel(a_sel), .bsrc(bsrc),
        .md_sel(md_sel), .wrsrc(wrsrc), .stld(stld),
        .tmp_sel(tmp_sel), .wr_sp(wr_sp), .stack_sel(stack_sel),
        .st_sel(st_sel),
        .shiftkinit(shiftkinit), .shiftrinit(shiftrinit),
        .shift_finish(shift_finish),
        .setf(setf), .exgf(exgf), .btstfinish(btstfinish),
        .lmoinit(lmoinit), .lmofinish(lmofinish),
        .multiinit(multiinit),
        .multiadvance(multiadvance), .ptrwr(ptrwr), .listwr(listwr),
        .mulinit(mulinit), .mulstep(mulstep),
        .mulcorrq(mulcorrq), .mulcorrm(mulcorrm),
        .mulfinish(mulfinish), .mulwrhi(mulwrhi), .mulwrlo(mulwrlo),
        .divinit(divinit), .divload(divload), .divnega(divnega),
        .divnegmd(divnegmd), .divnegb(divnegb),
        .divcheck(divcheck), .divstep(divstep),
        .dsjfinish(dsjfinish), .xy_finish(xy_finish),
        .alu_sel(alu_sel), .cc_sel(cc_sel), .pc_sel(pc_sel),
        .mem_sel(mem_sel), .ea_sel(ea_sel)
    );
    wire gfx_need_dest=(control[14:10]!=0 || pmask!=0);
    jttms10_gfx u_gfx(
        .clk(clk), .rst(rst), .cen(active), .step(step && gfx_active),
        .enter(gfx_enter), .resume(gfx_resume),
        .interrupt_take(gfx_take), .family(gfx_family), .ir(ir),
        .rf_qs(rs_data), .rf_qd(rd_data),
        .psize(psize), .convsp(convsp), .convdp(convdp),
        .control(control), .last_pixel_addr(ea),
        .alu_n(n), .alu_z(z), .alu_v(v),.alu_result(result),
        .need_dest(gfx_need_dest), .word_fill(fill_word),.native_line(line_native),
        .irq_pending(nmi_req || (irq_req && st[21])), .transparent(pix_transparent),
        .active(gfx_active), .checkpoint(gfx_checkpoint),
        .done(gfx_done), .end_pending(gfx_end_pending),
        .rf_sa(gfx_rf_sa), .rf_da(gfx_rf_da), .rf_wa(gfx_rf_wa),
        .load_a(gfx_load_a), .load_b(gfx_load_b),
        .a_data(gfx_a_data), .b_data(gfx_b_data), .alu_op(gfx_alu_op),
        .dst_a(gfx_dst_a), .dst_b(gfx_dst_b), .dst_md(gfx_dst_md),
        .dst_ea(gfx_dst_ea), .dst_tmp(gfx_dst_tmp), .dst_rf(gfx_dst_rf),
        .dst_ir(gfx_dst_ir),
        .md_to_rf(gfx_mdrf),
        .bus_read(gfx_bus_read), .bus_write(gfx_bus_write),
        .bus_pixel(gfx_bus_pixel), .bus_size(gfx_bus_size), .bus_sync(gfx_bus_sync),.bus_post(gfx_bus_post),.bus_skip(gfx_bus_skip),
        .pix_source(gfx_pix_source), .pix_visible(gfx_pix_visible),
        .pix_process(gfx_pix_process), .pix_test(gfx_pix_test), .pix_word(gfx_pix_word),
        .product(gfx_product), .product_y(gfx_product_y), .packed_xy(gfx_packed_xy),.alu_capture(gfx_alu_capture),
        .flag_z(gfx_flag_z), .flag_nz(gfx_flag_nz),
        .flag_nvzc(gfx_flag_nvzc), .flag_vclip(gfx_flag_vclip),
        .flag_vpix(gfx_flag_vpix), .flag_vclear(gfx_flag_vclear),
        .flag_wvp(gfx_flag_wvp), .clip(gfx_clip)
    );
    wire rf_write_ext;
    assign rf_write_ext=(gfx_active && gfx_rf_wa[5]) || fill_xy_convert;
    wire cross_move = ir[15:10]==6'b010011 && ir[9];
    wire [4:0] dst = {ir[4]^cross_move,ir[3:0]};
    // Stack instructions continuously select SP on the synchronous read
    // port, including the ROM-prime cycle before their first microstep.
    wire stack_ir = ir==16'h01e0 || ir==16'h01c0 || ir==16'h0d5f ||
                    ir==16'h0d3f || ir==16'h0940 ||
                    ir[15:5]==11'h049 || ir[15:5]==11'h04b ||
                    ir[15:5]==11'h048;
    wire call_rs_ir = ir[15:5]==11'h049;
    // Both window limits are nonnegative. Cross-sign comparisons still
    // need the original signed operands when the packed difference wraps.
    wire cpw_low_x=a[15]!=b[15] ? a[15] : !result[15] && result[15:0]!=0;
    wire cpw_low_y=a[31]!=b[31] ? a[31] : !result[31] && result[31:16]!=0;
    wire cpw_high_x=a[15]!=b[15] ? !a[15] : result[15];
    wire cpw_high_y=a[31]!=b[31] ? !a[31] : result[31];
    wire [31:0] cpw_code=md | (cpw_high_x ? 32'h40 : 32'd0) |
                             (cpw_high_y ? 32'h100 : 32'd0);
    jttms10_regs u_regs(
`ifdef JTTMS10_REGRESSION
        .obs_rf_we   ( obs_rf_we   ),
        .obs_rf_addr ( obs_rf_addr ),
        .obs_rf_data ( obs_rf_data ),
`endif
        .clk(clk),
        .rs_ext(gfx_active && gfx_rf_sa[5]),
        .rd_ext(gfx_active && gfx_rf_da[5]),
        .wa_ext(rf_write_ext),
        .rs(gfx_active ? gfx_rf_sa[4:0] :
            fetch && (completed || mem_fast || mem_ack) && decode_fill_xy ? 5'd18 :
            fill_xy_convert ? 5'd18 :
            fetch && (completed || mem_fast || mem_ack) && decode_pixel_xy_address_store ? {decode_opcode[4],decode_opcode[3:0]} :
            pixel_xy_copy && reti_second ? {ir[4],ir[3:0]} :
            pixel_xy_address_store && !load_address_ready ? {ir[4],ir[3:0]} :
            pixel_draw_store && mem_sel==WRITE_MEM ? 5'd25 :
            fetch && (completed || mem_fast || mem_ack) && (decode_stack_read || decode_stack_push) ? 5'd15 :
            fetch && (completed || mem_fast || mem_ack) && decode_call_register ? {decode_opcode[4],decode_opcode[3:0]} :
            fetch && (completed || mem_fast || (mem_ack && decode_cpw)) ? {decode_opcode[4],decode_opcode[8:5]} :
            stack_pop || stack_return ? 5'd15 :
            ir==16'h0940 && tmp[25] ? 5'd26 :
            multi_ir ? {ir[4],multi_index} :
            call_rs_ir ? {ir[4],ir[3:0]} : {ir[4],ir[8:5]}),
        .rd(gfx_active ? gfx_rf_da[4:0] :
            fetch && (completed || mem_fast || mem_ack) && decode_multi ? {decode_opcode[4],decode_opcode[3:0]} :
            fetch && (completed || mem_fast || mem_ack) && (decode_stack_read || decode_stack_push) ? 5'd15 :
            fetch && (completed || mem_fast || mem_ack) && (decode_call || decode_trap) ? 5'd15 :
            fetch && (completed || mem_fast || mem_ack) && decode_cpw ? 5'd21 :
            fetch && (completed || mem_fast) && (decode_cvxyl || decode_pixel_xy_load || decode_pixel_xy_address_store || decode_pixel_xy_copy || decode_fill_xy) ? 5'd20 :
            fetch && (completed || mem_fast) && (decode_copy || decode_store || decode_control || decode_multi) ? {decode_opcode[4],decode_opcode[3:0]} :
            pixel_draw_store && load_address_ready ? {ir[4],ir[3:0]} :
            cpw_ir ? 5'd22 : convert_ir ? 5'd20 :
            stack_ir || push_active ? 5'd15 :
            div_ir && div_pairread ? {ir[4],ir[3:0]+4'd1} :
            {ir[4],ir[3:0]}),
        .wa(gfx_active ? gfx_rf_wa[4:0] :
            fill_xy_convert ? 5'd19 :
            wr_sp ? 5'd15 : ptrwr ? {ir[4],ir[3:0]} :
            listwr ? {ir[4],multi_index} :
            mulwrlo && (div_ir ? div_pair : !ir[0]) ?
                {ir[4],ir[3:0]+4'd1} :
            wrsrc ? {ir[4],ir[8:5]} : dst),
        .we(step && ((gfx_active && (gfx_dst_rf || gfx_mdrf)) ||
                    wr_reg || wrsrc || wr_sp || ptrwr || listwr ||
                    (dsjfinish && dsj_allow) ||
                    ((mulwrhi && (div_ir ? div_pair : !ir[0])) || mulwrlo) &&
                    (!div_ir || (!div_early &&
                      (!div_error || (div_mod && div_signed))))) && !rst),
        .wd(gfx_active ? (gfx_mdrf ? md : result) :
            cpw_ir ? cpw_code :
            shift_finish ? shift_result :
            exgf ? {26'd0,old_field} :
            lmofinish ? {27'd0,lmo_count} :
            listwr ? read_data :
            mulwrhi ? (div_ir ? md : b) :
            mulwrlo ? (div_ir && (div_mod || div_pair) ? b : md) : result),
        .qs(rs_data), .qd(rd_data)
    );
    reg [3:0] alu_op;
    wire [31:0] pixel_alu_a, pixel_alu_b;
    wire [3:0] pixel_alu_op;
    wire pixel_alu_req, pixel_transparent;
    wire unused_pixel_valid;
    wire [15:0] unused_pixel_result, unused_pixel_mask;
    wire gfx_color_lane = drav_ir || line_ir ||
                          (array_ir && (array_fill || array_binary));
    wire [15:0] pixel_source = (pixel_load || pixel_copy) ? read_data[15:0] : gfx_color_lane ?
                               rs_data[15:0] >> ea[3:0] : rs_data[15:0];
    jttms10_pixel u_pixel(
        .psize(psize[4:0]), .ppop(control[14:10]),
        .transparency(control[5]), .pmask(pmask),
        .source_is_register(pix_register_source),
        .src_addr_lo((pixel_load || pixel_copy || array_binary) ? ea[3:0] : pix_src_addr),
        .dst_addr_lo(ea[3:0]),
        .source_pixel(pixel_source),
        .dest_pixel(pixel_process ? read_data[15:0] : gfx_need_dest ? md[15:0] : 16'd0),
        .alu_a(pixel_alu_a), .alu_b(pixel_alu_b),
        .alu_op(pixel_alu_op), .alu_req(pixel_alu_req),
        .alu_result(result), .alu_borrow(c),
        .valid(unused_pixel_valid), .visible_source(pixel_visible_source),
        .result_pixel(unused_pixel_result), .write_mask(unused_pixel_mask),
        .write_pixel(pixel_write_pixel), .transparent(pixel_transparent)
    );
    always @* begin
        alu_op=0;
        if(gfx_active)
            alu_op=gfx_pix_process && pixel_alu_req ?
                   pixel_alu_op : gfx_alu_op;
        else case(alu_sel)
            PASS_ALU: alu_op=0;
            ADD_ALU:  alu_op=1;
            ADC_ALU:  alu_op=2;
            SUB_ALU:  alu_op=3;
            SBC_ALU:  alu_op=4;
            AND_ALU:  alu_op=5;
            ANDN_ALU: alu_op=6;
            OR_ALU:   alu_op=7;
            XOR_ALU:  alu_op=8;
            NOT_ALU:  alu_op=9;
            NEG_ALU:  alu_op=10;
            ABS_ALU:  alu_op=11;
            default:;
        endcase
    end
    wire [31:0] div_trial = {b[30:0],md[31]};
    wire [31:0] alu_a =
        divnegmd ? md : divnegb ? b :
        mulcorrm ? tmp : a;
    wire [31:0] alu_b =
        divstep ? div_trial : divnegb ? 32'd0 : b;
    wire alu_cin = divnegb && !div_phase ? !div_lowzero : st[30];
    wire [31:0] shared_alu_a = gfx_active ?
        (gfx_pix_process && pixel_alu_req ? pixel_alu_a : gfx_product ? mul_product[31:0] : gfx_alu_capture ? gfx_a_data : a) : alu_a;
    wire [31:0] shared_alu_b = gfx_active ?
        (gfx_pix_process && pixel_alu_req ? pixel_alu_b : gfx_alu_capture ? gfx_b_data : b) : alu_b;
    wire shared_alu_packed;
    assign shared_alu_packed=(xy_packed && !gfx_active) || gfx_packed_xy;
    jttms10_alu u_alu(.a(shared_alu_a),.b(shared_alu_b),.op(alu_op),.cin(alu_cin),
        .split16(shared_alu_packed),
        .result(result),.n(n),.z(z),.c(c),.v(v));
    always @* begin
        condition=0;
        case(ir[11:8])
            0: condition=1;
            1: condition=!st[31]&&!st[29];
            2: condition=st[30]||st[29];
            3: condition=!st[30]&&!st[29];
            4: condition=st[31]^st[28];
            5: condition=!(st[31]^st[28]);
            6: condition=(st[31]^st[28])||st[29];
            7: condition=!(st[31]^st[28])&&!st[29];
            8: condition=st[30];
            9: condition=!st[30];
            10:condition=st[29];
            11:condition=!st[29];
            12:condition=st[28];
            13:condition=!st[28];
            14:condition=st[31];
            15:condition=!st[31];
            default:;
        endcase
    end
    // All relative PC updates share one adder. Select only an enabled
    // update so a false conditional branch cannot mask a simultaneous DSJ
    // or ordinary increment; direct PC writes retain their later priority.
    wire pc_dsj_add = dsjfinish && dsj_allow && result!=0;
    wire pc_short_add = pc_sel==REL_PC && condition;
    wire pc_long_add = pc_sel==LONGREL_PC && condition;
    wire pc_tmp_add = pc_sel==TMPREL_PC;
    wire pc_add = pcinc || pc_dsj_add || pc_short_add ||
                  pc_long_add || pc_tmp_add;
    wire [31:0] pc_delta = pcinc && ld_ir && decode_byte_packet ? 32'd48 :
                           pcinc && ld_ir && decode_byte_first ? 32'd32 :
                           pcinc && byte_finish && !immediate_last ? 32'd32 : pc_tmp_add ? {tmp[27:0],4'd0} :
                           pc_long_add ? {{12{md[15]}},md[15:0],4'd0} :
                           pc_short_add ? {{20{ir[7]}},ir[7:0],4'd0} :
                           pc_dsj_add ? dsj_delta : 32'd16;
    wire [31:0] pc_plus = pc + pc_delta;
    // Scheduling covers scalar/immediate, control flow and load/store families
    // with oracle probes. Other memory/graphics forms retain their earlier schedule
    // until their event contracts are independently covered.
    always @(posedge clk) begin
        if(rst) begin
            timing_active<=0;
            branch_pending<=0;branch_taken<=0;
            immediate_last<=0; copy_operand_left<=0;
            store_pending<=0;store_started<=0;
            load_pending<=0; reti_second<=0; load_started<=0; load_address_ready<=0; load_issue_left<=0;
            time_left<=0;
            fetch_wait<=0;
        end else begin
            if(cen) begin
                if(timing_active && time_left!=0) time_left<=time_left-16'd1;
                if(fetch_wait!=0) fetch_wait<=fetch_wait-16'd1;
                if(load_issue_left!=0) load_issue_left<=load_issue_left-1'b1;
            end
            // ACK capture is independent of CEN, like the response data.
            // External fetches (CD or a cache fill) need the additional
            // processing state in UG §5.4.7. Response/dispatch clocks occupy
            // part of that state; cached hits have no external-fetch penalty.
            // Early data requests can ACK while the ROM still holds the
            // preceding extension microinstruction. Only a real program
            // transfer may rebase fetch/extension work.
            if(mem_req && mem_ack && mem_program)
                fetch_wait<=mem_cached ? 16'd0 : CLKS_PER_STATE[15:0]-16'd2;
            if(mem_req && mem_ack && mem_program && mem_fast && branch_relative && (fetch || ir[7:0]==8'h80))
                fetch_wait<=0;
            // A cache-fill penalty must leave the following intrinsic word
            // states intact. CD already supplies a separate processing state
            // for each external word. With the cache enabled, rebase from
            // this fill's ACK: one processing state plus the remaining one
            // or two intrinsic word states, before final writeback/fetch.
            // The cache response bridge has consumed one clock at this ACK.
            if(mem_req && mem_ack && mem_program && imm && !mem_cached && !control[15] && timing_active)
                time_left<=immediate_tail_clocks-16'd2;
            // DSJ's final decrement/test work survives an external offset
            // fetch. TI pp.12-70..74 requires 3/9 taken and 2/8 untaken.
            if(mem_req && mem_ack && mem_program && imm && !mem_cached && timing_active && dsj_ir)
                time_left<=dsj_tail_clocks-16'd2;
            if(mem_req && mem_ack && mem_program && imm && mem_fast && branch_relative && ir[7:0]==0)
                time_left<=16'd2*CLKS_PER_STATE[15:0]+FETCH_OVERLAP-16'd1;
            // Keep the intrinsic address-generation states after an external
            // extension response. Its cache bridge has consumed one clock.
            if((load_pending || store_pending) && imm && mem_req && mem_ack && mem_program && !mem_cached)
                load_issue_left<=(call_ir ? (call_absolute && !immediate_last ? LOAD_LEAD : LOAD_PRE) : load_offset || store_offset || !immediate_last ? LOAD_LEAD : LOAD_PRE)-1'b1;
            // Cache hits can supply packet operands early; external words
            // retain their state grid and the remaining address work.
            if(copy_packet && imm && mem_req && mem_ack && mem_program && !mem_cached)
                load_issue_left<=control[15] ?
                    (copy_operand_left>3'd1 ? LOAD_LEAD : LOAD_PRE)-1'b1 :
                    copy_remaining_clocks-1'b1;
            if(step && imm && copy_packet) copy_operand_left<=copy_operand_left-1'b1;
            if((load_pending || store_pending) && step && ea_sel!=0) load_address_ready<=1;
            if(pixel_xy_copy && step && ea_sel==SUM_EA) reti_second<=1;
            if(early_load && !load_started && cen && mem_req) load_started<=1;
            // Bus waits must not consume the CPU work following a load.
            // The cache/field response bridge has consumed two clocks of
            // that final state at this ACK; sign extension needs one more.
            if(mem_req && mem_ack && early_load && timing_active)
                time_left<=load_finish_clocks-16'd3;
            if(mem_req && mem_ack && trap_ir && !trap_zero && stack_sel==READ_STACK && timing_active)
                time_left<=(rd_data[3:0]==0 ? 16'd1 : 16'd3)*CLKS_PER_STATE[15:0]-16'd3;
            if(step && (mem_sel==READ_MEM || (stack_read && stack_sel==READ_STACK))) begin
                load_pending<=multi_load && multi_steps>1;
                if(multi_load) begin load_started<=0;load_address_ready<=multi_steps>1;load_issue_left<=0;end
                if(copy_ir || pixel_process || pixel_copy) begin store_pending<=1;load_address_ready<=1;end
                if(pixel_xy_copy) load_issue_left<=LOAD_PRE-LOAD_NEXT_LIMIT;
            end
            // The second RETI field uses the updated SP. Retain a complete
            // source-port settling interval before accepting that read.
            if(step && wr_sp && stack_irq && !reti_second) begin
                reti_second<=1; load_pending<=1; load_started<=0;
                load_address_ready<=1; load_issue_left<=1;
            end
            if(mem_req && mem_ack && early_load && copy_long_finish)
                load_issue_left<=LOAD_LEAD-LOAD_NEXT_LIMIT;
            if(early_store && !store_started && cen && mem_req) store_started<=1;
            if(step && (mem_sel==WRITE_MEM || ((stack_push || multi_ir) && stack_sel==WRITE_STACK))) begin
                store_pending<=multi_ir && multi_steps>1;
                if(multi_ir) begin store_started<=0;load_address_ready<=0;load_issue_left<=0;end
            end
            // The last posted field leaves two CPU states from its first
            // allocated bus state; later words remain hidden on a hit.
            if(mem_req && mem_ack && early_store && multi_ir && multi_steps==1)
                time_left<=(mem_slot ? 16'd2 : 16'd3)*CLKS_PER_STATE[15:0]-{{(16-$clog2(CLKS_PER_STATE)){1'b0}},mem_phase}-16'd1;
            if(step && multiinit && immediate_word!=0) begin
                load_pending<=ir[5];store_pending<=!ir[5];
                load_started<=0;store_started<=0;load_address_ready<=0;
            end
            if(mem_req && mem_ack && mem_program && imm && multi_ir && !mem_cached) begin
                load_issue_left<=(ir[5] ? 2 : 4)*CLKS_PER_STATE[LOAD_IW-1:0]-2;
                if(immediate_word==0) time_left<=(ir[5] ? (rd_data[3:0]==0 ? 16'd5 : 16'd7) : 16'd4)*CLKS_PER_STATE[15:0]-16'd2;
            end
            if(TIMED_PROGRAM!=0 && array_fill && !store_started &&
               step && gfx_pix_word && fill_word_eligible && rd_data=={fill_pixels[30:0],1'b0})
                load_issue_left<=load_issue_left+CLKS_PER_STATE[LOAD_IW-1:0]-1'b1;
            if(array_fill && gfx_active && fill_word && gfx_bus_write && mem_req && mem_ack)
                store_started<=1;
            if((gfx_bus_post && mem_req && mem_ack) || (gfx_bus_skip && step)) begin
                time_left<=LINE_PIXEL_CLKS;
                if(gfx_bus_post) store_started<=1;
            end
            if(step && imm) immediate_last<=1;
            if(step && byte_finish) begin
                load_address_ready<=1;
                load_issue_left<=0;
                time_left<=CLKS_PER_STATE[15:0]-16'd2;
            end
            if(step && ni) timing_active<=0;
            if(step && ld_ir) begin
                timing_active<=decode_timed || decode_native_line;
                branch_pending<=decode_control;
                immediate_last<=decode_immediate_word || decode_byte_first;
                copy_operand_left<=decode_copy_absolute_pair ? 3'd4 : decode_copy_offset_pair ? 3'd2 : 3'd0;
                load_pending<=decode_pixel_readpost || decode_load || decode_copy; load_started<=0; reti_second<=0;
                store_pending<=decode_store && !decode_pixel_readpost;store_started<=0;
                load_address_ready<=!decode_pixel_xy_copy && !decode_pixel_xy_address_store && (decode_load_direct || (decode_copy && !decode_copy_pre && !decode_copy_extension) || (decode_store && !decode_call && !decode_store_pre && (!decode_store_extension || decode_byte_packet)));
                load_issue_left<=TIMED_PROGRAM!=0 && decode_opcode==16'h0fc0 ? FILL_LEAD : TIMED_PROGRAM!=0 && decode_fill_xy ? FILL_XY_LEAD : decode_pixel_xy_copy ? LOAD_LEAD+LOAD_PRE : (decode_pixel_xy_load || decode_pixel_xy_address_store) ? LOAD_LEAD+LOAD_PRE : decode_pixel_load || decode_pixel_store ? LOAD_PRE : decode_multi ? ((decode_opcode[5] ? 2 : control[15] ? 7 : rd_data[3:0]==0 ? 4 : 10)*CLKS_PER_STATE[LOAD_IW-1:0]) : decode_call ? (decode_call_relative ? LOAD_PRE : LOAD_LEAD) : decode_stack_push ? (rd_data[3:0]==0 ? LOAD_PRE : {LOAD_IW{1'b0}}) : decode_load_pre || decode_store_pre || decode_copy_pre || decode_dsj ? LOAD_PRE : decode_copy_absolute_pair ? COPY_FOUR : decode_byte_first ? LOAD_PRE : (decode_load_extension || (decode_store_extension && !decode_byte_packet) || decode_copy_extension) ? LOAD_LEAD : {LOAD_IW{1'b0}};
                time_left<=decode_native_line ? LINE_SETUP_CLKS : decode_clocks-16'd1;
            end
            if(cen && branch_pending) begin
                branch_pending<=0;
                branch_taken<=branch_will_take;
                // SPVS002C p14: untaken long JR is two states. The older
                // entry says four; source alternatives stay in the tests.
                if(branch_shorter || branch_long_untaken)
                    time_left<=time_left-branch_cut_clocks-16'd1;
            end
            // MPYU's extra state depends on the selected field's sign bit,
            // which is available once synchronous register reads complete.
            if(step && mulinit && timing_active && mul_ir && ir[9] && field_ext_input[field_msb])
                time_left<=time_left+CLKS_PER_STATE[15:0]-16'd1;
            if(step && divcheck && timing_active && (a==0 || !c))
                time_left<=time_left-div_cut_clocks-16'd1;
            if(step && mulfinish && timing_active && div_ir && !div_early && div_signed && md==32'h8000_0000)
                time_left<=time_left+div_extra_clocks-16'd1;
        end
    end
    always @(posedge clk) begin
        retire <= 0;
        nmi_clear <= 0;
        emu_ack <= 0;
        wvp_set <= 0;
        if(rst) begin
            pc<=0;
            st<=32'h10;
            ir<=0;
            md<=0;
            a<=0;
            b<=0;
            ea<=0;
            tmp<=0;
            shift_zero<=1;
            mul_count<=0;
            div_pairread<=0;
            div_dvdneg<=0;
            div_dvsneg<=0;
            div_lowzero<=0;
            div_phase<=0;
            div_early<=0;
            div_error<=0;
            lmo_count<=0;
            multi_mask<=0;
            multi_index<=0;
            multi_steps<=0;
            fault<=0;
            completed<=0;
            bus_data<=0;
            vector_latched<=0;
            push_high<=0;
            hw_entry<=0;
            pix_src_addr<=0;
            fill_word<=0;
            pix_transparent<=0;
            pbx_push<=0;
            line_hw_push<=0;
        end else begin
            if(gfx_enter || gfx_resume) fill_word<=0;
            if(hw_take) begin
                vector_latched<=nmi_req ? 32'hfffffee0 : irq_vector;
                nmi_clear<=nmi_req;
                hw_entry<=1;
                pbx_push<=gfx_checkpoint && array_ir &&
                          !(nmi_req && nmi_nostack);
                line_hw_push<=gfx_checkpoint && line_ir &&
                             !(nmi_req && nmi_nostack);
            end
            if(push_entry) push_high<=1;
            // Capture the old pointer before postincrement can write Rs.
            // Both XY conversions precede the read; consume its source EA
            // before selecting the saved destination for the posted write.
            if(cen && step && mem_sel==READ_MEM && load_pending && timing_active && pixel_xy_copy) ea<=a;
            if(early_load && !load_started && cen && mem_req && load_direct) ea<=mem_addr;
            if(early_store && !store_started && cen && mem_req) begin
                if(store_direct) ea<=store_target;
                md<=store_source;
            end
            if(mem_req && mem_ack) begin
                completed<=1;
                bus_data<=mem_rdata;
            end
            if(active && cen && halt) fault<=1;
            if(step) begin
                // An early data response can arrive while pointer helpers
                // are paused. Retain it until a bus microinstruction consumes it.
                if(!(load_pending || store_pending) || bus_op) completed<=0;
                if(emu_step) emu_ack<=1;
                if(push_active && stack_sel==WRITE_STACK)
                    push_high<=~push_high;
                if(ld_ir && decode_byte_packet) ea<=mem_next_data;
                if(ld_ir && decode_byte_first) a<={16'd0,mem_next_data[15:0]};
                if(ld_ir && reserved_opcode) begin
                    vector_latched<=32'hfffffc20;
                end
                if(bus_op && !mem_we) md<=read_data;
                case(md_sel)
                    A_MD: md<=a;
                    PC_MD: begin
                        md<=line_hw_push ? pc-32'd16 : pc;
                        line_hw_push<=0;
                    end
                    ST_MD: begin
                        md<=st | (pbx_push ? 32'h0200_0000 : 32'd0);
                        pbx_push<=0;
                    end
                    default:;
                endcase
                case(tmp_sel)
                    EA_TMP: tmp<=ea;
                    A_TMP: tmp<=call_ir && imm ? (call_relative ? {{16{immediate_word[15]}},immediate_word} : immediate_value) : a;
                    MD_TMP: tmp<=md;
                    default:;
                endcase
                if(ld_ir) begin
                    ir<=fetch ? read_data[15:0] : md[15:0];
                    div_pairread<=0;
                    if(fetch && decode_cpw) begin a<=rs_data; b<=rd_data; end
                    if(fetch && decode_stack_push) begin a<=32'd32; b<=rd_data; end
                end
                if(gfx_active && gfx_dst_ir) ir<=result[15:0];
                if(shiftkinit || shiftrinit) begin
                    shift_zero<=shift_raw==0;
                    tmp<=shift_factor;
                end
                if(lmoinit) lmo_count<=lmo_code;
                if(multiinit) begin
                    multi_mask<=multi_aligned[14:0];
                    multi_steps<=multi_candidate==0 ? 5'd0 : multi_aligned[14:0]==0 ? 5'd1 : 5'd2;
                    multi_index<=ir[5] ? 4'd15-lmo_code[3:0] : lmo_code[3:0];
                    // TI p.12-112 includes zero/MIN_INT exceptions.
                    if(!ir[5]) st[31]<=~rd_data[31];
                end
                if(multiadvance) begin
                    multi_mask<=multi_aligned[14:0];
                    multi_steps<=multi_candidate==0 ? 5'd0 : multi_aligned[14:0]==0 ? 5'd1 : 5'd2;
                    multi_index<=multi_index+(ir[5] ? -(lmo_code[3:0]+4'd1) : lmo_code[3:0]+4'd1);
                end
                if(mulinit) begin
                    // Capture both operands before either half of a pair write.
                    if(convert_ir) begin
                        a<={{16{rs_data[31]}},rs_data[31:16]};
                        tmp<=shift_factor;
                        mul_count<=0;
                    end else begin
                        a<=rd_data;
                        b<=0;
                        md<=field_extended;
                        tmp<=field_extended;
                    end
                end
                if(mulstep) begin
                    // One inferred DSP-backed unsigned product, using the
                    // existing architectural product storage and write path.
                    if(convert_ir) begin
                        if(mul_count[0]) a<=md | mul_product[31:0];
                        else md<=mul_product[31:0];
                    end else begin
                        b<=mul_product[63:32];
                        md<=mul_product[31:0];
                    end
                end
                if(mulcorrq && convert_ir) begin
                    a<={16'd0,rs_data[15:0]};
                    tmp<={27'd0,psize[4:0]};
                    mul_count<=5'd1;
                end else if(mulcorrq && !ir[9] && tmp[31]) b<=result;
                if(mulcorrm && !ir[9] && a[31]) b<=result;
                if(divinit) begin
                    // qs and qd are already primed by the fetch/dispatch
                    // cycles. The pair low half is read after this step.
                    a<=rs_data;
                    tmp<=rd_data;
                    div_dvsneg<=rs_data[31];
                    div_dvdneg<=rd_data[31];
                    div_pairread<=div_pair;
                    div_phase<=0;
                    div_early<=0;
                    div_error<=0;
                    mul_count<=0;
                end
                if(divload) begin
                    b<=div_pair ? tmp : 32'd0;
                    md<=div_pair ? rd_data : tmp;
                    div_lowzero<=div_pair ? rd_data==0 : tmp==0;
                end
                if(divnega && div_signed && div_dvsneg) a<=result;
                if(divnegmd && div_signed &&
                   (div_phase ? div_qneg : div_dvdneg)) md<=result;
                if(divnegb && div_signed && div_dvdneg &&
                   (div_phase || div_pair)) b<=result;
                if(divcheck) div_early<=a==0 || !c;
                if(divstep) begin
                    b<=b[31] || !c ? result : div_trial;
                    md<={md[30:0],b[31] || !c};
                    mul_count<=mul_count-5'd1;
                end
                if(xy_finish && cpw_ir) begin
                    if(wr_reg) st[28]<=|cpw_code;
                    else md<=(cpw_low_x ? 32'h20 : 32'd0) | (cpw_low_y ? 32'h80 : 32'd0);
                end else if(xy_finish) begin
                    st[31]<=result[15:0]==0;
                    st[28]<=xy_sub ?
                        (a[15]!=b[15] ? !a[15] && b[15] : result[15]) :
                        result[15];
                    st[29]<=result[31:16]==0;
                    st[30]<=xy_sub ?
                        (a[31]!=b[31] ? !a[31] && b[31] : result[31]) :
                        result[31];
                end
                if(mulfinish) begin
                    if(pixel_draw_store || (pixel_xy_copy && mem_sel!=READ_MEM)) a<=result;
                    else if(pixel_process || pixel_copy) md<={16'd0,pixel_copy ? pixel_visible_source : pixel_write_pixel};
                    else if(div_ir) begin
                        div_phase<=1;
                        div_error<=div_early || div_range;
                        st[28]<=div_early || div_range;
                        if(div_mod) begin
                            // TI MOD examples use remainder, despite the
                            // contradictory "quotient" word in flag prose.
                            if(!div_early) st[29]<=b==0;
                        end else begin
                            st[29]<=!div_early && !div_range && md==0;
                            if(div_signed)
                                st[31]<=!div_early &&
                                    (md==32'h8000_0000 ||
                                     (div_qneg && md!=0));
                        end
                    end else begin
                        if(!ir[9]) st[31]<=ir[0] ? md[31] : b[31];
                        st[29]<=ir[0] ? md==0 : b==0 && md==0;
                    end
                end
                if(pc_add) pc<=pc_plus;
                case(b_sel)
                    REG_B: b<=rd_data;
                    ZERO_B: b<=0;
                    default:;
                endcase
                if(bsrc) b<=rs_data;
                case(a_sel)
                    REG_A: a<=rs_data;
                    K_A: a<=ir[9:5]==0 ? 32'd32 : {27'd0,ir[9:5]};
                    IMMLO_A: a<={16'd0,immediate_word};
                    IMMSE_A, IMMHI_A, IMMSEINV_A, IMMHIINV_A:
                        a<=immediate_value ^ {32{immediate_invert}};
                    RD_A: a<=rd_data;
                    ST_A: a<=st;
                    SIZE_A: a<={26'd0,field_size};
                    EXT_A: a<=field_extended;
                    PC_A: a<=pc;
                    REV_A: a<=32'd8;
                    WORD_A: a<=32'd32;
                    HALF_A: a<=32'd16;
                    ONE_A: a<=32'd1;
                    MOVX_A: a<={rd_data[31:16],rs_data[15:0]};
                    MOVY_A: a<={rs_data[31:16],rd_data[15:0]};
                    RETADJ_A: a<=32'd32+{23'd0,ir[4:0],4'd0};
                    SEXT_A: a<=field_extended;
                    ZEXT_A: a<=field_extended;
                    default:;
                endcase
                case(ea_sel)
                    A_EA: ea<=imm && a_sel==IMMHI_A ? immediate_value : a;
                    B_EA: ea<=b;
                    SUM_EA: ea<=result;
                    SWAP_EA: begin ea<=tmp; tmp<=ea; end
                    TRAP_EA: ea<=32'hffffffe0-{22'd0,ir[4:0],5'd0};
                    HWVECTOR_EA: ea<=vector_latched;
                    default:;
                endcase
                if(byte_finish)
                    ea<=immediate_last ? {read_data[15:0],a[15:0]} :
                                        {mem_next_data[15:0],read_data[15:0]};
                if(multi_load && multiadvance && multi_steps>1) ea<=rd_data;
                case(pc_sel)
                    MD_PC: pc<={md[31:4],4'd0};
                    REG_PC:pc<={rd_data[31:4],4'd0};
                    ABS_PC:if(condition) pc<=imm && a_sel==IMMHI_A ?
                                             {immediate_word,a[15:4],4'd0} : {a[31:4],4'd0};
                    TMP_PC:pc<={tmp[31:4],4'd0};
                    default:;
                endcase
                if(stld) st<=a;
                if(setf) begin
                    if(ir[9]) st[11:6]<={ir[5],ir[4:0]};
                    else st[5:0]<={ir[5],ir[4:0]};
                end
                if(exgf) begin
                    if(ir[9]) st[11:6]<=rd_data[5:0];
                    else st[5:0]<=rd_data[5:0];
                end
                case(st_sel)
                    MD_ST: st<=md;
                    TMP_ST: st<=reti_pbx ?
                        (tmp & ~32'h0200_0000) : tmp;
                    INIT_ST: st<=32'h10;
                    default:;
                endcase
                case(cc_sel)
                    NZV_CC: begin st[31]<=n; st[29]<=z; st[28]<=0; end
                    NVZC_CC:begin st[31]<=n; st[30]<=c; st[29]<=z; st[28]<=v; end
                    // ABS writes |a| but N records the sign of 0-a. With
                    // ABS selected, v identifies the minimum signed value.
                    NZVABS_CC:begin st[31]<=a[31] ? v : !z; st[29]<=z; st[28]<=v; end
                    NZFIELD_CC:begin st[31]<=n; st[29]<=z; end
                    Z_CC:st[29]<=z;
                    C0_CC:st[30]<=0;
                    C1_CC:st[30]<=1;
                    I0_CC:st[21]<=0;
                    I1_CC:st[21]<=1;
                    default:;
                endcase
                if(shift_finish) begin
                    st[30]<=shift_carry;
                    st[29]<=shift_result==0;
                    if(shift_kind==3'd0 || shift_kind==3'd2) st[31]<=shift_result[31];
                    if(shift_kind==3'd0) st[28]<=shift_overflow;
                end
                if(pixel_load && wr_reg) st[28]<=|result;
                if(btstfinish) st[29]<=~a[btst_index];
                if(lmofinish) st[29]<=a==0;
                if(gfx_active) begin
                    if(gfx_load_a) a<=gfx_a_data;
                    if(gfx_load_b) b<=gfx_b_data;
                    if(gfx_dst_a) a<=result;
                    if(gfx_dst_b) b<=result;
                    if(gfx_dst_md) md<=result;
                    if(gfx_dst_ea) ea<=result;
                    if(gfx_dst_tmp) tmp<=result;
                    if(gfx_pix_word) fill_word<=fill_word_eligible;
                    if(gfx_pix_source) pix_src_addr<=ea[3:0];
                    if(gfx_pix_visible) md<={16'd0,pixel_visible_source};
                    if(gfx_pix_process) begin
                        md<={16'd0,fill_word ? rs_data[15:0] : pixel_write_pixel};
                        pix_transparent<=pixel_transparent;
                    end
                    if(gfx_pix_test) pix_transparent<=pixel_transparent;
                    if(gfx_flag_z) st[29]<=z;
                    if(gfx_flag_nz) begin st[31]<=n; st[29]<=z; end
                    if(gfx_flag_nvzc) begin
                        st[31]<=n; st[30]<=c; st[29]<=z; st[28]<=v;
                    end
                    if(gfx_flag_vclip) st[28]<=gfx_clip;
                    if(gfx_flag_vpix) st[28]<=|pixel_visible_source;
                    if(gfx_flag_vclear) st[28]<=0;
                    if(gfx_flag_wvp) wvp_set<=1;
                end
                retire<=(ni || gfx_done) && !hw_entry;
                if(ni) hw_entry<=0;
            end
        end
    end
endmodule
