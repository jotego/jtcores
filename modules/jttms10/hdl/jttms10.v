/* SPDX-License-Identifier: GPL-3.0-or-later */
// Microcoded TMS34010 execution datapath. Addresses are BIT addresses and
// requests describe 1..32-bit fields. Peripheral/bus integration is separate.
module jttms10(
    input             rst, clk, cen,
    input             irq_req,
    input      [31:0] irq_vector,
    input             nmi_req, nmi_nostack, halt_req, emu_run,
    input      [15:0] psize, convsp, convdp, control, pmask,
    output reg        nmi_clear, emu_ack,
    output reg        wvp_set,
    output            mem_req, mem_we, mem_iaq, mem_program, mem_pixel,
    output     [31:0] mem_addr, mem_wdata,
    output     [5:0]  mem_size,
    input      [31:0] mem_rdata,
    input             mem_ack,
    output reg [31:0] pc, st,
    output reg [15:0] ir,
    output reg        retire, fault
);
    // The shared generated header also contains the sequencer's constants.
    /* verilator lint_off UNUSEDPARAM */
    `include "tms10_param.vh"
    /* verilator lint_on UNUSEDPARAM */
    wire step, vector, fetch, imm, pcinc, ld_ir, ni, halt;
    wire wr_reg, bsrc, wrsrc, stld, wr_sp;
    wire shiftkinit, shiftrinit, shift_step, shift_finish;
    wire setf, exgf, btstfinish, lmoinit, lmoscan, lmofinish;
    wire multiinit, multiadvance, ptrwr, listwr;
    wire mulinit, mulstep, mulcorrq, mulcorrm, mulfinish, mulwrhi, mulwrlo;
    wire divinit, divload, divnega, divnegmd, divnegb, divcheck, divstep;
    wire dsjfinish, xyx, xyy;
    wire array_init, array_cap, array_srcstep, array_dststep, array_count;
    wire array_srcpre, array_dstpre;
    wire array_win, array_offset_active, array_query_active,
         array_query_first, array_canon_active, array_canon_dst;
    wire array_source_phase, array_wb_src;
    wire array_pitch_src, array_pitch_dst;
    wire array_save_active, array_restore_active;
    wire array_rebase_active;
    wire [1:0] array_rebase_phase;
    wire line_setup_active, line_prep_active, line_loop_active;
    wire line_advance_active, line_write_active;
    wire [3:0] line_phase;
    wire gfx_step, cvloop_active, wincheck_active, pixconv_active;
    wire hw_take, reserved_opcode, push_entry, push_active, emu_step;
    wire [3:0] cc_sel;
    wire [3:0] alu_sel;
    wire [4:0] a_sel;
    wire [2:0] pc_sel;
    wire [1:0] b_sel, md_sel, mem_sel, stack_sel, tmp_sel, st_sel;
    wire [2:0] ea_sel;
    wire [31:0] rs_data, rd_data, result;
    wire [15:0] pixel_visible_source;
    wire n,z,c,v;
    reg [31:0] md, a, b, ea, tmp, bus_data;
    reg [31:0] vector_latched;
    reg push_high, hw_entry;
    reg [2:0] gfx_phase;
    reg [2:0] gfx_rs;
    reg pix_conv_src, pix_clip;
    reg [31:0] pix_src_val, pix_dst_val;
    reg [3:0] pix_src_addr;
    reg [15:0] pix_color;
    reg [15:0] pix_src_pixel, pix_dst_pixel, pix_write_data;
    reg pix_transparent;
    reg [3:0] array_index;
    reg [15:0] array_dx, array_xleft, array_yleft, array_color0;
    wire [31:0] array_wstart = rs_data;
    wire [31:0] array_wend = rd_data;
    // Array endpoints and extents fit signed 18 bits; corner offsets need 19.
    // Preserve 32-bit sign-extended values at every consumer.
    reg signed [17:0] array_xend_q;
    wire signed [31:0] array_xend = {{14{array_xend_q[17]}},array_xend_q};
    reg signed [17:0] array_yend_q;
    wire signed [31:0] array_yend = {{14{array_yend_q[17]}},array_yend_q};
    reg signed [17:0] array_wxend_q;
    wire signed [31:0] array_wxend = {{14{array_wxend_q[17]}},array_wxend_q};
    reg signed [17:0] array_wyend_q;
    wire signed [31:0] array_wyend = {{14{array_wyend_q[17]}},array_wyend_q};
    reg signed [17:0] array_width_q;
    wire signed [31:0] array_width = {{14{array_width_q[17]}},array_width_q};
    reg [31:0] array_height;
    reg signed [18:0] array_xoff_q;
    wire signed [31:0] array_xoff = {{13{array_xoff_q[18]}},array_xoff_q};
    reg signed [18:0] array_yoff_q;
    wire signed [31:0] array_yoff = {{13{array_yoff_q[18]}},array_yoff_q};
    reg [3:0] array_winphase;
    reg array_window_violation_q;
    reg array_offset_convert, array_corner_mode, array_query_mode;
    reg array_canon_linear;
    reg [15:0] array_dyminus1;
    reg array_checkpoint, pbx_push;
    reg line_checkpoint, line_abort, line_hw_push;
    reg [4:0] shift_count;
    reg [4:0] mul_count;
    reg div_pairread, div_dvdneg, div_dvsneg, div_lowzero;
    reg div_phase, div_early, div_error;
    reg shift_c, shift_v;
    reg [4:0] lmo_count;
    reg [15:0] multi_mask;
    reg [3:0] multi_index;
    reg [4:0] multi_steps;
    wire multi_bit = multi_mask[15];
    wire multi_ir = ir[15:5]==11'h04c || ir[15:5]==11'h04d;
    wire mul_ir = ir[15:10]==6'b010111;
    wire div_ir = ir[15:10]==6'b010110 || ir[15:10]==6'b011011;
    wire div_mod = ir[15:10]==6'b011011;
    wire div_signed = !ir[9];
    wire div_pair = !div_mod && !ir[0];
    wire div_qneg = div_dvdneg ^ div_dvsneg;
    wire div_range = div_signed &&
        (div_qneg ? md>32'h8000_0000 : md>=32'h8000_0000);
    wire dsjs_ir = ir[15:11]==5'b00111;
    wire dsj_allow = ir[15:5]==11'h06d ? st[29] :
                     ir[15:5]==11'h06e ? !st[29] : 1'b1;
    wire signed [9:0] dsjs_disp = ir[10] ?
        -$signed({1'b0,ir[9:5],4'd0}) : $signed({1'b0,ir[9:5],4'd0});
    wire [31:0] dsj_delta = dsjs_ir ? {{22{dsjs_disp[9]}},dsjs_disp} :
                                      {{12{md[15]}},md[15:0],4'd0};
    wire xy_add = ir[15:9]==7'b1110000;
    wire xy_sub = ir[15:9]==7'b1110001;
    wire xy_op = xy_add || xy_sub;
    wire cpw_ir = ir[15:9]==7'b1110011;
    wire pix_rxy = ir[15:9]==7'b1111000;
    wire pix_xyreg = ir[15:9]==7'b1111001;
    wire pix_xyxy = ir[15:9]==7'b1111010;
    wire drav_ir = ir[15:9]==7'b1111011;
    wire line_ir = ir==16'hdf1a || ir==16'hdf9a;
    wire pix_rlin = ir[15:9]==7'b1111100;
    wire pix_linreg = ir[15:9]==7'b1111101;
    wire pix_linlin = ir[15:9]==7'b1111110;
    wire array_ir = ir==16'h0f00 || ir==16'h0f20 ||
                    ir==16'h0f40 || ir==16'h0f60 ||
                    ir==16'h0f80 || ir==16'h0fa0 ||
                    ir==16'h0fc0 || ir==16'h0fe0;
    wire array_fill = ir==16'h0fc0 || ir==16'h0fe0;
    wire array_binary = ir==16'h0f80 || ir==16'h0fa0;
    // A binary source field is fetched once per 32 destination pixels.
    // DX-XLEFT is the number consumed in this row, so its low five bits
    // identify the start of each segment without another counter.
    wire array_binary_need_read =
        array_dx[4:0]==array_xleft[4:0];
    wire array_rev_h = !array_fill && !array_binary && control[8];
    wire array_rev_v = !array_fill && !array_binary && control[9];
    wire array_src_xy = ir==16'h0f40 || ir==16'h0f60;
    wire array_dst_xy = ir==16'h0f20 || ir==16'h0f60 ||
                        ir==16'h0fa0 || ir==16'h0fe0;
    wire array_convert = array_offset_convert || array_canon_linear ||
                         (pix_conv_src ? array_src_xy : array_dst_xy);
    wire array_zero = array_dx==0 || array_yleft==0;
    wire array_rowend = array_xleft==16'd1;
    wire array_last = array_rowend && array_yleft==16'd1;
    wire line_diag = !pix_src_val[31] &&
                     (pix_src_val!=0 || ir[7]);
    wire line_empty = array_height==0;
    wire line_last = array_height==0;
    wire reti_pbx = ir==16'h0940 && tmp[25];
    wire array_corner_needed = !array_fill && !array_binary &&
        (control[8] || control[9]) && (array_src_xy || array_dst_xy);
    wire array_canon_needed = array_corner_needed;
    wire array_offset_dest = array_src_xy && !array_dst_xy;
    wire array_window_needed =
        (array_dst_xy && control[7:6]!=0) || array_corner_needed;
    wire array_window_done = array_corner_mode ?
        array_winphase==4'd7 : array_winphase==4'd15;
    wire signed [31:0] array_x0 = {{16{pix_dst_val[15]}},pix_dst_val[15:0]};
    wire signed [31:0] array_y0 = {{16{pix_dst_val[31]}},pix_dst_val[31:16]};
    wire signed [31:0] array_wx0 =
        {{16{array_wstart[15]}},array_wstart[15:0]};
    wire signed [31:0] array_wy0 =
        {{16{array_wstart[31]}},array_wstart[31:16]};
    // Endpoint registers become the clipped bounds after four shared-ALU
    // comparisons. The violation bit captures whether any bound changed.
    wire signed [31:0] array_left = array_xend;
    wire signed [31:0] array_top = array_yend;
    wire signed [31:0] array_right = array_wxend;
    wire signed [31:0] array_bottom = array_wyend;
    wire array_window_overlap =
        $signed(array_width)>0 && $signed(array_height)>0;
    wire array_window_violation = array_window_violation_q;
    wire array_window_query = control[7:6]==2'd1 &&
                              array_window_overlap;
    wire array_window_abort = control[7:6]==2'd1 ||
        (control[7:6]==2'd2 && array_window_violation) ||
        (control[7:6]==2'd3 && !array_window_overlap);
    wire array_corner_next = !array_corner_mode &&
        array_corner_needed && !array_window_abort;
    wire array_offset_needed = !array_fill &&
        (array_xoff!=0 || array_yoff!=0) &&
        (!array_src_xy || !array_dst_xy) &&
        (!array_dst_xy || control[7:6]!=2'd3 ||
         array_window_overlap);
    wire pix_load = pix_xyreg || pix_linreg;
    wire pix_field = pix_rxy || pix_xyreg || pix_xyxy || drav_ir ||
                     line_ir ||
                     pix_rlin || pix_linreg || pix_linlin || array_ir;
    wire pix_register_source = pix_rxy || pix_rlin || drav_ir || line_ir ||
                               (array_ir && array_fill);
    wire pixel_need_dest = !pix_clip &&
                           (control[14:10]!=0 || pmask!=0);
    // W1 never draws, and W2/W3 abort an out-of-window PIXT before its
    // source access. The final WINCHECK step sees the completed clip bits.
    wire pixel_abort = (pix_rxy || pix_xyxy) &&
                       (control[7:6]==2'd1 ||
                        (control[7:6]!=0 && |md[8:5]));
    wire pix_skip_write = pix_field && mem_sel==WRITE_MEM &&
                          (pix_clip || pix_transparent);
    wire [4:0] pixel_shift = psize==16'd16 ? 5'd4 :
                             psize==16'd8  ? 5'd3 :
                             psize==16'd4  ? 5'd2 :
                             psize==16'd2  ? 5'd1 : 5'd0;
    // The architectural register is 16 bits; conversion encodes its shift
    // solely in the low five bits.
    wire unused_convdp_high = &convdp[15:5];
    wire unused_convsp_high = &convsp[15:5];
    wire unused_control_bits = &{control[15],control[9:8],control[4:0]};
    wire lmo_more = !a[31] && a!=0 && lmo_count!=5'd31;
    wire [4:0] btst_index = ir[15:10]==6'b000111 ? ~ir[9:5] : b[4:0];
    wire [5:0] old_field = ir[9] ? st[11:6] : st[5:0];
    // The two encoding families use the same five operation numbers.
    wire [2:0] shift_kind = ir[15:13]==3'b001 ? ir[12:10] : ir[11:9];
    wire shift_right = shift_kind==3'd2 || shift_kind==3'd3;
    wire [4:0] shift_raw = shiftkinit ? ir[9:5] : rs_data[4:0];
    reg completed;
    wire field_op = mem_sel!=0 || stack_sel!=0;
    wire bus_op = vector || fetch || imm || field_op;
    wire ready = !bus_op || completed || mem_ack || pix_skip_write;
    wire [31:0] read_data = completed ? bus_data : mem_rdata;
    // Only the execution phase owns the bus; this prevents a completed
    // microinstruction from being presented again while the ROM is primed.
    wire active;
    assign mem_req = active && bus_op && !completed && !rst && !fault &&
                     !pix_skip_write;
    // MOVB always uses an 8-bit signed field. Ordinary MOVE selects one of
    // the two independent FS/FE fields; a size encoding of zero means 32.
    wire byte_op = ir[15:10]==6'b100011 || ir[15:10]==6'b101011 ||
                   ir[15:9]==7'b1001110 || ir[15:9]==7'b1011110 ||
                   ir[15:5]==11'h02f || ir[15:5]==11'h03f || ir==16'h0340;
    wire [4:0] fs = mul_ir ? st[10:6] : ir[9] ? st[10:6] : st[4:0];
    wire [5:0] field_size = byte_op ? 6'd8 : fs==0 ? 6'd32 : {1'b0,fs};
    wire field_signed = byte_op || (ir[9] ? st[11] : st[5]);
    wire [31:0] field_mask;
    genvar field_bit;
    generate for (field_bit=0; field_bit<32; field_bit=field_bit+1) begin : g_field_mask
        assign field_mask[field_bit] = field_size > field_bit;
    end endgenerate
    wire [4:0] field_msb = field_size[4:0]-5'd1;
    // Field extension has three mutually exclusive consumers: memory-load
    // EXT_A, register SEXT/ZEXT, and multiply's source-field capture.
    wire [31:0] field_ext_input = mulinit ? rs_data :
                                  a_sel==EXT_A ? md : a;
    wire field_ext_signed = mulinit ? !ir[9] :
                            a_sel==EXT_A ? field_signed :
                            a_sel==SEXT_A;
    wire field_ext_fill = field_ext_signed && field_ext_input[field_msb];
    wire [31:0] field_extended = (field_ext_input & field_mask) |
                                 ({32{field_ext_fill}} & ~field_mask);
    assign mem_we = mem_sel==WRITE_MEM || stack_sel==WRITE_STACK;
    assign mem_addr = field_op ? ea : vector ? 32'hffffffe0 : pc;
    assign mem_size = push_active && stack_sel==WRITE_STACK ? 6'd16 :
                      (stack_sel!=0 || vector) ? 6'd32 :
                      array_binary && array_source_phase &&
                      mem_sel==READ_MEM ?
                          (array_xleft>=16'd32 ? 6'd32 :
                           {1'b0,array_xleft[4:0]}) :
                      pix_field && field_op ? {1'b0,psize[4:0]} :
                      field_op ? field_size : 6'd16;
    assign mem_wdata = push_active && stack_sel==WRITE_STACK ?
                       {16'd0, push_high ? md[31:16] : md[15:0]} :
                       pix_field && mem_sel==WRITE_MEM ?
                       {16'd0,pix_write_data} : md;
    assign mem_iaq = fetch;
    // The cache accepts every PC-directed word, including extension words.
    // IAQ remains the separate opcode bus-status signal.
    assign mem_program = fetch || imm;
    // PIXT will assert this for its logical pixel field transaction. CPW
    // and CVXYL are register-only operations and never tag memory cycles.
    assign mem_pixel = pix_field && field_op;

    jttms10_ctrl u_ctrl(
        .rst(rst), .clk(clk), .enable(cen), .ready(ready), .md(md[15:0]),
        .shift_count(shift_count), .lmo_more(lmo_more),
        .multi_bit(multi_bit), .multi_steps(multi_steps),
        .multi_load(ir[5]),
        .mul_count(mul_count),
        .div_early_cond(a==0 || !c),
        .pixel_need_dest(pixel_need_dest),
        .pixel_abort(pixel_abort),
        .array_active(array_ir), .array_fill(array_fill),
        .array_binary(array_binary),
        .array_binary_need_read(array_binary_need_read),
        .array_convert(array_convert), .array_zero(array_zero),
        .array_last(array_last), .array_index(array_index),
        .array_checkpoint(array_checkpoint), .reti_pbx(reti_pbx),
        .line_ir(line_ir), .line_checkpoint(line_checkpoint),
        .line_empty(line_empty), .line_last(line_last),
        .line_abort(line_abort),
        .array_window_needed(array_window_needed),
        .array_window_done(array_window_done),
        .array_window_abort(array_window_abort),
        .array_window_query(array_window_query),
        .array_offset_needed(array_offset_needed),
        .array_corner_next(array_corner_next),
        .array_query_mode(array_query_mode),
        .array_canon_needed(array_canon_needed),
        .irq_req(irq_req), .nmi_req(nmi_req),
        .nmi_nostack(nmi_nostack), .halt_req(halt_req),
        .emu_run(emu_run), .ie(st[21]),
        .hw_take(hw_take), .reserved_opcode(reserved_opcode),
        .push_entry(push_entry), .push_active(push_active), .emu_step(emu_step),
        .execute(step), .active(active), .vector(vector), .fetch(fetch), .imm(imm),
        .pcinc(pcinc), .ld_ir(ld_ir), .ni(ni), .halt(halt),
        .b_sel(b_sel), .wr_reg(wr_reg), .a_sel(a_sel), .bsrc(bsrc),
        .md_sel(md_sel), .wrsrc(wrsrc), .stld(stld),
        .tmp_sel(tmp_sel), .wr_sp(wr_sp), .stack_sel(stack_sel),
        .st_sel(st_sel),
        .shiftkinit(shiftkinit), .shiftrinit(shiftrinit),
        .shift_step(shift_step), .shift_finish(shift_finish),
        .setf(setf), .exgf(exgf), .btstfinish(btstfinish),
        .lmoinit(lmoinit), .lmoscan(lmoscan), .lmofinish(lmofinish),
        .multiinit(multiinit),
        .multiadvance(multiadvance), .ptrwr(ptrwr), .listwr(listwr),
        .mulinit(mulinit), .mulstep(mulstep),
        .mulcorrq(mulcorrq), .mulcorrm(mulcorrm),
        .mulfinish(mulfinish), .mulwrhi(mulwrhi), .mulwrlo(mulwrlo),
        .divinit(divinit), .divload(divload), .divnega(divnega),
        .divnegmd(divnegmd), .divnegb(divnegb),
        .divcheck(divcheck), .divstep(divstep),
        .dsjfinish(dsjfinish), .xyx(xyx), .xyy(xyy),
        .array_init(array_init), .array_cap(array_cap),
        .array_srcstep(array_srcstep), .array_dststep(array_dststep),
        .array_count(array_count),
        .array_srcpre(array_srcpre), .array_dstpre(array_dstpre),
        .array_source_phase(array_source_phase),
        .array_wb_src(array_wb_src),
        .array_pitch_src(array_pitch_src),
        .array_pitch_dst(array_pitch_dst),
        .array_save_active(array_save_active),
        .array_restore_active(array_restore_active),
        .array_rebase_active(array_rebase_active),
        .array_rebase_phase(array_rebase_phase),
        .line_setup_active(line_setup_active),
        .line_prep_active(line_prep_active),
        .line_loop_active(line_loop_active),
        .line_advance_active(line_advance_active),
        .line_write_active(line_write_active),
        .line_phase(line_phase),
        .array_offset_active(array_offset_active),
        .array_query_active(array_query_active),
        .array_query_first(array_query_first),
        .array_canon_active(array_canon_active),
        .array_canon_dst(array_canon_dst), .array_win(array_win),
        .gfx_step(gfx_step), .cvloop_active(cvloop_active),
        .wincheck_active(wincheck_active), .pixconv_active(pixconv_active),
        .alu_sel(alu_sel), .cc_sel(cc_sel), .pc_sel(pc_sel),
        .mem_sel(mem_sel), .ea_sel(ea_sel)
    );
    wire cross_move = ir[15:10]==6'b010011 && ir[9];
    wire [4:0] dst = {ir[4]^cross_move,ir[3:0]};
    // Stack instructions continuously select SP on the synchronous read
    // port, including the ROM-prime cycle before their first microstep.
    wire stack_ir = ir==16'h01e0 || ir==16'h01c0 || ir==16'h0d5f ||
                    ir==16'h0d3f || ir==16'h0940 ||
                    ir[15:5]==11'h049 || ir[15:5]==11'h04b ||
                    ir[15:5]==11'h048;
    wire call_rs_ir = ir[15:5]==11'h049;
    reg [4:0] array_ctx_rs, array_ctx_wa;
    reg [4:0] line_setup_rs;
    reg [31:0] array_ctx_wd;
    always @* begin
        case(array_index)
            4'd0: line_setup_rs=5'd16; // B0 decision
            4'd1: line_setup_rs=5'd18; // B2 XY pointer
            4'd2: line_setup_rs=5'd23; // B7 b:a
            4'd3: line_setup_rs=5'd25; // B9 COLOR1
            4'd4: line_setup_rs=5'd26; // B10 count
            4'd5: line_setup_rs=5'd27; // B11 diagonal increment
            default: line_setup_rs=5'd28; // B12 lateral increment
        endcase
        case(array_index)
            4'd0: array_ctx_rs=5'd16;  // B0
            4'd1: array_ctx_rs=5'd17;  // B1
            4'd2: array_ctx_rs=5'd18;  // B2
            4'd3: array_ctx_rs=5'd19;  // B3
            4'd4: array_ctx_rs=5'd24;  // B8
            4'd5: array_ctx_rs=5'd25;  // B9
            4'd6: array_ctx_rs=5'd26;  // B10
            4'd7: array_ctx_rs=5'd27;  // B11
            4'd8: array_ctx_rs=5'd28;  // B12
            4'd9: array_ctx_rs=5'd29;  // B13
            default: array_ctx_rs=5'd30; // B14
        endcase
        case(array_index)
            4'd0: begin array_ctx_wa=5'd16; array_ctx_wd=pix_src_val; end
            4'd1: begin array_ctx_wa=5'd18; array_ctx_wd=pix_dst_val; end
            4'd2: begin array_ctx_wa=5'd26; array_ctx_wd={array_dx,ir}; end
            4'd3: begin array_ctx_wa=5'd27;
                        array_ctx_wd={array_yleft,array_xleft}; end
            4'd4: begin array_ctx_wa=5'd28;
                        array_ctx_wd=array_binary ? tmp : rs_data; end
            4'd5: begin array_ctx_wa=5'd29; array_ctx_wd=rs_data; end
            default: begin array_ctx_wa=5'd30;
                           array_ctx_wd={array_height[15:0],
                                         array_dyminus1}; end
        endcase
    end
    // Row bases live in the unused upper half of the mirrored RF RAM.
    // Both RF reads are primed on the clock before each microstep executes.
    wire scratch_src_cap = array_cap && array_index==4'd0;
    wire scratch_dst_cap = array_cap && array_index==4'd2;
    wire scratch_offset_dst = a_sel==SAVESRC_A &&
                              array_offset_active && array_offset_dest;
    wire scratch_save_src = a_sel==SAVESRC_A && !scratch_offset_dst &&
        array_ir && (!array_canon_active || array_src_xy ||
                     array_canon_linear);
    wire scratch_save_dst = a_sel==SAVEDST_A && array_ir &&
        (!array_canon_active || array_dst_xy || array_canon_linear);
    wire scratch_rebase_src = array_rebase_active && array_win &&
                              array_rebase_phase==2'd1 && !array_fill;
    wire scratch_rebase_dst = array_rebase_active && array_win &&
                              array_rebase_phase==2'd2;
    wire scratch_step_src = array_srcstep && !array_fill && array_rowend;
    wire scratch_step_dst = array_dststep && array_rowend &&
                             !(array_fill && array_last);
    wire scratch_src_write = scratch_src_cap || scratch_save_src ||
                             scratch_rebase_src || scratch_step_src;
    wire scratch_dst_write = scratch_dst_cap || scratch_offset_dst ||
        scratch_save_dst || scratch_rebase_dst || scratch_step_dst;
    wire scratch_write = scratch_src_write || scratch_dst_write;
    wire [31:0] scratch_wdata = array_cap ? rs_data :
        ((scratch_save_src && !array_offset_active &&
          !array_canon_linear) ||
         (scratch_save_dst && !array_canon_linear)) ? a : result;
    // WSTART/WEND occupy upper mirrored-RF words 34/35. They are read
    // together throughout window/canonical phases; context-save primes the
    // source port one step before writing each architectural PBX word.
    wire window_ctx_read = array_ir &&
        ((array_win && !line_prep_active && !line_advance_active &&
          !array_rebase_active) || array_canon_active ||
         (array_count && array_last && array_canon_needed));
    wire scratch_save_read = array_save_active &&
        (array_index==4'd3 || array_index==4'd4);
    wire window_plain_step = array_win && !line_prep_active &&
        !line_advance_active && !array_rebase_active &&
        !array_canon_active;
    wire scratch_ws_write =
        (array_cap && !line_setup_active && !array_restore_active &&
         array_index==4'd5) ||
        (array_restore_active && array_cap && array_index==4'd8 &&
         !array_binary) ||
        (window_plain_step && !array_corner_mode &&
         array_winphase==4'd14 && array_corner_needed &&
         !array_window_abort) ||
        (window_plain_step && array_corner_mode &&
         array_winphase==4'd0 && control[7:6]==2'd0);
    wire scratch_we_write =
        (array_cap && !line_setup_active && !array_restore_active &&
         array_index==4'd6) ||
        (array_restore_active && array_cap && array_index==4'd9) ||
        (window_plain_step && !array_corner_mode &&
         array_winphase==4'd15 && array_corner_needed &&
         !array_window_abort) ||
        (window_plain_step && array_corner_mode &&
         array_winphase==4'd1 && control[7:6]==2'd0);
    wire scratch_wstart_wend_write = scratch_ws_write || scratch_we_write;
    wire scratch_any_write = scratch_write || scratch_wstart_wend_write;

    wire [4:0] scratch_wa = scratch_ws_write ? 5'd2 :
        scratch_we_write ? 5'd3 : scratch_dst_write ? 5'd1 : 5'd0;
    wire [31:0] scratch_any_wdata = array_cap ? rs_data :
        scratch_ws_write ? pix_src_val :
        scratch_we_write ?
            ((!array_corner_mode && control[7:6]==2'd3) ?
              {array_top[15:0],array_left[15:0]} : pix_dst_val) :
        scratch_wdata;
    // Prime the synchronous RF port while the pixel write completes; LINE
    // phases 0/1 then consume B11/B12 directly without pitch flip-flops.
    wire line_pitch_read =
        (line_loop_active && mem_sel==WRITE_MEM) ||
        (line_advance_active && line_phase<=4'd1);
    jttms10_regs u_regs(
        .clk(clk), .rs_ext(window_ctx_read || scratch_save_read),
        .rd_ext(window_ctx_read || array_pitch_src || array_pitch_dst),
        .wa_ext(scratch_any_write),
        .rs(window_ctx_read ? 5'd2 :
            scratch_save_read ? (array_index==4'd3 ? 5'd2 : 5'd3) :
            line_pitch_read ? (line_diag ? 5'd27 : 5'd28) :
            line_setup_active ? line_setup_rs :
            array_restore_active ? array_ctx_rs :
            array_pitch_src ? 5'd17 :
            array_pitch_dst ? 5'd19 :
                       gfx_rs==3'd1 ? 5'd21 :
                       gfx_rs==3'd2 ? 5'd22 :
                       gfx_rs==3'd3 ? 5'd20 :
                       gfx_rs==3'd4 ? 5'd25 :
                       array_ir ? {1'b1,array_index} :
                       multi_ir ? {ir[4],multi_index} :
                         call_rs_ir ? {ir[4],ir[3:0]} : {ir[4],ir[8:5]}),
        .rd(window_ctx_read ? 5'd3 :
            array_pitch_src ? 5'd0 :
            array_pitch_dst ? 5'd1 :
            stack_ir || push_active ? 5'd15 :
            div_ir && div_pairread ? {ir[4],ir[3:0]+4'd1} :
            {ir[4],ir[3:0]}),
        .wa(line_write_active ?
                (line_phase==4'd0 ? 5'd16 :
                 line_phase==4'd1 ? 5'd18 : 5'd26) :
            scratch_any_write ? scratch_wa :
            array_save_active ? array_ctx_wa :
            wr_sp ? 5'd15 : ptrwr ? {ir[4],ir[3:0]} :
            array_query_active && listwr ?
                (array_query_first ? 5'd18 : 5'd23) :
            array_ir && listwr ? (array_wb_src ? 5'd16 : 5'd18) :
            listwr ? {ir[4],multi_index} :
            mulwrlo && (div_ir ? div_pair : !ir[0]) ?
                {ir[4],ir[3:0]+4'd1} :
            wrsrc ? {ir[4],ir[8:5]} : dst),
        .we(step && (scratch_any_write || wr_reg || wrsrc || wr_sp || ptrwr ||
                     (listwr && (array_save_active ||
                                 !(array_ir && array_fill &&
                                  array_wb_src && !array_query_active))) ||
                     (dsjfinish && dsj_allow) ||
                     ((mulwrhi && (div_ir ? div_pair : !ir[0])) || mulwrlo) &&
                     (!div_ir || (!div_early &&
                       (!div_error || (div_mod && div_signed))))) && !rst),
        .wd(line_write_active ?
                (line_phase==4'd0 ? pix_src_val :
                 line_phase==4'd1 ? pix_dst_val : array_height) :
            scratch_any_write ? scratch_any_wdata :
            array_save_active ? array_ctx_wd :
            pix_load && a_sel==LOAD_A && wr_reg ?
                {16'd0,pixel_visible_source} :
            drav_ir && wr_reg ? md :
            cpw_ir && wr_reg ? md :
            exgf ? {26'd0,old_field} :
            lmofinish ? {27'd0,lmo_count} :
            array_query_active && listwr ?
                (array_query_first ?
                 {array_top[15:0],array_left[15:0]} :
                 {array_height[15:0],array_width[15:0]}) :
            array_ir && listwr ?
                (array_wb_src ? pix_src_val : pix_dst_val) :
            listwr ? md :
            xy_op && wr_reg ? md :
            mulwrhi ? (div_ir ? md : b) :
            mulwrlo ? (div_ir && (div_mod || div_pair) ? b : md) : result),
        .qs(rs_data), .qd(rd_data)
    );
    reg [3:0] alu_op;
    wire [31:0] pixel_alu_a, pixel_alu_b;
    wire [3:0] pixel_alu_op;
    wire pixel_alu_req, pixel_transparent;
    wire [15:0] pixel_write_pixel;
    wire unused_pixel_valid;
    wire [15:0] unused_pixel_result, unused_pixel_mask;
    wire [15:0] array_color = array_binary && !pix_src_pixel[0] ?
                               array_color0 : pix_color;
    wire [11:0] array_chunks_read =
        {1'b0,array_width[15:5]}+{11'd0,(|array_width[4:0])};
    wire [31:0] array_rebase_src_bits = array_binary ?
        {15'd0,array_chunks_read,5'd0} :
        psize==16'd16 ? {12'd0,array_width[15:0],4'd0} :
        psize==16'd8  ? {13'd0,array_width[15:0],3'd0} :
        psize==16'd4  ? {14'd0,array_width[15:0],2'd0} :
        psize==16'd2  ? {15'd0,array_width[15:0],1'd0} :
                        {16'd0,array_width[15:0]};
    wire [31:0] array_rebase_dst_bits =
        psize==16'd16 ? {12'd0,array_width[15:0],4'd0} :
        psize==16'd8  ? {13'd0,array_width[15:0],3'd0} :
        psize==16'd4  ? {14'd0,array_width[15:0],2'd0} :
        psize==16'd2  ? {15'd0,array_width[15:0],1'd0} :
                        {16'd0,array_width[15:0]};
    wire [15:0] pixel_source = drav_ir || line_ir ||
                               array_fill || array_binary ?
        ((array_ir ? array_color : pix_color) >> ea[3:0]) : pix_src_pixel;
    jttms10_pixel u_pixel(
        .psize(psize[4:0]), .ppop(control[14:10]),
        .transparency(control[5]), .pmask(pmask),
        .source_is_register(pix_register_source),
        .src_addr_lo(array_binary ? ea[3:0] : pix_src_addr),
        .dst_addr_lo(ea[3:0]),
        .source_pixel(pixel_source), .dest_pixel(pix_dst_pixel),
        .alu_a(pixel_alu_a), .alu_b(pixel_alu_b),
        .alu_op(pixel_alu_op), .alu_req(pixel_alu_req),
        .alu_result(result), .alu_borrow(c),
        .valid(unused_pixel_valid), .visible_source(pixel_visible_source),
        .result_pixel(unused_pixel_result), .write_mask(unused_pixel_mask),
        .write_pixel(pixel_write_pixel), .transparent(pixel_transparent)
    );
    always @* begin
        alu_op=0;
        if(line_prep_active && array_win)
            alu_op=line_phase==0 ? 1 : 3;
        else if(line_advance_active && array_win)
            alu_op=line_phase==4'd3 ? 3 : 1;
        else if(array_rebase_active && array_win)
            alu_op=array_rebase_phase==0 || !array_rev_h ? 3 : 1;
        else if((array_win &&
            (array_corner_mode ? array_winphase==4'd2 :
             (array_winphase>=4'd4 && array_winphase<=4'd11))) ||
           array_count || (array_rev_h &&
           (array_srcpre || array_dstpre)) ||
           (array_rev_v && array_rowend &&
           (array_srcstep || array_dststep))) alu_op=3;
        else if(array_win || array_srcpre || array_dstpre ||
                array_srcstep || array_dststep) alu_op=1;
        else if(a_sel==PROCESS_A && pixel_alu_req) alu_op=pixel_alu_op;
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
            SHIFT_ALU: begin
                if(cvloop_active) alu_op=12;
                else case(shift_kind)
                    3'd0,3'd1: alu_op=12;
                    3'd2:      alu_op=14;
                    3'd3:      alu_op=13;
                    3'd4:      alu_op=15;
                    default:;
                endcase
            end
            LMO_ALU: alu_op=12;
            default:;
        endcase
    end
    wire [31:0] div_trial = {b[30:0],md[31]};
    wire cpw_compare = wincheck_active && gfx_step &&
                       gfx_phase>=3'd2 && gfx_phase<=3'd5;
    wire [31:0] cpw_source_x = {{16{a[15]}},a[15:0]};
    wire [31:0] cpw_source_y = {{16{a[31]}},a[31:16]};
    wire [31:0] cpw_start_x = {{16{tmp[15]}},tmp[15:0]};
    wire [31:0] cpw_start_y = {{16{tmp[31]}},tmp[31:16]};
    wire [31:0] cpw_end_x = {{16{b[15]}},b[15:0]};
    wire [31:0] cpw_end_y = {{16{b[31]}},b[31:16]};
    wire [31:0] alu_a = line_prep_active && array_win ?
                            (line_phase==0 ?
                             {15'd0,array_yleft,1'b0} :
                             {15'd0,array_dx,1'b0}) :
                        line_advance_active && array_win ?
                            (line_phase==4'd0 ?
                             {16'd0,(rs_data[15:0])} :
                             line_phase==4'd1 ?
                             {16'd0,(rs_data[31:16])} :
                             line_phase==4'd2 ?
                             (line_diag ? array_yend : array_xend) :
                             32'd1) :
                        array_rebase_active && array_win ?
                            (array_rebase_phase==0 ?
                             {16'd0,array_xleft} :
                             array_rebase_phase==1 ?
                             array_rebase_src_bits :
                             array_rebase_dst_bits) :
                        array_canon_active && array_win ?
                            {16'd0,array_height[15:0]} :
                        array_win ?
                            (array_corner_mode ?
                             (array_winphase==4'd2 ? 32'd1 :
                              array_winphase==4'd3 ||
                              array_winphase==4'd5 ?
                              {16'd0,array_dx} :
                              {16'd0,array_dyminus1}) :
                             array_winphase==4'd0 ? {16'd0,array_dx} :
                             array_winphase==4'd1 ? {16'd0,array_yleft} :
                             array_winphase==4'd2 ||
                             array_winphase==4'd3 ? 32'd1 :
                             array_winphase==4'd4 ? array_wxend :
                             array_winphase==4'd5 ? array_wyend :
                             array_winphase==4'd6 ? array_wx0 :
                             array_winphase==4'd7 ? array_wy0 :
                             array_winphase==4'd8 ? array_left :
                             array_winphase==4'd9 ? array_top :
                             array_winphase==4'd10 ? array_x0 :
                             array_winphase==4'd11 ? array_y0 :
                             array_winphase==4'd12 ? array_xoff :
                             array_yoff) :
                        array_count ? 32'd1 :
                        array_srcpre || array_dstpre ? {16'd0,psize} :
                        array_srcstep ?
                            (array_rowend ? rs_data :
                             (array_binary ? 32'd32 : {16'd0,psize})) :
                        array_dststep ?
                            (array_rowend && !(array_fill && array_last) ?
                             rs_data : {16'd0,psize}) :
                        array_canon_active && array_canon_linear &&
                        (a_sel==SAVESRC_A || a_sel==SAVEDST_A) ? a :
                        array_offset_active && a_sel==SAVESRC_A ? a :
                        a_sel==PROCESS_A && pixel_alu_req ? pixel_alu_a :
                        a_sel==DRAVX_A ? {16'd0,pix_src_val[15:0]} :
                        a_sel==DRAVY_A ? {16'd0,pix_src_val[31:16]} :
                        cpw_compare ?
                        (gfx_phase==3'd2 ? cpw_start_x :
                         gfx_phase==3'd3 ? cpw_start_y :
                         gfx_phase==3'd4 ? cpw_source_x : cpw_source_y) :
                        xyx ? {16'd0,a[15:0]} :
                        xyy ? {16'd0,a[31:16]} :
                        divnegmd ? md : divnegb ? b :
                        mulcorrm ? tmp : mulstep && !md[0] ? 32'd0 : a;
    wire [31:0] alu_b = line_prep_active && array_win ?
                            (line_phase==0 ? 32'd0 : array_xend) :
                        line_advance_active && array_win ?
                            (line_phase==4'd0 ?
                             {16'd0,pix_dst_val[15:0]} :
                             line_phase==4'd1 ?
                             {16'd0,pix_dst_val[31:16]} :
                             line_phase==4'd2 ?
                             pix_src_val : array_height) :
                        array_rebase_active && array_win ?
                            (array_rebase_phase==0 ?
                             {16'd0,array_dx} :
                             array_rebase_phase==1 ?
                             pix_src_val : pix_dst_val) :
                        array_canon_active && array_win ?
                            (array_canon_dst ?
                             {{16{array_wend[31]}},array_wend[31:16]} :
                             {{16{array_wstart[31]}},array_wstart[31:16]}) :
                        array_win ?
                            (array_corner_mode ?
                             (array_winphase==4'd2 ? {16'd0,array_yleft} :
                              array_winphase==4'd3 ?
                                  (array_src_xy ?
                                   {{16{pix_src_val[15]}},pix_src_val[15:0]} :
                                   array_xoff) :
                              array_winphase==4'd4 ?
                                  (array_src_xy ?
                                   {{16{pix_src_val[31]}},pix_src_val[31:16]} :
                                   array_yoff) :
                              array_winphase==4'd5 ?
                                  (array_dst_xy ? array_x0 : array_xoff) :
                                  (array_dst_xy ? array_y0 : array_yoff)) :
                             array_winphase==4'd0 ? array_x0 :
                             array_winphase==4'd1 ? array_y0 :
                             array_winphase==4'd2 ?
                                 {{16{array_wend[15]}},array_wend[15:0]} :
                             array_winphase==4'd3 ?
                                 {{16{array_wend[31]}},array_wend[31:16]} :
                             array_winphase==4'd4 ? array_xend :
                             array_winphase==4'd5 ? array_yend :
                             array_winphase==4'd6 ? array_x0 :
                             array_winphase==4'd7 ? array_y0 :
                             array_winphase==4'd8 ? array_right :
                             array_winphase==4'd9 ? array_bottom :
                             array_winphase==4'd10 ? array_left :
                             array_winphase==4'd11 ? array_top :
                             array_winphase==4'd12 ?
                                 {{16{pix_src_val[15]}},pix_src_val[15:0]} :
                                 {{16{pix_src_val[31]}},pix_src_val[31:16]}) :
                        array_canon_active && array_canon_linear &&
                        (a_sel==SAVESRC_A || a_sel==SAVEDST_A) ?
                            (array_canon_dst ? array_wend : array_wstart) :
                        array_offset_active && a_sel==SAVESRC_A ?
                            (array_offset_dest ? pix_dst_val : pix_src_val) :
                        array_count ?
                            (array_rowend ? {16'd0,array_yleft} :
                             {16'd0,array_xleft}) :
                        array_srcpre ? pix_src_val :
                        array_dstpre ? pix_dst_val :
                        array_srcstep ?
                            (array_rowend ? rd_data : pix_src_val) :
                        array_dststep ?
                            (array_rowend && !(array_fill && array_last) ?
                             rd_data : pix_dst_val) :
                        a_sel==PROCESS_A && pixel_alu_req ? pixel_alu_b :
                        a_sel==DRAVX_A ? {16'd0,pix_dst_val[15:0]} :
                        a_sel==DRAVY_A ? {16'd0,pix_dst_val[31:16]} :
                        cpw_compare ?
                        (gfx_phase==3'd2 ? cpw_source_x :
                         gfx_phase==3'd3 ? cpw_source_y :
                         gfx_phase==3'd4 ? cpw_end_x : cpw_end_y) :
                        xyy ? {16'd0,b[31:16]} :
                        xyx ? {16'd0,b[15:0]} :
                        divstep ? div_trial : divnegb ? 32'd0 : b;
    wire alu_cin = divnegb && !div_phase ? !div_lowzero : st[30];
    jttms10_alu u_alu(.a(alu_a),.b(alu_b),.op(alu_op),.cin(alu_cin),
        .result(result),.n(n),.z(z),.c(c),.v(v));
    reg condition;
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
    wire [31:0] pc_delta = pc_tmp_add ? {tmp[27:0],4'd0} :
                           pc_long_add ? {{12{md[15]}},md[15:0],4'd0} :
                           pc_short_add ? {{20{ir[7]}},ir[7:0],4'd0} :
                           pc_dsj_add ? dsj_delta : 32'd16;
    wire [31:0] pc_plus = pc + pc_delta;
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
            shift_count<=0;
            mul_count<=0;
            div_pairread<=0;
            div_dvdneg<=0;
            div_dvsneg<=0;
            div_lowzero<=0;
            div_phase<=0;
            div_early<=0;
            div_error<=0;
            shift_c<=0;
            shift_v<=0;
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
            gfx_phase<=0;
            gfx_rs<=0;
            pix_conv_src<=0;
            pix_clip<=0;
            pix_src_val<=0;
            pix_dst_val<=0;
            pix_src_addr<=0;
            pix_color<=0;
            pix_src_pixel<=0;
            pix_dst_pixel<=0;
            pix_write_data<=0;
            pix_transparent<=0;
            array_index<=0;
            array_winphase<=0;
            array_offset_convert<=0;
            array_corner_mode<=0;
            array_query_mode<=0;
            array_canon_linear<=0;
            array_checkpoint<=0;
            pbx_push<=0;
            line_checkpoint<=0;
            line_abort<=0;
            line_hw_push<=0;
        end else begin
            if(hw_take) begin
                vector_latched<=nmi_req ? 32'hfffffee0 : irq_vector;
                nmi_clear<=nmi_req;
                hw_entry<=1;
                array_checkpoint<=0;
                pbx_push<=array_checkpoint && !(nmi_req && nmi_nostack);
                line_checkpoint<=0;
                line_hw_push<=line_checkpoint && !(nmi_req && nmi_nostack);
                if(array_checkpoint) array_index<=0;
            end
            if(push_entry) push_high<=1;
            if(mem_req && mem_ack) begin
                completed<=1;
                bus_data<=mem_rdata;
            end
            if(active && cen && halt) fault<=1;
            if(step) begin
                completed<=0;
                if(emu_step) emu_ack<=1;
                if(push_active && stack_sel==WRITE_STACK)
                    push_high<=~push_high;
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
                    A_TMP: tmp<=a;
                    MD_TMP: tmp<=md;
                    default:;
                endcase
                if(ld_ir) begin
                    ir<=md[15:0];
                    div_pairread<=0;
                    gfx_phase<=0;
                    gfx_rs<=0;
                    pix_conv_src<=0;
                    array_offset_convert<=0;
                    array_corner_mode<=0;
                    array_query_mode<=0;
                    array_canon_linear<=0;
                end
                if(ni && reti_pbx) begin
                    array_index<=0;
                    gfx_rs<=0;
                    pix_clip<=0;
                    pix_transparent<=0;
                    array_offset_convert<=0;
                    array_corner_mode<=0;
                    array_query_mode<=0;
                    array_canon_linear<=0;
                end
                if(array_init) begin
                    array_index<=0;
                    gfx_rs<=0;
                    pix_clip<=0;
                    pix_transparent<=0;
                    pix_src_pixel<=0;
                    pix_dst_pixel<=0;
                    array_winphase<=0;
                    array_corner_mode<=0;
                    array_query_mode<=0;
                    array_canon_linear<=0;
                    array_xoff_q<=0;
                    array_yoff_q<=0;
                    line_abort<=0;
                    line_checkpoint<=0;
                end
                if(array_save_active && listwr)
                    array_index<=array_index+4'd1;
                if(array_restore_active && array_cap) begin
                    array_index<=array_index+4'd1;
                    case(array_index)
                        4'd0: begin
                            pix_src_val<=rs_data;
                        end
                        4'd2: begin
                            pix_dst_val<=rs_data;
                        end
                        4'd4: array_color0<=rs_data[15:0];
                        4'd5: pix_color<=rs_data[15:0];
                        4'd6: begin
                            ir<=rs_data[15:0];
                            array_dx<=rs_data[31:16];
                        end
                        4'd7: begin
                            array_yleft<=rs_data[31:16];
                            array_xleft<=rs_data[15:0];
                        end
                        4'd8: if(array_binary) tmp<=rs_data;
                        default: begin
                            array_height<={16'd0,rs_data[31:16]};
                            array_dyminus1<=rs_data[15:0];
                        end
                    endcase
                end
                if(array_cap && line_setup_active) begin
                    array_index<=array_index+4'd1;
                    case(array_index)
                        4'd0: pix_src_val<=rs_data;
                        4'd1: pix_dst_val<=rs_data;
                        4'd2: begin
                            array_dx<=rs_data[15:0];
                            array_yleft<=rs_data[31:16];
                        end
                        4'd3: pix_color<=rs_data[15:0];
                        4'd4: array_height<=rs_data;
                        default:;
                    endcase
                end
                if(array_cap && !line_setup_active &&
                   !array_restore_active) begin
                    array_index<=array_index+4'd1;
                    if(array_index==4'd9 && !(
                       array_dst_xy && control[7:6]!=0))
                        array_corner_mode<=array_corner_needed;
                    case(array_index)
                        4'd0: begin
                            pix_src_val<=rs_data;
                        end
                        4'd2: begin
                            pix_dst_val<=rs_data;
                        end

                        4'd7: begin
                            array_dx<=rs_data[15:0];
                            array_xleft<=rs_data[15:0];
                            array_yleft<=rs_data[31:16];
                            array_height<={16'd0,rs_data[31:16]};
                        end
                        4'd8: array_color0<=rs_data[15:0];
                        4'd9: begin
                            pix_color<=rs_data[15:0];
                        end
                        default:;
                    endcase
                end
                if(a_sel==INIT_A) begin
                    pix_src_val<=rs_data;
                    pix_dst_val<=rd_data;
                    pix_src_pixel<=rs_data[15:0];
                    pix_dst_pixel<=0;
                    pix_clip<=0;
                    pix_transparent<=0;
                    gfx_rs<=drav_ir ? 3'd4 : 3'd0; // B9 COLOR1
                end
                if(cc_sel==SRCADDR_CC) begin
                    ea<=pix_src_val;
                    pix_src_addr<=pix_src_val[3:0];
                end
                if(cc_sel==DSTADDR_CC) ea<=pix_dst_val;
                if(a_sel==SRCPREP_A) begin
                    a<=array_offset_active ?
                        {array_yoff[15:0],array_xoff[15:0]} :
                        pix_src_val;
                    pix_conv_src<=!array_offset_active ||
                                  !array_offset_dest;
                    gfx_phase<=0;
                end
                if(a_sel==DSTPREP_A) begin
                    a<=pix_dst_val;
                    pix_conv_src<=0;
                    gfx_phase<=0;
                end
                if(a_sel==SAVESRC_A) begin
                    pix_src_addr<=a[3:0];
                    ea<=a;
                    if(array_offset_active && array_offset_dest) begin
                        pix_dst_val<=result;
                    end else if(array_ir &&
                       (!array_canon_active || array_src_xy ||
                        array_canon_linear)) begin
                        pix_src_val<=array_offset_active ||
                            array_canon_linear ? result : a;
                    end
                    if(array_offset_active) array_offset_convert<=0;
                end
                if(a_sel==SAVEDST_A) begin
                    ea<=a;
                    if(array_ir &&
                       (!array_canon_active || array_dst_xy ||
                        array_canon_linear)) begin
                        pix_dst_val<=array_canon_linear ? result : a;
                    end
                end
                if(a_sel==SRCCAP_A) begin
                    if(array_binary) begin
                        pix_src_pixel<=array_binary_need_read ?
                            {15'd0,md[0]} : {15'd0,tmp[0]};
                        tmp<=array_binary_need_read ?
                            {1'b0,md[31:1]} : {1'b0,tmp[31:1]};
                    end else pix_src_pixel<=md[15:0];
                end
                if(cc_sel==DSTCAP_CC) pix_dst_pixel<=md[15:0];
                if(a_sel==PROCESS_A) begin
                    pix_write_data<=pixel_write_pixel;
                    pix_transparent<=pixel_transparent;
                end
                if(a_sel==LOAD_A) st[28]<=pixel_visible_source!=0;
                if(a_sel==WINPREP_A) begin
                    a<=pix_dst_val;
                    gfx_phase<=0;
                    pix_clip<=0;
                end
                if(array_offset_active && a_sel==SRCPREP_A)
                    array_offset_convert<=1;
                if(line_prep_active && array_win) begin
                    if(line_phase==0) array_xend_q<=result[17:0];
                    else array_yend_q<=result[17:0];
                end else if(line_advance_active && array_win) begin
                    case(line_phase)
                        4'd0: md[15:0]<=result[15:0];
                        4'd1: md[31:16]<=result[15:0];
                        4'd2: begin
                            pix_src_val<=result;
                            pix_dst_val<=md;
                        end
                        4'd3: array_height<=result;
                        default:;
                    endcase
                end else if(array_rebase_active && array_win) begin
                    case(array_rebase_phase)
                        2'd0: array_width_q<=result[17:0];
                        2'd1:;
                        2'd2:;
                        default:;
                    endcase
                end else if(array_canon_active && array_win) begin
                    a<=array_canon_dst ?
                        (array_dst_xy ?
                         {result[15:0],array_wend[15:0]} :
                         {array_height[15:0],16'd0}) :
                        (array_src_xy ?
                         {result[15:0],array_wstart[15:0]} :
                         {array_height[15:0],16'd0});
                    pix_conv_src<=!array_canon_dst;
                    array_canon_linear<=array_canon_dst ?
                        !array_dst_xy : !array_src_xy;
                    gfx_phase<=0;
                end else if(array_win) begin
                    array_winphase<=array_winphase+4'd1;
                    if(array_corner_mode) begin
                        case(array_winphase)
                            4'd2: array_dyminus1<=result[15:0];
                            4'd3: if(control[8]) begin
                                if(array_src_xy)
                                    pix_src_val[15:0]<=result[15:0];
                                else array_xoff_q<=result[18:0];
                            end
                            4'd4: if(control[9]) begin
                                if(array_src_xy)
                                    pix_src_val[31:16]<=result[15:0];
                                else array_yoff_q<=result[18:0];
                            end
                            4'd5: if(control[8]) begin
                                if(array_dst_xy)
                                    pix_dst_val[15:0]<=result[15:0];
                                else array_xoff_q<=result[18:0];
                            end
                            4'd6: if(control[9]) begin
                                if(array_dst_xy)
                                    pix_dst_val[31:16]<=result[15:0];
                                else array_yoff_q<=result[18:0];
                            end
                            default:;
                        endcase
                    end else begin
                    case(array_winphase)
                        4'd0: array_xend_q<=result[17:0];
                        4'd1: array_yend_q<=result[17:0];
                        4'd2: array_wxend_q<=result[17:0];
                        4'd3: array_wyend_q<=result[17:0];
                        4'd4: begin
                            array_wxend_q<=n ? array_xend_q : array_wxend_q;
                            array_window_violation_q<=!n && !z;
                        end
                        4'd5: begin
                            array_wyend_q<=n ? array_yend_q : array_wyend_q;
                            array_window_violation_q<=
                                array_window_violation_q || (!n && !z);
                        end
                        4'd6: begin
                            array_xend_q<=n ? array_wx0[17:0] : array_x0[17:0];
                            array_window_violation_q<=array_window_violation_q || n;
                        end
                        4'd7: begin
                            array_yend_q<=n ? array_wy0[17:0] : array_y0[17:0];
                            array_window_violation_q<=array_window_violation_q || n;
                        end
                        4'd8: array_width_q<=result[17:0];
                        4'd9: array_height<={{14{result[17]}},result[17:0]};
                        4'd10: array_xoff_q<=result[18:0];
                        4'd11: array_yoff_q<=result[18:0];
                        4'd12: if(control[7:6]==2'd3 && array_src_xy)
                            pix_src_val[15:0]<=result[15:0];
                        4'd13: if(control[7:6]==2'd3 && array_src_xy)
                            pix_src_val[31:16]<=result[15:0];
                        4'd15: begin
                            if(array_window_query) array_query_mode<=1;
                            if(array_corner_next) begin
                                array_corner_mode<=1;
                                array_winphase<=0;
                            end
                            st[28]<=control[7:6]==2'd1 ?
                                    !array_window_overlap :
                                    array_window_violation;
                            if((control[7:6]==2'd1 &&
                                array_window_overlap) ||
                               (control[7:6]==2'd2 &&
                                array_window_violation)) wvp_set<=1;
                            if(control[7:6]==2'd3 &&
                               array_window_overlap) begin
                                pix_dst_val<=
                                    {array_top[15:0],array_left[15:0]};
                                array_dx<=array_width[15:0];
                                array_xleft<=array_width[15:0];
                                array_yleft<=array_height[15:0];
                            end
                        end
                        default:;
                    endcase
                    end
                end
                if(cc_sel==COLOR_CC) pix_color<=rs_data[15:0];
                if(array_srcpre && array_rev_h) pix_src_val<=result;
                if(array_dstpre && array_rev_h) pix_dst_val<=result;
                if(array_srcstep && !array_fill) begin
                    if(array_rowend ||
                       (array_binary ? array_binary_need_read :
                        !array_rev_h)) pix_src_val<=result;
                end
                if(array_dststep) begin
                    if(array_rowend || !array_rev_h) pix_dst_val<=result;
                end
                if(array_count) begin
                    array_checkpoint<=!array_last &&
                        (array_rowend ||
                         (array_rev_h ?
                          (psize==16'd16 ||
                           {1'b0,pix_dst_val[3:0]}<psize[4:0]) :
                          pix_dst_val[31:4]!=ea[31:4]));
                    if(array_rowend) begin
                        array_yleft<=result[15:0];
                        array_xleft<=array_dx;
                    end else array_xleft<=result[15:0];
                end
                if(array_source_phase && step) array_checkpoint<=0;
                if(line_loop_active && a_sel==WINPREP_A)
                    line_checkpoint<=0;
                if(line_write_active && listwr && line_phase==4'd2)
                    line_checkpoint<=!line_last && !line_abort;
                if(a_sel==DRAVX_A) md[15:0]<=result[15:0];
                if(a_sel==DRAVY_A) md[31:16]<=result[15:0];
                if(gfx_step) begin
                    if(cvloop_active) begin
                        a<=result;
                        shift_count<=shift_count-5'd1;
                    end else if(wincheck_active) begin
                        gfx_phase<=gfx_phase+3'd1;
                        case(gfx_phase)
                            3'd0: begin
                                md<=0;
                                gfx_rs<=3'd1; // B5 WSTART
                            end
                            3'd1: begin
                                tmp<=rs_data;
                                gfx_rs<=3'd2; // B6 WEND
                            end
                            3'd2: md[5]<=n;
                            3'd3: begin md[7]<=n; b<=rs_data; end
                            3'd4: md[6]<=n;
                            3'd5: md[8]<=n;
                            3'd6: begin
                                if(!cpw_ir && control[7:6]!=0) begin
                                    st[28]<=|md[8:5];
                                    pix_clip<=control[7:6]==2'd1 || |md[8:5];
                                    if((control[7:6]==2'd1 && !(|md[8:5])) ||
                                       (control[7:6]==2'd2 && (|md[8:5])))
                                        wvp_set<=1;
                                end
                                if(line_ir)
                                    line_abort<=
                                        (control[7:6]==2'd1 &&
                                         !(|md[8:5])) ||
                                        (control[7:6]==2'd2 &&
                                         (|md[8:5]));
                            end
                            default:;
                        endcase
                    end else if(pixconv_active) begin
                            gfx_phase<=gfx_phase+3'd1;
                            case(gfx_phase)
                                3'd0: begin
                                    tmp<=a;
                                    a<={{16{a[31]}},a[31:16]};
                                    shift_count<=5'd31-
                                        (pix_field && pix_conv_src ?
                                         convsp[4:0] : convdp[4:0]);
                                    gfx_rs<=3'd3; // B4 OFFSET
                                end
                                3'd1: begin
                                    b<=a;
                                    a<={16'd0,tmp[15:0]};
                                    shift_count<=array_offset_convert &&
                                        array_binary ? 5'd0 : pixel_shift;
                                end
                                3'd2: a<=result;
                                3'd3: b<=array_offset_convert ||
                                           array_canon_linear ? 32'd0 :
                                                rs_data;
                                3'd4: a<=result;
                                default:;
                            endcase
                    end
                end
                if(shiftkinit || shiftrinit) begin
                    shift_count<=shift_right ? -shift_raw : shift_raw;
                    shift_c<=0;
                    shift_v<=0;
                end
                if(shift_step) begin
                    shift_count<=shift_count-5'd1;
                    shift_c<=c;
                    shift_v<=shift_v | (a[31]^result[31]);
                    a<=result;
                end
                if(lmoinit) lmo_count<=0;
                if(multiinit) begin
                    multi_mask<=md[15:0];
                    multi_steps<=5'd16;
                    multi_index<=ir[5] ? 4'd15 : 4'd0;
                    // MMTM N is the sign of 0-Rp, including the guide's
                    // zero and MIN_INT exceptions: complement original sign.
                    if(!ir[5]) st[31]<=~rd_data[31];
                end
                if(multiadvance) begin
                    multi_mask<={multi_mask[14:0],1'b0};
                    multi_steps<=multi_steps-5'd1;
                    multi_index<=multi_index+(ir[5] ? 4'hf : 4'd1);
                end
                if(mulinit) begin
                    // Capture both operands before either half of a pair write.
                    a<=rd_data;
                    b<=0;
                    md<=field_extended;
                    tmp<=field_extended;
                    mul_count<=0; // zero encodes the first of 32 steps
                end
                if(mulstep) begin
                    // Shift the 33-bit sum one bit right into the 64-bit
                    // partial product; ALU C supplies the top carry bit.
                    b<={c,result[31:1]};
                    md<={result[0],md[31:1]};
                    mul_count<=mul_count-5'd1;
                end
                if(mulcorrq && !ir[9] && tmp[31]) b<=result;
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
                if(xyx) begin
                    md[15:0]<=result[15:0];
                    st[31]<=result[15:0]==0;
                    st[28]<=xy_sub ?
                        (a[15]!=b[15] ? !a[15] && b[15] : result[15]) :
                        result[15];
                end
                if(xyy) begin
                    md[31:16]<=result[15:0];
                    st[29]<=result[15:0]==0;
                    st[30]<=xy_sub ?
                        (a[31]!=b[31] ? !a[31] && b[31] : result[15]) :
                        result[15];
                end
                if(mulfinish) begin
                    if(div_ir) begin
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
                if(lmoscan && lmo_more) begin
                    a<=result;
                    lmo_count<=lmo_count+5'd1;
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
                    IMMSE_A: a<={{16{md[15]}},md[15:0]};
                    IMMLO_A: a<={16'd0,md[15:0]};
                    IMMHI_A: a<={md[15:0],a[15:0]};
                    INV_A: a<=~a;
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
                    A_EA: ea<=a;
                    B_EA: ea<=b;
                    SUM_EA: ea<=result;
                    TMP_EA: ea<=tmp;
                    SWAP_EA: begin ea<=tmp; tmp<=ea; end
                    TRAP_EA: ea<=32'hffffffe0-{22'd0,ir[4:0],5'd0};
                    HWVECTOR_EA: ea<=vector_latched;
                    default:;
                endcase
                case(pc_sel)
                    MD_PC: pc<={md[31:4],4'd0};
                    REG_PC:pc<={rd_data[31:4],4'd0};
                    ABS_PC:if(condition) pc<={a[31:4],4'd0};
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
                    NZVABS_CC:begin st[31]<=n; st[29]<=z; st[28]<=v; end
                    NZFIELD_CC:begin st[31]<=n; st[29]<=z; end
                    Z_CC:st[29]<=z;
                    C0_CC:st[30]<=0;
                    C1_CC:st[30]<=1;
                    I0_CC:st[21]<=0;
                    I1_CC:st[21]<=1;
                    default:;
                endcase
                if(shift_finish) begin
                    st[30]<=shift_c;
                    st[29]<=z;
                    if(shift_kind==3'd0 || shift_kind==3'd2) st[31]<=n;
                    if(shift_kind==3'd0) st[28]<=shift_v;
                end
                if(btstfinish) st[29]<=~a[btst_index];
                if(lmofinish) st[29]<=a==0;
                if(cpw_ir && wr_reg) st[28]<=|md[8:5];
                retire<=ni && !hw_entry;
                if(ni) hw_entry<=0;
            end
        end
    end
endmodule
