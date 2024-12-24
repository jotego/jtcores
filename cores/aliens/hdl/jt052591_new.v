/*  This file is part of JTCORES.
    JTCORES program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTCORES program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTCORES.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 15-4-2023 */

// Programmable custom chip used in Thunder Force, S.P.Y. and Helix
// The main CPU writes the program to its internal RAM
// Based on Furrtek's RE work
// https://github.com/furrtek/SiliconRE/tree/master/Konami/052591

module jt052591(
    input             rst,
    input             clk,
    input             cen,

    // CPU interface
    input             cs,
    input             cpu_we,
    input      [12:0] cpu_addr,
    input      [ 7:0] cpu_dout,
    output reg [ 7:0] cpu_din,
    output            cpu2ram_we,

    // RAM. Called E(xternal) or ER (External RAM) in the pinout
    output reg        ram_we,
    output     [10:0] ram_addr, // real chip has 12:0, but 12,11 are NC in sch.
    input      [ 7:0] ram_dout,
    output reg [ 7:0] ram_din,

    // original pin names
    input             bk,       // 0=internal RAM, 1=external RAM
    output reg        out0,     // connected to PCMFIRQ in Thunder Cross
    input             start,    // triggers the programmed process
    // Debug
    output    [ 7:0]  st_dout
);

// CPU registers
reg  [15:0] acc, a, b;
reg  [15:0] gpr[0:7];   // general purpose registers
reg  [ 5:0] pc, ret;
reg         run;
// Program code
reg  [ 5:0] iwa;
reg  [35:0] iram[0:63];
reg  [ 4:0] prog_sub; // hot one encoding for active byte during iram programming
wire        iw;
// ALU
reg  [15:0] op1;
wire        n,z,v,c;
// control
wire [15:0] rslt;
wire [ 2:0] bra_sel, a_sel, b_sel;
wire [ 5:0] bra_pc;
wire [ 1:0] cc_sel, ram_sel;
wire [ 1:0] sh_sel;
wire        bra_set, bra_enb, out_en,
            ram_en, ram_rd, ram_we,
            alt;
reg         ram_rdl, ram_wel;
wire [ 5:0] nx_pc;
reg         cc_ok;

assign iw = cpu_we && cs && bk;
assign ext_mux =  ir[8:6]==3'b010 ? a : rslt;
assign a_sel
assign sz      =~(ir[35] & ~alt); // 1 = 16-bit, 0=8-bit operation
assign out_en  =  ir[34] &  alt;
// assign ???  =  ir[34] & ~alt;
// assign rot? =  ir[33];
// assign arith?  ir[32];
assign ram_sel =  ir[31:30];
assign ram_en  = ~ir[29] & run; // 28, 27 = ram rd/we
assign bra_set =  ir[26];
assign bra_sel =  ir[25:24];
assign cc_sel  =  ir[23:22];
assign bra_pc  =  ir[21:16];
assign alt     =  ir[15];
assign b_sel   =  ir[14:12];
assign a_sel   =  ir[11:9];
assign sh_sel  =  ir[ 8:7];
assign acc_wr  =  ir[6];    // also gated by ir[8:7]
assign alu_ctl =  ir[5:3];
assign ir[2:0] =  ir[2:0];
assign bra_en  = ~alt;
assign ram_rd  = ram_en & ram_rdl;
assign ram_we  = ram_en & ram_wel;
assign nx_pc   = pc+6'd1;
assign bra_ok  = cc_ok | bra_set;

always @* begin
    // Pre- Shift/rotate
    casez( sh_sel )
        2'b0?: rot = rslt;
        2'b10: rot = {ir[33] ? rslt[0] : CIN0, acc[15:1]}; // rotate (ir[33]) or shift right
        2'b11: rot = {rslt[14:0], ir[33] ? 1'b0 : ~rslt[15]}; // shift left (ir[33]) or odd rotate left
    endcase
    // CC evaluation for branching
    case( cc_sel )
        0: cc_ok = z;
        1: cc_ok = c;
        2: cc_ok = v;
        3: cc_ok = n;
    endcase
end

always @(posedge clk,posedge rst) begin
    if( rst ) begin
        pc       <= 0;
        pc0      <= 0;
        ret      <= 0;
        run      <= 0;
        ram_din  <= 0;
        ram_addr <= 0;
        out0     <= 1;
        ram_rd   <= 0;
        ram_we   <= 0;
    end else begin
        if( ~iwl & iw & cpu_addr[9]) begin
            pc <= cpu_dout[7] ? 6'd0 : cpu_dout[5:0];
            if(!cpu_dout[7]) pc0 <= cpu_dout[5:0];
        end
        if( cen ) begin
            run    <= start;
            ir     <= iram[pc];
            a      <= gpr[a_sel];
            b      <= gpr[b_sel];
            if( ~alt ) begin
                ram_rd <= ~ir[28];
                ram_we <= ~ir[27];
            end
            case( ram_sel )
                0: ram_din  <= ext_mux[ 7:0];
                1: ram_din  <= ext_mux[15:8];
                2: ram_addr <= ext_mux[12:0];
                default:;
            endcase
            case( ir[8:6] )
                0: acc <= rslt;
            endcase
            if( out_en ) out0 <= ir[16];
            // PC
            pc <= nx_pc;
            if( bra_en ) case( bra_sel )
                0: begin ret <= nx_pc; if( bra_ok ) pc <= bra_pc; end // CALL cc,addr
                1: if( bra_ok  ) pc <= bra_pc;                        // JUMP cc,addr
                2: if( bra_ok  ) pc <= ret;                           // RET  cc
                3: if( bra_set ) pc <= pc0;
            endcase
            if( !run ) pc <= pc;
        end
    end
end

always @(posedge clk,posedge rst) begin
    if( rst ) begin
        prog_sub <= 1;
        iwa      <= 0;
    end else begin
        iwl <= iw;
        if( ~iwl & iw &  cpu_addr[9]) iwa <= 0;
        if( ~iwl & iw & ~cpu_addr[9]) begin
            prog_sub <= { prog_sub[3:0], prog_sub[4] };
            if( prog_sub[4] ) iwa <= iwa+6'd1;
            case( prog_sub )
                5'b1<<0: iram[iwa][ 7: 0] <= cpu_dout;
                5'b1<<1: iram[iwa][15: 8] <= cpu_dout;
                5'b1<<2: iram[iwa][23:16] <= cpu_dout;
                5'b1<<3: iram[iwa][31:24] <= cpu_dout;
                5'b1<<4: iram[iwa][35:32] <= cpu_dout;
            endcase
        end
    end
end

assign alu_a_mux = (ir[35] & alt) ? {{4{ir[28]}}, ir[27:16]} : {iram_din[7:0], D_MUX[7:0]};
assign op0 = J89 ? {8'd0, alu_a_mux[7:0]} : alu_a_mux;

always @(*) begin
    case(op1_sel)
        0: op1 = acc;
        1: op1 = regb;
        2: op1 = acc;
        3: op1 = regb;
        4: op1 = rega;
        5: op1 = rega;
        6: op1 = acc;
        7: op1 = 0;
    endcase
    if( ir[4] ) op1 = ~op1;
end

jt052591_alu u_alu(
    .sel    (alu_ctl),      // operation selection IR[5:3]
    .op0    ( op0   ),
    .op1    ( op1   ),
    .rslt   ( rslt  ),
    .c      ( c     ),
    .v      ( v     ),
    .n      ( n     ),
    .z      ( z     )
);

endmodule

module jt052591_alu(
    input      [ 2:0] sel,      // operation selection IR[5:3]
    input      [15:0] op0,
    input      [15:0] op1,
    // input             sz,
    output reg [15:0] rslt,
    output            c,
    output            v,
    output            n,
    output            z
);
    // always 16-bit results
    assign z = rslt==0;
    assign n = rslt[15];

    always @* begin
        c = 0;
        v = 0;
        case( sel )
            0,1: begin
                { c, rslt } = {1'b0,op0}+{1'b0,op1}; // 1 ADC?
                v = &{op0[15],op1[15],~rslt[15]} | &{~op0[15],~op1[15],rslt[15]};
            end
            2: begin
                { c, rslt } = {1'b0,op0}-{1'b0,op1};
                v = &{op0[15],~op1[15],~rslt[15]} | &{~op0[15],op1[15],rslt[15]};
            end
            3: rslt = op0 | op1;
            4: rslt = op0 & op1;
            default: begin
                $display("Unknown ALU operation");
                $finish;
            end
        endcase
    end

endmodule