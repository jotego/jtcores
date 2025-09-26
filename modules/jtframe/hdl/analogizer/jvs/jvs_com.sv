//////////////////////////////////////////////////////////////////////
// JVS Communication Module (jvs_com.sv)
// ALPHA Version - JVS Protocol Communication Layer
//
// This module handles the low-level JVS communication protocol including:
// - UART TX/RX with configurable baud rates
// - RS485 transceiver control with timing requirements
// - JVS frame encapsulation and decapsulation
// - Escape sequence handling (D0 DF → E0, D0 CF → D0)
// - Checksum calculation and validation
//
// RS485 Timing Requirements:
// - Setup delay: 10μs before transmission
// - Hold delay: 30μs after transmission for signal integrity
//
// Frame Format: SYNC(0xE0) + NODE + LENGTH + DATA + CHECKSUM
//
// Author: Totaly FuRy - Sebastien DUPONCHEEL (sduponch on GitHub)
// Compatible I/O Boards: NAJV2 (Tekken 7), NAJV (Time Crisis 4), TAITO CORP Ver2.0 (Viewlix)
// Incompatible: "No Brand;NAOMI Converter98701;ver2.0" (frames are ignored)
//////////////////////////////////////////////////////////////////////

module jvs_com
#(
    parameter MASTER_CLK_FREQ = 50_000_000,
    parameter JVS_BUFFER_SIZE = 256,  // Maximum JVS frame data size
    parameter CMD_FIFO_SIZE = 16      // Command FIFO depth (max commands per frame)
)
(
    // Clock and Reset
    input  wire         clk_sys,
    input  wire         reset,
    input  wire         i_ena,
    // UART Physical Interface
    input  wire         uart_rx,
    output wire         uart_tx,
    output wire         o_rs485_dir,   // RS485 transmit enable (active high)
    
    // High-level Protocol Interface - TX Path
    input  wire [7:0]   tx_data,       // Data byte (CMD + args)
    input  wire         tx_data_push,  // Pulse to push data byte into buffer
    input  wire         tx_cmd_push,   // Pulse to push command byte (stores in FIFO)
    input  wire [7:0]   dst_node,      // Destination node address
    input  wire         commit,        // Pulse to encapsulate and transmit
    output reg          tx_ready,      // Ready to accept new data
    
    // High-level Protocol Interface - RX Path
    output reg [7:0]    rx_byte,       // Current data byte
    input  wire         rx_next,       // Pulse to get next byte
    output reg [BUFFER_ADDR_BITS-1:0] rx_remaining, // Auto-sized bytes remaining counter
    output reg [7:0]    src_node,      // Source node of response
    output reg [7:0]    src_cmd,       // CMD from command FIFO
    output reg [7:0]    src_cmd_status, // STATUS byte decoded from JVS response
    input  wire         src_cmd_next,  // Pulse to get next command from FIFO
    output reg [CMD_ADDR_BITS:0] src_cmd_count, // Auto-sized command count with overflow bit
    output reg          rx_complete,   // Pulse when frame complete
    output reg          rx_error,       // Checksum or format error
    input  wire         rx_processing_done, // Signal that RX processing is complete, ready for TX
    
    // Debug/Status Interface
    output reg [3:0]    tx_state_debug, // Current TX state for debugging
    output reg [3:0]    rx_state_debug, // Current RX state for debugging
    output reg [7:0]    frames_tx_count, // Transmitted frame counter
    output reg [7:0]    frames_rx_count, // Received frame counter
    output reg [7:0]    checksum_errors_count // Checksum error counter
);

    // RS485 Timing Constants (in clock cycles at 48MHz)
    localparam logic [15:0] RS485_SETUP_CYCLES = MASTER_CLK_FREQ / 100_000; // ~10µs
    localparam logic [15:0] RS485_HOLD_CYCLES = MASTER_CLK_FREQ / 33_333; // ~30µs
    
    // JVS Protocol Constants
    localparam JVS_CHECKSUM_SIZE = 1;      // Checksum is 1 byte

    // Automatic sizing based on buffer parameters
    localparam BUFFER_ADDR_BITS = $clog2(JVS_BUFFER_SIZE);  // Address bits for buffer indexing
    localparam CMD_ADDR_BITS = $clog2(CMD_FIFO_SIZE);       // Address bits for command FIFO
    
    // TX State Machine
    localparam [3:0] TX_IDLE         = 4'h0;
    localparam [3:0] TX_SETUP        = 4'h1;
    localparam [3:0] TX_SYNC         = 4'h2;
    localparam [3:0] TX_NODE         = 4'h3;
    localparam [3:0] TX_LENGTH       = 4'h4;
    localparam [3:0] TX_DATA         = 4'h5;
    localparam [3:0] TX_CHECKSUM     = 4'h6;
    localparam [3:0] TX_TRANSMIT_BYTE = 4'h7;
    localparam [3:0] TX_TRANSMIT_BYTE_DONE = 4'h8;
    localparam [3:0] TX_HOLD         = 4'h9;
    
    // RX State Machine
    localparam [3:0] RX_IDLE        = 4'h0;
    localparam [3:0] RX_SYNC        = 4'h1;
    localparam [3:0] RX_NODE        = 4'h2;
    localparam [3:0] RX_LENGTH      = 4'h3;
    localparam [3:0] RX_DATA        = 4'h4;
    localparam [3:0] RX_CHECKSUM    = 4'h5;
    localparam [3:0] RX_VALIDATE    = 4'h6;
    localparam [3:0] RX_ESCAPE_WAIT = 4'h7;
    
    // JVS Protocol Constants
    localparam [7:0] JVS_SYNC       = 8'hE0;
    localparam [7:0] JVS_ESCAPE     = 8'hD0;
    localparam [7:0] JVS_ESC_SYNC   = 8'hDF;  // D0 DF → E0
    localparam [7:0] JVS_ESC_ESC    = 8'hCF;  // D0 CF → D0

    // Status Codes - General response status (position 3 in frame)
    localparam STATUS_NORMAL = 8'h01;        // Normal operation status
    localparam STATUS_UNKNOWN_CMD = 8'h02;   // Unknown command received
    localparam STATUS_SUM_ERROR = 8'h03;     // Checksum error in received data
    localparam STATUS_ACK_OVERFLOW = 8'h04;  // Acknowledgment overflow
    localparam STATUS_BUSY = 8'h05;          // Device busy, cannot process command
    
    //////////////////////////////////////////////////////////////////////
    // Internal Registers and Wires
    //////////////////////////////////////////////////////////////////////
    
    // UART Interface
    wire        uart_tx_active;
    wire        uart_tx_done;
    wire        uart_tx_valid;
    wire [7:0]  uart_tx_data;
    wire        uart_rx_valid;
    wire [7:0]  uart_rx_data;
    
    // TX State Machine
    reg [3:0]   tx_state;
    reg [3:0]   tx_next_state;      // État suivant après TX_TRANSMIT_BYTE
    reg [15:0]  tx_timer;
    reg [BUFFER_ADDR_BITS-1:0] tx_data_idx;  // Auto-sized for buffer indexing
    reg [7:0]   tx_checksum;
    reg         tx_escape_pending;
    reg [7:0]   tx_escape_byte;

    // TX Data Buffer Management
    reg [7:0]   tx_data_buffer [0:JVS_BUFFER_SIZE-1]; // Buffer for pushed data (parameterized)
    reg [BUFFER_ADDR_BITS-1:0] tx_data_count;         // Auto-sized byte counter
    reg [7:0]   tx_dst_node_latched;    // Latched destination node
    reg         tx_commit_pending;      // Commit pending processing
    
    // Command FIFO for multi-command frame tracking
    reg [7:0]   cmd_fifo [0:CMD_FIFO_SIZE-1];          // FIFO to store commands (parameterized)
    reg [CMD_ADDR_BITS-1:0] cmd_write_ptr;             // Auto-sized write pointer
    reg [CMD_ADDR_BITS-1:0] cmd_read_ptr;              // Auto-sized read pointer
    reg [CMD_ADDR_BITS:0]   cmd_count;                 // Auto-sized counter with overflow bit
    reg         cmd_fifo_init;          // Pulse to initialize command FIFO reading
    
    // RX State Machine
    reg [3:0]   rx_state;
    reg [BUFFER_ADDR_BITS-1:0] rx_data_idx;           // Auto-sized for buffer indexing
    reg [7:0]   rx_checksum_calc;
    reg [7:0]   rx_checksum_recv;
    reg         rx_escape_mode;
    reg [7:0]   rx_byte_buffer;
    reg [BUFFER_ADDR_BITS-1:0] rx_length_internal;    // Auto-sized length storage
    reg [7:0]   rx_buffer [0:JVS_BUFFER_SIZE-1];      // Internal RX data buffer (parameterized)
    reg [BUFFER_ADDR_BITS-1:0] rx_read_idx;           // Auto-sized read index
    reg         rx_complete_pulse;  // One-cycle pulse for rx_complete
    
    // Internal frame buffers
    reg [7:0]   tx_frame_node;
    reg [7:0]   tx_frame_length;
    reg [7:0]   tx_frame_cmd;        // First byte (CMD) for RX echo
    
    // Edge detection registers for TX control signals
    reg tx_cmd_push_d, tx_data_push_d, commit_d;
    wire tx_cmd_push_negedge = tx_cmd_push_d & ~tx_cmd_push;
    wire tx_data_push_negedge = tx_data_push_d & ~tx_data_push;
    wire commit_negedge = commit_d & ~commit;
    
    //////////////////////////////////////////////////////////////////////
    // Buffer copying eliminated - using tx_data_buffer directly
    //////////////////////////////////////////////////////////////////////

    //////////////////////////////////////////////////////////////////////
    // UART Instance
    //////////////////////////////////////////////////////////////////////
    localparam UART_CLKS_PER_BIT = MASTER_CLK_FREQ / 115200;
    uart_tx #(
        .CLKS_PER_BIT(UART_CLKS_PER_BIT) // UART baud rate divisor
    ) uart_tx_inst (
        .i_Clock(clk_sys),
        .i_Tx_DV(uart_tx_valid),
        .i_Tx_Byte(uart_tx_data),
        .o_Tx_Active(uart_tx_active),
        .o_Tx_Serial(uart_tx),
        .o_Tx_Done(uart_tx_done)
    );
    
    uart_rx #(
        .CLKS_PER_BIT(UART_CLKS_PER_BIT) // UART baud rate divisor
    ) uart_rx_inst (
        .i_Clock(clk_sys),
        .i_Rx_Serial(uart_rx),
        .o_Rx_DV(uart_rx_valid),
        .o_Rx_Byte(uart_rx_data)
    );
    
    //////////////////////////////////////////////////////////////////////
    // RS485 Control Logic
    //////////////////////////////////////////////////////////////////////

    reg rs485_tx_enable;
    reg rx_to_tx_pending;  // Flag to indicate transition from RX to TX needed
    assign o_rs485_dir = rs485_tx_enable;
  
    //////////////////////////////////////////////////////////////////////
    // TX State Machine
    //////////////////////////////////////////////////////////////////////
    
    reg uart_tx_dv;
    assign uart_tx_valid = uart_tx_dv;
    reg [7:0] uart_tx_byte;
    assign uart_tx_data = uart_tx_byte;
    
    //////////////////////////////////////////////////////////////////////
    // TX Data Buffer Management
    //////////////////////////////////////////////////////////////////////
    
    always @(posedge clk_sys) begin
        if (reset) begin
            
            // Initialize command FIFO
            cmd_write_ptr <= 0;
            cmd_read_ptr <= 0;
            cmd_count <= 0;
        end else begin
            // Handle data and command push - all managed in TX state machine
            
            // Handle command push - store in FIFO on negedge for better timing
            if (tx_cmd_push_negedge && tx_ready && cmd_count < 16) begin
                cmd_fifo[cmd_write_ptr] <= tx_data;
                cmd_write_ptr <= cmd_write_ptr + 1;
                cmd_count <= cmd_count + 1;

                // Log command push and current FIFO state
                $write("[%0t] JVS_COM: CMD PUSH 0x%02X -> FIFO[%0d], count=%0d, FIFO: [", $time, tx_data, cmd_write_ptr, cmd_count + 1);
                for (int i = 0; i < cmd_count; i++) begin
                    $write("0x%02X", cmd_fifo[(cmd_read_ptr + i) % 16]);
                    if (i < cmd_count - 1) $write(", ");
                end
                if (cmd_count > 0) $write(", ");
                $write("0x%02X]", tx_data);
                $display("");
            end
            
            // Handle commit - moved to TX state machine
            
            // Handle command FIFO initialization from RX
            if (cmd_fifo_init && cmd_count > 0) begin
                src_cmd <= cmd_fifo[cmd_read_ptr];
            end
            
            // Handle src_cmd_next to advance command FIFO
            if (src_cmd_next && cmd_count > 0) begin
                $write("[%0t] JVS_COM: CMD NEXT 0x%02X consumed, count=%0d->%0d, remaining: [", $time, src_cmd, cmd_count, cmd_count - 1);
                for (int i = 1; i < cmd_count; i++) begin
                    $write("0x%02X", cmd_fifo[(cmd_read_ptr + i) % 16]);
                    if (i < cmd_count - 1) $write(", ");
                end
                $display("]");

                cmd_read_ptr <= cmd_read_ptr + 1;
                cmd_count <= cmd_count - 1;

                // Update src_cmd with next command if available
                // Use the incremented read pointer value (will be available next cycle)
                if (cmd_count > 1) begin
                    src_cmd <= cmd_fifo[cmd_read_ptr + 1];
                end else begin
                    // No more commands available
                    src_cmd <= 8'h00;  // Clear src_cmd when FIFO is empty
                end
            end else if (src_cmd_next && cmd_count == 0) begin
                $display("[%0t] JVS_COM: ERROR - CMD NEXT requested but FIFO is empty (cmd_count=0)", $time);
            end

            // Check for cmd_count underflow (should never happen)
            if (cmd_count[4]) begin  // MSB of 5-bit counter indicates underflow
                $display("[%0t] JVS_COM: CRITICAL ERROR - cmd_count underflow detected: %0d", $time, cmd_count);
                $display("[%0t] JVS_COM: FIFO state - read_ptr=%0d, write_ptr=%0d", $time, cmd_read_ptr, cmd_write_ptr);
            end
        end
    end
    
    //////////////////////////////////////////////////////////////////////
    // TX State Machine
    //////////////////////////////////////////////////////////////////////
    
    always @(posedge clk_sys) begin
        if (reset) begin
            tx_state <= TX_IDLE;
            tx_next_state <= TX_IDLE;
            tx_timer <= 0;
            rs485_tx_enable <= 1'b0;
            uart_tx_dv <= 1'b0;
            tx_data_idx <= 0;
            tx_checksum <= 0;
            tx_escape_pending <= 1'b0;
            frames_tx_count <= 0;
            tx_state_debug <= TX_IDLE;
            tx_data_count <= 0;
            tx_ready <= 1'b1;
            tx_commit_pending <= 1'b0;
            tx_cmd_push_d <= 1'b0;
            tx_data_push_d <= 1'b0;
            commit_d <= 1'b0;
        end else begin
            tx_state_debug <= tx_state;
            uart_tx_dv <= 1'b0; // Default, pulse when needed


            // Update edge detection registers
            tx_cmd_push_d <= tx_cmd_push;
            tx_data_push_d <= tx_data_push;
            commit_d <= commit;
            
            case (tx_state)
                TX_IDLE: begin
                    // Only force RX mode when idle AND no TX pending and no RX processing pending
                    if (!tx_commit_pending && !rx_to_tx_pending) begin
                        rs485_tx_enable <= 1'b0;  // Force RX mode when truly idle
                    end

                    // Handle data and command push on negedge for better timing
                    if ((tx_data_push_negedge || tx_cmd_push_negedge) && tx_ready) begin
                        tx_data_buffer[tx_data_count] <= tx_data;
                        tx_data_count <= tx_data_count + 1;

                        // Store first CMD for backward compatibility
                        if (tx_data_count == 0) begin
                            tx_frame_cmd <= tx_data;
                        end
                    end
                    // Handle commit request on falling edge
                    if (commit_negedge && tx_ready) begin
                        tx_dst_node_latched <= dst_node;
                        tx_commit_pending <= 1'b1;
                        tx_ready <= 1'b0;
                        // Prepare frame from TX data buffer immediately
                        tx_frame_node <= dst_node;
                        tx_frame_length <= tx_data_count + JVS_CHECKSUM_SIZE;
                        tx_timer <= 0;
                        tx_state <= TX_SETUP;
                    end
                end
                
                TX_SETUP: begin
                    // RS485 setup delay (10μs)
                    if (tx_timer < RS485_SETUP_CYCLES) begin
                        tx_timer <= tx_timer + 1;
                        rs485_tx_enable <= 1'b1;
                    end else begin
                        tx_timer <= 0;
                        tx_checksum <= 0;
                        tx_data_idx <= 0;
                        tx_state <= TX_SYNC;
                    end
                end
                
                TX_SYNC: begin
                    uart_tx_byte <= JVS_SYNC;
                    tx_next_state <= TX_NODE;
                    tx_state <= TX_TRANSMIT_BYTE;
                end
                
                TX_NODE: begin
                    if (needs_escape(tx_frame_node)) begin
                        if (!tx_escape_pending) begin
                            uart_tx_byte <= JVS_ESCAPE;
                            tx_escape_pending <= 1'b1;
                            tx_escape_byte <= get_escape_byte(tx_frame_node);
                            tx_next_state <= TX_NODE;  // Revenir pour envoyer l'échappement
                        end else begin
                            uart_tx_byte <= tx_escape_byte;
                            tx_escape_pending <= 1'b0;
                            tx_checksum <= tx_checksum + tx_frame_node;
                            tx_next_state <= TX_LENGTH;
                        end
                    end else begin
                        uart_tx_byte <= tx_frame_node;
                        tx_checksum <= tx_checksum + tx_frame_node;
                        tx_next_state <= TX_LENGTH;
                    end
                    tx_state <= TX_TRANSMIT_BYTE;
                end
                
                TX_LENGTH: begin
                    if (needs_escape(tx_frame_length)) begin
                        if (!tx_escape_pending) begin
                            uart_tx_byte <= JVS_ESCAPE;
                            tx_escape_pending <= 1'b1;
                            tx_escape_byte <= get_escape_byte(tx_frame_length);
                            tx_next_state <= TX_LENGTH;  // Revenir pour envoyer l'échappement
                        end else begin
                            uart_tx_byte <= tx_escape_byte;
                            tx_escape_pending <= 1'b0;
                            tx_checksum <= tx_checksum + tx_frame_length;
                            tx_next_state <= TX_DATA;
                        end
                    end else begin
                        uart_tx_byte <= tx_frame_length;
                        tx_checksum <= tx_checksum + tx_frame_length;
                        tx_next_state <= TX_DATA;
                    end
                    tx_state <= TX_TRANSMIT_BYTE;
                end
                
                TX_DATA: begin
                    if (tx_data_idx < tx_data_count) begin
                        if (needs_escape(tx_data_buffer[tx_data_idx])) begin
                            if (!tx_escape_pending) begin
                                uart_tx_byte <= JVS_ESCAPE;
                                tx_escape_pending <= 1'b1;
                                tx_escape_byte <= get_escape_byte(tx_data_buffer[tx_data_idx]);
                                tx_next_state <= TX_DATA;  // Revenir pour envoyer l'échappement
                            end else begin
                                uart_tx_byte <= tx_escape_byte;
                                tx_escape_pending <= 1'b0;
                                tx_checksum <= tx_checksum + tx_data_buffer[tx_data_idx];
                                tx_data_idx <= tx_data_idx + 1;
                                tx_next_state <= TX_DATA;  // Continuer avec le prochain byte
                            end
                        end else begin
                            uart_tx_byte <= tx_data_buffer[tx_data_idx];
                            tx_checksum <= tx_checksum + tx_data_buffer[tx_data_idx];
                            tx_data_idx <= tx_data_idx + 1;
                            tx_next_state <= TX_DATA;  // Continuer avec le prochain byte
                        end
                        tx_state <= TX_TRANSMIT_BYTE;
                    end else begin
                        tx_state <= TX_CHECKSUM;
                    end
                end
                
                TX_CHECKSUM: begin
                    if (needs_escape(tx_checksum)) begin
                        if (!tx_escape_pending) begin
                            uart_tx_byte <= JVS_ESCAPE;
                            tx_escape_pending <= 1'b1;
                            tx_escape_byte <= get_escape_byte(tx_checksum);
                            tx_next_state <= TX_CHECKSUM;  // Revenir pour envoyer l'échappement
                        end else begin
                            uart_tx_byte <= tx_escape_byte;
                            tx_escape_pending <= 1'b0;
                            tx_next_state <= TX_HOLD;
                        end
                    end else begin
                        uart_tx_byte <= tx_checksum;
                        tx_next_state <= TX_HOLD;
                    end
                    tx_state <= TX_TRANSMIT_BYTE;
                end
                
                TX_TRANSMIT_BYTE: begin
                    if (!uart_tx_active && !uart_tx_dv) begin
                        uart_tx_dv <= 1'b1;
                        tx_state <= TX_TRANSMIT_BYTE_DONE;
                    end
                end

                TX_TRANSMIT_BYTE_DONE: begin
                    // Clear data valid signal when UART starts transmission
                    if (uart_tx_dv && uart_tx_active) begin
                        uart_tx_dv <= 1'b0;
                    end
                    // Move to next state when transmission completes
                    if (uart_tx_done) begin
                        tx_state <= tx_next_state;
                    end
                end

                TX_HOLD: begin
                    // RS485 hold delay (30μs) - initialiser timer si pas déjà fait
                    if (tx_next_state != TX_HOLD) begin
                        tx_timer <= 0;
                        tx_next_state <= TX_HOLD; // Éviter de réinitialiser
                    end else if (tx_timer < RS485_HOLD_CYCLES) begin
                        tx_timer <= tx_timer + 1;
                    end else begin
                        rs485_tx_enable <= 1'b0;
                        frames_tx_count <= frames_tx_count + 1;
                        // Reset transmission state
                        tx_commit_pending <= 1'b0;
                        tx_data_count <= 0;
                        tx_ready <= 1'b1;
                        tx_state <= TX_IDLE;
                    end
                end
                
                default: tx_state <= TX_IDLE;
            endcase
        end
    end
    
    //////////////////////////////////////////////////////////////////////
    // RX State Machine
    //////////////////////////////////////////////////////////////////////
    
    always @(posedge clk_sys) begin
        if (reset) begin
            rx_state <= RX_IDLE;
            rx_complete <= 1'b0;
            rx_error <= 1'b0;
            rx_data_idx <= 0;
            rx_checksum_calc <= 0;
            rx_escape_mode <= 1'b0;
            frames_rx_count <= 0;
            checksum_errors_count <= 0;
            rx_state_debug <= RX_IDLE;
            cmd_fifo_init <= 1'b0;
            rx_to_tx_pending <= 1'b0;
            src_cmd_status <= 8'h00;  // No STATUS received yet
        end else begin
            rx_state_debug <= rx_state;
            rx_complete <= rx_complete_pulse; // Connect to pulse register
            rx_error <= 1'b0; // Default
            cmd_fifo_init <= 1'b0; // Default, pulse when initializing command FIFO
            rx_complete_pulse <= 1'b0; // Default pulse to 0

            // Log RX state changes for simulation
            if (rx_state_debug != rx_state) begin
            end
            
            if (uart_rx_valid) begin
                // Log all received bytes

                case (rx_state)
                    RX_IDLE: begin
                        // RX mode is managed by TX state machine
                        if (uart_rx_data == JVS_SYNC) begin
                            rx_checksum_calc <= 0;
                            rx_data_idx <= 0;
                            rx_escape_mode <= 1'b0;
                            rx_length_internal <= 0;  // CRITICAL: Reset length for new frame
                            rx_state <= RX_NODE;
                        end else begin
                        end
                    end

                    RX_NODE: begin
                        if (uart_rx_data == JVS_ESCAPE) begin
                        end
                        if (handle_escape_rx(uart_rx_data, rx_escape_mode, rx_byte_buffer)) begin
                            src_node <= rx_byte_buffer;
                            rx_checksum_calc <= rx_checksum_calc + rx_byte_buffer;
                            rx_state <= RX_LENGTH;
                        end
                    end

                    RX_LENGTH: begin
                        if (uart_rx_data == JVS_ESCAPE) begin
                        end
                        if (handle_escape_rx(uart_rx_data, rx_escape_mode, rx_byte_buffer)) begin
                            rx_length_internal <= rx_byte_buffer;
                            rx_checksum_calc <= rx_checksum_calc + rx_byte_buffer;
                            rx_data_idx <= 0;
                            rx_state <= RX_DATA;
                        end
                    end

                    RX_DATA: begin
                        if (uart_rx_data == JVS_ESCAPE) begin
                        end
                        if (handle_escape_rx(uart_rx_data, rx_escape_mode, rx_byte_buffer)) begin
                            if (rx_data_idx < rx_length_internal - 1) begin
                                rx_buffer[rx_data_idx] <= rx_byte_buffer;
                                rx_checksum_calc <= rx_checksum_calc + rx_byte_buffer;
                                rx_data_idx <= rx_data_idx + 1;
                            end else begin
                                rx_checksum_recv <= rx_byte_buffer;
                                rx_state <= RX_VALIDATE;
                            end
                        end
                    end

                    default: rx_state <= RX_IDLE;
                endcase
            end

            // RX_VALIDATE state - executes every cycle when in this state, not just when uart_rx_valid
            if (rx_state == RX_VALIDATE) begin
                if (rx_checksum_calc == rx_checksum_recv) begin
                    frames_rx_count <= frames_rx_count + 1;

                    // Initialize command FIFO reading - start with first command
                    cmd_fifo_init <= 1'b1;

                    // Setup sequential read interface - start from REPORT byte (skip STATUS)
                    src_cmd_status <= rx_buffer[0];  // Store STATUS directly
                    rx_read_idx <= 1;
                    rx_byte <= rx_buffer[1];  // REPORT byte ready (STATUS already decoded)
                    rx_remaining <= rx_length_internal - 2;
                    rx_complete_pulse <= 1'b1;  // Generate one-cycle pulse

                    // Set flag to indicate we need to transition to TX mode for response
                    rx_to_tx_pending <= 1'b1;
                end else begin
                    checksum_errors_count <= checksum_errors_count + 1;
                    rx_error <= 1'b1;
                end
                rx_state <= RX_IDLE;
            end

            // Handle transition from RX to TX when processing is done
            if (rx_processing_done && rx_to_tx_pending) begin
                rx_to_tx_pending <= 1'b0;
                // Force TX mode for response transmission
                // Note: rs485_tx_enable will be managed by TX state machine
            end
        end
        
        // Handle rx_next sequential read interface
        if (rx_next && rx_remaining > 0) begin
            rx_read_idx <= rx_read_idx + 1;
            rx_byte <= rx_buffer[rx_read_idx + 1];
            rx_remaining <= rx_remaining - 1;
        end
        
        // Always output current command count
        src_cmd_count <= cmd_count;
    end
    
    //////////////////////////////////////////////////////////////////////
    // Helper Functions
    //////////////////////////////////////////////////////////////////////
    
    function automatic needs_escape(input [7:0] data);
        needs_escape = (data == JVS_SYNC || data == JVS_ESCAPE);
    endfunction
    
    function automatic [7:0] get_escape_byte(input [7:0] data);
        if (data == JVS_SYNC)
            get_escape_byte = JVS_ESC_SYNC;
        else if (data == JVS_ESCAPE)
            get_escape_byte = JVS_ESC_ESC;
        else
            get_escape_byte = data;
    endfunction
    
    function automatic handle_escape_rx(
        input [7:0] rx_byte,
        ref logic escape_mode,
        ref [7:0] decoded_byte
    );
        if (escape_mode) begin
            if (rx_byte == JVS_ESC_SYNC) begin
                decoded_byte = JVS_SYNC;
                escape_mode = 1'b0;
                handle_escape_rx = 1'b1;
            end else if (rx_byte == JVS_ESC_ESC) begin
                decoded_byte = JVS_ESCAPE;
                escape_mode = 1'b0;
                handle_escape_rx = 1'b1;
            end else begin
                escape_mode = 1'b0;
                handle_escape_rx = 1'b0; // Invalid escape sequence
            end
        end else if (rx_byte == JVS_ESCAPE) begin
            escape_mode = 1'b1;
            handle_escape_rx = 1'b0;
        end else begin
            decoded_byte = rx_byte;
            handle_escape_rx = 1'b1;
        end
    endfunction

endmodule