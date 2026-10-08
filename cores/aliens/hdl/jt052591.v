/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */

// Konami 052591 programmable processor. Instruction decoding and datapath
// derived from Furrtek's silicon RE (Konami/052591 in SiliconRE).
// cen is the M12 enable; pin 21 is grounded on the normal configuration,
// giving one instruction every two cen pulses. clk must run at least 4x M12
// to accommodate the synchronous program and external RAMs.
module jt052591(
    input             rst,
    input             clk,
    input             cen,

    input             cs,
    input             cpu_we,
    input      [12:0] cpu_addr,
    input      [ 7:0] cpu_dout,
    input      [ 7:0] cpu_ram_dout,
    output     [ 7:0] cpu_din,
    output            cpu2ram_we,

    output     [12:0] ram_addr,
    output     [ 7:0] ram_din,
    output            ram_we,
    output            ram_oe,
    input      [ 7:0] ram_dout,

    input             bk,       // 0=program/configuration, 1=external RAM
    input             start,    // level-sensitive RUN, not a start pulse
    output reg        out0,
    output     [ 7:0] st_dout
);

reg  [31:8] load_data;
wire [35:0] prog_data, ir;
wire [ 5:0] prog_addr;
reg  [ 5:0] load_pc, pc, ret;
reg  [ 2:0] load_byte;
reg         pc_lock, host_wr_l, run, phase;
wire        host_wr, load_wr, prog_we, execute;

reg  [15:0] gpr[0:7];
reg  [15:0] acc;
wire [15:0] reg_a, reg_b, pre_mux, alu_a, ax, bx;
reg  [15:0] alu_b;
wire [15:0] prop, gen, result, reg_result, acc_result, ext;
wire [16:0] carry;
wire [ 2:0] source;
wire        inv_a, force_prop, arithmetic, cin, overflow;
reg         div_sub, div_mux;
reg  [ 7:0] ram_msb;
reg         condition;
reg  [ 5:0] next_pc;

reg  [12:0] ext_addr;
reg  [ 7:0] ext_data;
reg         oe_n, we_n;
wire [12:0] next_addr;
wire [ 7:0] next_data;
integer k;
genvar bitno;

// A CPU write may last many clk cycles. Capture each bus transaction once.
assign host_wr    = cs && cpu_we;
assign load_wr    = host_wr && !host_wr_l && !start && !run && !bk;
assign prog_we    = load_wr && !cpu_addr[9] && load_byte==3'd4 && !rst;
assign prog_data  = {cpu_dout[3:0],load_data,ram_msb};
assign prog_addr  = start && run ? pc : (pc_lock ? 6'd0 : load_pc);
assign cpu2ram_we = host_wr && bk && !start && !run && !rst;
// The die schematic gates external reads with BK (CPU_ERAM, sheet 3).
// Program RAM is write-only; a deselected data bus reads as pull-ups here.
assign cpu_din    = cs && bk && !start && !run ? cpu_ram_dout : 8'hff;
assign execute   = cen && phase && run && start;
assign st_dout   = {pc, !out0, run};

assign reg_a     = gpr[ir[11:9]];
assign reg_b     = gpr[ir[14:12]];
assign pre_mux   = ir[35] && ir[15] ? {{3{ir[28]}},ir[28:16]} :
                  ir[35]          ? {8'd0,ram_dout} : {ram_msb,ram_dout};
// The previous instruction's 33:32 controls the iterative multiply/divide
// datapath. These are not ordinary saved condition flags.
assign source    = {ir[2],ir[1] | (div_mux && !acc[0]),ir[0]};
assign alu_a     = source[2] && (source[0] || source[1]) ? pre_mux :
                  !source[2] && !source[1] ? reg_a : 16'd0;
assign inv_a     = ir[3] | div_sub;
assign ax        = alu_a ^ {16{inv_a}};
assign bx        = alu_b ^ {16{ir[4]}};
assign cin       = ir[33:32]==2'b01 ? inv_a : (!ir[15] && ir[34]);
assign force_prop= (ir[5] && !ir[4]) || (!ir[5] && ir[4] && inv_a);
assign arithmetic= !ir[5] && !(ir[4] && inv_a);
assign prop      = ax | bx | {16{force_prop}};
assign gen       = ax & bx;
assign carry[0]  = cin;
// Keep the carry network active for logical instructions too: its output
// still drives the carry/overflow branch conditions on the original chip.
generate for(bitno=0;bitno<16;bitno=bitno+1) begin : alu_bits
    assign carry[bitno+1] = gen[bitno] | (prop[bitno] && carry[bitno]);
    assign result[bitno] = prop[bitno] ^ gen[bitno] ^ ir[5] ^
                          (arithmetic && carry[bitno]);
end endgenerate
assign overflow  = carry[16] ^ (arithmetic && carry[15]);
assign reg_result= !ir[8] ? result : ir[7] ?
                  {result[14:0],ir[33] ? 1'b0 : acc[15]} :
                  {ir[33] ? (result[15]^overflow) : cin,result[15:1]};
assign acc_result= !ir[8] ? result : ir[7] ?
                  {acc[14:0],ir[33] ? 1'b0 : !result[15]} :
                  {ir[33] ? result[0] : cin,acc[15:1]};
assign ext       = ir[8:6]==3'b010 ? reg_a : result;
assign next_addr = ir[31:30]==2'b10 ? ext[12:0] : ext_addr;
assign next_data = !ir[31] ? (ir[30] ? ext[15:8] : ext[7:0]) : ext_data;
assign ram_addr  = ext_addr;
assign ram_din   = ext_data;
assign ram_we    = execute && !ir[29] && !we_n && !rst;
assign ram_oe    = run && start && !ir[29] && !oe_n && !rst;

always @* begin
    // Only the A-input selector uses the iterative division modifier.
    case(ir[2:0])
        0,2,6: alu_b = acc;
        1,3:   alu_b = reg_b;
        4,5:   alu_b = reg_a;
        7:     alu_b = 0;
    endcase
    case(ir[23:22])
        0: condition = result==0;
        1: condition = carry[16];
        2: condition = overflow;
        3: condition = result[15];
    endcase
    next_pc = pc+6'd1;
    if(!ir[15] && (ir[26] || condition)) begin
        case(ir[25:24])
            0,1: next_pc = ir[21:16];
            2:   next_pc = ret;
            3:   next_pc = ir[26] ? load_pc : pc+6'd1;
        endcase
    end
end

always @(posedge clk) begin
    if(rst) begin
        host_wr_l <= 0;
        load_pc   <= 0;
        load_byte <= 0;
        load_data <= 0;
        pc_lock   <= 1;
    end else begin
        host_wr_l <= host_wr;
        if(load_wr) begin
            if(cpu_addr[9]) begin
                load_pc   <= cpu_dout[5:0];
                pc_lock   <= cpu_dout[7];
                load_byte <= 0;
            end else begin
                case(load_byte)
                    1: load_data[15: 8] <= cpu_dout;
                    2: load_data[23:16] <= cpu_dout;
                    3: load_data[31:24] <= cpu_dout;
                    default:;
                endcase
                if(load_byte==4) begin
                    load_byte <= 0;
                    load_pc   <= load_pc+6'd1;
                end else load_byte <= load_byte+3'd1;
            end
        end
    end
end

always @(posedge clk) begin
    if(rst) begin
        run           <= 0;
        phase         <= 0;
        pc            <= 0;
        ret           <= 0;
        acc           <= 0;
        div_sub       <= 0;
        div_mux       <= 0;
        ram_msb       <= 0;
        out0          <= 1;
        ext_addr      <= 0;
        ext_data      <= 0;
        oe_n          <= 1;
        we_n          <= 1;
        for(k=0;k<8;k=k+1) gpr[k] <= 0;
    end else begin
        // The silicon shares the first upload-byte latch with the external
        // RAM high-byte latch; preserve this even across partial uploads.
        if(load_wr && !cpu_addr[9] && load_byte==0) ram_msb <= cpu_dout;
        if(!start) begin
            run     <= 0;
            phase   <= 0;
            pc      <= load_pc;
            out0    <= 1;
            oe_n    <= 1;
            we_n    <= 1;
        end else if(cen) begin
            run   <= 1;
            phase <= !phase;
            if(!run) pc <= load_pc;
            if(execute) begin
                pc       <= next_pc;
                // The return latch captures PC+1 even for an untaken call.
                if(!ir[15] && ir[25:24]==0) ret <= pc+6'd1;
                div_sub  <= ir[33:32]==2'b01 && !result[15];
                div_mux  <= &ir[33:32];
                if(!ir[35] && !ir[15]) ram_msb <= ram_dout;
                if(ir[8] || ir[7]) gpr[ir[14:12]] <= reg_result;
                if(!ir[6] && (ir[8] || !ir[7])) acc <= acc_result;
                if(ir[15] && !ir[34]) out0 <= ir[16];
                ext_addr <= next_addr;
                ext_data <= next_data;
                // The RAM samples the existing address/data latches on
                // this edge, before the EXT bus updates them. Its control
                // likewise comes from the previous control instruction.
                if(!ir[15]) begin
                    oe_n <= ir[28];
                    we_n <= ir[27];
                end
            end
        end
    end
end

jtframe_ram #(.DW(36),.AW(6)) u_program(
    .clk    ( clk       ),
    .cen    ( 1'b1      ),
    .data   ( prog_data ),
    .addr   ( prog_addr ),
    .we     ( prog_we   ),
    .q      ( ir        )
);


endmodule
