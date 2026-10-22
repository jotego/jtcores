/* SPDX-License-Identifier: GPL-3.0-or-later */
// Microcoded TMS34010 execution datapath. Addresses are BIT addresses and
// requests describe 1..32-bit fields. Peripheral/bus integration is separate.
module jttms10(
`ifdef JTTMS10_REGRESSION
    output            obs_decode, obs_rf_we, obs_hw_complete,
    output     [31:0] obs_decode_pc, obs_rf_data,
    output     [15:0] obs_decode_ir,
    output     [ 5:0] obs_rf_addr,
    output    [170:0] obs_work,
`endif
    input             rst, clk, cen,
    input             cache_flush,
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
    output            peek_req, peek_consume,
    input             peek_ack, peek_hit,
    input      [15:0]  peek_data,
    output reg [31:0] pc, st,
    output reg [15:0] ir,
    output reg        retire, fault
);
    // The shared generated header also contains the sequencer's constants.
    /* verilator lint_off UNUSEDPARAM */
    `include "tms10_param.vh"
    /* verilator lint_on UNUSEDPARAM */
    wire step, vector, fetch, imm, pcinc, ld_ir, ni, halt;
`ifdef JTTMS10_REGRESSION
    wire [11:0] obs_control;
`endif
    wire peek, slot_take, halt_accept;
    wire wr_reg, bsrc, wrsrc, stld, wr_sp;
    wire shiftkinit, shiftrinit, shift_step, shift_finish;
    wire setf, exgf, btstfinish, lmoinit, lmoscan, lmofinish;
    wire multiinit, multiadvance, ptrwr, listwr;
    wire mulinit, mulstep, mulcorrq, mulcorrm, mulfinish, mulwrhi, mulwrlo;
    wire divinit, divload, divnega, divnegmd, divnegb, divcheck, divstep;
    wire dsjfinish, xyx, xyy;
    wire gfx_active, gfx_checkpoint, gfx_done, gfx_enter, gfx_resume,
         gfx_take, gfx_clip;
    wire [7:0] gfx_family;
    wire [5:0] gfx_rf_sa, gfx_rf_da, gfx_rf_wa, gfx_bus_size;
    wire gfx_load_a,gfx_load_b,gfx_dst_a,gfx_dst_b,gfx_dst_md,
         gfx_dst_ea,gfx_dst_tmp,gfx_dst_rf,gfx_dst_ir,gfx_mdrf;
    wire gfx_bus_read,gfx_bus_write,gfx_bus_pixel;
    wire gfx_pix_source,gfx_pix_visible,gfx_pix_process,gfx_pix_test;
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
    reg [31:0] md, a, b, ea, tmp, bus_data;
    reg [31:0] vector_latched;
    reg push_high, hw_entry;
    reg [3:0] pix_src_addr;
    reg pix_transparent;
    reg pbx_push, line_hw_push;
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
    wire pix_rxy = ir[15:9]==7'b1111000;
    wire drav_ir = ir[15:9]==7'b1111011;
    wire line_ir = ir==16'hdf1a || ir==16'hdf9a;
    wire pix_rlin = ir[15:9]==7'b1111100;
    wire array_ir = ir==16'h0f00 || ir==16'h0f20 ||
                    ir==16'h0f40 || ir==16'h0f60 ||
                    ir==16'h0f80 || ir==16'h0fa0 ||
                    ir==16'h0fc0 || ir==16'h0fe0;
    wire array_fill = ir==16'h0fc0 || ir==16'h0fe0;
    wire array_binary = ir==16'h0f80 || ir==16'h0fa0;
    wire reti_pbx = ir==16'h0940 && tmp[25];
    wire pix_register_source = pix_rxy || pix_rlin || drav_ir || line_ir ||
                               (array_ir && array_fill);
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
    reg completed, bus_started;
    reg slot_valid, peek_pending;
    reg [15:0] slot_opcode;
    wire slot_ready = slot_valid && !cache_flush && !control[15];
    wire field_op = mem_sel!=0 || stack_sel!=0 ||
                    gfx_bus_read || gfx_bus_write;
    wire bus_op = vector || fetch || imm || field_op;
    wire gfx_skip_write = gfx_active && gfx_bus_write &&
                          gfx_bus_pixel && pix_transparent;
    wire ready = !bus_op || completed || mem_ack || gfx_skip_write;
    wire [31:0] read_data = completed ? bus_data : mem_rdata;
    // Only the execution phase owns the bus; this prevents a completed
    // microinstruction from being presented again while the ROM is primed.
    wire active;
    assign peek_req = step && peek && !slot_valid && !peek_pending;
    assign peek_consume = slot_take;
    assign mem_req = active && bus_op && !completed && !rst && !fault &&
                     (cen || bus_started) &&
                     !gfx_skip_write;
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
    assign mem_we = gfx_active ? gfx_bus_write :
                    mem_sel==WRITE_MEM || stack_sel==WRITE_STACK;
    assign mem_addr = field_op ? ea : vector ? 32'hffffffe0 : pc;
    assign mem_size = gfx_active ? gfx_bus_size :
                      push_active && stack_sel==WRITE_STACK ? 6'd16 :
                      (stack_sel!=0 || vector) ? 6'd32 :
                      field_op ? field_size : 6'd16;
    assign mem_wdata = gfx_active ? md :
                       push_active && stack_sel==WRITE_STACK ?
                       {16'd0, push_high ? md[31:16] : md[15:0]} :
                       md;
    assign mem_iaq = fetch;
    // The cache accepts every PC-directed word, including extension words.
    // IAQ remains the separate opcode bus-status signal.
    assign mem_program = fetch || imm;
    // PIXT will assert this for its logical pixel field transaction. CPW
    // and CVXYL are register-only operations and never tag memory cycles.
    assign mem_pixel = gfx_active && gfx_bus_pixel;

`ifdef JTTMS10_REGRESSION
    assign obs_hw_complete = step && ni && hw_entry;
    assign obs_decode     = step && (ld_ir || slot_take);
    assign obs_decode_pc  = slot_take ? pc : fetch ? pc : pc-32'd16;
    assign obs_decode_ir  = slot_take ? slot_opcode : fetch ? read_data[15:0] : md[15:0];
    assign obs_work       = {obs_control, active, a, b, md, tmp, mul_count,
                             multi_mask, multi_index, multi_steps};
`endif

    jttms10_ctrl u_ctrl(
`ifdef JTTMS10_REGRESSION
        .obs_control ( obs_control ),
`endif
        .rst(rst), .clk(clk), .enable(cen), .ready(ready), .md(md[15:0]),
        .shift_count(shift_count), .lmo_more(lmo_more),
        .multi_bit(multi_bit), .multi_steps(multi_steps),
        .multi_load(ir[5]),
        .mul_count(mul_count),
        .div_early_cond(a==0 || !c),
        .reti_pbx(reti_pbx),
        .slot_valid(slot_ready), .slot_opcode(slot_opcode),
        .gfx_active(gfx_active), .gfx_done(gfx_done),
        .gfx_checkpoint(gfx_checkpoint),
        .gfx_pbx_ir(rs_data[15:0]),
        .irq_req(irq_req), .nmi_req(nmi_req),
        .nmi_nostack(nmi_nostack), .halt_req(halt_req),
        .emu_run(emu_run), .ie(st[21]),
        .hw_take(hw_take), .reserved_opcode(reserved_opcode),
        .push_entry(push_entry), .push_active(push_active), .emu_step(emu_step),
        .execute(step), .active(active), .vector(vector), .fetch(fetch), .imm(imm),
        .peek(peek), .slot_take(slot_take), .halt_accept(halt_accept),
        .gfx_enter(gfx_enter), .gfx_resume(gfx_resume),
        .gfx_take(gfx_take), .gfx_family(gfx_family),
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
        .alu_n(n), .alu_z(z), .alu_v(v),
        .need_dest(gfx_need_dest), .transparent(pix_transparent),
        .active(gfx_active), .checkpoint(gfx_checkpoint),
        .done(gfx_done),
        .rf_sa(gfx_rf_sa), .rf_da(gfx_rf_da), .rf_wa(gfx_rf_wa),
        .load_a(gfx_load_a), .load_b(gfx_load_b),
        .a_data(gfx_a_data), .b_data(gfx_b_data), .alu_op(gfx_alu_op),
        .dst_a(gfx_dst_a), .dst_b(gfx_dst_b), .dst_md(gfx_dst_md),
        .dst_ea(gfx_dst_ea), .dst_tmp(gfx_dst_tmp), .dst_rf(gfx_dst_rf),
        .dst_ir(gfx_dst_ir),
        .md_to_rf(gfx_mdrf),
        .bus_read(gfx_bus_read), .bus_write(gfx_bus_write),
        .bus_pixel(gfx_bus_pixel), .bus_size(gfx_bus_size),
        .pix_source(gfx_pix_source), .pix_visible(gfx_pix_visible),
        .pix_process(gfx_pix_process), .pix_test(gfx_pix_test),
        .flag_z(gfx_flag_z), .flag_nz(gfx_flag_nz),
        .flag_nvzc(gfx_flag_nvzc), .flag_vclip(gfx_flag_vclip),
        .flag_vpix(gfx_flag_vpix), .flag_vclear(gfx_flag_vclear),
        .flag_wvp(gfx_flag_wvp), .clip(gfx_clip)
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
    jttms10_regs u_regs(
`ifdef JTTMS10_REGRESSION
        .obs_rf_we   ( obs_rf_we   ),
        .obs_rf_addr ( obs_rf_addr ),
        .obs_rf_data ( obs_rf_data ),
`endif
        .clk(clk),
        .rs_ext(gfx_active && gfx_rf_sa[5]),
        .rd_ext(gfx_active && gfx_rf_da[5]),
        .wa_ext(gfx_active && gfx_rf_wa[5]),
        .rs(gfx_active ? gfx_rf_sa[4:0] :
            ir==16'h0940 && tmp[25] ? 5'd26 :
            multi_ir ? {ir[4],multi_index} :
            call_rs_ir ? {ir[4],ir[3:0]} : {ir[4],ir[8:5]}),
        .rd(gfx_active ? gfx_rf_da[4:0] :
            stack_ir || push_active ? 5'd15 :
            div_ir && div_pairread ? {ir[4],ir[3:0]+4'd1} :
            {ir[4],ir[3:0]}),
        .wa(gfx_active ? gfx_rf_wa[4:0] :
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
            exgf ? {26'd0,old_field} :
            lmofinish ? {27'd0,lmo_count} :
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
    wire unused_pixel_valid;
    wire [15:0] unused_pixel_result, unused_pixel_mask;
    wire gfx_color_lane = drav_ir || line_ir ||
                          (array_ir && (array_fill || array_binary));
    wire [15:0] pixel_source = gfx_color_lane ?
                               rs_data[15:0] >> ea[3:0] : rs_data[15:0];
    jttms10_pixel u_pixel(
        .psize(psize[4:0]), .ppop(control[14:10]),
        .transparency(control[5]), .pmask(pmask),
        .source_is_register(pix_register_source),
        .src_addr_lo(array_binary ? ea[3:0] : pix_src_addr),
        .dst_addr_lo(ea[3:0]),
        .source_pixel(pixel_source),
        .dest_pixel(gfx_need_dest ? md[15:0] : 16'd0),
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
            SHIFT_ALU: case(shift_kind)
                3'd0,3'd1: alu_op=12;
                3'd2:      alu_op=14;
                3'd3:      alu_op=13;
                3'd4:      alu_op=15;
                default:;
            endcase
            LMO_ALU: alu_op=12;
            default:;
        endcase
    end
    wire [31:0] div_trial = {b[30:0],md[31]};
    wire [31:0] alu_a =
        xyx ? {16'd0,a[15:0]} :
        xyy ? {16'd0,a[31:16]} :
        divnegmd ? md : divnegb ? b :
        mulcorrm ? tmp : mulstep && !md[0] ? 32'd0 : a;
    wire [31:0] alu_b =
        xyy ? {16'd0,b[31:16]} :
        xyx ? {16'd0,b[15:0]} :
        divstep ? div_trial : divnegb ? 32'd0 : b;
    wire alu_cin = divnegb && !div_phase ? !div_lowzero : st[30];
    wire [31:0] shared_alu_a = gfx_active ?
        (gfx_pix_process && pixel_alu_req ? pixel_alu_a : a) : alu_a;
    wire [31:0] shared_alu_b = gfx_active ?
        (gfx_pix_process && pixel_alu_req ? pixel_alu_b : b) : alu_b;
    jttms10_alu u_alu(.a(shared_alu_a),.b(shared_alu_b),.op(alu_op),.cin(alu_cin),
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
    wire pc_redirect = step && (pc_sel!=0 || pc_dsj_add ||
                                pc_short_add || pc_long_add || pc_tmp_add);
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
            bus_started<=0;
            slot_valid<=0;
            peek_pending<=0;
            slot_opcode<=0;
            bus_data<=0;
            vector_latched<=0;
            push_high<=0;
            hw_entry<=0;
            pix_src_addr<=0;
            pix_transparent<=0;
            pbx_push<=0;
            line_hw_push<=0;
        end else begin
            if(step) bus_started<=0;
            else if(mem_req) bus_started<=1;
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
            if(mem_req && mem_ack) begin
                completed<=1;
                bus_data<=mem_rdata;
            end
            if(peek_req) peek_pending<=1;
            if(peek_pending && peek_ack) begin
                peek_pending<=0;
                if(peek_hit) begin
                    slot_opcode<=peek_data;
                    slot_valid<=1;
                end
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
                if(slot_take && reserved_opcode)
                    vector_latched<=32'hfffffc20;
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
                end
                if(slot_take) begin
                    ir<=slot_opcode;
                    pc<=pc+32'd16;
                    div_pairread<=0;
                end
                if(gfx_active && gfx_dst_ir) ir<=result[15:0];
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
                if(gfx_active) begin
                    if(gfx_load_a) a<=gfx_a_data;
                    if(gfx_load_b) b<=gfx_b_data;
                    if(gfx_dst_a) a<=result;
                    if(gfx_dst_b) b<=result;
                    if(gfx_dst_md) md<=result;
                    if(gfx_dst_ea) ea<=result;
                    if(gfx_dst_tmp) tmp<=result;
                    if(gfx_pix_source) pix_src_addr<=ea[3:0];
                    if(gfx_pix_visible) md<={16'd0,pixel_visible_source};
                    if(gfx_pix_process) begin
                        md<={16'd0,pixel_write_pixel};
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
            if(slot_take || hw_take || halt_accept || cache_flush || control[15] ||
               pc_redirect) begin
                slot_valid<=0;
                peek_pending<=0;
            end
            if(hw_take) hw_entry<=1;
        end
    end
endmodule
