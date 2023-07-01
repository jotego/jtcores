// Copyright 2011-2018 Frederic Requin
//
// This file is part of the MCC216 project
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

module j68_mem_io
(
    // Clock and reset
    input             rst,      // CPU reset
    input             clk,      // CPU clock
    /* direct_enable = 1 */ input clk_ena, // CPU clock enable
    // Outside bus interface
    output            rd_ena,   // Read strobe
    output            wr_ena,   // Write strobe
    input             data_ack, // Data acknowledge
    output      [1:0] byte_ena, // Byte enable
    output     [31:0] address,  // Address bus
    input      [15:0] rd_data,  // Data bus in
    output     [15:0] wr_data,  // Data bus out
    // 68000 control
    output      [2:0] fc,       // Function code
    input       [2:0] ipl_n,    // Interrupt level
    // I/O bus
    input             io_rd,    // I/O read strobe from J68 micro-core
    input             io_wr,    // I/O write strobe from J68 micro-core
    input             io_ext,   // External memory access
    input             io_reg,   // Read/write to CPU register
    output            io_rdy,   // Data ready to J68 micro-core
    output     [15:0] io_din,   // Data to J68 micro-core
    input      [15:0] io_dout,  // Data from J68 micro-core
    input      [19:0] inst_in,  // Microcode word
    // ALU interface (MUL/DIV)
    input             cc_upd,   // Condition codes update
    input      [3:0]  alu_op,   // ALU operation
    input      [15:0] a_src,    // A source
    input      [15:0] b_src,    // B source
    output            v_flg,    // V flag from divide
    // Decoder data
    output     [15:0] insw,     // Instruction word
    output     [15:0] extw,     // Extension word
    output     [15:0] ea1b,     // EA #1 bitfield
    // Status register
    input      [4:0]  ccr_in,   // XNZVC 68000 flags
    output     [10:0] sr_out,   // Status register
    output     [10:0] flg_c,    // Flag output control
    // Register access
    input      [3:0]  loop_cnt, // Loop count for MOVEM
    output reg [5:0]  reg_addr, // Register address
    output reg        reg_wr,   // Register write enable
    output reg [1:0]  reg_bena, // Register byte enable
    // Debug
    output     [31:0] dbg_pc,   // Program counter
    output            dbg_if    // Instruction fetch
);
    parameter USE_CLK_ENA = 0;

    reg  [15:1] r_vec_addr;     // Vector address (reg)
    reg  [31:0] r_pc_addr;      // Program counter (reg)
    reg  [31:0] r_ea1_addr;     // Effective address #1 (reg)
    reg  [31:0] r_ea2_addr;     // Effective address #2 (reg)
    reg         r_v_flg;        // Overflow flag from divide
    reg  [10:0] r_flg_c;        // Flag output control
    reg   [7:0] r_cpu_sr;       // Status register high byte (reg)
    wire  [2:0] w_int_nr;       // Interrupt number (wire)
    wire        w_cc_jump;      // Condition code jump flag (wire)
    wire [31:0] w_vec_addr;     // Vector address (wire)
    
    reg  [15:0] r_md_lsh;       // MUL/DIV left shifter (reg)
    reg  [31:0] r_md_acc;       // MUL/DIV accumulator (reg)
    wire [31:0] w_md_val;       // Multiplier/Divisor (wire)
    wire [31:0] w_md_res;       // MUL/DIV partial result (wire)
    wire        w_borrow;       // Subtract borrow
    
    reg         r_io_rdy;       // Data ready to J68 micro-core
    reg  [15:0] r_io_din;       // Data to J68 micro-core
    reg  [15:0] r_ins_word;     // Instruction word
    wire        w_ins_rdy;      // Instruction word ready
    reg  [15:0] r_ext_word;     // Extension word
    wire        w_ext_rdy;      // Extension word ready
    reg  [15:0] r_imm_word;     // Immediate word
    wire        w_imm_rdy;      // Immediate word ready
    wire [15:0] w_imm_val;      // Immediate value
    wire [11:0] w_dec_jump;     // Decoder call address
    wire  [3:0] w_ea1_jump;     // EA #1 jump table index
    wire  [3:0] w_ea2_jump;     // EA #2 jump table index

    reg         r_io_ext;       // Delayed io_ext
    reg  [31:0] r_address;      // Address bus
    reg   [2:0] r_fc;           // Function code
    reg         r_mem_rd;       // Memory read (reg)
    reg         r_rd_ena;       // Read strobe
    reg         r_mem_wr;       // Memory write (reg)
    reg         r_wr_ena;       // Write strobe
    reg   [1:0] r_byte_ena;     // Byte enable
    reg  [15:0] r_wr_data;      // Data bus out
    reg         r_mem_err;      // Address error during data access (reg)
    reg  [31:0] r_err_addr;     // Address that caused an address error (reg)
    reg  [15:0] r_err_inst;     // Opcode executed during an address error (reg)
    reg   [4:0] r_err_cpu;      // CPU state during an address error (reg)
    reg  [31:0] w_mem_addr;     // Memory address (wire)
    reg  [2:0]  w_mem_inc;      // Memory address increment (wire)
    wire        w_sp_inc;       // Memory increment for stack access (wire)
    wire  [3:0] w_loop_cnt;     // Loop count for MOVEM
    reg   [1:0] r_ctr;

    assign dbg_pc = r_pc_addr;

    assign w_sp_inc = ((r_ins_word[2:0]  == 3'b111) && (inst_in[1:0] == 2'b00)) // EA1 with A7
                   || ((r_ins_word[11:9] == 3'b111) && (inst_in[1:0] == 2'b01)) // EA2 with A7
                    ? 1'b1 : 1'b0;
  
    // Address MUX and increment
    always@(*) begin : MEM_ADDR_MUX
        case (inst_in[1:0]) // addr field
            2'b00 : w_mem_addr = r_ea1_addr; // Read/write EA1 data
            2'b01 : w_mem_addr = r_ea2_addr; // Read/write EA2 data
            2'b10 : w_mem_addr = r_pc_addr;  // Fetch instruction
            2'b11 : w_mem_addr = w_vec_addr; // Fetch vector
        endcase
        case ({inst_in[10]|inst_in[11], inst_in[3:2]}) // size & incr fields
            // No increment, byte
            3'b000 : w_mem_inc = 3'b000;
            // Post increment, word (stack) / byte
            3'b001 : w_mem_inc = (w_sp_inc) ? 3'b010 : 3'b001;
            // Pre decrement, word (stack) / byte
            3'b010 : w_mem_inc = (w_sp_inc) ? 3'b110 : 3'b111;
            // Pre increment, word (stack) / byte
            3'b011 : w_mem_inc = (w_sp_inc) ? 3'b010 : 3'b001;
            // No increment, word
            3'b100 : w_mem_inc = 3'b000;
            // Post increment, word
            3'b101 : w_mem_inc = 3'b010;
            // Pre decrement, word
            3'b110 : w_mem_inc = 3'b110;
            // Pre increment, word
            3'b111 : w_mem_inc = 3'b010;
        endcase
    end
    assign w_vec_addr = { 8'b0, r_vec_addr[15:10], 8'b0, r_vec_addr[9:1], 1'b0 };

    // Registers read
    always@(posedge rst or posedge clk) begin : REG_READ
    
        if (rst) begin
            r_ins_word <= 16'h0000;
            r_ext_word <= 16'h0000;
            r_imm_word <= 16'h0000;
            r_io_din   <= 16'h0000;
            r_io_rdy   <= 1'b0;
            r_ctr      <= 2'b00;
        end
        else if (clk_ena) begin
            if (io_rd) begin
                case (inst_in[3:0])
                    // Effective address #1
                    4'b0000 : r_io_din <= r_ea1_addr[15:0];
                    4'b0001 : r_io_din <= r_ea1_addr[31:16];
                    // Effective address #2
                    4'b0010 : r_io_din <= r_ea2_addr[15:0];
                    4'b0011 : r_io_din <= r_ea2_addr[31:16];
                    // Program
                    4'b0100 : r_io_din <= r_pc_addr[15:0];
                    4'b0101 : r_io_din <= r_pc_addr[31:16];
                    // Vectors
                    4'b0110 :
                    begin
                        r_io_din <= { 5'b00000, r_vec_addr[4:2], 8'h00 };
                        r_ctr    <= 2'b00;
                    end
                    // CPU state
                    4'b0111 :
                    begin
                        case (r_ctr)
                            2'b00 : r_io_din <= r_err_inst;
                            2'b01 : r_io_din <= r_err_addr[15:0];
                            2'b10 : r_io_din <= r_err_addr[31:16];
                            2'b11 : r_io_din <= {11'b0, r_err_cpu };
                        endcase
                        r_ctr <= r_ctr + 2'd1;
                    end
                    // Immediate value
                    4'b1000 : r_io_din <= w_imm_val;
                    // MUL/DIV left shifter
                    4'b1001 : r_io_din <= r_md_lsh;
                    // MUL/DIV accumulator
                    4'b1010 : r_io_din <= r_md_acc[15:0];
                    4'b1011 : r_io_din <= r_md_acc[31:16];
                    // Jump table indexes
                    4'b1100 : r_io_din <= {  4'd0, w_dec_jump };
                    4'b1101 : r_io_din <= { 12'd0, w_ea1_jump };
                    4'b1110 : r_io_din <= { 12'd0, w_ea2_jump };
                    // Status register : T-S--III---XNZVC
                    4'b1111 : r_io_din <= { r_cpu_sr[7], 1'b0, r_cpu_sr[5], 2'b00, r_cpu_sr[2:0], 3'b000, ccr_in };
                    default : r_io_din <= 16'h0000;
                endcase
            end
            else if ((r_mem_rd) && (data_ack)) begin
                // Memory read
                case ({ inst_in[11:10], address[0] })
                    // Byte, even addr. :    ---            use
                    3'b000 : r_io_din <= {  rd_data[7:0], rd_data[15:8] };
                    // Byte, odd addr.  :    ---            use
                    3'b001 : r_io_din <= { rd_data[15:8],  rd_data[7:0] };
                    // Word, even addr. :    use            use
                    3'b010 : r_io_din <= { rd_data[15:8],  rd_data[7:0] };
                    // Word, odd addr.  :      !! exception !!
                    3'b011 : r_io_din <= { rd_data[15:8],  rd_data[7:0] };
                    // LSB, even addr.  :    ---            use
                    3'b100 : r_io_din <= {  8'b0000_0000, rd_data[15:8] };
                    // LSB, odd addr.   :    ---            use
                    3'b101 : r_io_din <= {  8'b0000_0000,  rd_data[7:0] };
                    // MSB, even addr.  :    use            ---
                    3'b110 : r_io_din <= { rd_data[15:8],  8'b0000_0000 };
                    // MSB, odd addr.   :    use            ---
                    3'b111 : r_io_din <= {  rd_data[7:0],  8'b0000_0000 };
                endcase
                // Instruction fetch
                if (inst_in[1:0] == 2'b10) begin
                    case (inst_in[3:2])
                        2'b00   : r_ins_word <= rd_data; // Fetching instruction
                        2'b01   : r_ext_word <= rd_data; // Fetching extension word
                        default : r_imm_word <= rd_data; // Fetching immediate data
                    endcase
                end
            end
            else begin
                r_io_din <= 16'h0000;
            end
            // Ready signal for register read, memory read and write
            r_io_rdy <= io_rd | (r_mem_rd & data_ack) | (r_mem_wr & data_ack) | r_mem_err;
        end
    end
  
    assign io_rdy = r_io_rdy;
    assign io_din = r_io_din;
  
    // Status bits for the test module : T-SaeIII--b
    assign sr_out[10]  = r_cpu_sr[7];           // Trace
    assign sr_out[9]   = 1'b0;                  // Not used
    assign sr_out[8]   = r_cpu_sr[5];           // Supervisor
    assign sr_out[7]   = r_cpu_sr[4]|r_mem_err; // Address error (internal)
    assign sr_out[6]   = r_cpu_sr[3]|r_cpu_sr[4]|r_mem_err; // Exception (internal)
    assign sr_out[5:3] = r_cpu_sr[2:0];         // Interrupt level
    assign sr_out[2:1] = 2'b00;                 // Not used
    assign sr_out[0]   = w_cc_jump;             // Branch flag

    // Registers writes
    always@(posedge rst or posedge clk) begin : REG_WRITE
    
        if (rst) begin
            r_vec_addr    <= 15'd0;
            r_pc_addr     <= 32'd0;
            r_ea1_addr    <= 32'd0;
            r_ea2_addr    <= 32'd0;
            r_md_lsh      <= 16'd0;
            r_md_acc      <= 32'd0;
            r_v_flg       <= 1'b0;
            r_cpu_sr      <= 8'b00100111;
            r_flg_c       <= 11'b00_00_000_00_00;
        end
        else if (clk_ena) begin
            if (io_wr) begin
                case (inst_in[3:0])
                    // Effective address #1 (and #2 for RMW cycles)
                    4'b0000 : begin
                        r_ea1_addr[15:0]  <= io_dout;
                        r_ea2_addr[15:0]  <= io_dout;
                    end
                    4'b0001 : begin
                        r_ea1_addr[31:16] <= io_dout;
                        r_ea2_addr[31:16] <= io_dout;
                    end
                    // Effective address #2
                    4'b0010 : r_ea2_addr[15:0]  <= io_dout;
                    4'b0011 : r_ea2_addr[31:16] <= io_dout;
                    // Program
                    4'b0100 : r_pc_addr[15:0]   <= io_dout;
                    4'b0101 : r_pc_addr[31:16]  <= io_dout;
                    // Vectors
                    4'b0110 : begin
                        r_vec_addr  <= io_dout[15:1];
                        r_cpu_sr[4] <= 1'b0; // Clear address error
                    end
                    4'b0111 : ; // No VBR on 68000, vector address is 9-bit long !
                    // MUL/DIV left shifer
                    4'b1001 : r_md_lsh          <= io_dout;
                    // MUL/DIV accumulator
                    4'b1010 : r_md_acc[15:0]    <= io_dout;
                    4'b1011 : r_md_acc[31:16]   <= io_dout;
                    // Status register
                    4'b1111 : begin
                        // MSB (word write)
                        if (inst_in[10]) begin
                            r_cpu_sr[7]   <= io_dout[15];   // Trace
                            r_cpu_sr[6]   <= 1'b0;
                            r_cpu_sr[5]   <= io_dout[13];   // Supervisor
                            r_cpu_sr[2:0] <= io_dout[10:8]; // Interrupt mask
                        end
                        // LSB
                        r_flg_c[10] <= 1'b1;
                        r_flg_c[9]  <= io_dout[4];    // Extend flag
                        r_flg_c[8]  <= 1'b1;
                        r_flg_c[7]  <= io_dout[3];    // Negative flag
                        r_flg_c[6]  <= 1'b0;
                        r_flg_c[5]  <= 1'b1;
                        r_flg_c[4]  <= io_dout[2];    // Zero flag
                        r_flg_c[3]  <= 1'b1;
                        r_flg_c[2]  <= io_dout[1];    // Overflow flag
                        r_flg_c[1]  <= 1'b1;
                        r_flg_c[0]  <= io_dout[0];    // Carry flag
                    end
                    default : ;
                endcase
            end
            else begin
                r_flg_c <= 11'b00_00_000_00_00;
                
                // Memory control
                if ((io_ext) && (!r_io_ext)) begin
                    // Auto-increment/decrement
                    case (inst_in[1:0]) // addr field
                        2'b00 : r_ea1_addr <= r_ea1_addr + { {29{w_mem_inc[2]}}, w_mem_inc };
                        2'b01 : r_ea2_addr <= r_ea2_addr + { {29{w_mem_inc[2]}}, w_mem_inc };
                        2'b10 : r_pc_addr  <= r_pc_addr  + 32'd2;
                        2'b11 : r_vec_addr[9:1] <= r_vec_addr[9:1] + 9'd1;
                    endcase
                end
                
                // Multiply/divide step (right shift special)
                if (alu_op[3:1] == 3'b111) begin
                    // Accumulator
                    if ((alu_op[0]) || (w_borrow)) begin
                        r_md_acc <= w_md_res;
                    end
                    // Left shifter
                    r_md_lsh <= { r_md_lsh[14:0], w_borrow };
                    // V flag
                    if (cc_upd) r_v_flg <= r_md_lsh[15];
                end
                
                // Interrupts management
                if (((w_int_nr > r_cpu_sr[2:0]) || (w_int_nr == 3'd7)) && (w_int_nr >= r_vec_addr[4:2]) && (r_vec_addr[9:5] == 5'b00011)) begin
                    r_cpu_sr[3] <= 1'b1;
                    r_vec_addr[9:1] <= { 5'b00011, w_int_nr, 1'b0 };
                end
                else begin
                    r_cpu_sr[3] <= r_cpu_sr[4] | r_cpu_sr[7]; // Address error or trace mode
                end
                
                // Latch address error flag
                if (r_mem_err) r_cpu_sr[4] <= 1'b1;
            end
        end
    end
  
    assign v_flg = r_v_flg;
    assign flg_c = r_flg_c;
  
    // Interrupt number
    assign w_int_nr = ~ipl_n;
  
    // Multiply/divide step
    assign w_md_val = (r_md_lsh[15]) || (!alu_op[0]) ? { b_src, a_src } : 32'd0;
    j68_addsub_32 U_addsub
    (
        .add_sub (alu_op[0]),
        .dataa   (r_md_acc),
        .datab   (w_md_val),
        .cout    (w_borrow),
        .result  (w_md_res)
    );
  
    // Debug : instruction fetch signal
    assign dbg_if = (inst_in[3:0] == 4'b0010) ? io_ext & ~r_io_ext : 1'b0;

    // Memory access
    always@(posedge rst or posedge clk) begin : MEM_READ_WRITE
    
        if (rst) begin
            r_io_ext   <= 1'b0;
            r_address  <= 32'd0;
            r_fc       <= 3'b100;
            r_mem_rd   <= 1'b0;
            r_rd_ena   <= 1'b0;
            r_mem_wr   <= 1'b0;
            r_wr_ena   <= 1'b0;
            r_byte_ena <= 2'b00;
            r_mem_err  <= 1'b0;
            r_err_addr <= 32'd0;
            r_err_inst <= 16'h0000;
            r_err_cpu  <= 5'b00000;
            r_wr_data  <= 16'h0000;
        end
        else if (clk_ena) begin
            // Delayed io_ext
            r_io_ext <= io_ext;
            // Memory address and data output
            if ((io_ext) && (!r_io_ext) && ((!inst_in[3]) || (inst_in[1]))) begin
                // No or Post increment
                r_address <= w_mem_addr;
                // Function code
                r_fc[2] <= r_cpu_sr[5];         // 0 : User, 1 : Supervisor
                case (inst_in[1:0])
                    2'b00 : r_fc[1:0] <= 2'b01; // EA1    : data
                    2'b01 : r_fc[1:0] <= 2'b01; // EA2    : data
                    2'b10 : r_fc[1:0] <= 2'b10; // PC     : program
                    2'b11 : r_fc[1:0] <= 2'b11; // Vector : CPU
                endcase
                // Memory write
                case ({ inst_in[11:10], w_mem_addr[0] })
                    // Byte, even addr. :     ---            use
                    3'b000 : r_wr_data <= {  io_dout[7:0], io_dout[15:8] };
                    // Byte, odd addr.  :     ---            use
                    3'b001 : r_wr_data <= { io_dout[15:8],  io_dout[7:0] };
                    // Word, even addr. :     use            use
                    3'b010 : r_wr_data <= { io_dout[15:8],  io_dout[7:0] };
                    // Word, odd addr.  :      !! exception !!
                    3'b011 : r_wr_data <= { io_dout[15:8],  io_dout[7:0] };
                    // LSB, even addr.  :    use            ---
                    3'b100 : r_wr_data <= {  io_dout[7:0], io_dout[15:8] };
                    // LSB, odd addr.   :    ---            use
                    3'b101 : r_wr_data <= { io_dout[15:8],  io_dout[7:0] };
                    // MSB, even addr.  :    use            ---
                    3'b110 : r_wr_data <= { io_dout[15:8],  io_dout[7:0] };
                    // MSB, odd addr.   :    ---            use
                    3'b111 : r_wr_data <= {  io_dout[7:0], io_dout[15:8] };
                endcase
            end
            else if ((r_io_ext) && (inst_in[3]) && (!inst_in[1])) begin
                // Pre decrement/increment
                r_address <= w_mem_addr;
                // Function code
                r_fc[2] <= r_cpu_sr[5];         // 0 : User, 1 : Supervisor
                case (inst_in[1:0])
                    2'b00 : r_fc[1:0] <= 2'b01; // EA1    : data
                    2'b01 : r_fc[1:0] <= 2'b01; // EA2    : data
                    2'b10 : r_fc[1:0] <= 2'b10; // PC     : program
                    2'b11 : r_fc[1:0] <= 2'b11; // Vector : CPU
                endcase
                // Memory write
                case ({ inst_in[11:10], w_mem_addr[0] })
                    // Byte, even addr. :     ---            use
                    3'b000 : r_wr_data <= {  io_dout[7:0], io_dout[15:8] };
                    // Byte, odd addr.  :     ---            use
                    3'b001 : r_wr_data <= { io_dout[15:8],  io_dout[7:0] };
                    // Word, even addr. :     use            use
                    3'b010 : r_wr_data <= { io_dout[15:8],  io_dout[7:0] };
                    // Word, odd addr.  :      !! exception !!
                    3'b011 : r_wr_data <= { io_dout[15:8],  io_dout[7:0] };
                    // LSB, even addr.  :    use            ---
                    3'b100 : r_wr_data <= {  io_dout[7:0], io_dout[15:8] };
                    // LSB, odd addr.   :    ---            use
                    3'b101 : r_wr_data <= { io_dout[15:8],  io_dout[7:0] };
                    // MSB, even addr.  :    use            ---
                    3'b110 : r_wr_data <= { io_dout[15:8],  io_dout[7:0] };
                    // MSB, odd addr.   :    ---            use
                    3'b111 : r_wr_data <= {  io_dout[7:0], io_dout[15:8] };
                endcase
            end
            
            // Read, write and byte strobes
            if ((io_ext) && (!r_io_ext)) begin
                r_mem_rd <= inst_in[7];
                r_mem_wr <= inst_in[6];
                case ({ inst_in[11:10], w_mem_addr[0] })
                    3'b000 : r_byte_ena <= { ~(inst_in[3] & ~inst_in[1]), (inst_in[3] & ~inst_in[1]) };
                    3'b001 : r_byte_ena <= { (inst_in[3] & ~inst_in[1]), ~(inst_in[3] & ~inst_in[1]) };
                    3'b010 : r_byte_ena <= 2'b11;
                    3'b011 : // Word access at odd address !!
                    begin
                        r_byte_ena <= 2'b00;                 // No read/write
                        r_mem_err  <= 1'b1;                  // Address error
                        r_err_addr <= w_mem_addr;            // Keep EA value
                        r_err_inst <= r_ins_word;            // Keep opcode
                        case (inst_in[1:0])
                            2'b00 : r_err_cpu[1:0] <= 2'b01; // EA1    : data
                            2'b01 : r_err_cpu[1:0] <= 2'b01; // EA2    : data
                            2'b10 : r_err_cpu[1:0] <= 2'b10; // PC     : program
                            2'b11 : r_err_cpu[1:0] <= 2'b11; // Vector : CPU
                        endcase
                        r_err_cpu[2] <= r_cpu_sr[5];         // 0 : User, 1 : Supervisor
                        r_err_cpu[3] <= 1'b0;                // Instruction identified
                        r_err_cpu[4] <= inst_in[7];          // 0 : Write, 1 : Read
                    end
                    3'b100 : r_byte_ena <= 2'b10;
                    3'b101 : r_byte_ena <= 2'b01;
                    3'b110 : r_byte_ena <= 2'b10;
                    3'b111 : r_byte_ena <= 2'b01;
                endcase
            end
            
            // Keep PC value for address error exception
            if ((io_wr) && (inst_in[3:1] == 3'b010)) begin
                if (inst_in[0])
                    r_err_addr[31:16] <= io_dout;
                else
                    r_err_addr[15:0]  <= io_dout;
                // Address error if odd address on PC
                if ((!inst_in[0]) && (io_dout[0])) begin
                    r_mem_err  <= 1'b1;       // Address error
                    r_err_inst <= r_ins_word; // Keep opcode
                    r_err_cpu  <= { 2'b10, r_cpu_sr[5], 2'b10 };
                end
            end
            
            // End of memory cycle : acknowledge or error
            if ((data_ack) || (r_mem_err)) begin
                r_mem_rd   <= 1'b0;
                r_rd_ena   <= 1'b0;
                r_mem_wr   <= 1'b0;
                r_wr_ena   <= 1'b0;
                r_byte_ena <= 2'b00;
                r_mem_err  <= 1'b0;
                r_fc       <= { r_cpu_sr[5], 2'b00 }; // No access
            end
            else begin
                r_rd_ena   <= (inst_in[7] & (~inst_in[3] | inst_in[1]) & io_ext) | r_mem_rd;
                r_wr_ena   <= (inst_in[6] & (~inst_in[3] | inst_in[1]) & io_ext) | r_mem_wr;
            end
        end
    end

    // Outside bus interface
    assign fc       = r_fc;
    assign rd_ena   = r_rd_ena;
    assign wr_ena   = r_wr_ena;
    assign byte_ena = r_byte_ena;
    assign address  = r_address;
    assign wr_data  = r_wr_data;

    // Instruction decoder
    assign w_ins_rdy = (inst_in[3:0] == 4'b0010) ? (r_io_rdy & r_io_ext) : 1'b0;
    assign w_ext_rdy = (inst_in[3:0] == 4'b0110) ? (r_io_rdy & r_io_ext) : 1'b0;
    assign w_imm_rdy = (inst_in[3:0] == 4'b1010) ? (r_io_rdy & r_io_ext) : 1'b0;

    j68_decode 
    #(
        .USE_CLK_ENA (USE_CLK_ENA)
    )
    U_decode
    (
        .rst         (rst),
        .clk         (clk),
        .clk_ena     (1'b1),
        .ins_rdy     (w_ins_rdy),
        .instr       (r_ins_word),
        .ext_rdy     (w_ext_rdy),
        .ext_wd      (r_ext_word),
        .imm_rdy     (w_imm_rdy),
        .imm_wd      (r_imm_word),
        .user_mode   (~r_cpu_sr[5]),
        .ccr_in      (ccr_in[3:0]),
        .dec_jmp     (w_dec_jump),
        .ea1_jmp     (w_ea1_jump),
        .ea2_jmp     (w_ea2_jump),
        .imm_val     (w_imm_val),
        .ea1_bit     (ea1b),
        .cc_jmp      (w_cc_jump),
        .ext_inst    (),
        .bit_inst    (),
        .vld_inst    ()
    );
    assign insw = r_ins_word;
    assign extw = r_ext_word;
  
    // Registers access
    assign w_loop_cnt = ea1b[4] ? loop_cnt : ~loop_cnt;
    always@(*) begin : REG_ADDR
    
        case (inst_in[3:0])
            4'b0000 : reg_addr = { 2'b10,  r_ins_word[2:0],                 inst_in[8] }; // D[EA1]
            4'b0001 : reg_addr = { 2'b11,  r_ins_word[2:0],                 inst_in[8] }; // A[EA1]
            4'b0010 : reg_addr = { 1'b1,   r_ins_word[3:0],                 inst_in[8] }; // R[EA1]
            4'b0011 : reg_addr = { 5'b11111,                                inst_in[8] }; // A7
            4'b0100 : reg_addr = { 2'b10,  r_ins_word[11:9],                inst_in[8] }; // D[EA2]
            4'b0101 : reg_addr = { 2'b11,  r_ins_word[11:9],                inst_in[8] }; // A[EA2]
            4'b0110 : reg_addr = { 1'b1,   r_ins_word[6], r_ins_word[11:9], inst_in[8] }; // R[EA2]
            4'b0111 : reg_addr = { 1'b1,   w_loop_cnt,                      inst_in[8] }; // R[CNT]
            4'b1000 : reg_addr = { 2'b10,  r_ext_word[14:12],               inst_in[8] }; // D[EXT]
            4'b1001 : reg_addr = { 2'b11,  r_ext_word[14:12],               inst_in[8] }; // A[EXT]
            4'b1010 : reg_addr = { 1'b1,   r_ext_word[15:12],               inst_in[8] }; // R[EXT]
            default : reg_addr = { 2'b01,  inst_in[2:0],                    inst_in[8] }; // VBR, TMP1, TMP2, USP, SSP
        endcase
        reg_wr      = inst_in[6] & io_reg;
        reg_bena[0] = io_reg;
        reg_bena[1] = inst_in[10] & io_reg;
    end

endmodule
