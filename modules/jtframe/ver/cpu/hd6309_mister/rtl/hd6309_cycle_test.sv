`ifndef MCTEST_TARGET_INSTRUCTIONS
`define MCTEST_TARGET_INSTRUCTIONS 99999975
`endif
`ifndef MCTEST_NATIVE_MODE
`define MCTEST_NATIVE_MODE 1
`endif

// Long batch cycle counter for HD6309 emulation and native instruction paths.
// Opcode PCs and expected intervals are independently checked by the companion
// Software result parser against the Atkinson timing manifest.
module hd6309_cycle_test #(
    parameter integer TARGET_INSTRUCTIONS = `MCTEST_TARGET_INSTRUCTIONS,
    parameter integer NATIVE_MODE = `MCTEST_NATIVE_MODE
) (
    input  wire        clk,
    input  wire        reset_n,
    input  wire [7:0]  result_word_addr,
    output reg  [31:0] result_word_data,
    output wire        test_done
);
    localparam integer SLOT_COUNT = 25;
    localparam [15:0] PC_INCE = 16'h0110;
    localparam [15:0] PC_TFR  = 16'h0112;
    localparam [15:0] PC_ADDR = 16'h0114;
    localparam [15:0] PC_LDD  = 16'h0117;
    localparam [15:0] PC_MULD = 16'h011A;
    localparam [15:0] PC_DIVD = 16'h011E;
    localparam [15:0] PC_DIVQ = 16'h0121;
    localparam [15:0] PC_LDW  = 16'h0125;
    localparam [15:0] PC_TFM  = 16'h0129;
    localparam [15:0] PC_BAND = 16'h012C;
    localparam [15:0] PC_AIM  = 16'h0130;
    localparam [15:0] PC_OIM  = 16'h0133;
    localparam [15:0] PC_EIM  = 16'h0136;
    localparam [15:0] PC_TIM  = 16'h013A;
    localparam [15:0] PC_LDE  = 16'h013D;
    localparam [15:0] PC_LDF  = 16'h013F;
    localparam [15:0] PC_LDWX = 16'h0141;
    localparam [15:0] PC_LDACW= 16'h0143;
    localparam [15:0] PC_LDAAF= 16'h0145;
    localparam [15:0] PC_LDAB0= 16'h0149;
    localparam [15:0] PC_LDACF= 16'h014D;
    localparam [15:0] PC_LDAD0= 16'h014F;
    localparam [15:0] PC_LDAEF= 16'h0151;
    localparam [15:0] PC_LDAF0= 16'h0153;
    localparam [15:0] PC_BRA  = 16'h0155;

    reg [1:0] phase;
    wire cen_E = phase == 2'b00;
    wire cen_Q = phase == 2'b10;
    reg done;
    wire cpu_cen_E = cen_E && !done;
    wire cpu_cen_Q = cen_Q && !done;
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) phase <= 2'b00;
        else          phase <= phase + 2'b01;
    end

    wire [7:0] cpu_dout;
    wire [15:0] cpu_addr;
    wire cpu_rnw, cpu_op;
    wire cpu_bs, cpu_ba, cpu_avma, cpu_busy, cpu_lic;
    wire [111:0] cpu_regs;
    wire [55:0] cpu_regs6309;
    reg [7:0] rom [0:255];
    reg [7:0] direct_mem [0:255];
    reg [7:0] ram_2000;
    reg [111:0] frozen_regs;
    reg [55:0] frozen_regs6309;
    reg [7:0] frozen_ram, frozen_40, frozen_10, frozen_42, frozen_41;
    reg snapshot_valid;
    integer init_index;

    initial begin
        for (init_index=0; init_index<256; init_index=init_index+1) begin
            rom[init_index] = 8'h12;
            direct_mem[init_index] = 8'h12;
        end
        // Setup: select MD, E=$11, F=0, X=$0010, Y=$0020.
        rom[8'h00]=8'h11; rom[8'h01]=8'h3d; rom[8'h02]=NATIVE_MODE ? 8'h01 : 8'h00;
        rom[8'h03]=8'h11; rom[8'h04]=8'h86; rom[8'h05]=8'h11;
        rom[8'h06]=8'h11; rom[8'h07]=8'hc6; rom[8'h08]=8'h00;
        rom[8'h09]=8'h8e; rom[8'h0a]=8'h00; rom[8'h0b]=8'h10;
        rom[8'h0c]=8'h10; rom[8'h0d]=8'h8e; rom[8'h0e]=8'h00; rom[8'h0f]=8'h20;
        // Fixed 25-instruction loop, beginning at $0110.
        rom[8'h10]=8'h11; rom[8'h11]=8'h4c;                         // INCE
        rom[8'h12]=8'h1f; rom[8'h13]=8'he8;                         // TFR E,A
        rom[8'h14]=8'h10; rom[8'h15]=8'h30; rom[8'h16]=8'hef;       // ADDR E,F
        rom[8'h17]=8'hcc; rom[8'h18]=8'h00; rom[8'h19]=8'h01;       // LDD #1
        rom[8'h1a]=8'h11; rom[8'h1b]=8'h8f; rom[8'h1c]=8'h00; rom[8'h1d]=8'h01; // MULD #1
        rom[8'h1e]=8'h11; rom[8'h1f]=8'h8d; rom[8'h20]=8'h01;       // DIVD #$01 (8-bit immediate)
        rom[8'h21]=8'h11; rom[8'h22]=8'h8e; rom[8'h23]=8'h00; rom[8'h24]=8'h01; // DIVQ #1
        rom[8'h25]=8'h10; rom[8'h26]=8'h86; rom[8'h27]=8'h00; rom[8'h28]=8'h00; // LDW #0
        rom[8'h29]=8'h11; rom[8'h2a]=8'h38; rom[8'h2b]=8'h12;       // TFM X+,Y+, W=0
        rom[8'h2c]=8'h11; rom[8'h2d]=8'h30; rom[8'h2e]=8'h40; rom[8'h2f]=8'h40; // BAND direct, A bit0 to memory bit0 at $40
        rom[8'h30]=8'h02; rom[8'h31]=8'h0f; rom[8'h32]=8'h40;       // AIM direct
        rom[8'h33]=8'h61; rom[8'h34]=8'h0f; rom[8'h35]=8'h84;       // OIM indexed ,X
        rom[8'h36]=8'h75; rom[8'h37]=8'h0f; rom[8'h38]=8'h00; rom[8'h39]=8'h42; // EIM extended
        rom[8'h3a]=8'h0b; rom[8'h3b]=8'h0f; rom[8'h3c]=8'h41;       // TIM direct
        rom[8'h3d]=8'ha6; rom[8'h3e]=8'h87;                         // LDA E,X
        rom[8'h3f]=8'ha6; rom[8'h40]=8'h8a;                         // LDA F,X
        rom[8'h41]=8'ha6; rom[8'h42]=8'h8e;                         // LDA W,X
        rom[8'h43]=8'ha6; rom[8'h44]=8'h8f;                         // LDA ,W
        rom[8'h45]=8'ha6; rom[8'h46]=8'haf; rom[8'h47]=8'h00; rom[8'h48]=8'h04; // LDA n,W
        rom[8'h49]=8'ha6; rom[8'h4a]=8'hb0; rom[8'h4b]=8'h00; rom[8'h4c]=8'h04; // LDA [n,W]
        rom[8'h4d]=8'ha6; rom[8'h4e]=8'hcf;                         // LDA ,W++
        rom[8'h4f]=8'ha6; rom[8'h50]=8'hd0;                         // LDA [,W++]
        rom[8'h51]=8'ha6; rom[8'h52]=8'hef;                         // LDA ,--W
        rom[8'h53]=8'ha6; rom[8'h54]=8'hf0;                         // LDA [,--W]
        rom[8'h55]=8'h20; rom[8'h56]=8'hb9;                         // BRA $0110
        // Distinct memory operands expose wrong effective addresses.
        direct_mem[8'h40]=8'ha5;
        direct_mem[8'h41]=8'ha5;
        direct_mem[8'h42]=8'ha5;
        direct_mem[8'h10]=8'ha5;
        direct_mem[8'h20]=8'h5a;
        direct_mem[8'h04]=8'h00; direct_mem[8'h05]=8'h20;
        direct_mem[8'h02]=8'h00; direct_mem[8'h03]=8'h20;
        direct_mem[8'h00]=8'h00; direct_mem[8'h01]=8'h20;
        rom[8'hfe]=8'h01; rom[8'hff]=8'h00; // reset vector $0100
    end

    function automatic [7:0] read_byte(input [15:0] address);
        begin
            if (address >= 16'h0100 && address <= 16'h01ff)
                read_byte = rom[address[7:0]];
            else if (address < 16'h0100)
                read_byte = direct_mem[address[7:0]];
            else if (address == 16'h2000)
                read_byte = ram_2000;
            else
                read_byte = 8'h12;
        end
    endfunction

    wire [7:0] cpu_din = read_byte(cpu_addr);
    mc6809i #(.HD6309(1)) u_cpu (
        .D(cpu_din), .DOut(cpu_dout), .ADDR(cpu_addr), .RnW(cpu_rnw),
        .clk(clk), .cen_E(cpu_cen_E), .cen_Q(cpu_cen_Q), .BS(cpu_bs), .BA(cpu_ba),
        .nIRQ(1'b1), .nFIRQ(1'b1), .nNMI(1'b1), .AVMA(cpu_avma),
        .BUSY(cpu_busy), .LIC(cpu_lic), .nHALT(1'b1), .nRESET(reset_n),
        .nDMABREQ(1'b1), .OP(cpu_op), .RegData(cpu_regs),
        .RegData6309(cpu_regs6309)
    );

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) ram_2000 <= 8'h00;
        else if (cpu_cen_Q && !cpu_rnw) begin
            if (cpu_addr == 16'h2000) ram_2000 <= cpu_dout;
            else if (cpu_addr < 16'h0100) direct_mem[cpu_addr[7:0]] <= cpu_dout;
        end
    end

    wire fetch_event = cpu_cen_E && cpu_op;
    reg running;
    assign test_done = snapshot_valid;
    reg [31:0] instruction_count, interval_cycles, total_cycles;
    reg [31:0] slot_count [0:SLOT_COUNT-1];
    reg [31:0] slot_cycles [0:SLOT_COUNT-1];
    reg [15:0] current_pc;
    reg [31:0] closed_cycles;
    integer i;

    function automatic integer pc_slot(input [15:0] pc_value);
        begin
            case (pc_value)
                PC_INCE: pc_slot=0; PC_TFR: pc_slot=1; PC_ADDR: pc_slot=2;
                PC_LDD: pc_slot=3; PC_MULD: pc_slot=4; PC_DIVD: pc_slot=5;
                PC_LDW: pc_slot=6; PC_DIVQ: pc_slot=7; PC_TFM: pc_slot=8;
                PC_BAND: pc_slot=9; PC_AIM: pc_slot=10; PC_OIM: pc_slot=11;
                PC_EIM: pc_slot=12; PC_TIM: pc_slot=13; PC_LDE: pc_slot=14;
                PC_LDF: pc_slot=15; PC_LDWX: pc_slot=16; PC_LDACW: pc_slot=17;
                PC_LDAAF: pc_slot=18; PC_LDAB0: pc_slot=19; PC_LDACF: pc_slot=20;
                PC_LDAD0: pc_slot=21; PC_LDAEF: pc_slot=22; PC_LDAF0: pc_slot=23;
                PC_BRA: pc_slot=24;
                default: pc_slot=-1;
            endcase
        end
    endfunction

    function automatic [15:0] slot_pc(input integer slot);
        begin
            case (slot)
                0:slot_pc=PC_INCE; 1:slot_pc=PC_TFR; 2:slot_pc=PC_ADDR;
                3:slot_pc=PC_LDD; 4:slot_pc=PC_MULD; 5:slot_pc=PC_DIVD;
                6:slot_pc=PC_LDW; 7:slot_pc=PC_DIVQ; 8:slot_pc=PC_TFM;
                9:slot_pc=PC_BAND; 10:slot_pc=PC_AIM; 11:slot_pc=PC_OIM;
                12:slot_pc=PC_EIM; 13:slot_pc=PC_TIM; 14:slot_pc=PC_LDE;
                15:slot_pc=PC_LDF; 16:slot_pc=PC_LDWX; 17:slot_pc=PC_LDACW;
                18:slot_pc=PC_LDAAF; 19:slot_pc=PC_LDAB0; 20:slot_pc=PC_LDACF;
                21:slot_pc=PC_LDAD0; 22:slot_pc=PC_LDAEF; 23:slot_pc=PC_LDAF0;
                default:slot_pc=PC_BRA;
            endcase
        end
    endfunction

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            running <= 1'b0;
            done <= 1'b0;
            instruction_count <= 0;
            interval_cycles <= 0;
            total_cycles <= 0;
            current_pc <= 0;
            for (i=0; i<SLOT_COUNT; i=i+1) begin
                slot_count[i] <= 0;
                slot_cycles[i] <= 0;
            end
        end else if (!done) begin
            if (running && cpu_cen_E) interval_cycles <= interval_cycles + 1'b1;
            if (fetch_event) begin
                if (!running) begin
                    if (cpu_addr == PC_INCE) begin
                        running <= 1'b1;
                        current_pc <= cpu_addr;
                        interval_cycles <= 0;
                    end
                end else if (!(cpu_addr == current_pc + 16'd1 &&
                    ((current_pc == PC_INCE) || (current_pc == PC_ADDR) ||
                     (current_pc == PC_MULD) || (current_pc == PC_DIVD) ||
                     (current_pc == PC_LDW) || (current_pc == PC_DIVQ) ||
                     (current_pc == PC_TFM) || (current_pc == PC_BAND)))) begin
                    closed_cycles = interval_cycles + 1'b1;
                    instruction_count <= instruction_count + 1'b1;
                    total_cycles <= total_cycles + closed_cycles;
                    if (pc_slot(current_pc) >= 0) begin
                        slot_count[pc_slot(current_pc)] <= slot_count[pc_slot(current_pc)] + 1'b1;
                        slot_cycles[pc_slot(current_pc)] <= slot_cycles[pc_slot(current_pc)] + closed_cycles;
                    end
                    if (instruction_count + 1'b1 >= TARGET_INSTRUCTIONS) begin
                        done <= 1'b1;
                        running <= 1'b0;
                    end else begin
                        current_pc <= cpu_addr;
                        interval_cycles <= 0;
                    end
                end
            end
        end
    end

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            frozen_regs <= 112'b0;
            frozen_regs6309 <= 56'b0;
            frozen_ram <= 8'b0; frozen_40 <= 8'b0; frozen_10 <= 8'b0;
            frozen_42 <= 8'b0; frozen_41 <= 8'b0;
            snapshot_valid <= 1'b0;
        end else if (done && !snapshot_valid) begin
            frozen_regs <= cpu_regs;
            frozen_regs6309 <= cpu_regs6309;
            frozen_ram <= ram_2000;
            frozen_40 <= direct_mem[8'h40]; frozen_10 <= direct_mem[8'h10];
            frozen_42 <= direct_mem[8'h42]; frozen_41 <= direct_mem[8'h41];
            snapshot_valid <= 1'b1;
        end
    end

    // JTMT v1 header plus 25 PC records and 13 frozen result words.
    always @* begin
        result_word_data=32'h0;
        case (result_word_addr)
            0:result_word_data=32'h544D544A; 1:result_word_data=32'd1;
            2:result_word_data={30'b0,snapshot_valid,running}; 3:result_word_data=32'd96;
            4:result_word_data=NATIVE_MODE; 5:result_word_data=TARGET_INSTRUCTIONS;
            6:result_word_data=instruction_count; 7:result_word_data=total_cycles;
            83:result_word_data={24'b0,frozen_ram}; 84:result_word_data=frozen_regs[31:0];
            85:result_word_data={16'b0,frozen_regs[47:32]}; 86:result_word_data={16'b0,frozen_regs[63:48]};
            87:result_word_data={16'b0,frozen_regs[79:64]}; 88:result_word_data={16'b0,frozen_regs[95:80]};
            89:result_word_data={16'b0,frozen_regs[111:96]}; 90:result_word_data=frozen_regs6309[31:0];
            91:result_word_data={8'b0,frozen_regs6309[55:32]};
            92:result_word_data={24'b0,frozen_40}; 93:result_word_data={24'b0,frozen_10};
            94:result_word_data={24'b0,frozen_42}; 95:result_word_data={24'b0,frozen_41};
            default: begin
                if (result_word_addr>=8 && result_word_addr<83) begin
                    case ((result_word_addr-8)%3)
                        0:result_word_data={16'b0,slot_pc((result_word_addr-8)/3)};
                        1:result_word_data=slot_count[(result_word_addr-8)/3];
                        2:result_word_data=slot_cycles[(result_word_addr-8)/3];
                    endcase
                end
            end
        endcase
    end
endmodule
