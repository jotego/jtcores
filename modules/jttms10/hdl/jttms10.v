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
    wire reg_b, wr_reg, bsrc, a_md, wrsrc, stld, ea_tmp;
    wire [2:0] cc_sel;
    wire [3:0] alu_sel, a_sel;
    wire [2:0] pc_sel;
    wire [1:0] mem_sel;
    wire [2:0] ea_sel;
    reg [31:0] md, a, b, ea, tmp, bus_data;
    reg completed;
    wire field_op = mem_sel!=0;
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
    wire [4:0] fs = ir[9] ? st[10:6] : st[4:0];
    wire [5:0] field_size = byte_op ? 6'd8 : fs==0 ? 6'd32 : {1'b0,fs};
    wire field_signed = byte_op || (ir[9] ? st[11] : st[5]);
    wire [31:0] field_mask = 32'hffffffff >> (6'd32-field_size);
    wire [4:0] field_msb = field_size[4:0]-5'd1;
    wire [31:0] extended = (md & field_mask) |
        ((field_signed && md[field_msb]) ? ~field_mask : 32'd0);
    assign mem_we = mem_sel==WRITE_MEM;
    assign mem_addr = field_op ? ea : vector ? 32'hffffffe0 : pc;
    assign mem_size = field_op ? field_size : vector ? 6'd32 : 6'd16;
    assign mem_wdata = md;
    assign mem_iaq = fetch;

    jttms10_ctrl u_ctrl(
        .rst(rst), .clk(clk), .enable(cen), .ready(ready), .md(md[15:0]),
        .execute(step), .active(active), .vector(vector), .fetch(fetch), .imm(imm),
        .pcinc(pcinc), .ld_ir(ld_ir), .ni(ni), .halt(halt),
        .reg_b(reg_b), .wr_reg(wr_reg), .a_sel(a_sel), .bsrc(bsrc),
        .a_md(a_md), .wrsrc(wrsrc), .stld(stld),
        .ea_tmp(ea_tmp),
        .alu_sel(alu_sel), .cc_sel(cc_sel), .pc_sel(pc_sel),
        .mem_sel(mem_sel), .ea_sel(ea_sel)
    );
    wire [31:0] rs_data, rd_data, result;
    wire cross_move = ir[15:10]==6'b010011 && ir[9];
    wire [4:0] dst = {ir[4]^cross_move,ir[3:0]};
    jttms10_regs u_regs(
        .clk(clk), .rs({ir[4],ir[8:5]}), .rd({ir[4],ir[3:0]}),
        .wa(wrsrc ? {ir[4],ir[8:5]} : dst),
        .we(step && (wr_reg || wrsrc) && !rst), .wd(result),
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
            default:;
        endcase
    end
    wire n,z,c,v;
    jttms10_alu u_alu(.a(a),.b(b),.op(alu_op),.cin(st[30]),
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
                if(a_md) md<=a;
                if(ea_tmp) tmp<=ea;
                if(ld_ir) ir<=md[15:0];
                if(pcinc) pc<=pc+32'd16;
                if(reg_b) b<=rd_data;
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
                    default:;
                endcase
                case(ea_sel)
                    A_EA: ea<=a;
                    B_EA: ea<=b;
                    SUM_EA: ea<=result;
                    TMP_EA: ea<=tmp;
                    SWAP_EA: begin ea<=tmp; tmp<=ea; end
                    default:;
                endcase
                case(pc_sel)
                    MD_PC: pc<={md[31:4],4'd0};
                    REG_PC:pc<={rd_data[31:4],4'd0};
                    REL_PC:if(condition) pc<=pc+{{20{ir[7]}},ir[7:0],4'd0};
                    LONGREL_PC:if(condition) pc<=pc+{{12{md[15]}},md[15:0],4'd0};
                    ABS_PC:if(condition) pc<={a[31:4],4'd0};
                    default:;
                endcase
                if(stld) st<=a;
                case(cc_sel)
                    NZV_CC: begin st[31]<=n; st[29]<=z; st[28]<=0; end
                    NVZC_CC:begin st[31]<=n; st[30]<=c; st[29]<=z; st[28]<=v; end
                    Z_CC:st[29]<=z;
                    C0_CC:st[30]<=0;
                    C1_CC:st[30]<=1;
                    I0_CC:st[21]<=0;
                    I1_CC:st[21]<=1;
                    default:;
                endcase
                retire<=ni;
            end
        end
    end
endmodule
