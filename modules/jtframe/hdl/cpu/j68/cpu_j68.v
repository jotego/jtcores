// Copyright 2011-2018 Frederic Requin
//
// The J68 core:
// -------------
// Simple re-implementation of the MC68000 CPU
// The core has the following characteristics:
//  - Tested on a Cyclone III (90 MHz) and a Stratix II (180 MHz)
//  - from 1500 (~70 MHz) to 1900 LEs (~90 MHz) on Cyclone III
//  - 2048 x 20-bit microcode ROM
//  - 256 x 28-bit decode ROM
//  - 2 x block RAM for the data and instruction stacks
//  - stack based CPU with forth-like microcode
//  - not cycle-exact : needs a frequency ~3 x higher
//  - all 68000 instructions are implemented
//  - almost all 68000 exceptions are implemented (only bus error missing)
//  - only auto-vector interrupts supported

module cpu_j68
(
    // Clock and reset
    input         rst,          // CPU reset
    input         clk,          // CPU clock
    /* direct_enable = 1 */ input clk_ena, // CPU clock enable
    // Bus interface
    output        rd_ena,       // Read strobe
    output        wr_ena,       // Write strobe
    input         data_ack,     // Data acknowledge
    output [1:0]  byte_ena,     // Byte enable
    output [31:0] address,      // Address bus
    input  [15:0] rd_data,      // Data bus in
    output [15:0] wr_data,      // Data bus out
    // 68000 control
    output [2:0]  fc,           // Function code
    input  [2:0]  ipl_n,        // Interrupt level
    // 68000 debug
    output [3:0]  dbg_reg_addr, // Register address
    output [3:0]  dbg_reg_wren, // Register write enable
    output [15:0] dbg_reg_data, // Register write data
    output [15:0] dbg_sr_reg,   // Status register
    output [31:0] dbg_pc_reg,   // Program counter
    output [31:0] dbg_usp_reg,  // User stack pointer
    output [31:0] dbg_ssp_reg,  // Supervisor stack pointer
    output [31:0] dbg_vbr_reg,  // Vector base register
    output [31:0] dbg_cycles,   // Cycles counter
    output        dbg_ifetch,   // Instruction fetch
    output  [2:0] dbg_irq_lvl   // Interrupt level
);
    parameter USE_CLK_ENA = 0;

    // ALU operations
    localparam [4:0]
        ALU_ADD     = 5'b00000,
        ALU_ADDC    = 5'b00001,
        ALU_SUB     = 5'b00010,
        ALU_SUBC    = 5'b00011,
        ALU_AND     = 5'b00100,
        ALU_BAND    = 5'b10100,
        ALU_OR      = 5'b00101,
        ALU_BOR     = 5'b10101,
        ALU_XOR     = 5'b00110,
        ALU_BXOR    = 5'b10110,
        ALU_NOT     = 5'b00111,
        ALU_BNOT    = 5'b10111,
        ALU_SHL     = 5'b01000,
        ALU_SHR     = 5'b01100,
        ALU_DIV     = 5'b01110,
        ALU_MUL     = 5'b01111;

    // ALU inputs
    localparam [1:0]
        A_ADD_ZERO  = 2'b00,
        A_ADD_T     = 2'b10,
        A_ADD_NOT_T = 2'b11,
        B_ADD_ZERO  = 2'b00,
        B_ADD_N     = 2'b10,
        B_ADD_NOT_N = 2'b11,
        A_LOG_ZERO  = 2'b00,
        A_LOG_IMM   = 2'b01,
        A_LOG_T     = 2'b10,
        A_LOG_RAM   = 2'b11,
        B_LOG_ZERO  = 2'b00,
        B_LOG_IO    = 2'b01,
        B_LOG_N     = 2'b10,
        B_LOG_NOT_N = 2'b11;

    reg                 r_rst_dly;  // Delayed reset signal

    wire [19:0]         w_inst_in;  // Internal RAM instruction read
    wire                w_ram_rd;   // Internal RAM read
    reg                 r_ram_rd;   // Internal RAM read (delayed)
    wire                w_ram_wr;   // Internal RAM write
    wire [1:0]          w_ram_bena; // Internal RAM byte enable
    wire [10:0]         w_ram_addr; // Internal RAM address
    wire [15:0]         w_ram_din;  // Internal RAM data write
    wire [15:0]         w_ram_dout; // Internal RAM data read
    wire                w_ram_rdy;  // RAM data ready

    wire                w_reg_wr;   // CPU register write
    wire [1:0]          w_reg_bena; // CPU register byte enable
    wire [10:0]         w_reg_addr; // CPU register address

    reg  [11:0]         w_alu_c;    // ALU control (wire)
    reg  [10:0]         w_flg_c;    // Flags control (wire)
    reg  [3:0]          w_cin_c;    // Carry in control (wire)

    reg  [3:0]          r_ds_ptr;   // Data stack pointer (reg)
    reg  [3:0]          w_ds_nxt;   // Next data stack pointer (wire)
    wire [3:0]          w_ds_inc;   // Data stack pointer increment (wire)
    reg  [15:0]         r_ds[0:15]; // Data stack (regs)
    reg  [15:0]         r_ds_T;     // Data stack output T (reg)
    wire [15:0]         w_ds_N;     // Data stack output N (wire)
    wire [31:0]         w_ds_R;     // Data stack input : ALU result (wire)
    reg                 w_ds_wr;    // Data stack write enable (wire)

    wire                w_ifetch;   // Fetch next instruction
    wire [10:0]         w_pc_inc;   // PC value incremented by 1 (wire)
    reg  [10:0]         r_pc_reg;   // PC register (reg)
    reg  [10:0]         w_pc_nxt;   // Next PC value (wire)
    wire [10:0]         w_pc_loop;  // PC value for loop (wire)

    reg  [3:0]          r_rs_ptr;   // Return stack pointer (reg)
    reg  [3:0]          w_rs_nxt;   // Next return stack pointer (wire)
    reg  [10:0]         r_rs[0:15]; // Return stack (regs)
    wire [10:0]         w_rs_q;     // Return stack output (wire)
    reg  [10:0]         w_rs_d;     // Return stack input (wire)
    reg                 w_rs_wr;    // Return stack write enable (wire)
    reg                 w_rs_rd;    // Return stack read enable (wire)

    // Micro-instruction decode
    wire        w_io_op   = (w_inst_in[19:17] == 3'b100)  ? 1'b1 : 1'b0;
    wire        w_reg_op  = (w_inst_in[19:17] == 3'b101)  ? 1'b1 : 1'b0;
    wire        w_t_mode  = (w_inst_in[15:12] == 4'b1111) ? 1'b1 : 1'b0;
    wire        w_branch;
    wire [3:0]  w_loop_cnt;
    wire        w_loop;
    wire        w_skip;

    // ALU <-> Flags
    wire [31:0] w_res;
    wire [3:0]  w_alu;
    wire [1:0]  w_size;
    wire [4:0]  w_c_flg;
    wire [5:0]  w_v_flg;
    wire [10:0] w_sr;
    wire [4:0]  w_ccr;
    wire        w_c_in;
    wire        w_z_flg;
    wire        w_g_flg;

    // Memory access
    wire        w_io_rd;    // I/O register read
    wire        w_io_wr;    // I/O register write
    wire        w_io_ext;   // External memory access
    wire        w_io_rdy;   // I/O data ready
    wire        w_io_end;   // End of I/O cycle
    wire [15:0] w_io_din;   // I/O data input
    wire [10:0] w_io_flg_c; // Flag control (for SR write)

    // M68k instruction decoder
    wire [15:0] w_insw;     // Instruction word
    wire [15:0] w_extw;     // Extension word
    wire [15:0] w_ea1b;     // Effective address #1 bitfield

    // Debug
    reg  [31:0] r_usp_reg;
    reg  [31:0] r_ssp_reg;
    reg  [31:0] r_cycles;
    reg         r_go_super;
    reg   [2:0] r_irq_lvl;
    wire        w_super_st;

    // Delayed reset
    always@(posedge clk) begin : RESET_DLY
        if (clk_ena) r_rst_dly <= rst;
    end

    // RAM access
    assign w_ram_rd   = w_reg_op & w_inst_in[7] & ~w_ram_rdy;
    assign w_ram_addr = w_reg_addr;
    assign w_ram_bena = w_reg_bena & { w_reg_wr, w_reg_wr };
    assign w_ram_din  = r_ds_T;
    assign w_ram_rdy  = (w_reg_op & w_inst_in[6]) | r_ram_rd;

    always@(posedge clk) begin : RAM_READ
        if (clk_ena) r_ram_rd <= w_ram_rd;
    end

    // Debug
    assign dbg_reg_addr    = (w_reg_wr) ? w_reg_addr[4:1] : 4'b0000;
    assign dbg_reg_wren[3] = w_reg_wr & w_reg_addr[5] & w_reg_addr[0] & w_reg_bena[1];
    assign dbg_reg_wren[2] = w_reg_wr & w_reg_addr[5] & w_reg_addr[0] & w_reg_bena[0];
    assign dbg_reg_wren[1] = w_reg_wr & w_reg_addr[5] & ~w_reg_addr[0] & w_reg_bena[1];
    assign dbg_reg_wren[0] = w_reg_wr & w_reg_addr[5] & ~w_reg_addr[0] & w_reg_bena[0];
    assign dbg_reg_data    = (w_reg_wr) ? r_ds_T : 16'h0000;
    assign dbg_sr_reg      = { (w_sr & 11'b1010_0111_000) , w_ccr};
    assign dbg_usp_reg     = r_usp_reg;
    assign dbg_ssp_reg     = r_ssp_reg;
    assign dbg_vbr_reg     = 32'h00000000;
    assign dbg_cycles      = r_cycles;
    assign dbg_irq_lvl     = r_irq_lvl;
    assign w_super_st      = w_sr[8] | r_go_super;

    always @(posedge rst or posedge clk) begin : CPU_DEBUG

        if (rst) begin
            r_usp_reg  <= 32'd0;
            r_ssp_reg  <= 32'd0;
            r_cycles   <= 32'd0;
            r_go_super <= 1'b0;
            r_irq_lvl  <= 3'd0;
        end
        else if (clk_ena) begin
            // Stack pointers access
            if (w_reg_wr) begin
                // USP low word
                if ((w_reg_addr[5:0] == 6'b011100) ||
                    ((w_reg_addr[5:0] == 6'b111110) && (!w_super_st))) begin
                    r_usp_reg[15:0] <= r_ds_T;
                end
                // USP high word
                if ((w_reg_addr[5:0] == 6'b011101) ||
                    ((w_reg_addr[5:0] == 6'b111111) && (!w_super_st))) begin
                    r_usp_reg[31:16] <= r_ds_T;
                end
                // SSP low word
                if ((w_reg_addr[5:0] == 6'b011110) ||
                    ((w_reg_addr[5:0] == 6'b111110) && (w_super_st))) begin
                    r_ssp_reg[15:0] <= r_ds_T;
                end
                // SSP high word
                if ((w_reg_addr[5:0] == 6'b011111) ||
                    ((w_reg_addr[5:0] == 6'b111111) && (w_super_st))) begin
                    r_ssp_reg[31:16] <= r_ds_T;
                end
            end

            // Number of cycles
            r_cycles <= r_cycles + 32'd1;

            if (USE_CLK_ENA == 1) begin
                // We will enter supervisor state
                if (w_sr[8]) begin
                    r_go_super <= 1'b0;
                end
                else if ((r_pc_reg >= 11'h014) && (r_pc_reg <= 11'h044)) begin
                    r_go_super <= 1'b1;
                end

                // Interrupt acknowledge
                if (r_pc_reg == 11'h016) begin
                    r_irq_lvl <= ~ipl_n;
                end
                // Interrupt clear
                else if (ipl_n == 3'b111) begin
                    r_irq_lvl <= 3'd0;
                end
            end
            else begin
                // We will enter supervisor state
                if (w_sr[8]) begin
                    r_go_super <= 1'b0;
                end
                else if ((r_pc_reg >= 11'h015) && (r_pc_reg <= 11'h045)) begin
                    r_go_super <= 1'b1;
                end

                // Interrupt acknowledge
                if (r_pc_reg == 11'h017) begin
                    r_irq_lvl <= ~ipl_n;
                end
                // Interrupt clear
                else if (ipl_n == 3'b111) begin
                    r_irq_lvl <= 3'd0;
                end
            end
        end
    end

    // I/O access
    assign w_io_wr   = ~w_inst_in[8] & w_inst_in[6] & w_io_op;
    assign w_io_rd   = ~w_inst_in[8] & w_inst_in[7] & w_io_op & ~w_io_rdy;
    assign w_io_ext  = w_inst_in[8] & w_io_op & ~w_io_rdy;
    assign w_io_end  = w_io_rdy | w_io_wr;


    // PC calculation
    assign w_pc_inc  = r_pc_reg + 11'd1;

    always @(*) begin : PC_CALC

        if (rst) begin
            w_pc_nxt = 11'h000;
        end
        else begin
            case (w_inst_in[19:17])
                // LOOP instruction
                3'b000 : begin
                    if (w_skip) begin
                        // Null loop count
                        w_pc_nxt = w_inst_in[10:0];
                    end
                    else begin
                        // First instruction of the loop
                        w_pc_nxt = w_pc_inc;
                    end
                end
                // JUMP/CALL instruction
                3'b001 : begin
                    if (w_branch) begin
                        // Branch taken
                        w_pc_nxt = w_inst_in[10:0] | (r_ds_T[10:0] & {11{w_t_mode}});
                    end
                    else begin
                        // Branch not taken
                        w_pc_nxt = w_pc_inc;
                    end
                end
                // Rest of instruction
                default : begin
                    if (w_inst_in[16]) begin
                        // With RTS
                        w_pc_nxt = w_rs_q;
                    end
                    else begin
                        if (w_loop) begin
                            // Jump to start of loop
                            w_pc_nxt = w_pc_loop;
                        end
                        else begin
                            // Following instruction
                            w_pc_nxt = w_pc_inc;
                        end
                    end
                end
            endcase
        end
    end

    assign w_ifetch = ((w_io_end | w_ram_rdy | (~w_io_op & ~w_reg_op) | r_rst_dly) & ~rst);

    always @(posedge rst or posedge clk) begin : PC_REG

        if (rst) begin
            r_pc_reg <= 11'h7FF;
        end
        else if (clk_ena) begin
            if (w_ifetch) r_pc_reg <= w_pc_nxt;
        end
    end


    // Return stack pointer calculation
    always @(*) begin : RS_PTR_CALC

        if (w_inst_in[19:17] == 3'b001) begin
            if (w_inst_in[16]) begin
                // "JUMP" instruction
                w_rs_nxt = r_rs_ptr;
                w_rs_d   = r_pc_reg;
                w_rs_wr  = 1'b0;
                w_rs_rd  = 1'b0;
            end
            else begin
                // "CALL" instruction
                w_rs_nxt = r_rs_ptr - 4'd1;
                w_rs_d   = w_pc_inc;
                w_rs_wr  = 1'b1;
                w_rs_rd  = 1'b0;
            end
        end
        else begin
            if ((w_inst_in[16]) && (w_ifetch)) begin
                // Embedded "RTS"
                w_rs_nxt = r_rs_ptr + 4'd1;
                w_rs_d   = r_pc_reg;
                w_rs_wr  = 1'b0;
                w_rs_rd  = 1'b1;
            end
            else begin
                // No "RTS"
                w_rs_nxt = r_rs_ptr;
                w_rs_d   = r_pc_reg;
                w_rs_wr  = 1'b0;
                w_rs_rd  = 1'b0;
            end
        end
    end

    // Return stack
    always @(posedge rst or posedge clk) begin : RS_PTR_REG

        if (rst) begin
            r_rs_ptr <= 4'd0;
        end
        else if (clk_ena) begin
            // Latch the return stack pointer
            r_rs_ptr <= w_rs_nxt;
            if (w_rs_wr) r_rs[w_rs_nxt] <= w_rs_d;
        end
    end
    // Return stack output value
    assign w_rs_q = r_rs[r_rs_ptr];

    assign w_ds_inc = {{3{w_inst_in[13]}}, w_inst_in[12]};

    // ALU parameters and data stack update
    always@(*) begin : ALU_DS_PTR_CALC

        case(w_inst_in[19:17])
            // LOOP
            3'b000 : begin
                // Generate a "DROP" or a "NOP"
                w_alu_c[11:10] = 2'b01;              // Operand size
                w_alu_c[9]     = 1'b0;               // CCR update
                w_alu_c[8:4]   = ALU_OR;             // ALU operation
                // Data stack update if "LOOP T"
                if (w_inst_in[11]) begin
                    // DROP
                    w_alu_c[3:2] = A_LOG_ZERO;       // A = 0x0000
                    w_alu_c[1:0] = B_LOG_N;          // B = Next on stack
                    w_ds_nxt     = r_ds_ptr - 4'd1;
                end
                else begin
                    // NOP
                    w_alu_c[3:2] = A_LOG_T;          // A = Top of stack
                    w_alu_c[1:0] = B_LOG_ZERO;       // B = 0x0000
                    w_ds_nxt     = r_ds_ptr;
                end
                w_ds_wr        = 1'b0;
            end
            // CALL, JUMP
            3'b001 : begin
                // Generate a "DROP" or a "NOP"
                w_alu_c[11:10] = 2'b01;              // Operand size
                w_alu_c[9]     = 1'b0;               // CCR update
                w_alu_c[8:4]   = ALU_OR;             // ALU operation
                // Data stack update if "JUMP (T)" or "CALL (T)"
                if (w_t_mode) begin
                    // DROP
                    w_alu_c[3:2] = A_LOG_ZERO;       // A = 0x0000
                    w_alu_c[1:0] = B_LOG_N;          // B = Next on stack
                    w_ds_nxt     = r_ds_ptr - 4'd1;
                end
                else begin
                    // NOP
                    w_alu_c[3:2] = A_LOG_T;          // A = Top of stack
                    w_alu_c[1:0] = B_LOG_ZERO;       // B = 0x0000
                    w_ds_nxt     = r_ds_ptr;
                end
                w_ds_wr        = 1'b0;
            end
            // LIT
            3'b010 : begin
                w_alu_c[11:10] = 2'b01;              // Operand size
                w_alu_c[9]     = 1'b0;               // CCR update
                w_alu_c[8:4]   = ALU_OR;             // ALU operation
                w_alu_c[3:2]   = A_LOG_IMM;          // A = Immediate value
                w_alu_c[1:0]   = B_LOG_ZERO;         // B = 0x0000
                // Data stack update
                w_ds_nxt       = r_ds_ptr + 4'd1;
                w_ds_wr        = 1'b1;
            end
            // FLAG
            3'b011 : begin
                // Generate a "NOP"
                w_alu_c[11:10] = 2'b01;              // Operand size
                w_alu_c[9]     = 1'b0;               // CCR update
                w_alu_c[8:4]   = ALU_OR;             // ALU operation
                w_alu_c[3:2]   = A_LOG_T;            // A = Top of stack
                w_alu_c[1:0]   = B_LOG_ZERO;         // B = 0x0000
                // No data stack update
                w_ds_nxt       = r_ds_ptr;
                w_ds_wr        = 1'b0;
            end
            // I/O reg. access
            3'b100 : begin
                w_alu_c[11:10] = 2'b01;              // Operand size
                w_alu_c[9]     = w_inst_in[9];       // CCR update
                w_alu_c[8:4]   = ALU_OR;             // ALU operation
                if (w_inst_in[7]) begin
                    if (w_ds_inc[0]) begin
                        // I/O register load
                        w_alu_c[3:2] = A_LOG_ZERO;   // A = 0x0000
                        w_alu_c[1:0] = B_LOG_IO;     // B = I/O data
                    end
                    else begin
                        // I/O register fetch
                        w_alu_c[3:2] = A_LOG_T;      // A = Top of stack
                        w_alu_c[1:0] = B_LOG_ZERO;   // B = 0x0000
                    end
                end
                else begin
                    if (w_ds_inc[0]) begin
                        // I/O register store
                        w_alu_c[3:2] = A_LOG_ZERO;   // A = 0x0000
                        w_alu_c[1:0] = B_LOG_N;      // B = Next on stack
                    end
                    else begin
                        // I/O register write
                        w_alu_c[3:2] = A_LOG_T;      // A = Top of stack
                        w_alu_c[1:0] = B_LOG_ZERO;   // B = 0x0000
                    end
                end
                // Data stack update
                w_ds_nxt       = r_ds_ptr + w_ds_inc;
                w_ds_wr        = w_inst_in[14];
            end
            // M68k reg. access
            3'b101 : begin
                w_alu_c[11:10] = 2'b01;              // Operand size
                w_alu_c[9]     = w_inst_in[9];       // CCR update
                w_alu_c[8:4]   = ALU_OR;             // ALU operation
                if (w_inst_in[7]) begin
                    // M68k register load
                    w_alu_c[3:2] = A_LOG_RAM;        // A = RAM data
                    w_alu_c[1:0] = B_LOG_ZERO;       // B = 0x0000
                end
                else begin
                    if (w_ds_inc[0]) begin
                        // M68k register store
                        w_alu_c[3:2] = A_LOG_ZERO;   // A = 0x0000
                        w_alu_c[1:0] = B_LOG_N;      // B = Next on stack
                    end
                    else begin
                        // M68k register write
                        w_alu_c[3:2] = A_LOG_T;      // A = Top of stack
                        w_alu_c[1:0] = B_LOG_ZERO;   // B = 0x0000
                    end
                end
                // Data stack update
                w_ds_nxt       = r_ds_ptr + w_ds_inc;
                w_ds_wr        = w_inst_in[14];
            end
            // ALU operation
            3'b110 : begin
                w_alu_c[11:10] = w_inst_in[11:10];   // Operand size
                w_alu_c[9]     = w_inst_in[9];       // CCR update
                w_alu_c[8:4]   = w_inst_in[8:4];     // ALU operation
                w_alu_c[3:2]   = w_inst_in[3:2];     // A source
                w_alu_c[1:0]   = w_inst_in[1:0];     // B source
                // Data stack update
                w_ds_nxt       = r_ds_ptr + w_ds_inc;
                w_ds_wr        = w_inst_in[14];
            end
            default : begin
                // Generate a "NOP"
                w_alu_c[11:10] = 2'b01;              // Operand size
                w_alu_c[9]     = 1'b0;               // CCR update
                w_alu_c[8:4]   = ALU_OR;             // ALU operation
                w_alu_c[3:2]   = A_LOG_T;            // A = Top of stack
                w_alu_c[1:0]   = B_LOG_ZERO;         // B = 0x0000
                // No data stack update
                w_ds_nxt       = r_ds_ptr;
                w_ds_wr        = 1'b0;
            end
        endcase
    end

    // Data stack
    always @(posedge rst or posedge clk) begin : DS_PTR_REG

        if (rst) begin
            r_ds_ptr <= 4'd0;
            r_ds_T   <= 16'h0000;
        end
        else if (clk_ena) begin
            if ((w_io_end) || (w_ram_rdy) || (!(w_io_op | w_reg_op))) begin
                // Latch the data stack pointer
                r_ds_ptr <= w_ds_nxt;
                // Latch the data stack value T
                r_ds_T   <= w_ds_R[15:0];
                // Latch the data stack value N
                if (w_ds_wr) r_ds[w_ds_nxt] <= w_ds_R[31:16];
            end
        end
    end
    // Data stack output value #1 (N)
    assign w_ds_N = r_ds[r_ds_ptr];


    // Flags control
    always@(*) begin : FLAGS_CTRL

        if (w_inst_in[19:17] == 3'b011) begin
            // Update flags
            w_flg_c = w_inst_in[10:0];
            w_cin_c = w_inst_in[14:11];
        end
        else begin
            // Keep flags
            w_flg_c = w_io_flg_c;
            w_cin_c = 4'b0000;
        end
    end


    // 16/32-bit ALU
    j68_alu U_alu
    (
        .rst        (rst),
        .clk        (clk),
        .clk_ena    (clk_ena),
        .size       (w_alu_c[11:10]),
        .cc_upd     (w_alu_c[9]),
        .alu_c      (w_alu_c[8:4]),
        .a_ctl      (w_alu_c[3:2]),
        .b_ctl      (w_alu_c[1:0]),
        .c_in       (w_c_in),
        .v_in       (w_ccr[1]),
        .a_src      (r_ds_T),
        .b_src      (w_ds_N),
        .ram_in     (w_ram_dout),
        .io_in      (w_io_din),
        .imm_in     (w_inst_in[15:0]),
        .result     (w_ds_R),
        .c_flg      (w_c_flg),
        .v_flg      (w_v_flg[4:0]),
        .l_res      (w_res),
        .l_alu      (w_alu),
        .l_size     (w_size)
    );


    // Flags update
    j68_flags U_flags
    (
        .rst        (rst),
        .clk        (clk),
        .clk_ena    (clk_ena),
        .c_flg      (w_c_flg),
        .v_flg      (w_v_flg),
        .l_res      (w_res),
        .l_alu      (w_alu),
        .l_size     (w_size),
        .a_src      (r_ds_T),
        .b_src      (w_ds_N),
        .flg_c      (w_flg_c),
        .cin_c      (w_cin_c),
        .cc_out     (w_ccr),
        .c_in       (w_c_in),
        .z_flg      (w_z_flg),
        .g_flg      (w_g_flg)
    );


    // Conditional Jump/Call
    j68_test U_test
    (
        .inst_in    (w_inst_in),
        .flg_in     ({w_g_flg, w_res[15], w_z_flg, w_c_flg[1]}),
        .sr_in      ({w_sr, w_ccr}),
        .a_src      (r_ds_T),
        .ea1b       (w_ea1b),
        .extw       (w_extw),
        .branch     (w_branch)
    );


    // Hardware loop
    j68_loop U_loop
    (
        .rst        (rst),
        .clk        (clk),
        .clk_ena    (clk_ena),
        .inst_in    (w_inst_in),
        .i_fetch    (w_ifetch),
        .a_src      (r_ds_T[5:0]),
        .pc_in      (w_pc_nxt),
        .pc_out     (w_pc_loop),
        .branch     (w_loop),
        .skip       (w_skip),
        .lcount     (w_loop_cnt)
    );


    // Bus interface
    j68_mem_io
    #(
        .USE_CLK_ENA (USE_CLK_ENA)
    )
    U_mem_io
    (
        .rst        (rst),
        .clk        (clk),
        .clk_ena    (clk_ena),
        .rd_ena     (rd_ena),
        .wr_ena     (wr_ena),
        .data_ack   (data_ack),
        .byte_ena   (byte_ena),
        .address    (address),
        .rd_data    (rd_data),
        .wr_data    (wr_data),
        .fc         (fc),
        .ipl_n      (ipl_n),
        .io_rd      (w_io_rd),
        .io_wr      (w_io_wr),
        .io_ext     (w_io_ext),
        .io_reg     (w_reg_op),
        .io_rdy     (w_io_rdy),
        .io_din     (w_io_din),
        .io_dout    (r_ds_T),
        .inst_in    (w_inst_in),
        .cc_upd     (w_alu_c[9]),
        .alu_op     (w_alu_c[7:4]),
        .a_src      (r_ds_T),
        .b_src      (w_ds_N),
        .v_flg      (w_v_flg[5]),
        .insw       (w_insw),
        .extw       (w_extw),
        .ea1b       (w_ea1b),
        .ccr_in     (w_ccr),
        .sr_out     (w_sr),
        .flg_c      (w_io_flg_c),
        .loop_cnt   (w_loop_cnt),
        .reg_addr   (w_reg_addr[5:0]),
        .reg_wr     (w_reg_wr),
        .reg_bena   (w_reg_bena),
        .dbg_pc     (dbg_pc_reg),
        .dbg_if     (dbg_ifetch)
    );
    assign w_reg_addr[10:6] = 5'b11111;

    // Microcode ROM : 2048 x 20-bit
    j68_dpram_2048x20
    #(
        .RAM_INIT_FILE ((USE_CLK_ENA) ? "j68_ram_c.mem" : "j68_ram.mem")
    )
    U_j68_dpram_2048x20
    (
        // Reset and clock
        .clock     (clk),
        .clocken   (clk_ena),
        // Port A : micro-instruction fetch
        .rden_a    (w_ifetch),
        .address_a (w_pc_nxt),
        .q_a       (w_inst_in),
        // Port B : m68k registers read/write
        .wren_b    (w_ram_bena),
        .address_b (w_ram_addr),
        .data_b    (w_ram_din),
        .q_b       (w_ram_dout)
    );

endmodule
