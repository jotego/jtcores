/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 19-10-2026 */

module m6802_reference(
    input             rst, cpu_rst, clk, cen, enable,
    input             ready, mr_n,
    input      [ 7:0] din,
    output     [15:0] addr,
    output     [ 7:0] dout,
    output            e, vma, wr, done,
    output            instruction_end
);

// MC6802 Table 8/MR manual: ../../../../modules/jt680x/doc/complete_6802.md.
// Frisky Tom FC compatibility: ../../doc/hardware_verification.md.
reg [15:0] pc, x, s, ea, op_pc;
reg [7:0] a, b, cc, op, data8, high_byte;
reg [3:0] cycle;
reg [1:0] reset_stage;
reg waiting, illegal;
reg [15:0] cycle_addr;
reg [7:0] cycle_dout;
reg cycle_vma, cycle_wr;
reg [3:0] last_cycle;
reg [7:0] result, next_cc, left, right;
reg [8:0] arithmetic;
reg [4:0] half_sum;
reg [15:0] word_result;
reg [8:0] compare_high;
reg subtract, carry_in;

wire [1:0] mode=op[5:4];
wire [3:0] operation=op[3:0];
wire memory_op=op[7] && operation!=13 && op!=8'hfc;
wire word_op=operation==12 || operation==14 || operation==15;
wire store_op=operation==7 || operation==15;
wire unary_memory=op[7:5]==3'b011 && operation!=14;
wire unary_acc=op[7:5]==3'b010;
wire jump=op==8'h6e || op==8'h7e;
wire jsr=op==8'h9d || op==8'had || op==8'hbd;
wire bsr=op==8'h8d;
wire branch=op[7:4]==2;
wire [3:0] operand_cycle=mode==0 ? 4'd1 : mode==1 ? 4'd2 :
                           mode==2 ? 4'd4 : 4'd3;
wire [3:0] transfer_cycle=operand_cycle+{3'd0,store_op};
wire [15:0] index_partial={x[15:8],ea[7:0]};
wire [15:0] store_word=op[6] ? x : s;
wire [15:0] operand_word={high_byte,din};
wire branch_taken=branch_condition(op[3:0],cc);

assign instruction_end=done && reset_stage==2 && !waiting &&
                       cycle==last_cycle && cycle!=0;

function branch_condition;
    input [3:0] condition;
    input [7:0] flags;
    begin
        case(condition)
             0: branch_condition=1;
             1: branch_condition=0;
             2: branch_condition=!(flags[0] || flags[2]);
             3: branch_condition=flags[0] || flags[2];
             4: branch_condition=!flags[0];
             5: branch_condition=flags[0];
             6: branch_condition=!flags[2];
             7: branch_condition=flags[2];
             8: branch_condition=!flags[1];
             9: branch_condition=flags[1];
            10: branch_condition=!flags[3];
            11: branch_condition=flags[3];
            12: branch_condition=!(flags[3]^flags[1]);
            13: branch_condition=flags[3]^flags[1];
            14: branch_condition=!(flags[2] || (flags[3]^flags[1]));
            15: branch_condition=flags[2] || (flags[3]^flags[1]);
        endcase
    end
endfunction

function supported;
    input [7:0] code;
    begin
        supported=0;
        if(code[7]) begin
            case(code[3:0])
                0,1,2,4,5,6,8,9,10,11,14: supported=1;
                12: supported=!code[6] || code==8'hfc;
                7,15: supported=code[5:4]!=0;
                13: supported=!code[6];
                default:;
            endcase
        end else if(code[7:4]>=4) begin
            case(code[3:0])
                0,3,4,6,7,8,9,10,12,13,15: supported=1;
                14: supported=code[7:4]>=6;
                default:;
            endcase
        end else if(code[7:4]==2) supported=1;
        else case(code)
            8'h01,8'h06,8'h07,8'h08,8'h09,8'h0a,8'h0b,8'h0c,8'h0d,8'h0e,8'h0f,
            8'h10,8'h11,8'h16,8'h17,8'h19,8'h1b,
            8'h30,8'h31,8'h32,8'h33,8'h34,8'h35,8'h36,8'h37,
            8'h39,8'h3b,8'h3e,8'h3f: supported=1;
            default:;
        endcase
    end
endfunction

always @* begin
    last_cycle=1;
    if(memory_op) last_cycle=transfer_cycle+{3'd0,word_op};
    if(unary_memory) last_cycle=mode==2 ? 6 : 5;
    if(jump) last_cycle=mode==2 ? 3 : 2;
    if(branch) last_cycle=3;
    if(bsr) last_cycle=7;
    if(jsr) last_cycle=mode==1 ? 5 : mode==2 ? 7 : 8;
    case(op)
        8'h08,8'h09,8'h30,8'h31,8'h32,8'h33,
        8'h34,8'h35,8'h36,8'h37: last_cycle=3;
        8'h39: last_cycle=4;
        8'h3b: last_cycle=9;
        8'h3e: last_cycle=8;
        8'h3f: last_cycle=11;
        8'hfc: last_cycle=3;
        default:;
    endcase
end

always @* begin
    cycle_addr=pc;
    cycle_dout=0;
    cycle_vma=1;
    cycle_wr=0;
    if(reset_stage!=2) begin
        cycle_addr=reset_stage==0 ? 16'hfffe : 16'hffff;
    end else if(waiting || illegal) begin
        cycle_vma=0;
    end else if(cycle!=0) begin
        if(memory_op) begin
            if(mode!=0) begin
                if(cycle>=operand_cycle) cycle_addr=ea;
                if(mode==2 && cycle==2) cycle_addr=x;
                if(mode==2 && cycle==3) cycle_addr=index_partial;
                if(mode==2 && (cycle==2 || cycle==3)) cycle_vma=0;
                if(store_op && cycle==operand_cycle) cycle_vma=0;
                if(cycle>transfer_cycle && word_op) cycle_addr=ea+16'd1;
                if(store_op && cycle>=transfer_cycle) begin
                    cycle_wr=1;
                    cycle_dout=word_op ? (cycle==transfer_cycle ?
                        store_word[15:8] : store_word[7:0]) : (op[6] ? b : a);
                end
            end
        end else if(unary_memory || jump) begin
            if(mode==2) begin
                if(cycle==2) cycle_addr=x;
                if(cycle==3) cycle_addr=index_partial;
                if(cycle==2 || cycle==3) cycle_vma=0;
            end
            if(cycle>=operand_cycle) cycle_addr=ea;
            if(unary_memory && cycle==last_cycle-1) cycle_vma=0;
            if(unary_memory && cycle==last_cycle) begin
                cycle_vma=operation!=13;
                cycle_wr=1;
                cycle_dout=result;
            end
        end else if(branch || bsr) begin
            if(cycle>=2) cycle_vma=0;
            if(branch && cycle==3) cycle_addr=branch_taken ? ea : pc;
            if(bsr) begin
                if(cycle==3 || cycle==4) begin
                    cycle_addr=s;
                    cycle_vma=1;
                    cycle_wr=1;
                    cycle_dout=cycle==3 ? pc[7:0] : pc[15:8];
                end
                if(cycle==5) cycle_addr=s;
                if(cycle==7) cycle_addr={op_pc[15:8],ea[7:0]};
            end
        end else if(jsr) begin
            if(mode==1) begin
                if(cycle>=2) begin
                    cycle_addr=s;
                    cycle_vma=cycle==2 || cycle==3;
                    cycle_wr=cycle_vma;
                    cycle_dout=cycle==2 ? pc[7:0] : pc[15:8];
                end
                if(cycle==5) cycle_addr=ea;
            end else if(mode==2) begin
                if(cycle>=2) cycle_vma=0;
                if(cycle==2 || cycle==6) cycle_addr=x;
                if(cycle==7) cycle_addr=index_partial;
                if(cycle==3 || cycle==4 || cycle==5) cycle_addr=s;
                if(cycle==3 || cycle==4) begin
                    cycle_vma=1;
                    cycle_wr=1;
                    cycle_dout=cycle==3 ? pc[7:0] : pc[15:8];
                end
            end else begin
                if(cycle==3) cycle_addr=ea;
                if(cycle>=4 && cycle<=6) cycle_addr=s;
                if(cycle==4 || cycle==5) begin
                    cycle_wr=1;
                    cycle_dout=cycle==4 ? pc[7:0] : pc[15:8];
                end
                if(cycle==6 || cycle==7) cycle_vma=0;
                if(cycle>=7) cycle_addr=op_pc+16'd2;
            end
        end else begin
            case(op)
                8'hfc: if(cycle==3) cycle_vma=0;
                8'h08,8'h09: begin
                    if(cycle>=2) begin
                        cycle_vma=0;
                        cycle_addr=cycle==2 ? x :
                            (op==8'h08 ? x+16'd1 : x-16'd1);
                    end
                end
                8'h30,8'h31,8'h34,8'h35: begin
                    if(cycle>=2) begin
                        cycle_vma=0;
                        cycle_addr=op==8'h35 ? x : s;
                        if(cycle==3) case(op)
                            8'h30,8'h31: cycle_addr=s+16'd1;
                            8'h34: cycle_addr=s-16'd1;
                            8'h35: cycle_addr=x-16'd1;
                            default:;
                        endcase
                    end
                end
                8'h36,8'h37: begin
                    if(cycle>=2) cycle_addr=s;
                    if(cycle==2) begin
                        cycle_wr=1;
                        cycle_dout=op[0] ? b : a;
                    end
                    if(cycle==3) cycle_vma=0;
                end
                8'h32,8'h33,8'h39,8'h3b: begin
                    if(cycle==2) begin
                        cycle_addr=s;
                        cycle_vma=0;
                    end
                    if(cycle>=3) cycle_addr=s+16'd1;
                end
                8'h3e,8'h3f: begin
                    if(cycle>=2 && cycle<=8) begin
                        cycle_addr=s;
                        cycle_wr=1;
                        case(cycle)
                            2: cycle_dout=pc[7:0];
                            3: cycle_dout=pc[15:8];
                            4: cycle_dout=x[7:0];
                            5: cycle_dout=x[15:8];
                            6: cycle_dout=a;
                            7: cycle_dout=b;
                            8: cycle_dout=cc;
                            default:;
                        endcase
                    end
                    if(cycle==9) begin
                        cycle_addr=s;
                        cycle_vma=0;
                    end
                    if(cycle==10) cycle_addr=16'hfffa;
                    if(cycle==11) cycle_addr=16'hfffb;
                end
                default:;
            endcase
        end
    end
end

always @* begin
    left=op[6] ? b : a;
    right=din;
    if(unary_acc) left=op[4] ? b : a;
    if(unary_memory) left=data8;
    result=left;
    next_cc=cc;
    arithmetic=0;
    half_sum=0;
    word_result=operand_word;
    compare_high={1'b0,x[15:8]}-{1'b0,operand_word[15:8]};
    subtract=0;
    carry_in=0;

    if(memory_op && !word_op) begin
        case(operation)
            0,1,2,9,11: begin
                subtract=operation<=2;
                carry_in=(operation==2 || operation==9) && cc[0];
                arithmetic=subtract ? {1'b0,left}-{1'b0,right}-{8'd0,carry_in} :
                                      {1'b0,left}+{1'b0,right}+{8'd0,carry_in};
                result=arithmetic[7:0];
                next_cc[0]=arithmetic[8];
                next_cc[1]=(left[7]^result[7]) &
                    (subtract ? left[7]^right[7] : !(left[7]^right[7]));
                if(!subtract) begin
                    half_sum={1'b0,left[3:0]}+{1'b0,right[3:0]}+{4'd0,carry_in};
                    next_cc[5]=half_sum[4];
                end
            end
            4,5: result=left & right;
            6: result=right;
            7: result=left;
            8: result=left ^ right;
            10: result=left | right;
            default:;
        endcase
        next_cc[3:2]={result[7],result==0};
        if(operation>=4 && operation!=9 && operation!=11) next_cc[1]=0;
    end else if(memory_op && word_op) begin
        if(store_op) word_result=store_word;
        if(operation==12) begin
            word_result=x-operand_word;
            next_cc[3]=compare_high[7];
            next_cc[1]=(x[15]^operand_word[15]) & (x[15]^compare_high[7]);
        end else begin
            next_cc[3]=word_result[15];
            next_cc[1]=0;
        end
        next_cc[2]=word_result==0;
    end else if(unary_memory || unary_acc) begin
        case(operation)
             0: begin result=-left; next_cc[1:0]={left==8'h80,left!=0}; end
             3: begin result=~left; next_cc[1:0]=1; end
             4: begin result={1'b0,left[7:1]}; next_cc[0]=left[0]; end
             6: begin result={cc[0],left[7:1]}; next_cc[0]=left[0]; end
             7: begin result={left[7],left[7:1]}; next_cc[0]=left[0]; end
             8: begin result={left[6:0],1'b0}; next_cc[0]=left[7]; end
             9: begin result={left[6:0],cc[0]}; next_cc[0]=left[7]; end
            10: begin result=left-8'd1; next_cc[1]=left==8'h80; end
            12: begin result=left+8'd1; next_cc[1]=left==8'h7f; end
            13: next_cc[1:0]=0;
            15: begin result=0; next_cc[1:0]=0; end
            default:;
        endcase
        next_cc[3:2]={result[7],result==0};
        if(operation==4 || operation==6 || operation==7 ||
           operation==8 || operation==9) next_cc[1]=next_cc[3]^next_cc[0];
    end else begin
        case(op)
            8'h06: next_cc={2'b11,a[5:0]};
            8'h07: result=cc;
            8'h0a: next_cc[1]=0;
            8'h0b: next_cc[1]=1;
            8'h0c: next_cc[0]=0;
            8'h0d: next_cc[0]=1;
            8'h0e: next_cc[4]=0;
            8'h0f: next_cc[4]=1;
            8'h10,8'h11,8'h1b: begin
                arithmetic=op==8'h1b ? {1'b0,a}+{1'b0,b} : {1'b0,a}-{1'b0,b};
                result=arithmetic[7:0];
                next_cc[3:0]={result[7],result==0,
                    (a[7]^result[7]) & (op==8'h1b ? !(a[7]^b[7]) : a[7]^b[7]),
                    arithmetic[8]};
                if(op==8'h1b) begin
                    half_sum={1'b0,a[3:0]}+{1'b0,b[3:0]};
                    next_cc[5]=half_sum[4];
                end
            end
            8'h16,8'h17: begin
                result=op==8'h16 ? a : b;
                next_cc[3:1]={result[7],result==0,1'b0};
            end
            8'h19: begin
                right=0;
                if(a[3:0]>9 || cc[5]) right=8'h06;
                if(a>8'h99 || cc[0]) right=right | 8'h60;
                arithmetic={1'b0,a}+{1'b0,right};
                result=arithmetic[7:0];
                next_cc[3:2]={result[7],result==0};
                next_cc[0]=cc[0] || arithmetic[8];
            end
            default:;
        endcase
    end
end

always @(posedge clk) begin
    if(rst || cpu_rst) begin
        pc <= 0;
        op_pc <= 0;
        x <= 0;
        s <= 0;
        a <= 0;
        b <= 0;
        cc <= 8'hd0;
        op <= 8'h01;
        ea <= 0;
        data8 <= 0;
        high_byte <= 0;
        cycle <= 0;
        reset_stage <= 0;
        waiting <= 0;
        illegal <= 0;
    end else if(done) begin
        if(reset_stage==0) begin
            high_byte <= din;
            reset_stage <= 1;
        end else if(reset_stage==1) begin
            pc <= {high_byte,din};
            reset_stage <= 2;
        end else if(!waiting && !illegal) begin
            if(cycle==0) begin
                op <= din;
                illegal <= !supported(din);
                op_pc <= pc;
                pc <= pc+16'd1;
                cycle <= 1;
            end else begin
                cycle <= cycle==last_cycle ? 4'd0 : cycle+4'd1;
                if(memory_op || unary_memory || jump || jsr) begin
                    if(cycle==1) begin
                        pc <= pc+16'd1;
                        case(mode)
                            0: high_byte <= din;
                            1: ea <= {8'd0,din};
                            2: ea <= x+{8'd0,din};
                            3: ea[15:8] <= din;
                        endcase
                    end
                    if(mode==3 && cycle==2) begin
                        pc <= pc+16'd1;
                        ea[7:0] <= din;
                    end
                end
                if(memory_op) begin
                    if(mode==0 && word_op && cycle==2) pc <= pc+16'd1;
                    if(!store_op && word_op && cycle==transfer_cycle) high_byte <= din;
                    if(cycle==last_cycle) begin
                        cc <= next_cc;
                        if(!store_op) begin
                            if(word_op) begin
                                if(operation==14) begin
                                    if(op[6]) x <= operand_word;
                                    else s <= operand_word;
                                end
                            end else if(operation!=1 && operation!=5) begin
                                if(op[6]) b <= result;
                                else a <= result;
                            end
                        end
                    end
                end else if(unary_memory) begin
                    if(cycle==operand_cycle) data8 <= din;
                    if(cycle==last_cycle) cc <= next_cc;
                end else if(jump || jsr) begin
                    if(cycle_wr) s <= s-16'd1;
                    if(cycle==last_cycle) pc <= mode==3 && cycle==2 ? {ea[15:8],din} : ea;
                end else if(branch || bsr) begin
                    if(cycle==1) begin
                        ea <= pc+16'd1+{{8{din[7]}},din};
                        pc <= pc+16'd1;
                    end
                    if(cycle_wr) s <= s-16'd1;
                    if(cycle==last_cycle && (bsr || branch_taken)) pc <= ea;
                end else if(unary_acc) begin
                    cc <= next_cc;
                    if(operation!=13) begin
                        if(op[4]) b <= result;
                        else a <= result;
                    end
                end else begin
                    case(op)
                        // FC compatibility only; absent from MC6802 manual, real-chip behavior/timing unknown.
                        8'hfc: if(cycle<=2) pc <= pc+16'd1;
                        8'h01:;
                        8'h06,8'h0a,8'h0b,8'h0c,8'h0d,8'h0e,8'h0f: cc <= next_cc;
                        8'h07: a <= result;
                        8'h10,8'h1b: begin a <= result; cc <= next_cc; end
                        8'h11: cc <= next_cc;
                        8'h16: begin b <= result; cc <= next_cc; end
                        8'h17,8'h19: begin a <= result; cc <= next_cc; end
                        8'h08,8'h09: if(cycle==3) begin
                            x <= op==8'h08 ? x+16'd1 : x-16'd1;
                            cc[2] <= op==8'h08 ? x==16'hffff : x==16'd1;
                        end
                        8'h30: if(cycle==3) x <= s+16'd1;
                        8'h31: if(cycle==3) s <= s+16'd1;
                        8'h34: if(cycle==3) s <= s-16'd1;
                        8'h35: if(cycle==3) s <= x-16'd1;
                        8'h36,8'h37: if(cycle==2) s <= s-16'd1;
                        8'h32,8'h33: if(cycle==3) begin
                            s <= s+16'd1;
                            if(op[0]) b <= din;
                            else a <= din;
                        end
                        8'h39: begin
                            if(cycle==3) begin high_byte <= din; s <= s+16'd1; end
                            if(cycle==4) begin pc <= {high_byte,din}; s <= s+16'd1; end
                        end
                        8'h3b: if(cycle>=3) begin
                            s <= s+16'd1;
                            case(cycle)
                                3: cc <= {2'b11,din[5:0]};
                                4: b <= din;
                                5: a <= din;
                                6,8: high_byte <= din;
                                7: x <= {high_byte,din};
                                9: pc <= {high_byte,din};
                                default:;
                            endcase
                        end
                        8'h3e,8'h3f: begin
                            if(cycle_wr) s <= s-16'd1;
                            if(op==8'h3e && cycle==8) waiting <= 1;
                            if(op==8'h3f) begin
                                if(cycle==9) cc[4] <= 1;
                                if(cycle==10) high_byte <= din;
                                if(cycle==11) pc <= {high_byte,din};
                            end
                        end
                        default: illegal <= 1;
                    endcase
                end
            end
        end
    end
end

`ifdef SIMULATION
always @(posedge clk) begin
    if(!rst && !cpu_rst && illegal) $fatal(1,"M6802 unsupported opcode %h at %h",op,op_pc);
end
`endif

m6802_reference_bus u_bus(
    .rst          ( rst        ),
    .abort        ( cpu_rst    ),
    .clk          ( clk        ),
    .cen          ( cen        ),
    .enable       ( enable     ),
    .ready        ( ready      ),
    .mr_n         ( mr_n       ),
    .cycle_active ( 1'b1       ),
    .cycle_vma    ( cycle_vma  ),
    .cycle_wr     ( cycle_wr   ),
    .cycle_addr   ( cycle_addr ),
    .cycle_dout   ( cycle_dout ),
    .e            ( e          ),
    .vma          ( vma        ),
    .wr           ( wr         ),
    .addr         ( addr       ),
    .dout         ( dout       ),
    .done         ( done       )
);

endmodule
