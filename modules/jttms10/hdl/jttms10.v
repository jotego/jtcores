/* SPDX-License-Identifier: GPL-3.0-or-later */
// Microcoded TMS34010 execution datapath. Addresses are BIT addresses and
// requests describe 1..32-bit fields. Peripheral/bus integration is separate.
module jttms10(
    input             rst, clk, cen,
    output            mem_req, mem_we, mem_iaq,
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
    wire [3:0] cc_sel;
    wire [3:0] alu_sel;
    wire [4:0] a_sel;
    wire [2:0] pc_sel;
    wire [1:0] b_sel, md_sel, mem_sel, stack_sel, tmp_sel, st_sel;
    wire [2:0] ea_sel;
    wire [31:0] rs_data, rd_data, result;
    wire n,z,c,v;
    reg [31:0] md, a, b, ea, tmp, bus_data;
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
    wire ready = !bus_op || completed || mem_ack;
    wire [31:0] read_data = completed ? bus_data : mem_rdata;
    // Only the execution phase owns the bus; this prevents a completed
    // microinstruction from being presented again while the ROM is primed.
    wire active;
    assign mem_req = active && bus_op && !completed && !rst && !fault;
    // MOVB always uses an 8-bit signed field. Ordinary MOVE selects one of
    // the two independent FS/FE fields; a size encoding of zero means 32.
    wire byte_op = ir[15:10]==6'b100011 || ir[15:10]==6'b101011 ||
                   ir[15:9]==7'b1001110 || ir[15:9]==7'b1011110 ||
                   ir[15:5]==11'h02f || ir[15:5]==11'h03f || ir==16'h0340;
    wire [4:0] fs = mul_ir ? st[10:6] : ir[9] ? st[10:6] : st[4:0];
    wire [5:0] field_size = byte_op ? 6'd8 : fs==0 ? 6'd32 : {1'b0,fs};
    wire field_signed = byte_op || (ir[9] ? st[11] : st[5]);
    wire [31:0] field_mask = 32'hffffffff >> (6'd32-field_size);
    wire [4:0] field_msb = field_size[4:0]-5'd1;
    wire [31:0] extended = (md & field_mask) |
        ((field_signed && md[field_msb]) ? ~field_mask : 32'd0);
    wire [31:0] mul_field = (rs_data & field_mask) |
        ((!ir[9] && rs_data[field_msb]) ? ~field_mask : 32'd0);
    assign mem_we = mem_sel==WRITE_MEM || stack_sel==WRITE_STACK;
    assign mem_addr = field_op ? ea : vector ? 32'hffffffe0 : pc;
    assign mem_size = (stack_sel!=0 || vector)
                    ? 6'd32 : field_op ? field_size : 6'd16;
    assign mem_wdata = md;
    assign mem_iaq = fetch;

    jttms10_ctrl u_ctrl(
        .rst(rst), .clk(clk), .enable(cen), .ready(ready), .md(md[15:0]),
        .shift_count(shift_count), .lmo_more(lmo_more),
        .multi_bit(multi_bit), .multi_steps(multi_steps),
        .multi_load(ir[5]),
        .mul_count(mul_count),
        .div_early_cond(a==0 || !c),
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
    jttms10_regs u_regs(
        .clk(clk), .rs(multi_ir ? {ir[4],multi_index} :
                         call_rs_ir ? {ir[4],ir[3:0]} : {ir[4],ir[8:5]}),
        .rd(stack_ir ? 5'd15 :
            div_ir && div_pairread ? {ir[4],ir[3:0]+4'd1} :
            {ir[4],ir[3:0]}),
        .wa(wr_sp ? 5'd15 : ptrwr ? {ir[4],ir[3:0]} :
            listwr ? {ir[4],multi_index} :
            mulwrlo && (div_ir ? div_pair : !ir[0]) ?
                {ir[4],ir[3:0]+4'd1} :
            wrsrc ? {ir[4],ir[8:5]} : dst),
        .we(step && (wr_reg || wrsrc || wr_sp || ptrwr || listwr ||
                     (dsjfinish && dsj_allow) ||
                     ((mulwrhi && (div_ir ? div_pair : !ir[0])) || mulwrlo) &&
                     (!div_ir || (!div_early &&
                       (!div_error || (div_mod && div_signed))))) && !rst),
        .wd(exgf ? {26'd0,old_field} :
            lmofinish ? {27'd0,lmo_count} : listwr ? md :
            xy_op && wr_reg ? md :
            mulwrhi ? (div_ir ? md : b) :
            mulwrlo ? (div_ir && (div_mod || div_pair) ? b : md) : result),
        .qs(rs_data), .qd(rd_data)
    );
    reg [3:0] alu_op;
    always @* begin
        alu_op=0;
        case(alu_sel)
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
                case(shift_kind)
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
    wire [31:0] alu_a = xyx ? {16'd0,a[15:0]} :
                        xyy ? {16'd0,a[31:16]} :
                        divnegmd ? md : divnegb ? b :
                        mulcorrm ? tmp : mulstep && !md[0] ? 32'd0 : a;
    wire [31:0] alu_b = xyx ? {16'd0,b[15:0]} :
                        xyy ? {16'd0,b[31:16]} :
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
    always @(posedge clk) begin
        retire <= 0;
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
        end else begin
            if(mem_req && mem_ack) begin
                completed<=1;
                bus_data<=mem_rdata;
            end
            if(active && cen && halt) fault<=1;
            if(step) begin
                completed<=0;
                if(bus_op && !mem_we) md<=read_data;
                case(md_sel)
                    A_MD: md<=a;
                    PC_MD: md<=pc;
                    ST_MD: md<=st;
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
                    md<=mul_field;
                    tmp<=mul_field;
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
                if(pcinc) pc<=pc+32'd16;
                if(dsjfinish && dsj_allow && result!=0)
                    pc<=pc+dsj_delta;
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
                    EXT_A: a<=extended;
                    PC_A: a<=pc;
                    REV_A: a<=32'd8;
                    WORD_A: a<=32'd32;
                    ONE_A: a<=32'd1;
                    MOVX_A: a<={rd_data[31:16],rs_data[15:0]};
                    MOVY_A: a<={rs_data[31:16],rd_data[15:0]};
                    RETADJ_A: a<=32'd32+{23'd0,ir[4:0],4'd0};
                    SEXT_A: a<=(a & field_mask) |
                              (a[field_msb] ? ~field_mask : 32'd0);
                    ZEXT_A: a<=a & field_mask;
                    default:;
                endcase
                case(ea_sel)
                    A_EA: ea<=a;
                    B_EA: ea<=b;
                    SUM_EA: ea<=result;
                    TMP_EA: ea<=tmp;
                    SWAP_EA: begin ea<=tmp; tmp<=ea; end
                    TRAP_EA: ea<=32'hffffffe0-{22'd0,ir[4:0],5'd0};
                    default:;
                endcase
                case(pc_sel)
                    MD_PC: pc<={md[31:4],4'd0};
                    REG_PC:pc<={rd_data[31:4],4'd0};
                    REL_PC:if(condition) pc<=pc+{{20{ir[7]}},ir[7:0],4'd0};
                    LONGREL_PC:if(condition) pc<=pc+{{12{md[15]}},md[15:0],4'd0};
                    ABS_PC:if(condition) pc<={a[31:4],4'd0};
                    TMP_PC:pc<={tmp[31:4],4'd0};
                    TMPREL_PC:pc<=pc+{tmp[27:0],4'd0};
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
                    TMP_ST: st<=tmp;
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
                retire<=ni;
            end
        end
    end
endmodule
