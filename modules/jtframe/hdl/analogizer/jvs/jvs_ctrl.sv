// Author: Totaly FuRy - Sebastien DUPONCHEEL (sduponch on GitHub)
// Project: Analogizer JVS Controller
// Status: Alpha - Partial Implementation
// Date: 2025
//////////////////////////////////////////////////////////////////////
//Use: set_global_assignment -name VERILOG_MACRO "USE_DUMMY_JVS_DATA=1" 
//in project .qsf to use dummy data for simulation without JVS device

`default_nettype none
`timescale 1ns / 1ps

import jvs_defs_pkg::*;
import jvs_node_info_pkg::*;

module jvs_ctrl #(parameter MASTER_CLK_FREQ = 50_000_000)
(
    // System clock and control signals
    input logic i_clk,        // System clock (typically 50MHz)
    input logic i_rst,        // Asynchronous reset (active high)
    input logic i_ena,        // Module enable (active high)
    input logic i_stb,        // Strobe signal (not used in final version)
    
    // UART interface signals for RS485 communication
    input logic i_uart_rx,    // Serial data received from JVS device
    output logic o_uart_tx,   // Serial data transmitted to JVS device
    input logic i_sense,      // JVS SENSE line (read-only for master)
    output logic o_rx485_dir, // RS485 transceiver direction control (0=RX, 1=TX)
    
    // Output registers for direct interface
    output logic [15:0] player1_input_switch, // Player 1 digital input switches
    output logic [15:0] player2_input_switch, // Player 2 digital input switches
    output logic [15:0] player3_input_switch, // Player 3 digital input switches
    output logic [15:0] player4_input_switch, // Player 4 digital input switches
    // Output registers for analog interfaces
    output logic [15:0] analog_ch1,    // Analog channel 1 (16-bit)
    output logic [15:0] analog_ch2,    // Analog channel 2 (16-bit)
    output logic [15:0] analog_ch3,    // Analog channel 3 (16-bit)
    output logic [15:0] analog_ch4,    // Analog channel 4 (16-bit)
    output logic [15:0] analog_ch5,    // Analog channel 5 (16-bit)
    output logic [15:0] analog_ch6,    // Analog channel 6 (16-bit)
    output logic [15:0] analog_ch7,    // Analog channel 7 (16-bit)
    output logic [15:0] analog_ch8,    // Analog channel 8 (16-bit)
    
    // Screen position outputs (light gun/touch screen) - raw 16-bit data
    output logic has_screen_pos,        // Device supports screen position inputs
    output logic [15:0] screen_pos_x,   // Screen X position (16-bit from JVS)
    output logic [15:0] screen_pos_y,   // Screen Y position (16-bit from JVS)

    // Coin counter outputs (up to 4 coin slots)
    output logic [15:0] coin_count[4],  // Coin counters for each slot (16-bit values)
    output logic coin1,                 // Coin increase signal for slot 1
    output logic coin2,                 // Coin increase signal for slot 2
    output logic coin3,                 // Coin increase signal for slot 3
    output logic coin4,                 // Coin increase signal for slot 4
    
    // Digital output from SNAC
    input logic [15:0] output_digital_ch1, // Digital output channel 1 from SNAC

    //JVS node information structure
    output logic jvs_data_ready,
    output jvs_node_info_t jvs_nodes,
    //RAM interface for node names (for debug/display purposes)
    output logic [7:0] node_name_rd_data,
    input logic [jvs_node_info_pkg::NAME_BRAM_ADDR_BITS-1:0] node_name_rd_addr  // Calculated address width based on BRAM size
); 

    localparam UART_CLKS_PER_BIT = MASTER_CLK_FREQ / 115200;
//==================================================================================
// Show in Quartus Synthesis if dummy data is used for simulation without JVS device
//==================================================================================
`ifdef USE_DUMMY_JVS_DATA
  initial $warning("=== USE_DUMMY_JVS_DATA is defined (=%0d). Using DUMMY data for JVS IO device ===", `USE_DUMMY_JVS_DATA);
`else
  initial $warning("=== USE_DUMMY_JVS_DATA is NOT defined.  Using REAL data for JVS IO device ===");
`endif

    //=========================================================================
    // JVS_COM INTERFACE SIGNALS (New modular interface)
    //=========================================================================
    // These signals will be used to communicate with the jvs_com module
    
    // TX interface signals
    logic [7:0] com_tx_data;        // Data byte to transmit  
    logic       com_tx_data_push;   // Pulse to push TX data
    logic       com_tx_cmd_push;    // Pulse to push TX command (stores in FIFO)
    logic [7:0] com_dst_node;       // Destination node address
    logic       com_commit;         // Pulse to commit and transmit frame
    logic       com_tx_ready;       // TX ready to accept data
    
    // RX interface signals
    logic [7:0] com_rx_byte;        // Current data byte from RX
    logic       com_rx_ready;       // Data in com_rx_byte is valid (BRAM timing)
    logic       com_rx_next;        // Pulse to get next RX byte
    logic [7:0] com_rx_remaining;   // Bytes remaining (0 = current is last)
    logic [7:0] com_src_node;       // Source node of response
    logic [7:0] com_src_cmd;        // CMD from command FIFO
    logic [7:0] com_src_cmd_status; // Status of src_cmd (STATUS_NORMAL/STATUS_BUSY)
    logic       com_src_cmd_next;   // Pulse to get next command from FIFO
    logic [4:0] com_src_cmd_count;  // Number of commands available in FIFO
    logic       com_rx_complete;    // Pulse when RX frame complete
    logic       com_rx_error;       // RX checksum or format error


    // Debug/Status signals from jvs_com
    logic [3:0] com_tx_state_debug;
    logic [3:0] com_rx_state_debug;
    logic [7:0] com_frames_tx_count;
    logic [7:0] com_frames_rx_count;
    logic [7:0] com_checksum_errors_count;

    // Edge detection for RX complete signal
    logic       com_rx_complete_d;      // Delayed version for edge detection
    wire        com_rx_complete_negedge = com_rx_complete_d & ~com_rx_complete;

    // Name copying variables for device identification parsing
    logic [7:0] copy_write_idx;         // Write index for name copying

    // Checksum calculation variables for BRAM optimization
    logic [15:0] name_checksum_crc;     // Current CRC16 checksum being calculated
    logic [jvs_node_info_pkg::NAME_BRAM_ADDR_BITS-1:0] name_bram_write_addr;  // Current BRAM write address

    logic [3:0] current_player;
    logic [3:0] global_player;
    logic [7:0] current_channel;

    // Analog parsing variables - simplified
    logic [7:0] temp_high_byte;     // Temporary storage for high byte
    //=========================================================================
    // JVS COMMUNICATION MODULE INSTANCE
    //=========================================================================
    
    // Instantiate JVS communication module
    jvs_com #(
        .MASTER_CLK_FREQ(MASTER_CLK_FREQ),
        .JVS_BUFFER_SIZE(256)
    ) jvs_com_inst (
        .clk_sys(i_clk),  // RX_NEXT/TX_NEXT states handle timing control
        .reset(i_rst),
        .i_ena(i_ena),

        // UART Physical Interface
        .uart_rx(i_uart_rx),
        .uart_tx(o_uart_tx),
        .o_rs485_dir(o_rx485_dir),          // RS485 direction control (TX=1, RX=0)
        
        // TX Interface
        .tx_data(com_tx_data),
        .tx_data_push(com_tx_data_push),
        .tx_cmd_push(com_tx_cmd_push),
        .dst_node(com_dst_node),
        .commit(com_commit),
        .tx_ready(com_tx_ready),
        
        // RX Interface
        .rx_byte(com_rx_byte),
        .rx_ready(com_rx_ready),
        .rx_next(com_rx_next),
        .rx_remaining(com_rx_remaining),
        .src_node(com_src_node),
        .src_cmd(com_src_cmd),
        .src_cmd_status(com_src_cmd_status),
        .src_cmd_next(com_src_cmd_next),
        .src_cmd_count(com_src_cmd_count),
        .rx_complete(com_rx_complete),
        .rx_error(com_rx_error),
        
        // Debug/Status Interface (unused for now)
        .tx_state_debug(com_tx_state_debug),
        .rx_state_debug(com_rx_state_debug),
        .frames_tx_count(com_frames_tx_count),
        .frames_rx_count(com_frames_rx_count),
        .checksum_errors_count(com_checksum_errors_count)
    );
    
    // RS485 direction is now directly connected to jvs_com output

    //=========================================================================
    // JVS PROTOCOL CONSTANTS
    //=========================================================================

    // Common delay timings (in clock cycles at MASTER_CLK_FREQ)
    localparam logic [31:0] INIT_DELAY_COUNT = MASTER_CLK_FREQ * 6; // 5.4 seconds
    localparam logic [31:0] FIRST_RESET_DELAY_COUNT = MASTER_CLK_FREQ * 1; // 2 seconds
    localparam logic [31:0] SECOND_RESET_DELAY_COUNT = MASTER_CLK_FREQ * 3; // 0.5 seconds
    localparam logic [15:0] TX_SETUP_DELAY_COUNT = MASTER_CLK_FREQ / 100_000; // ~10µs
    localparam logic [15:0] TX_HOLD_DELAY_COUNT = MASTER_CLK_FREQ / 33_333; // ~30µs
    localparam logic [31:0] RX_TIMEOUT_COUNT = MASTER_CLK_FREQ * 2; // 1s (augmenté pour le parsing des features)
    localparam logic [31:0] POLL_INTERVAL_COUNT = MASTER_CLK_FREQ / 1_000; // 1ms
    localparam logic [31:0] SETADDR_TO_IOIDENT_DELAY = MASTER_CLK_FREQ / 500; // 2ms delay after SETADDR
    localparam logic [31:0] IOIDENT_TO_CMDREV_DELAY = MASTER_CLK_FREQ / 1000; // 1ms delay after IOIDENT
    localparam logic [31:0] CMDREV_TO_JVSREV_DELAY = MASTER_CLK_FREQ / 1000; // 1ms delay after CMDREV
    localparam logic [31:0] JVSREV_TO_COMMVER_DELAY = MASTER_CLK_FREQ / 1000; // 1ms delay after JVSREV
    localparam logic [31:0] COMMVER_TO_FEATURES_DELAY = MASTER_CLK_FREQ / 1000; // 1ms delay after COMMVER
    localparam logic [31:0] FEATURES_TO_IDLE_DELAY = MASTER_CLK_FREQ / 500; // 2ms delay after FEATURES
    localparam logic [31:0] POLLING_INTERVAL_DELAY = MASTER_CLK_FREQ / 100; // 5ms delay between polling cycles (required for SEGA 838-13683B, newer cards tested working with 1ms)

    // JVS Frame structure constants for better code readability
    localparam JVS_SYNC_POS = 8'd0;          // Position of sync byte (E0)
    localparam JVS_ADDR_POS = 8'd1;          // Position of address byte
    localparam JVS_LENGTH_POS = 8'd2;        // Position of length byte
    localparam JVS_DATA_START = 8'd4;        // Start position of data bytes (RX) - after status and include report bytes
    localparam JVS_STATUS_POS = 8'd3;        // Position of status byte in response
    localparam JVS_REPORT_POS = 8'd4;        // Position of report byte in response (should be processed)
    localparam JVS_CMD_START = 8'd3;         // Start position of command bytes (TX)
    localparam JVS_OVERHEAD = 8'd2;          // Overhead for length calculation (includes checksum + command byte)
    localparam JVS_CHECKSUM_SIZE = 8'd1;     // Checksum is coded on one byte

    // Buffer size configuration for resource optimization
    localparam RX_BUFFER_SIZE = 128;         // Size of RX buffers (I/O Identify max 106 bytes)
    localparam TX_BUFFER_SIZE = 24;          // Size of TX buffer (max frame ~21 bytes)
    
    // JVS node management constants
    //localparam MAX_JVS_NODES = 2;            // Maximum supported JVS nodes (current implementation)
    //localparam NODE_NAME_SIZE = 100;         // Maximum size for node identification strings (per JVS spec)
    // Defined in jvs_node_info_pkg.sv

    //=========================================================================
    // STATE MACHINE DEFINITIONS
    //=========================================================================
    
    // INITIALIZATION SEQUENCE STATES (5.4s + 2s + 0.5s delays)
    localparam STATE_NODES_POOLING = 6'h00;    // Multi-node cyclic polling state (1ms interval per node)
    localparam STATE_INIT_DELAY = 6'h02;       // Initial 5.4s delay for system stabilization
    localparam STATE_FIRST_RESET = 6'h03;      // Send first reset command (F0 D9)
    localparam STATE_FIRST_RESET_DELAY = 6'h04; // 2-second delay after first reset
    localparam STATE_SECOND_RESET = 6'h05;     // Send second reset command for reliability
    localparam STATE_SECOND_RESET_DELAY = 6'h06; // 0.5-second delay after second reset
    
    // DEVICE DISCOVERY SEQUENCE STATES
    localparam STATE_SEND_SETADDR = 6'h07;     // Send address assignment command (F1 01)
    localparam RX_PARSE_SETADDR = 6'h08;    // Parse address assignment response
    localparam STATE_SEND_IOIDENT = 6'h09;     // Send device identification request (10)
    localparam RX_PARSE_IOIDENT = 6'h0A;    // Parse device ID string response
    localparam STATE_SEND_CMDREV = 6'h0B;      // Send command revision request (11)
    localparam RX_PARSE_CMDREV = 6'h0C;     // Parse command revision response (BCD format)
    localparam STATE_SEND_JVSREV = 6'h0D;      // Send JVS revision request (12)
    localparam RX_PARSE_COMMVER = 6'h0E;    // Parse communications version response (BCD format)
    localparam RX_PARSE_JVSREV = 6'h0F;     // Parse JVS revision response (BCD format)
    localparam STATE_SEND_COMMVER = 6'h10;     // Send communications version request (13)
    localparam STATE_SEND_FEATCHK = 6'h11;     // Send feature check request (14)
    
    // GENERIC FLOW CONTROL STATES
    localparam STATE_WAIT_RX = 6'h01;          // Wait for device response with 1s timeout
    localparam STATE_MAIN_TIMER_DELAY = 6'h3D; // Generic timer delay state - returns to return_state when done
    
    // INPUT POLLING SEQUENCE STATES (chained command construction)
    localparam STATE_SEND_INPUTS = 6'h12;         // Start input polling sequence
    localparam STATE_SEND_INPUTS_SWITCH = 6'h13;  // Add switch/button inputs (20) if available
    localparam STATE_SEND_INPUTS_COIN = 6'h14;    // Add coin inputs (21) if available
    localparam STATE_SEND_INPUTS_ANALOG = 6'h15;  // Add analog inputs (22) if available (joysticks)
    localparam STATE_SEND_INPUTS_ROTARY = 6'h16;  // Add rotary inputs (23) if available
    localparam STATE_SEND_INPUTS_KEYCODE = 6'h17; // Add keycode inputs (24) if available
    localparam STATE_SEND_INPUTS_SCREEN = 6'h18;  // Add screen position (25) if available (light gun)
    localparam STATE_SEND_INPUTS_MISC = 6'h19;    // Add misc inputs (26) if available
    localparam STATE_SEND_OUTPUT_DIGITAL = 6'h1A; // Send digital output command (32) for GPIO
    localparam STATE_SEND_OUTPUT_ANALOG = 6'h3E; // Send analog output command (33) for GPIO
    localparam STATE_SEND_FINALIZE = 6'h1B;       // Finalize chained command frame and transmit
    
    // RESET ARGUMENT STATES (for double reset sequence)
    localparam STATE_FIRST_RESET_ARG = 6'h1C;     // Push first reset argument (D9) and commit
    localparam STATE_SECOND_RESET_ARG = 6'h1D;    // Push second reset argument (D9) and commit
    
    // GENERIC HELPER STATES
    localparam STATE_TX_NEXT = 6'h1E;             // Generic TX byte advance state
    localparam STATE_RX_NEXT = 6'h1F;             // Generic RX byte advance state
    localparam STATE_FATAL_ERROR = 6'h20;         // Fatal error state - stops execution

    //=========================================================================
    // RX PARSING STATES (6-bit states for complex response handling)
    // These states handle parsing of JVS command responses
    //=========================================================================
    
    // FEATURE PARSING STATES
    localparam RX_PARSE_FEATURES = 6'h21;      // Parse device feature/capability data (14 response)
    localparam RX_PARSE_FEATURES_FUNCS = 6'h22; // Parse individual function capabilities
    localparam RX_PARSE_FUNC_DIGITAL = 6'h23;  // Parse digital input function parameters
    localparam RX_PARSE_FUNC_COIN = 6'h24;     // Parse coin input function parameters
    localparam RX_PARSE_FUNC_ANALOG = 6'h25;   // Parse analog input function parameters
    localparam RX_PARSE_FUNC_ROTARY = 6'h26;   // Parse rotary input function parameters
    localparam RX_PARSE_FUNC_SCREEN = 6'h27;   // Parse screen position function parameters
    localparam RX_PARSE_FUNC_MISC = 6'h28;     // Parse misc digital function parameters

    localparam RX_PARSE_FUNC_CARD = 6'h29;         // Parse card system function parameters
    localparam RX_PARSE_FUNC_HOPPER = 6'h2A;       // Parse hopper function parameters
    localparam RX_PARSE_FUNC_OUT_DIGITAL = 6'h2B;  // Parse output digital function parameters
    localparam RX_PARSE_FUNC_OUT_ANALOG = 6'h2C;   // Parse output analog function parameters
    localparam RX_PARSE_FUNC_CHAR = 6'h2D;         // Parse character display function parameters

    // INPUT DATA PARSING STATES (chained command response handling)
    localparam RX_PARSE_INPUTS_START = 6'h30;   // Initialize chained input response parsing
    localparam RX_PARSE_INPUT_CMD = 6'h31;      // Dispatch to parser based on command in FIFO
    localparam RX_PARSE_INPUTS_COMPLETE = 6'h3C; // Complete chained parsing, return to polling

    // DATA I/O COMMANDS
    localparam RX_PARSE_SWINP = 6'h32;          // Parse switch/button inputs (20) response
    localparam RX_PARSE_SWINP_PLAYER = 6'h33;   // Parse per-player switch data (recursive)
    localparam RX_PARSE_COININP = 6'h34;        // Parse coin inputs (21) response
    localparam RX_PARSE_ANLINP = 6'h35;         // Parse analog inputs (22) response
    localparam RX_PARSE_ANLINP_DATA = 6'h36;    // Parse per-channel analog data (recursive)
    localparam RX_PARSE_ROTINP = 6'h37;         // Parse rotary inputs (23) response
    localparam RX_PARSE_KEYINP = 6'h38;         // Parse keycode inputs (24) response
    localparam RX_PARSE_SCRPOSINP = 6'h39;      // Parse screen position (25) response (light gun)
    localparam RX_PARSE_MISCSWINP = 6'h3A;      // Parse misc digital inputs (26) response
    // OUTPUT COMMANDS
    localparam RX_PARSE_OUTPUT1 = 6'h3B;        // Parse digital output (32) response
    
    //=========================================================================
    // STATE VARIABLES AND CONTROL REGISTERS
    //=========================================================================
    // Current state for main protocol state machine
    logic [5:0] main_state;        // Main protocol state (6-bit for extended states)
    
    // TX state management for sequential byte transmission
    logic [5:0] return_state;      // State to return to after TX_NEXT (6-bit for extended states)
    logic [7:0] cmd_pos;           // Position in current command sequence (was [2:0] - caused overflow)

    // Timing and protocol control
    logic [31:0] delay_counter;    // Multi-purpose delay counter
    logic [31:0] timeout_counter;  // Timeout counter for waiting states
    logic [31:0] poll_timer;       // Timer for input polling frequency

    // Timeout and success state management for STATE_SEND commands
    logic [5:0]  on_timeout_state;       // State to go to on timeout
    logic [5:0]  on_success_state;       // State to go to on success
    logic [7:0]  timeout_retry_count;    // Generic timeout retry counter

    logic [7:0] current_device_addr; // Address assigned to JVS device (usually 0x01)
    logic polling_mode;            // Flag indicating we're in polling mode (after full initialization)

    // Temporary variables for parsing
    logic [7:0] current_func_code; // Store current function being parsed
    logic [3:0] current_coin;      // Current coin slot being parsed (0-3)
    logic [1:0] temp_coin_condition;
    logic [5:0] temp_counter_msb;

    //=========================================================================
    // JVS NODE INFORMATION STRUCTURES
    //=========================================================================
    // Structure to store information about each JVS node
    jvs_node_info_t jvs_nodes_r;

//see comments in JVS_Debugger.qsf under [JVS project settings] 
`ifdef USE_DUMMY_JVS_DATA
	jvs_node_info_t jvs_nodes_r2;
	 
    localparam jvs_node_info_t JVS_INFO_INIT = '{
        node_id: '{8'h01, 8'h02},
        node_cmd_ver: '{8'h13, 8'h11}, 
        node_jvs_ver: '{8'h30, 8'h30},  
        node_com_ver: '{8'h10, 8'h10},
        // Initialize dummy capabilities based on typical JVS device
        node_players: '{4'h2, 4'h1},              // 2 players for first device, 1 for second
        node_buttons: '{8'h0D, 8'h06},            // 13 buttons for P1, 6 for P2
        node_analog_channels: '{4'h2, 4'h0},      // 2 analog channels for first device
        node_analog_bits: '{8'h0A, 8'h08},        // 10-bit analog for first device, 8-bit for second
        node_rotary_channels: '{4'h0, 4'h0},      // No rotary encoders
        node_coin_slots: '{4'h2, 4'h1},           // 2 coin slots for first device, 1 for second
        // Additional input capabilities
        node_has_keycode_input: '{1'b0, 1'b0},    // No keycode input
        node_has_screen_pos: '{1'b0, 1'b0},       // No screen position input
        node_screen_pos_x_bits: '{8'h00, 8'h00},  // No screen X resolution
        node_screen_pos_y_bits: '{8'h00, 8'h00},  // No screen Y resolution  
        node_misc_digital_inputs: '{16'h0000, 16'h0000}, // No misc digital inputs (16-bit)
        // Output capabilities
        node_digital_outputs: '{8'h08, 8'h00},    // 8 digital outputs for first device
        node_analog_output_channels: '{4'h2, 4'h0}, // 2 analog output channels for first device
        node_card_system_slots: '{8'h00, 8'h00},  // No card system slots
        node_medal_hopper_channels: '{8'h00, 8'h00}, // No medal hopper channels
        node_has_char_display: '{1'b0, 1'b0},     // No character display
        node_char_display_width: '{8'h00, 8'h00}, // No character display width
        node_char_display_height: '{8'h00, 8'h00}, // No character display height
        node_char_display_type: '{8'h00, 8'h00},   // No character display type
        node_has_backup: '{1'b0, 1'b0}            // No backup support
    };
    assign jvs_nodes = jvs_nodes_r2;
`else 
    assign jvs_nodes = jvs_nodes_r;
`endif

    //=========================================================================
    // RAM for all node names (optimized BRAM storage)
    // Each node occupies NODE_NAME_SIZE bytes at address: node_index * NODE_NAME_SIZE
    (* ramstyle = "M10K" *) logic [7:0] node_name_ram [0:(jvs_node_info_pkg::MAX_JVS_NODES * jvs_node_info_pkg::NODE_NAME_SIZE) - 1];

////initial content for simulation without JVS device
`ifdef USE_DUMMY_JVS_DATA
    initial begin
        $readmemh("jvs_device_name.mem", node_name_ram, 0, jvs_node_info_pkg::NODE_NAME_SIZE-1); //null terminated string "namco ltd.;NAJV2;Ver1.00;JPN,Multipurpose."
    end
`endif

    //infer simple dual-port RAM for node name reading
    always_ff @(posedge i_clk) begin
        node_name_rd_data <= node_name_ram[node_name_rd_addr];
    end

    //=========================================================================
    // JVS DATA READY SIGNAL FOR OSD Display
    //=========================================================================
    logic jvs_data_ready_init, jvs_data_ready_joy;
    assign jvs_data_ready = jvs_data_ready_init | jvs_data_ready_joy;
    
    //=========================================================================
    // MAIN STATE MACHINE - JVS PROTOCOL HANDLER
    //=========================================================================  
    always @(posedge i_clk) begin
        jvs_data_ready_joy <= 1'b0; // signal for OSD

        // Update delayed register for edge detection
        com_rx_complete_d <= com_rx_complete;

        // Default: Clear all jvs_com control signals (they are pulses)
        com_tx_data_push <= 1'b0;
        com_tx_cmd_push <= 1'b0;
        com_commit <= 1'b0;
        com_rx_next <= 1'b0;
        com_src_cmd_next <= 1'b0;

        if (i_rst || !i_ena) begin
            // Initialize edge detection register
            com_rx_complete_d <= 1'b0;
            // Initialize jvs_com control signals
            com_tx_data_push <= 1'b0;
            com_tx_cmd_push <= 1'b0;
            com_commit <= 1'b0;
            com_rx_next <= 1'b0;
            com_src_cmd_next <= 1'b0;
            com_tx_data <= 8'h00;
            com_dst_node <= 8'h00;

            // Initialize all state variables on reset
            main_state <= STATE_INIT_DELAY;

            delay_counter <= 32'h0;
            timeout_counter <= 32'h0;
            poll_timer <= 32'h0;

            // Initialize timeout and success state management
            on_timeout_state <= STATE_FATAL_ERROR;      // Default timeout state
            on_success_state <= STATE_NODES_POOLING;    // Default success state
            timeout_retry_count <= 8'h00;               // Reset timeout retry counter
          
            // Initialize TX state management
            return_state <= 6'h0;
            cmd_pos <= 8'h0; // genrale parsing pointer

            // Initialize output button and joystick states
            player1_input_switch <= 16'h0000;  // All switches off
            analog_ch1 <= 16'h8000;            // Analog channel 1 centered
            analog_ch2 <= 16'h8000;            // Analog channel 2 centered
            analog_ch3 <= 16'h8000;            // Analog channel 3 centered
            analog_ch4 <= 16'h8000;            // Analog channel 4 centered
            analog_ch5 <= 16'h8000;            // Analog channel 5 centered
            analog_ch6 <= 16'h8000;            // Analog channel 6 centered
            analog_ch7 <= 16'h8000;            // Analog channel 7 centered
            analog_ch8 <= 16'h8000;            // Analog channel 8 centered
            player2_input_switch <= 16'h0000;  // All switches off
            player3_input_switch <= 16'h0000;  // All switches off
            player4_input_switch <= 16'h0000;  // All switches off

            // Initialize coin counters
            coin_count[0] <= 16'h0000;
            coin_count[1] <= 16'h0000;
            coin_count[2] <= 16'h0000;
            coin_count[3] <= 16'h0000;

            jvs_nodes_r.node_count <= 8'h00;
            current_device_addr <= 8'h01;    // Standard JVS device address
            polling_mode <= 1'b0;             // Start in initialization mode
            // Initialize JVS node information (single node only)
            jvs_nodes_r.node_id[0] <= 8'h01;
            jvs_nodes_r.node_cmd_ver[0] <= 8'h00;
            jvs_nodes_r.node_jvs_ver[0] <= 8'h00;
            jvs_nodes_r.node_com_ver[0] <= 8'h00;
            jvs_nodes_r.node_players[0] <= 4'h0;
            jvs_nodes_r.node_buttons[0] <= 8'h0;
            jvs_nodes_r.node_analog_channels[0] <= 4'h0;
            jvs_nodes_r.node_rotary_channels[0] <= 4'h0;
            jvs_nodes_r.node_has_keycode_input[0] <= 1'b0;
            // Initialize has_screen_pos output
            has_screen_pos <= 1'b0;
            jvs_nodes_r.node_has_screen_pos[0] <= 1'b0;
            jvs_nodes_r.node_screen_pos_x_bits[0] <= 8'h0;
            jvs_nodes_r.node_screen_pos_y_bits[0] <= 8'h0;
            jvs_nodes_r.node_misc_digital_inputs[0] <= 16'h0;
            // Output capabilities
            jvs_nodes_r.node_digital_outputs[0] <= 8'h0;
            jvs_nodes_r.node_analog_output_channels[0] <= 4'h0;
            jvs_nodes_r.node_card_system_slots[0] <= 8'h0;
            jvs_nodes_r.node_medal_hopper_channels[0] <= 8'h0;
            jvs_nodes_r.node_has_char_display[0] <= 1'b0;
            jvs_nodes_r.node_char_display_width[0] <= 8'h0;
            jvs_nodes_r.node_char_display_height[0] <= 8'h0;
            jvs_nodes_r.node_char_display_type[0] <= 8'h0;
            jvs_nodes_r.node_has_backup[0] <= 1'b0;
        end else begin
            jvs_data_ready_init <= 1'b0; // data ready is a pulse
            case (main_state)
                //-------------------------------------------------------------
                // NODES POOLING STATE - Multi-node cyclic polling for responsive gaming
                //-------------------------------------------------------------
                STATE_NODES_POOLING: begin
                    if (jvs_nodes_r.node_count > 1) begin
                        main_state <= STATE_SEND_INPUTS;
                        // Multiple nodes configured - cycle through them
                        if (current_device_addr >= jvs_nodes_r.node_count) begin
                            current_device_addr <= 8'h01;  // Reset to first node
                            jvs_data_ready_joy <= 1'b1;
                            global_player <= 4'd0;
                            delay_counter <= POLLING_INTERVAL_DELAY;
                            main_state <= STATE_MAIN_TIMER_DELAY;
                            return_state <= STATE_SEND_INPUTS;
                        end else begin
                            current_device_addr <= current_device_addr + 1;  // Next node
                            jvs_data_ready_joy <= 1'b1;
                            delay_counter <= POLLING_INTERVAL_DELAY;
                            main_state <= STATE_MAIN_TIMER_DELAY;
                            return_state <= STATE_SEND_INPUTS;
                        end
                    end else begin
                        // Single node or no nodes - keep address at 0x01
                        current_device_addr <= 8'h01;
                        jvs_data_ready_joy <= 1'b1;
                        global_player <= 4'd0;
                        // If we have only one node set a polling delay
                        delay_counter <= POLLING_INTERVAL_DELAY;
                        main_state <= STATE_MAIN_TIMER_DELAY;
                        return_state <= STATE_SEND_INPUTS;
                    end
                end

                //-------------------------------------------------------------
                // INITIALIZATION DELAY - Wait for system stabilization
                //-------------------------------------------------------------
                STATE_INIT_DELAY: begin
                    // Initial delay for core I/O initialization - 5.4 seconds
                    // This ensures the FPGA core and external circuits are fully stable
                    if (delay_counter < INIT_DELAY_COUNT) begin  // 5.4 seconds
                        delay_counter <= delay_counter + 1;
                    end else begin
                        delay_counter <= 32'h0;
                        main_state <= STATE_FIRST_RESET;
                    end
                end

                //-------------------------------------------------------------
                // FIRST RESET COMMAND - Begin JVS device initialization
                //-------------------------------------------------------------
                STATE_FIRST_RESET: begin
                    // Send first RESET command using sequential byte transmission
                    // JVS requires two reset commands for reliable initialization
                    if (com_tx_ready) begin
                        com_dst_node <= JVS_BROADCAST_ADDR;  // FF - Broadcast to all devices
                        return_state <= STATE_FIRST_RESET;
                        // Select byte and signal based on position
                        case (cmd_pos)
                            3'd0: begin
                                com_tx_data <= CMD_RESET;     // Reset command (0xF0)
                                com_tx_data_push <= 1'b1;     // Push as data because RESET does not give answer
                                main_state <= STATE_TX_NEXT; // Go to TX_NEXT
                            end
                            3'd1: begin
                                com_tx_data <= CMD_RESET_ARG; // Reset argument (0xD9)
                                com_tx_data_push <= 1'b1;    // Push as data  
                                main_state <= STATE_TX_NEXT; // Go to TX_NEXT
                            end
                            default: begin
                                // All bytes sent, commit and transition
                                com_commit <= 1'b1;
                                cmd_pos <= 8'd0;
                                main_state <= STATE_FIRST_RESET_DELAY;
                            end
                        endcase
                    end
                end

                //-------------------------------------------------------------
                // DELAY AFTER FIRST RESET
                //-------------------------------------------------------------
                STATE_FIRST_RESET_DELAY: begin
                    // 2 second delay after first RESET
                    if (delay_counter <FIRST_RESET_DELAY_COUNT) begin  //   2 seconds
                        delay_counter <= delay_counter + 1;
                    end else begin
                        delay_counter <= 32'h0;
                        main_state <= STATE_SECOND_RESET;
                    end
                end

                //-------------------------------------------------------------
                // SECOND RESET COMMAND - Ensure complete device reset
                //-------------------------------------------------------------
                STATE_SECOND_RESET: begin
                    // Send second RESET command using sequential byte transmission (identical to first)
                    if (com_tx_ready) begin
                        com_dst_node <= JVS_BROADCAST_ADDR;  // FF - Broadcast to all devices
                        return_state <= STATE_SECOND_RESET;
                        // Select byte and signal based on position
                        case (cmd_pos)
                            3'd0: begin
                                com_tx_data <= CMD_RESET;     // Reset command (0xF0)
                                com_tx_data_push <= 1'b1;     // Push as data does not give answer !!
                                main_state <= STATE_TX_NEXT; // Go to TX_NEXT
                            end
                            3'd1: begin
                                com_tx_data <= CMD_RESET_ARG; // Reset argument (0xD9)
                                com_tx_data_push <= 1'b1;    // Push as data  
                                main_state <= STATE_TX_NEXT; // Go to TX_NEXT
                            end
                            default: begin
                                // All bytes sent, commit and transition
                                com_commit <= 1'b1;
                                cmd_pos <= 8'd0;
                                main_state <= STATE_SECOND_RESET_DELAY;
                            end
                        endcase
                    end
                end

                //-------------------------------------------------------------
                // DELAY AFTER SECOND RESET
                //-------------------------------------------------------------
                STATE_SECOND_RESET_DELAY: begin
                    // 500ms delay after second RESET
                    // Shorter delay as devices should be ready after two resets 
                    if (delay_counter < SECOND_RESET_DELAY_COUNT) begin  // 500ms
                        delay_counter <= delay_counter + 1;
                    end else begin
                        delay_counter <= 32'h0;
                        main_state <= STATE_SEND_SETADDR;
                    end
                end

                //-------------------------------------------------------------
                // SET ADDRESS COMMAND - Assign unique address to device
                //-------------------------------------------------------------
                STATE_SEND_SETADDR: begin
                    // Configure timeout and success states for this command
                    timeout_counter <= RX_TIMEOUT_COUNT;           // Set timeout value

                    // Configure timeout handling based on retry count and node count
                    if (timeout_retry_count >= 8'd3 && jvs_nodes_r.node_count > 0) begin
                        // After 3 timeouts and at least 1 node configured: ignore i_sense and go to polling
                        on_timeout_state <= STATE_NODES_POOLING;
                    end else begin
                        // Normal timeout: retry SETADDR
                        on_timeout_state <= STATE_SEND_SETADDR;
                    end

                    on_success_state <= STATE_SEND_IOIDENT;        // On success: go to next command

                    // Send SET ADDRESS command using sequential byte transmission
                    return_state <= STATE_SEND_SETADDR; // STATE TO GO BACK from STATE_TX_NEXT
                    if (com_tx_ready) begin
                        if (i_sense == 1'b0) begin
                            // @TODO: Loop until i_sense goes high that indicate that all nodes are initialized
                            // jvs_node_r <= current_device_addr
                            // current_device_addr <= current_device_addr + 1
                        end
                        // Initialize command parameters on first entry
                        com_dst_node <= JVS_BROADCAST_ADDR;
                        main_state <= STATE_TX_NEXT; // State to pulse jvscom and push byte
                        // Select byte and signal based on position
                        case (cmd_pos)
                            3'd0: begin
                                com_tx_data <= CMD_SETADDR;         // Set address command (0xF1)
                                com_tx_cmd_push <= 1'b1;            // Push as command to store in jvscom FIFO for answer parsing
                                main_state <= STATE_TX_NEXT;        // Go to TX_NEXT
                            end
                            3'd1: begin
                                com_tx_data <= current_device_addr; // Address to assign
                                com_tx_data_push <= 1'b1;           // Push as data
                            end
                            default: begin
                                // All bytes sent, commit and transition
                                cmd_pos <= 3'd0; // @TODO: STATE_TX_NEXT should automatically reset com_pos to 0
                                com_commit <= 1'b1;
                                main_state <= STATE_WAIT_RX;
                            end
                        endcase
                    end
                end
                
                //-------------------------------------------------------------
                // PARSE SETADDR RESPONSE - Verify address assignment
                //-------------------------------------------------------------
                RX_PARSE_SETADDR: begin
                    return_state <= RX_PARSE_SETADDR;
                    case (cmd_pos)
                        3'd0: begin
                            com_src_cmd_next <= 1'b1; // Flush FIFO to advance to next command
                            // Check REPORT byte
                            if (com_rx_byte == REPORT_NORMAL) begin
                                com_rx_next <= 1'b1;     // Advance to first name character
                                main_state <= STATE_RX_NEXT;
                            end else begin
                                main_state <= STATE_FATAL_ERROR;
                            end
                        end
                        default: begin
                            cmd_pos <= 8'd0;          // Reset position for next command
                            // Add delay before going to configured success state
                            delay_counter <= SETADDR_TO_IOIDENT_DELAY;
                            return_state <= on_success_state;
                            main_state <= STATE_MAIN_TIMER_DELAY;
                        end
                    endcase
                end
                
                //-------------------------------------------------------------
                // READ ID COMMAND - Request device identification
                //-------------------------------------------------------------
                STATE_SEND_IOIDENT: begin
                    // Configure timeout and success states for this command
                    timeout_counter <= RX_TIMEOUT_COUNT;           // Set timeout value
                    on_timeout_state <= STATE_SEND_IOIDENT;        // On timeout: retry immediately
                    on_success_state <= STATE_SEND_CMDREV;         // On success: go to next command

                    if (com_tx_ready) begin
                        // Initialize command parameters on first entry
                        com_dst_node <= current_device_addr; // 01 - Address specific device
                        return_state <= STATE_SEND_IOIDENT;
                        main_state <= STATE_TX_NEXT;
                        // Select byte and signal based on position
                        case (cmd_pos)
                            3'd0: begin
                                com_tx_data <= CMD_IOIDENT;          // IO identity command (0x10)
                                com_tx_cmd_push <= 1'b1;             // Push as command
                                main_state <= STATE_TX_NEXT;        // Go to TX_NEXT
                            end
                            default: begin
                                // All bytes sent, commit and transition then wait answer
                                com_commit <= 1'b1;
                                main_state <= STATE_WAIT_RX;
                            end
                        endcase
                    end
                end
                
                //-------------------------------------------------------------
                // PARSE IOIDENT RESPONSE - Extract device name
                //-------------------------------------------------------------
                RX_PARSE_IOIDENT: begin
                    return_state <= RX_PARSE_IOIDENT;
                    case (cmd_pos)
                        3'd0: begin
                            com_src_cmd_next <= 1'b1; // Flush FIFO to advance to next command
                            // Check REPORT byte
                            if (com_rx_byte == REPORT_NORMAL) begin
                                copy_write_idx <= 8'd0;  // Reset write index for name copying
                                // Initialize checksum calculation and BRAM address
                                name_checksum_crc <= 16'h0000;  // Simple sum checksum initial value
                                name_bram_write_addr <= (current_device_addr - 1) * jvs_node_info_pkg::NODE_NAME_SIZE;
                                com_rx_next <= 1'b1;     // Advance to first name character
                                main_state <= STATE_RX_NEXT;
                            end else begin
                                main_state <= STATE_FATAL_ERROR;
                            end
                        end
                        default: begin
                            // Copy device name characters until null terminator or end of data
                            if (com_rx_remaining > 0) begin // > 1 because we need to leave room for checksum
                                if (com_rx_byte == 8'h00) begin
                                    // Found null terminator, store it and finish copying
                                    node_name_ram[name_bram_write_addr + copy_write_idx] <= 8'h00; // Store in BRAM
                                    // Store final checksum in node info structure
                                    jvs_nodes_r.node_name_checksum[current_device_addr - 1] <= name_checksum_crc;
                                    cmd_pos <= 8'd0;  // Reset position for next command
                                    // Add delay before sending CMDREV command
                                    delay_counter <= IOIDENT_TO_CMDREV_DELAY;
                                    return_state <= STATE_SEND_CMDREV;
                                    main_state <= STATE_MAIN_TIMER_DELAY;
                                end else if (copy_write_idx < jvs_node_info_pkg::NODE_NAME_SIZE - 1) begin
                                    // Store character in BRAM and update checksum
                                    node_name_ram[name_bram_write_addr + copy_write_idx] <= com_rx_byte;
                                    // Simple checksum update (sum of bytes for simplicity)
                                    name_checksum_crc <= name_checksum_crc + com_rx_byte;
                                    copy_write_idx <= copy_write_idx + 1;
                                    com_rx_next <= 1'b1;     // Advance to first name character
                                    main_state <= STATE_RX_NEXT;
                                end else begin
                                    // Buffer full, skip remaining characters until null terminator
                                    com_rx_next <= 1'b1;     // Advance to first name character
                                    cmd_pos <= 8'd0;  // Reset position for next command
                                    delay_counter <= IOIDENT_TO_CMDREV_DELAY;
                                    return_state <= on_success_state;
                                    main_state <= STATE_MAIN_TIMER_DELAY;
                                end
                            end else begin
                                // End of data reached without null terminator
                                cmd_pos <= 8'd0;
                                delay_counter <= IOIDENT_TO_CMDREV_DELAY;
                                return_state <= on_success_state;
                                main_state <= STATE_MAIN_TIMER_DELAY;
                            end
                        end
                    endcase
                end
                
                //-------------------------------------------------------------
                // COMMAND REVISION REQUEST - Get command format revision
                //-------------------------------------------------------------
                STATE_SEND_CMDREV: begin
                    // Configure timeout and success states for this command
                    timeout_counter <= RX_TIMEOUT_COUNT;           // Set timeout value
                    on_timeout_state <= STATE_SEND_CMDREV;         // On timeout: retry immediately
                    on_success_state <= STATE_SEND_JVSREV;         // On success: go to next command

                    if (com_tx_ready) begin
                        // Initialize command parameters on first entry
                        main_state <= STATE_TX_NEXT;
                        com_dst_node <= current_device_addr; // 01 - Address specific device
                        return_state <= STATE_SEND_CMDREV;
                        // Select byte and signal based on position
                        case (cmd_pos)
                            3'd0: begin
                                com_tx_data <= CMD_CMDREV;          // Command revision command (0x11)
                                com_tx_cmd_push <= 1'b1;            // Push as command (ONLY this one!)
                                main_state <= STATE_TX_NEXT;        // Go to TX_NEXT
                            end
                            default: begin
                                // All bytes sent, commit and transition
                                com_commit <= 1'b1;
                                main_state <= STATE_WAIT_RX;
                            end
                        endcase
                    end
                end
                
                //-------------------------------------------------------------
                // PARSE CMDREV RESPONSE - Extract command revision
                //-------------------------------------------------------------
                RX_PARSE_CMDREV: begin
                    return_state <= RX_PARSE_CMDREV;
                    case (cmd_pos)
                        3'd0: begin
                            com_src_cmd_next <= 1'b1; // Flush FIFO to advance to next command
                            // Check REPORT byte
                            if (com_rx_byte == REPORT_NORMAL) begin
                                com_rx_next <= 1'b1;     // Advance to revision data
                                main_state <= STATE_RX_NEXT;
                            end else begin
                                main_state <= STATE_FATAL_ERROR;
                            end
                        end
                        3'd1: begin
                            // Store command revision (BCD format)
                            jvs_nodes_r.node_cmd_ver[current_device_addr - 1] <= com_rx_byte;
                            cmd_pos <= 8'd0;          // Reset position for next command
                            delay_counter <= CMDREV_TO_JVSREV_DELAY;
                            return_state <= on_success_state;
                            main_state <= STATE_MAIN_TIMER_DELAY;
                        end
                        default: begin
                            cmd_pos <= 8'd0;          // Reset position for next command
                            delay_counter <= CMDREV_TO_JVSREV_DELAY;
                            return_state <= on_success_state;
                            main_state <= STATE_MAIN_TIMER_DELAY;
                        end
                    endcase
                end
                
                //-------------------------------------------------------------
                // JVS REVISION REQUEST - Get JVS protocol revision
                //-------------------------------------------------------------
                STATE_SEND_JVSREV: begin
                    // Send JVSREV command using sequential byte transmission
                    if (com_tx_ready) begin
                        com_dst_node <= current_device_addr; // 01
                        return_state <= STATE_SEND_JVSREV;
                        // Select byte and signal based on position
                        case (cmd_pos)
                            3'd0: begin
                                com_tx_data <= CMD_JVSREV;          // Command revision command (0x11)
                                com_tx_cmd_push <= 1'b1;            // Push as command
                                main_state <= STATE_TX_NEXT;        // Go to TX_NEXT
                            end
                            default: begin
                                // All bytes sent, commit and transition
                                com_commit <= 1'b1;
                                main_state <= STATE_WAIT_RX;
                            end
                        endcase
                    end
                end
                
                //-------------------------------------------------------------
                // PARSE JVSREV RESPONSE - Extract JVS revision
                //-------------------------------------------------------------
                RX_PARSE_JVSREV: begin
                    return_state <= RX_PARSE_JVSREV;
                    case (cmd_pos)
                        3'd0: begin
                            com_src_cmd_next <= 1'b1; // Flush FIFO to advance to next command
                            // Check REPORT byte
                            if (com_rx_byte == REPORT_NORMAL) begin
                                com_rx_next <= 1'b1;     // Advance to revision data
                                main_state <= STATE_RX_NEXT;
                            end else begin
                                main_state <= STATE_FATAL_ERROR;
                            end
                        end
                        3'd1: begin
                            // Store JVS revision (BCD format)
                            jvs_nodes_r.node_jvs_ver[current_device_addr - 1] <= com_rx_byte;
                            cmd_pos <= 8'd0;          // Reset position for next command
                            delay_counter <= JVSREV_TO_COMMVER_DELAY;
                            return_state <= STATE_SEND_COMMVER;
                            main_state <= STATE_MAIN_TIMER_DELAY;
                        end
                        default: begin
                            cmd_pos <= 8'd0;          // Reset position for next command
                            delay_counter <= JVSREV_TO_COMMVER_DELAY;
                            return_state <= STATE_SEND_COMMVER;
                            main_state <= STATE_MAIN_TIMER_DELAY;
                        end
                    endcase
                end
                
                //-------------------------------------------------------------
                // COMMUNICATIONS VERSION REQUEST - Get communication version
                //-------------------------------------------------------------
                STATE_SEND_COMMVER: begin
                    // Send COMMVER command using sequential byte transmission
                    if (com_tx_ready) begin
                        // Initialize command parameters on first entry
                        com_dst_node <= current_device_addr; // 01
                        return_state <= STATE_SEND_COMMVER;
                        // Select byte and signal based on position
                        case (cmd_pos)
                            3'd0: begin
                                com_tx_data <= CMD_COMMVER;          // Command revision command (0x11)
                                com_tx_cmd_push <= 1'b1;            // Push as command
                                main_state <= STATE_TX_NEXT;        // Go to TX_NEXT
                            end
                            default: begin
                                // All bytes sent, commit and transition
                                com_commit <= 1'b1;
                                main_state <= STATE_WAIT_RX;
                            end
                        endcase
                    end
                end
                
                //-------------------------------------------------------------
                // PARSE COMMVER RESPONSE - Extract communications version
                //-------------------------------------------------------------
                RX_PARSE_COMMVER: begin
                    return_state <= RX_PARSE_COMMVER;
                    case (cmd_pos)
                        3'd0: begin
                            com_src_cmd_next <= 1'b1; // Flush FIFO to advance to next command
                            // Check REPORT byte
                            if (com_rx_byte == REPORT_NORMAL) begin
                                com_rx_next <= 1'b1;     // Advance to revision data
                                main_state <= STATE_RX_NEXT;
                            end else begin
                                main_state <= STATE_FATAL_ERROR;
                            end
                        end
                        3'd1: begin
                            // Store communications version (BCD format)
                            jvs_nodes_r.node_com_ver[current_device_addr - 1] <= com_rx_byte;
                            cmd_pos <= 8'd0;          // Reset position for next command
                            delay_counter <= COMMVER_TO_FEATURES_DELAY;
                            return_state <= STATE_SEND_FEATCHK;
                            main_state <= STATE_MAIN_TIMER_DELAY;
                        end
                        default: begin
                            cmd_pos <= 8'd0;          // Reset position for next command
                            delay_counter <= COMMVER_TO_FEATURES_DELAY;
                            return_state <= STATE_SEND_FEATCHK;
                            main_state <= STATE_MAIN_TIMER_DELAY;
                        end
                    endcase
                end
                
                //-------------------------------------------------------------
                // FEATURE CHECK REQUEST - Get device capabilities
                //-------------------------------------------------------------
                STATE_SEND_FEATCHK: begin
                    // Configure timeout and success states for this command
                    timeout_counter <= RX_TIMEOUT_COUNT;           // Set timeout value
                    on_timeout_state <= STATE_SEND_FEATCHK;        // On timeout: retry immediately

                    // Configure success state based on i_sense (more nodes to configure?)
                    if (i_sense == 1'b0) begin
                        // More nodes to configure - go to SETADDR for next node after feature parsing
                        on_success_state <= STATE_SEND_SETADDR;
                    end else begin
                        // All nodes configured - proceed to input polling via STATE_NODES_POOLING
                        on_success_state <= STATE_NODES_POOLING;
                    end

                    // Send FEATCHK command using sequential byte transmission
                    if (com_tx_ready) begin
                        // Initialize command parameters on first entry
                        if (cmd_pos == 0) begin
                            com_dst_node <= current_device_addr; // 01
                            return_state <= STATE_SEND_FEATCHK;
                        end
                        
                        // Select byte and signal based on position
                        case (cmd_pos)
                            3'd0: begin
                                com_tx_data <= CMD_FEATCHK;         // Feature check command (0x14)
                                com_tx_cmd_push <= 1'b1;            // Push as command
                                main_state <= STATE_TX_NEXT;        // Go to TX_NEXT
                            end
                            default: begin
                                // All bytes sent, commit and transition
                                com_commit <= 1'b1;
                                cmd_pos <= 8'd0;
                                main_state <= STATE_WAIT_RX;
                            end
                        endcase
                    end
                end

                RX_PARSE_FEATURES: begin
                    $display("RX_PARSE_FEATURES");
                    return_state <= RX_PARSE_FEATURES;
                    case (cmd_pos)
                        3'd0: begin
                            // Check REPORT byte
                            com_src_cmd_next <= 1'b1; // Flush FIFO to advance to next command
                            if (com_rx_byte == REPORT_NORMAL) begin
                                com_rx_next <= 1'b1;
                                return_state <= RX_PARSE_FEATURES_FUNCS;
                                main_state <= STATE_RX_NEXT;
                                cmd_pos <= 0; // set cmd_pos to 0 for functions parsing, RX_NEXT increment cmd_pos so func parsing start a 1
                            end else begin
                                main_state <= STATE_WAIT_RX;
                            end
                        end
                    endcase
                end
                RX_PARSE_FEATURES_FUNCS: begin
                    $display("RX_PARSE_FEATURES_FUNC com_rx_remaining(%d), cmd_pos(%d), com_rx_byte(0x%02x)", com_rx_remaining, cmd_pos, com_rx_byte);
                    return_state <= RX_PARSE_FEATURES_FUNCS;
                    if (com_rx_remaining > 0) begin
                        case (cmd_pos)
                            3'd1: begin // FUNC
                                if (com_rx_byte == 8'h00) begin
                                    // Terminator found - feature parsing complete for this node
                                    // jvs_data_ready_init <= 1'b1;
                                    cmd_pos <= 8'd0;

                                    // Increment node count for this configured node
                                    jvs_nodes_r.node_count <= jvs_nodes_r.node_count + 1;

                                    // If going to SETADDR for next node, increment device address
                                    if (on_success_state == STATE_SEND_SETADDR) begin
                                        // Initializer next node
                                        jvs_nodes_r.node_id[current_device_addr + 1] <= current_device_addr + 1;
                                        jvs_nodes_r.node_cmd_ver[current_device_addr + 1] <= 8'h00;
                                        jvs_nodes_r.node_jvs_ver[current_device_addr + 1] <= 8'h00;
                                        jvs_nodes_r.node_com_ver[current_device_addr + 1] <= 8'h00;
                                        jvs_nodes_r.node_players[current_device_addr + 1] <= 4'h0;
                                        jvs_nodes_r.node_buttons[current_device_addr + 1] <= 8'h0;
                                        jvs_nodes_r.node_analog_channels[current_device_addr + 1] <= 4'h0;
                                        jvs_nodes_r.node_rotary_channels[current_device_addr + 1] <= 4'h0;
                                        jvs_nodes_r.node_has_keycode_input[current_device_addr + 1] <= 1'b0;
                                        // Initialize has_screen_pos output
                                        jvs_nodes_r.node_has_screen_pos[current_device_addr + 1] <= 1'b0;
                                        jvs_nodes_r.node_screen_pos_x_bits[current_device_addr + 1] <= 8'h0;
                                        jvs_nodes_r.node_screen_pos_y_bits[current_device_addr + 1] <= 8'h0;
                                        jvs_nodes_r.node_misc_digital_inputs[current_device_addr + 1] <= 16'h0;
                                        // Output capabilities
                                        jvs_nodes_r.node_digital_outputs[current_device_addr + 1] <= 8'h0;
                                        jvs_nodes_r.node_analog_output_channels[current_device_addr + 1] <= 4'h0;
                                        jvs_nodes_r.node_card_system_slots[current_device_addr + 1] <= 8'h0;
                                        jvs_nodes_r.node_medal_hopper_channels[current_device_addr + 1] <= 8'h0;
                                        jvs_nodes_r.node_has_char_display[current_device_addr + 1] <= 1'b0;
                                        jvs_nodes_r.node_char_display_width[current_device_addr + 1] <= 8'h0;
                                        jvs_nodes_r.node_char_display_height[current_device_addr + 1] <= 8'h0;
                                        jvs_nodes_r.node_char_display_type[current_device_addr + 1] <= 8'h0;
                                        jvs_nodes_r.node_has_backup[current_device_addr + 1] <= 1'b0;

                                        current_device_addr <= current_device_addr + 1;
                                    end

                                    // Add delay before going to configured success state
                                    delay_counter <= FEATURES_TO_IDLE_DELAY;
                                    return_state <= on_success_state;
                                    main_state <= STATE_MAIN_TIMER_DELAY;
                                end else begin
                                    // Store function code and continue
                                    current_func_code <= com_rx_byte;
                                    main_state <= STATE_RX_NEXT;
                                    com_rx_next <= 1'b1;
                                end
                            end
                            3'd2: begin // ARG1
                                case (current_func_code)
                                    FUNC_INPUT_DIGITAL: begin
                                        jvs_nodes_r.node_players[current_device_addr - 1] <= com_rx_byte[3:0];
                                        jvs_nodes_r.player_count <= jvs_nodes_r.player_count + com_rx_byte[3:0];
                                    end
                                    FUNC_INPUT_COIN: begin
                                        jvs_nodes_r.node_coin_slots[current_device_addr - 1] <= com_rx_byte[3:0];
                                    end
                                    FUNC_INPUT_ANALOG: begin
                                        jvs_nodes_r.node_analog_channels[current_device_addr - 1] <= com_rx_byte[3:0];
                                    end
                                    FUNC_INPUT_ROTARY: begin
                                        jvs_nodes_r.node_rotary_channels[current_device_addr - 1] <= com_rx_byte[3:0];
                                    end
                                    FUNC_INPUT_KEYCODE: begin
                                        jvs_nodes_r.node_has_keycode_input[current_device_addr - 1] <= 1'b1;
                                    end
                                    FUNC_INPUT_SCREEN_POS: begin
                                        jvs_nodes_r.node_screen_pos_x_bits[current_device_addr - 1] <= com_rx_byte;
                                    end
                                    FUNC_INPUT_MISC_DIGITAL: begin
                                        jvs_nodes_r.node_misc_digital_inputs[current_device_addr - 1][15:8] <= com_rx_byte;
                                    end
                                    FUNC_OUTPUT_CARD: begin
                                        jvs_nodes_r.node_card_system_slots[current_device_addr - 1] <= com_rx_byte;
                                    end
                                    FUNC_OUTPUT_HOPPER: begin
                                        jvs_nodes_r.node_medal_hopper_channels[current_device_addr - 1] <= com_rx_byte;
                                    end
                                    FUNC_OUTPUT_DIGITAL: begin
                                        jvs_nodes_r.node_digital_outputs[current_device_addr - 1] <= com_rx_byte;
                                    end
                                    FUNC_OUTPUT_ANALOG: begin
                                        jvs_nodes_r.node_analog_output_channels[current_device_addr - 1] <= com_rx_byte[3:0];
                                    end
                                    FUNC_OUTPUT_CHAR: begin
                                        jvs_nodes_r.node_has_char_display[current_device_addr - 1] <= 1'b1;
                                        jvs_nodes_r.node_char_display_width[current_device_addr - 1] <= com_rx_byte;
                                    end
                                    FUNC_OUTPUT_BACKUP: begin
                                        jvs_nodes_r.node_has_backup[current_device_addr - 1] <= 1'b1;
                                    end
                                    default: begin
                                        main_state <= STATE_FATAL_ERROR;
                                    end
                                endcase
                                main_state <= STATE_RX_NEXT;
                                com_rx_next <= 1'b1;
                            end
                            3'd3: begin // ARG2
                                case (current_func_code)
                                    FUNC_INPUT_DIGITAL: begin
                                        jvs_nodes_r.node_buttons[current_device_addr - 1] <= com_rx_byte;
                                    end
                                    FUNC_INPUT_ANALOG: begin
                                        jvs_nodes_r.node_analog_bits[current_device_addr - 1] <= com_rx_byte;
                                    end
                                    FUNC_INPUT_SCREEN_POS: begin
                                        jvs_nodes_r.node_screen_pos_y_bits[current_device_addr - 1] <= com_rx_byte;
                                        jvs_nodes_r.node_has_screen_pos[current_device_addr - 1] <= 1'b1;
                                        has_screen_pos <= 1'b1;
                                    end
                                    FUNC_INPUT_MISC_DIGITAL: begin
                                        jvs_nodes_r.node_misc_digital_inputs[current_device_addr - 1][7:0] <= com_rx_byte;
                                    end
                                    FUNC_OUTPUT_CHAR: begin
                                        jvs_nodes_r.node_char_display_height[current_device_addr - 1] <= com_rx_byte;
                                    end
                                endcase
                                main_state <= STATE_RX_NEXT;
                                com_rx_next <= 1'b1;
                            end
                            3'd4: begin // ARG3
                                case (current_func_code)
                                    FUNC_INPUT_SCREEN_POS: begin
                                        jvs_nodes_r.node_screen_pos_channels[current_device_addr - 1] <= com_rx_byte;
                                    end
                                    FUNC_OUTPUT_CHAR: begin
                                        jvs_nodes_r.node_char_display_type[current_device_addr - 1] <= com_rx_byte;
                                    end
                                endcase
                                main_state <= STATE_RX_NEXT;
                                com_rx_next <= 1'b1;
                                cmd_pos <= 0; // end of FUNC ARGS
                            end
                        endcase
                    end else begin
                        main_state <= STATE_SEND_INPUTS;
                    end
                end

                //-------------------------------------------------------------
                // READ INPUTS COMMAND - Request current input states
                //-------------------------------------------------------------
                STATE_SEND_INPUTS: begin
                    // Send input commands using new jvs_com interface
                    // Mark that we're now in polling mode (initialization complete)
                    if (polling_mode == 1'b0) begin
                        global_player <= 4'd0;
                        jvs_data_ready_init <= 1'b1;
                    end
                    polling_mode <= 1'b1;

                    // Configure timeout and success states for input polling
                    timeout_counter <= RX_TIMEOUT_COUNT;           // Set timeout value
                    on_timeout_state <= STATE_NODES_POOLING;       // On timeout: return to nodes polling cycle
                    on_success_state <= STATE_NODES_POOLING;       // On success: return to nodes polling cycle

                    if (com_tx_ready) begin
                        // Set destination node
                        com_dst_node <= current_device_addr; // 01

                        // Reset cmd_pos for new polling cycle
                        cmd_pos <= 8'd0;

                        // Begin progressive state machine - start with switch inputs
                        main_state <= STATE_SEND_INPUTS_SWITCH;
                    end
                end

                //-------------------------------------------------------------
                // INPUT BUILDING PROGRESSIVE STATES
                //-------------------------------------------------------------
                STATE_SEND_INPUTS_SWITCH: begin
                    if (jvs_nodes_r.node_players[current_device_addr - 1] > 0) begin
                        // Send SWINP command using sequential byte transmission
                        if (com_tx_ready) begin
                            // Initialize command parameters on first entry
                            if (cmd_pos == 0) begin
                                com_dst_node <= current_device_addr;
                                return_state <= STATE_SEND_INPUTS_SWITCH;
                            end

                            // Select byte and signal based on position
                            case (cmd_pos)
                                3'd0: begin
                                    com_tx_data <= CMD_SWINP;         // SWINP command (0x20)
                                    com_tx_cmd_push <= 1'b1;         // Push as command
                                    main_state <= STATE_TX_NEXT;     // Go to TX_NEXT
                                end
                                3'd1: begin
                                    com_tx_data <= jvs_nodes_r.node_players[current_device_addr - 1];  // Number of players
                                    com_tx_data_push <= 1'b1;        // Push as data
                                    main_state <= STATE_TX_NEXT;     // Go to TX_NEXT
                                end
                                3'd2: begin
                                    com_tx_data <= (jvs_nodes_r.node_buttons[current_device_addr - 1] + 7) / 8; // Bytes for buttons
                                    com_tx_data_push <= 1'b1;        // Push as data
                                    main_state <= STATE_TX_NEXT;     // Go to TX_NEXT
                                end
                                default: begin
                                    cmd_pos <= 8'd0;
                                    main_state <= STATE_SEND_INPUTS_COIN;
                                end
                            endcase
                        end
                    end else begin
                        main_state <= STATE_SEND_INPUTS_COIN;
                    end
                end
                STATE_SEND_INPUTS_COIN: begin // (CMD_COININP) @TODO: (CMD_COINDEC),(COININC)
                    if (jvs_nodes_r.node_coin_slots[current_device_addr - 1] > 0) begin
                        // Send COININP command using sequential byte transmission
                        if (com_tx_ready) begin
                            // Initialize command parameters on first entry
                            if (cmd_pos == 0) begin
                                com_dst_node <= current_device_addr;
                                return_state <= STATE_SEND_INPUTS_COIN;
                            end
                            // Select byte and signal based on position
                            case (cmd_pos)
                                3'd0: begin
                                    com_tx_data <= CMD_COININP;       // COININP command (0x21)
                                    com_tx_cmd_push <= 1'b1;         // Push as command
                                    main_state <= STATE_TX_NEXT;     // Go to TX_NEXT
                                end
                                3'd1: begin
                                    com_tx_data <= jvs_nodes_r.node_coin_slots[current_device_addr - 1]; // Number of coin slots
                                    com_tx_data_push <= 1'b1;        // Push as data
                                    main_state <= STATE_TX_NEXT;     // Go to TX_NEXT
                                end
                                default: begin
                                    cmd_pos <= 8'd0;
                                    main_state <= STATE_SEND_INPUTS_ANALOG;
                                end
                            endcase
                        end
                    end else begin
                        main_state <= STATE_SEND_INPUTS_ANALOG;
                    end
                end
                STATE_SEND_INPUTS_ANALOG: begin
                    if (jvs_nodes_r.node_analog_channels[current_device_addr - 1] > 0) begin
                        // Send ANLINP command using sequential byte transmission
                        if (com_tx_ready) begin
                            // Initialize command parameters on first entry
                            if (cmd_pos == 0) begin
                                com_dst_node <= current_device_addr;
                                return_state <= STATE_SEND_INPUTS_ANALOG;
                            end
                            // Select byte and signal based on position
                            case (cmd_pos)
                                3'd0: begin
                                    com_tx_data <= CMD_ANLINP;        // ANLINP command (0x22)
                                    com_tx_cmd_push <= 1'b1;         // Push as command
                                    main_state <= STATE_TX_NEXT;     // Go to TX_NEXT
                                end
                                3'd1: begin
                                    com_tx_data <= jvs_nodes_r.node_analog_channels[current_device_addr - 1]; // Number of analog channels
                                    com_tx_data_push <= 1'b1;        // Push as data
                                    main_state <= STATE_TX_NEXT;     // Go to TX_NEXT
                                end
                                default: begin
                                    // All bytes sent, commit and transition
                                    //com_commit <= 1'b1;
                                    cmd_pos <= 8'd0;
                                    main_state <= STATE_SEND_INPUTS_ROTARY;
                                end
                            endcase
                        end
                    end else begin
                        main_state <= STATE_SEND_INPUTS_ROTARY;
                    end
                end
                STATE_SEND_INPUTS_ROTARY: begin
                    if (jvs_nodes_r.node_rotary_channels[current_device_addr - 1] > 0) begin
                        // Send ROTINP command using sequential byte transmission
                        if (com_tx_ready) begin
                            // Initialize command parameters on first entry
                            if (cmd_pos == 0) begin
                                com_dst_node <= current_device_addr;
                                return_state <= STATE_SEND_INPUTS_ROTARY;
                            end

                            // Select byte and signal based on position
                            case (cmd_pos)
                                3'd0: begin
                                    com_tx_data <= CMD_ROTINP;        // ROTINP command (0x23)
                                    com_tx_cmd_push <= 1'b1;         // Push as command
                                    main_state <= STATE_TX_NEXT;     // Go to TX_NEXT
                                end
                                3'd1: begin
                                    com_tx_data <= jvs_nodes_r.node_rotary_channels[current_device_addr - 1]; // Number of rotary channels
                                    com_tx_data_push <= 1'b1;        // Push as data
                                    main_state <= STATE_TX_NEXT;     // Go to TX_NEXT
                                end
                                default: begin
                                    // All bytes sent, commit and transition
                                    //com_commit <= 1'b1;
                                    cmd_pos <= 8'd0;
                                    main_state <= STATE_SEND_INPUTS_KEYCODE;
                                end
                            endcase
                        end
                    end else begin
                        main_state <= STATE_SEND_INPUTS_KEYCODE;
                    end
                end
                STATE_SEND_INPUTS_KEYCODE: begin
                    if (jvs_nodes_r.node_has_keycode_input[current_device_addr - 1]) begin
                        // Send KEYINP command using sequential byte transmission (no parameters)
                        if (com_tx_ready) begin
                            // Initialize command parameters on first entry
                            if (cmd_pos == 0) begin
                                com_dst_node <= current_device_addr;
                                return_state <= STATE_SEND_INPUTS_KEYCODE;
                            end

                            // Select byte and signal based on position
                            case (cmd_pos)
                                3'd0: begin
                                    com_tx_data <= CMD_KEYINP;        // KEYINP command (0x24)
                                    com_tx_cmd_push <= 1'b1;         // Push as command
                                    main_state <= STATE_TX_NEXT;     // Go to TX_NEXT
                                end
                                default: begin
                                    // All bytes sent, commit and transition
                                    //com_commit <= 1'b1;
                                    cmd_pos <= 8'd0;
                                    main_state <= STATE_SEND_INPUTS_SCREEN;
                                end
                            endcase
                        end
                    end else begin
                        main_state <= STATE_SEND_INPUTS_SCREEN;
                    end
                end
                STATE_SEND_INPUTS_SCREEN: begin
                    if (jvs_nodes_r.node_has_screen_pos[current_device_addr - 1]) begin
                        // Send SCRPOSINP command using sequential byte transmission
                        if (com_tx_ready) begin
                            // Initialize command parameters on first entry
                            if (cmd_pos == 0) begin
                                com_dst_node <= current_device_addr;
                                return_state <= STATE_SEND_INPUTS_SCREEN;
                            end

                            // Select byte and signal based on position
                            case (cmd_pos)
                                3'd0: begin
                                    com_tx_data <= CMD_SCRPOSINP;     // SCRPOSINP command (0x25)
                                    com_tx_cmd_push <= 1'b1;         // Push as command
                                    main_state <= STATE_TX_NEXT;     // Go to TX_NEXT
                                end
                                3'd1: begin
                                    com_tx_data <= 8'h01;            // Channel index
                                    com_tx_data_push <= 1'b1;        // Push as data
                                    main_state <= STATE_TX_NEXT;     // Go to TX_NEXT
                                end
                                default: begin
                                    // All bytes sent, commit and transition
                                    //com_commit <= 1'b1;
                                    cmd_pos <= 8'd0;
                                    main_state <= STATE_SEND_INPUTS_MISC;
                                end
                            endcase
                        end
                    end else begin
                        main_state <= STATE_SEND_INPUTS_MISC;
                    end
                end
                STATE_SEND_INPUTS_MISC: begin
                    if (jvs_nodes_r.node_misc_digital_inputs[current_device_addr - 1] > 0) begin
                        // Send MISCSWINP command using sequential byte transmission
                        if (com_tx_ready) begin
                            // Initialize command parameters on first entry
                            if (cmd_pos == 0) begin
                                com_dst_node <= current_device_addr;
                                return_state <= STATE_SEND_INPUTS_MISC;
                            end

                            // Select byte and signal based on position
                            case (cmd_pos)
                                3'd0: begin
                                    com_tx_data <= CMD_MISCSWINP;     // MISCSWINP command (0x26)
                                    com_tx_cmd_push <= 1'b1;         // Push as command
                                    main_state <= STATE_TX_NEXT;     // Go to TX_NEXT
                                end
                                3'd1: begin
                                    com_tx_data <= (jvs_nodes_r.node_misc_digital_inputs[current_device_addr - 1] + 7) / 8; // Bytes needed
                                    com_tx_data_push <= 1'b1;        // Push as data
                                    main_state <= STATE_TX_NEXT;     // Go to TX_NEXT
                                end
                                default: begin
                                    // All bytes sent, commit and transition
                                    //com_commit <= 1'b1;
                                    cmd_pos <= 8'd0;
                                    main_state <= STATE_SEND_OUTPUT_DIGITAL;
                                end
                            endcase
                        end
                    end else begin
                        main_state <= STATE_SEND_OUTPUT_DIGITAL;
                    end
                end
                // @TODO: Card system not supported
                // @TODO: Medal Hopper not supported (CMD_PAYCNT),(PAYINC),
                STATE_SEND_OUTPUT_DIGITAL: begin // (CMD_OUTPUT1) @TODO: (CMD_OUTPUT2),(CMD_OUTPUT3)
                    // Check if device has digital outputs
                    if (jvs_nodes_r.node_digital_outputs[current_device_addr - 1] > 0) begin
                        if (jvs_nodes_r.node_players[current_device_addr - 1] == 1) begin
                            // Single player mode (Time Crisis style) - Send OUTPUT1 command using sequential byte transmission
                            if (com_tx_ready) begin
                                // Initialize command parameters on first entry
                                if (cmd_pos == 0) begin
                                    com_dst_node <= current_device_addr;
                                    return_state <= STATE_SEND_OUTPUT_DIGITAL;
                                end

                                // Select byte and signal based on position
                                case (cmd_pos)
                                    3'd0: begin
                                        com_tx_data <= CMD_OUTPUT1;       // OUTPUT1 command (0x32)
                                        com_tx_cmd_push <= 1'b1;         // Push as command
                                        main_state <= STATE_TX_NEXT;     // Go to TX_NEXT
                                    end
                                    3'd1: begin
                                        com_tx_data <= 8'h03;            // send 3 bytes
                                        com_tx_data_push <= 1'b1;        // Push as data
                                        main_state <= STATE_TX_NEXT;     // Go to TX_NEXT
                                    end
                                    3'd2: begin
                                        com_tx_data <= output_digital_ch1[7:0]; // Set GPIO1 to current value from SNAC
                                        com_tx_data_push <= 1'b1;        // Push as data
                                        main_state <= STATE_TX_NEXT;     // Go to TX_NEXT
                                    end
                                    3'd3: begin
                                        com_tx_data <= output_digital_ch1[15:8]; // Use MSB from SNAC module
                                        com_tx_data_push <= 1'b1;        // Push as data
                                        main_state <= STATE_TX_NEXT;     // Go to TX_NEXT
                                    end
                                    3'd4: begin
                                        com_tx_data <= 8'h00;
                                        com_tx_data_push <= 1'b1;        // Push as data
                                        main_state <= STATE_TX_NEXT;     // Go to TX_NEXT
                                    end
                                    default: begin
                                        // All bytes sent, transition to finalize
                                        cmd_pos <= 8'd0;
                                        main_state <= STATE_SEND_OUTPUT_ANALOG;
                                        current_channel <= 8'd0;
                                    end
                                endcase
                            end
                        end else begin
                            cmd_pos <= 8'd0;
                            main_state <= STATE_SEND_OUTPUT_ANALOG;
                            current_channel <= 8'd0;
                        end
                    end else begin
                        cmd_pos <= 8'd0;
                        main_state <= STATE_SEND_OUTPUT_ANALOG;
                        current_channel <= 8'd0;
                    end
                end
                // Analog Output not supported (CMD_ANLOUT)
                STATE_SEND_OUTPUT_ANALOG: begin // (CMD_ANLOUT)
                    // Check if device has analog outputs
                    if (jvs_nodes_r.node_analog_output_channels[current_device_addr - 1] > 0) begin
                        if(com_tx_ready) begin
                               // Initialize command parameters on first entry
                                if (cmd_pos == 0) begin
                                    com_dst_node <= current_device_addr;
                                    return_state <= STATE_SEND_OUTPUT_ANALOG;
                                end
                                if(current_channel >= jvs_nodes_r.node_analog_output_channels[current_device_addr - 1]) begin
                                    main_state <= STATE_SEND_FINALIZE;
                                    cmd_pos <= 0;
                                end else begin
                                    case (cmd_pos)
                                        3'd0: begin
                                            current_channel <= 0;
                                            com_tx_data <= CMD_ANLOUT;       // OUTPUT1 command (0x33)
                                            com_tx_cmd_push <= 1'b1;         // Push as command
                                            main_state <= STATE_TX_NEXT;     // Go to TX_NEXT
                                        end
                                        3'd1: begin
                                            com_tx_data <= jvs_nodes_r.node_analog_output_channels[current_device_addr - 1]; // Number of channels to send
                                            com_tx_data_push <= 1'b1;
                                            main_state <= STATE_TX_NEXT;     // Go to TX_NEXT
                                        end
                                        3'd2: begin
                                            com_tx_data <= 8'h00;           // Channel N MSB (@TODO: send null value at the momment)
                                            com_tx_data_push <=1'b1 ;       // Push data
                                            main_state <= STATE_TX_NEXT;    // Go to TX_NEXT
                                        end
                                        3'd3: begin
                                            com_tx_data <= 8'h00;            // Channel N LSB (@TODO: send null value at the momment)
                                            com_tx_data_push <= 1'b1;       // Push data
                                            main_state <= STATE_TX_NEXT;     // Go to TX_NEXT
                                            current_channel <= current_channel + 1;
                                            cmd_pos <= 1; // Go back to "3'd2" (MSB of next channel) after increased by TX_NEXT
                                        end
                                    endcase
                                end
                        end else begin
                            main_state <= STATE_SEND_FINALIZE;
                        end
                    end else begin
                        main_state <= STATE_SEND_FINALIZE;
                    end
                end
                // @TODO: Characters Output not supported (CHAROUT)
                // @TODO: Backup not supported
                //-------------------------------------------------------------
                // FINALIZE MULTI-COMMAND FRAME - Commit all accumulated commands
                //-------------------------------------------------------------
                STATE_SEND_FINALIZE: begin
                    com_commit <= 1'b1;
                    cmd_pos <= 8'd0;
                    main_state <= STATE_WAIT_RX;
                end

                RX_PARSE_INPUT_CMD: begin
                    // Check if there are commands in the FIFO
                    if (com_rx_remaining > 0) begin
                        // Parse based on current command in FIFO
                        case (com_src_cmd)
                            CMD_SETADDR: begin
                                case(cmd_pos)
                                    3'd0: begin
                                        com_src_cmd_next <= 1'b1; // Flush FIFO to advance to next command
                                        // Check REPORT byte
                                        if (com_rx_byte == REPORT_NORMAL) begin
                                            cmd_pos <= 8'd0;
                                            main_state <= STATE_SEND_IOIDENT;
                                        end else begin
                                            main_state <= STATE_FATAL_ERROR;
                                        end
                                    end
                                endcase
                            end
                            CMD_IOIDENT: begin
                                case(cmd_pos)
                                    3'd0: begin
                                        com_src_cmd_next <= 1'b1; // Flush FIFO to advance to next command
                                        // Check REPORT byte
                                        if (com_rx_byte == REPORT_NORMAL) begin
                                            copy_write_idx <= 8'd0;  // Reset write index for name copying
                                            // Initialize checksum calculation and BRAM address
                                            name_checksum_crc <= 16'h0000;  // Simple sum checksum initial value
                                            name_bram_write_addr <= (current_device_addr - 1) * jvs_node_info_pkg::NODE_NAME_SIZE;
                                            return_state <= RX_PARSE_INPUT_CMD;
                                            main_state <= STATE_RX_NEXT;
                                            com_rx_next <= 1'b1;
                                        end else begin
                                            main_state <= STATE_FATAL_ERROR;
                                        end
                                    end
                                    default: begin
                                        // Copy device name characters until null terminator or end of data
                                        if (com_rx_remaining > 0) begin
                                            if (com_rx_byte == 8'h00) begin
                                                // Found null terminator, store it and finish copying
                                                node_name_ram[name_bram_write_addr + copy_write_idx] <= 8'h00; // Store in BRAM
                                                // Store final checksum in node info structure
                                                jvs_nodes_r.node_name_checksum[current_device_addr - 1] <= name_checksum_crc;
                                                cmd_pos <= 8'd0;
                                                main_state <= STATE_SEND_CMDREV;
                                            end else if (copy_write_idx < jvs_node_info_pkg::NODE_NAME_SIZE - 1) begin
                                                // Store character in BRAM and update checksum
                                                node_name_ram[name_bram_write_addr + copy_write_idx] <= com_rx_byte;
                                                // Simple checksum update (sum of bytes for simplicity)
                                                name_checksum_crc <= name_checksum_crc + com_rx_byte;
                                                copy_write_idx <= copy_write_idx + 1;
                                                return_state <= RX_PARSE_INPUT_CMD;
                                                main_state <= STATE_RX_NEXT;
                                                com_rx_next <= 1'b1;
                                            end else begin
                                                // Name too long, truncate and finish
                                                node_name_ram[name_bram_write_addr + copy_write_idx] <= 8'h00; // Store in BRAM
                                                // Store final checksum in node info structure
                                                jvs_nodes_r.node_name_checksum[current_device_addr - 1] <= name_checksum_crc;
                                                cmd_pos <= 8'd0;
                                                main_state <= STATE_SEND_CMDREV;
                                            end
                                        end else begin
                                            // No more data, finish name copy
                                            node_name_ram[name_bram_write_addr + copy_write_idx] <= 8'h00; // Store in BRAM
                                            // Store final checksum in node info structure
                                            jvs_nodes_r.node_name_checksum[current_device_addr - 1] <= name_checksum_crc;
                                            cmd_pos <= 8'd0;
                                            main_state <= STATE_SEND_CMDREV;
                                        end
                                    end
                                endcase
                            end
                            CMD_CMDREV: begin
                                case(cmd_pos)
                                    3'd0: begin
                                        com_src_cmd_next <= 1'b1; // Flush FIFO to advance to next command
                                        // Check REPORT byte
                                        if (com_rx_byte == REPORT_NORMAL) begin
                                            return_state <= RX_PARSE_INPUT_CMD;
                                            main_state <= STATE_RX_NEXT;
                                            com_rx_next <= 1'b1;
                                        end else begin
                                            main_state <= STATE_FATAL_ERROR;
                                        end
                                    end
                                    3'd1: begin
                                        // Store command revision (BCD format)
                                        jvs_nodes_r.node_cmd_ver[current_device_addr - 1] <= com_rx_byte;
                                        cmd_pos <= 8'd0;
                                        main_state <= STATE_SEND_JVSREV;
                                    end
                                endcase
                            end
                            CMD_JVSREV: begin
                                case(cmd_pos)
                                    3'd0: begin
                                        com_src_cmd_next <= 1'b1; // Flush FIFO to advance to next command
                                        // Check REPORT byte
                                        if (com_rx_byte == REPORT_NORMAL) begin
                                            return_state <= RX_PARSE_INPUT_CMD;
                                            main_state <= STATE_RX_NEXT;
                                            com_rx_next <= 1'b1;
                                        end else begin
                                            main_state <= STATE_FATAL_ERROR;
                                        end
                                    end
                                    3'd1: begin
                                        // Store JVS revision (BCD format)
                                        jvs_nodes_r.node_jvs_ver[current_device_addr - 1] <= com_rx_byte;
                                        cmd_pos <= 8'd0;
                                        main_state <= STATE_SEND_COMMVER;
                                    end
                                endcase
                            end
                            CMD_COMMVER: begin
                                case(cmd_pos)
                                    3'd0: begin
                                        com_src_cmd_next <= 1'b1; // Flush FIFO to advance to next command
                                        // Check REPORT byte
                                        if (com_rx_byte == REPORT_NORMAL) begin
                                            return_state <= RX_PARSE_INPUT_CMD;
                                            main_state <= STATE_RX_NEXT;
                                            com_rx_next <= 1'b1;
                                        end else begin
                                            main_state <= STATE_FATAL_ERROR;
                                        end
                                    end
                                    3'd1: begin
                                        // Store communication version (BCD format)
                                        jvs_nodes_r.node_com_ver[current_device_addr - 1] <= com_rx_byte;
                                        cmd_pos <= 8'd0;
                                        main_state <= STATE_SEND_FEATCHK;
                                    end
                                endcase
                            end
                            CMD_FEATCHK: begin
                                case(cmd_pos)
                                    3'd0: begin
                                        com_src_cmd_next <= 1'b1; // Flush FIFO to advance to next command
                                        // Check REPORT byte
                                        if (com_rx_byte == REPORT_NORMAL) begin
                                            return_state <= RX_PARSE_INPUT_CMD;
                                            main_state <= STATE_RX_NEXT;
                                            com_rx_next <= 1'b1;
                                        end else begin
                                            main_state <= STATE_FATAL_ERROR;
                                        end
                                    end
                                    default: begin
                                        // Dispatch to RX_PARSE_FEATURES for feature parsing
                                        cmd_pos <= 0;
                                        main_state <= RX_PARSE_FEATURES;
                                    end
                                endcase
                            end
                            CMD_SWINP: begin
                                case(cmd_pos)
                                    3'd0: begin
                                        if (com_rx_byte == REPORT_NORMAL) begin
                                            return_state <= RX_PARSE_INPUT_CMD;
                                            main_state <= STATE_RX_NEXT;
                                            com_rx_next <= 1'b1;
                                        end else begin
                                            com_src_cmd_next <= 1'b1;
                                            return_state <= RX_PARSE_INPUT_CMD;
                                            cmd_pos <= 0;
                                            com_rx_next <= 1'b1;
                                            //main_state <= STATE_RX_NEXT;
                                            main_state <= STATE_FATAL_ERROR; // for now we stop the simulation @TODO: proper error handeling
                                        end
                                    end
                                    3'd1: begin
                                        current_player <= 0; // initialise player idx
                                        return_state <= RX_PARSE_SWINP;
                                        cmd_pos <= 0;
                                        main_state <= STATE_RX_NEXT;
                                        com_rx_next <= 1'b1;
                                    end
                                endcase
                            end
                            CMD_COININP: begin
                                case(cmd_pos)
                                    3'd0: begin
                                        // Check REPORT byte
                                        if (com_rx_byte == REPORT_NORMAL) begin
                                            return_state <= RX_PARSE_INPUT_CMD;
                                            main_state <= STATE_RX_NEXT;
                                            com_rx_next <= 1'b1;
                                            current_coin <= 0; // Initialize coin counter for parsing
                                        end else begin
                                            com_src_cmd_next <= 1'b1;
                                            cmd_pos <= 0;
                                            return_state <= RX_PARSE_INPUT_CMD;
                                            com_rx_next <= 1'b1;
                                            //main_state <= STATE_RX_NEXT;
                                            main_state <= STATE_FATAL_ERROR; // for now we stop the simulation @TODO: proper error handeling
                                        end
                                    end
                                    3'd1: begin
                                        // Dispatch to specialized COININP state
                                        current_coin <= 0; // Initialize coin counter for parsing
                                        return_state <= RX_PARSE_COININP;
                                        main_state <= RX_PARSE_COININP;
                                    end
                                endcase
                            end
                            CMD_ANLINP: begin
                                case(cmd_pos)
                                    3'd0: begin
                                        // Check REPORT byte
                                        if (com_rx_byte == REPORT_NORMAL) begin
                                            return_state <= RX_PARSE_INPUT_CMD;
                                            main_state <= STATE_RX_NEXT;
                                            com_rx_next <= 1'b1;
                                        end else begin
                                            com_src_cmd_next <= 1'b1;
                                            cmd_pos <= 0;
                                            return_state <= RX_PARSE_INPUT_CMD;
                                            main_state <= STATE_RX_NEXT;
                                            com_rx_next <= 1'b1;
                                        end
                                    end
                                    3'd1: begin
                                        // Dispatch to specialized ANLINP state
                                        cmd_pos <= 1; // Start at cmd_pos=1 for first analog byte
                                        current_channel <= 0; // Initialize channel counter
                                        return_state <= RX_PARSE_ANLINP;
                                        main_state <= RX_PARSE_ANLINP;
                                    end
                                endcase
                            end
                            CMD_ROTINP: begin
                                case(cmd_pos)
                                    3'd0: begin
                                        // Check REPORT byte
                                        if (com_rx_byte == REPORT_NORMAL) begin
                                            return_state <= RX_PARSE_INPUT_CMD;
                                            main_state <= STATE_RX_NEXT;
                                            com_rx_next <= 1'b1;
                                        end else begin
                                            com_src_cmd_next <= 1'b1;
                                            cmd_pos <= 0;
                                            return_state <= RX_PARSE_INPUT_CMD;
                                            main_state <= STATE_RX_NEXT;
                                            com_rx_next <= 1'b1;
                                        end
                                    end
                                    default: begin
                                        // Check if more data or advance to next command
                                        if (com_rx_remaining <= 1) begin
                                            // Last byte, advance to next command
                                            cmd_pos <= 0;
                                            com_src_cmd_next <= 1'b1;
                                        end
                                        return_state <= RX_PARSE_INPUT_CMD;
                                        main_state <= STATE_RX_NEXT;
                                        com_rx_next <= 1'b1;
                                    end
                                endcase
                            end
                            CMD_KEYINP: begin
                                case(cmd_pos)
                                    3'd0: begin
                                        // Check REPORT byte
                                        if (com_rx_byte == REPORT_NORMAL) begin
                                            return_state <= RX_PARSE_INPUT_CMD;
                                            main_state <= STATE_RX_NEXT;
                                            com_rx_next <= 1'b1;
                                        end else begin
                                            com_src_cmd_next <= 1'b1;
                                            cmd_pos <= 0;
                                            return_state <= RX_PARSE_INPUT_CMD;
                                            main_state <= STATE_RX_NEXT;
                                            com_rx_next <= 1'b1;
                                        end
                                    end
                                    default: begin
                                        // Check if more data or advance to next command
                                        if (com_rx_remaining <= 1) begin
                                            // Last byte, advance to next command
                                            cmd_pos <= 0;
                                            com_src_cmd_next <= 1'b1;
                                        end
                                        return_state <= RX_PARSE_INPUT_CMD;
                                        main_state <= STATE_RX_NEXT;
                                        com_rx_next <= 1'b1;
                                    end
                                endcase
                            end
                            CMD_SCRPOSINP: begin
                                case(cmd_pos)
                                    3'd0: begin
                                        // Check REPORT byte
                                        if (com_rx_byte == REPORT_NORMAL) begin
                                            return_state <= RX_PARSE_INPUT_CMD;
                                            main_state <= STATE_RX_NEXT;
                                            com_rx_next <= 1'b1;
                                        end else begin
                                            com_src_cmd_next <= 1'b1;
                                            cmd_pos <= 0;
                                            return_state <= RX_PARSE_INPUT_CMD;
                                            main_state <= STATE_RX_NEXT;
                                            com_rx_next <= 1'b1;
                                        end
                                    end
                                    3'd1: begin
                                        // Dispatch to specialized SCRPOSINP state for screen position parsing
                                        cmd_pos <= 0;
                                        return_state <= RX_PARSE_SCRPOSINP;
                                        main_state <= RX_PARSE_SCRPOSINP;
                                    end
                                endcase
                            end
                            CMD_MISCSWINP: begin
                                case(cmd_pos)
                                    3'd0: begin
                                        // Check REPORT byte
                                        if (com_rx_byte == REPORT_NORMAL) begin
                                            return_state <= RX_PARSE_INPUT_CMD;
                                            main_state <= STATE_RX_NEXT;
                                            com_rx_next <= 1'b1;
                                        end else begin
                                            com_src_cmd_next <= 1'b1;
                                            cmd_pos <= 0;
                                            return_state <= RX_PARSE_INPUT_CMD;
                                            main_state <= STATE_RX_NEXT;
                                            com_rx_next <= 1'b1;
                                        end
                                    end
                                    default: begin
                                        // Simple parsing - skip misc digital data (not implemented)
                                        // Check if more data or advance to next command
                                        if (com_rx_remaining <= 1) begin
                                            // Last byte, advance to next command
                                            cmd_pos <= 0;
                                            com_src_cmd_next <= 1'b1;
                                        end
                                        return_state <= RX_PARSE_INPUT_CMD;
                                        main_state <= STATE_RX_NEXT;
                                        com_rx_next <= 1'b1;
                                    end
                                endcase
                            end
                            CMD_OUTPUT1: begin
                                case(cmd_pos)
                                    3'd0: begin
                                        // Check REPORT byte
                                        if (com_rx_byte == REPORT_NORMAL) begin
                                            return_state <= RX_PARSE_INPUT_CMD;
                                            main_state <= STATE_RX_NEXT;
                                            com_rx_next <= 1'b1;
                                        end else begin
                                            com_src_cmd_next <= 1'b1;
                                            cmd_pos <= 0;
                                            return_state <= RX_PARSE_INPUT_CMD;
                                            main_state <= STATE_RX_NEXT;
                                            com_rx_next <= 1'b1;
                                        end
                                    end
                                    default: begin
                                        // Simple parsing - OUTPUT1 response is just acknowledgment, no complex data
                                        // Check if more data or advance to next command
                                        if (com_rx_remaining <= 1) begin
                                            // Last byte, advance to next command
                                            cmd_pos <= 0;
                                            com_src_cmd_next <= 1'b1;
                                        end
                                        return_state <= RX_PARSE_INPUT_CMD;
                                        main_state <= STATE_RX_NEXT;
                                        com_rx_next <= 1'b1;
                                    end
                                endcase
                            end
                            default: begin
                                com_src_cmd_next <= 1'b1;
                                cmd_pos <= 0;
                                return_state <= RX_PARSE_INPUT_CMD;
                                main_state <= STATE_RX_NEXT;
                                com_rx_next <= 1'b1;
                            end
                        endcase
                    end else begin
                        // No more commands to process
                        if (polling_mode) begin
                            main_state <= STATE_NODES_POOLING;
                        end else begin
                            // Still in initialization mode - continue init sequence
                            // This should not happen normally as init commands should continue the sequence
                            main_state <= STATE_FATAL_ERROR;
                        end
                    end
                end
                
                RX_PARSE_SWINP: begin
                    return_state <= RX_PARSE_SWINP;
                    if (current_player >= jvs_nodes_r.node_players[current_device_addr - 1]) begin
                        // We finished parsing node players
                        global_player <= global_player + jvs_nodes_r.node_players[current_device_addr - 1];
                        cmd_pos <= 0;
                        com_src_cmd_next <= 1'b1;
                        return_state <= RX_PARSE_INPUT_CMD;
                        main_state <= STATE_RX_NEXT;
                        com_rx_next <= 1'b1;
                    end else begin
                        case (global_player + current_player)
                            4'd0: begin // Player 1
                                if (cmd_pos == 1) begin
                                    // First player data byte
                                    player1_input_switch[15] <= com_rx_byte[7];  // START
                                    player1_input_switch[14] <= com_rx_byte[6];  // SELECT/SERVICE
                                    player1_input_switch[0]  <= com_rx_byte[5];  // UP
                                    player1_input_switch[1]  <= com_rx_byte[4];  // DOWN
                                    player1_input_switch[2]  <= com_rx_byte[3];  // LEFT
                                    player1_input_switch[3]  <= com_rx_byte[2];  // RIGHT
                                    player1_input_switch[4]  <= com_rx_byte[1];  // A (push1)
                                    player1_input_switch[5]  <= com_rx_byte[0];  // B (push2)

                                    if (jvs_nodes_r.node_buttons[current_device_addr - 1] <= 8) begin
                                        // Only 1 byte per player, clear unused bits and advance to next player
                                        player1_input_switch[13:6] <= 8'b00000000;
                                        current_player <= current_player + 1;
                                        cmd_pos <= 0;
                                    end
                                    main_state <= STATE_RX_NEXT;
                                    com_rx_next <= 1'b1;
                                end else if (cmd_pos == 2 && jvs_nodes_r.node_buttons[current_device_addr - 1] > 8) begin
                                    // Second player data byte (additional buttons)
                                    player1_input_switch[6] <= com_rx_byte[7];   // X (push3)
                                    player1_input_switch[7] <= com_rx_byte[6];   // Y (push4)
                                    player1_input_switch[8] <= com_rx_byte[5];   // push5 -> L1
                                    player1_input_switch[9] <= com_rx_byte[4];   // push6 -> R1
                                    player1_input_switch[10] <= com_rx_byte[3];  // push7 -> L2
                                    player1_input_switch[11] <= com_rx_byte[2];  // push8 -> R2
                                    player1_input_switch[12] <= com_rx_byte[1];  // push9 -> L3
                                    player1_input_switch[13] <= com_rx_byte[0];  // push10 -> R3
                                    // Advance to next player
                                    current_player <= current_player + 1;
                                    cmd_pos <= 0; // Reset for next player
                                    main_state <= STATE_RX_NEXT;
                                    com_rx_next <= 1'b1;
                                end
                            end

                            4'd1: begin // Player 2
                                if (cmd_pos == 1) begin
                                    // First player data byte
                                    player2_input_switch[15] <= com_rx_byte[7];  // START
                                    player2_input_switch[14] <= com_rx_byte[6];  // SELECT/SERVICE
                                    player2_input_switch[0]  <= com_rx_byte[5];  // UP
                                    player2_input_switch[1]  <= com_rx_byte[4];  // DOWN
                                    player2_input_switch[2]  <= com_rx_byte[3];  // LEFT
                                    player2_input_switch[3]  <= com_rx_byte[2];  // RIGHT
                                    player2_input_switch[4]  <= com_rx_byte[1];  // A (push1)
                                    player2_input_switch[5]  <= com_rx_byte[0];  // B (push2)

                                    if (jvs_nodes_r.node_buttons[current_device_addr - 1] <= 8) begin
                                        // Only 1 byte per player, clear unused bits and advance to next player
                                        player2_input_switch[13:6] <= 8'b00000000;
                                        current_player <= current_player + 1;
                                        cmd_pos <= 0;
                                    end
                                    main_state <= STATE_RX_NEXT;
                                    com_rx_next <= 1'b1;
                                end else if (cmd_pos == 2 && jvs_nodes_r.node_buttons[current_device_addr - 1] > 8) begin
                                    // Second player data byte (additional buttons) - match your reference bit mapping
                                    player2_input_switch[6] <= com_rx_byte[7];   // X (push3)
                                    player2_input_switch[7] <= com_rx_byte[6];   // Y (push4)
                                    player2_input_switch[8] <= com_rx_byte[5];   // push5 -> L1
                                    player2_input_switch[9] <= com_rx_byte[4];   // push6 -> R1
                                    player2_input_switch[10] <= com_rx_byte[3];  // push7 -> L2
                                    player2_input_switch[11] <= com_rx_byte[2];  // push8 -> R2
                                    // Clear unused upper bits for consistency with reference
                                    player2_input_switch[13:12] <= 2'b00;
                                    // Advance to next player
                                    current_player <= current_player + 1;
                                    cmd_pos <= 0; // Reset for next player
                                    main_state <= STATE_RX_NEXT;
                                    com_rx_next <= 1'b1;
                                end
                            end

                            4'd2: begin // Player 3
                                if (cmd_pos == 1) begin
                                    // First player data byte
                                    player3_input_switch[15] <= com_rx_byte[7];  // START
                                    player3_input_switch[14] <= com_rx_byte[6];  // SELECT/SERVICE
                                    player3_input_switch[0]  <= com_rx_byte[5];  // UP
                                    player3_input_switch[1]  <= com_rx_byte[4];  // DOWN
                                    player3_input_switch[2]  <= com_rx_byte[3];  // LEFT
                                    player3_input_switch[3]  <= com_rx_byte[2];  // RIGHT
                                    player3_input_switch[4]  <= com_rx_byte[1];  // A (push1)
                                    player3_input_switch[5]  <= com_rx_byte[0];  // B (push2)

                                    if (jvs_nodes_r.node_buttons[current_device_addr - 1] <= 8) begin
                                        // Only 1 byte per player, clear unused bits and advance to next player
                                        player3_input_switch[13:6] <= 8'b00000000;
                                        current_player <= current_player + 1;
                                        cmd_pos <= 0;
                                    end
                                    main_state <= STATE_RX_NEXT;
                                    com_rx_next <= 1'b1;
                                end else if (cmd_pos == 2 && jvs_nodes_r.node_buttons[current_device_addr - 1] > 8) begin
                                    // Second player data byte (additional buttons)
                                    player3_input_switch[6] <= com_rx_byte[7];   // X (push3)
                                    player3_input_switch[7] <= com_rx_byte[6];   // Y (push4)
                                    player3_input_switch[8] <= com_rx_byte[5];   // push5 -> L1
                                    player3_input_switch[9] <= com_rx_byte[4];   // push6 -> R1
                                    player3_input_switch[10] <= com_rx_byte[3];  // push7 -> L2
                                    player3_input_switch[11] <= com_rx_byte[2];  // push8 -> R2
                                    // Clear unused upper bits for consistency
                                    player3_input_switch[13:12] <= 2'b00;
                                    // Advance to next player
                                    current_player <= current_player + 1;
                                    cmd_pos <= 0; // Reset for next player
                                    main_state <= STATE_RX_NEXT;
                                    com_rx_next <= 1'b1;
                                end
                            end

                            4'd3: begin // Player 4
                                if (cmd_pos == 1) begin
                                    // First player data byte
                                    player4_input_switch[15] <= com_rx_byte[7];  // START
                                    player4_input_switch[14] <= com_rx_byte[6];  // SELECT/SERVICE
                                    player4_input_switch[0]  <= com_rx_byte[5];  // UP
                                    player4_input_switch[1]  <= com_rx_byte[4];  // DOWN
                                    player4_input_switch[2]  <= com_rx_byte[3];  // LEFT
                                    player4_input_switch[3]  <= com_rx_byte[2];  // RIGHT
                                    player4_input_switch[4]  <= com_rx_byte[1];  // A (push1)
                                    player4_input_switch[5]  <= com_rx_byte[0];  // B (push2)

                                    if (jvs_nodes_r.node_buttons[current_device_addr - 1] <= 8) begin
                                        // Only 1 byte per player, clear unused bits and advance to next player
                                        player4_input_switch[13:6] <= 8'b00000000;
                                        current_player <= current_player + 1;
                                        cmd_pos <= 0;
                                    end
                                    main_state <= STATE_RX_NEXT;
                                    com_rx_next <= 1'b1;
                                end else if (cmd_pos == 2 && jvs_nodes_r.node_buttons[current_device_addr - 1] > 8) begin
                                    // Second player data byte (additional buttons)
                                    player4_input_switch[6] <= com_rx_byte[7];   // X (push3)
                                    player4_input_switch[7] <= com_rx_byte[6];   // Y (push4)
                                    player4_input_switch[8] <= com_rx_byte[5];   // push5 -> L1
                                    player4_input_switch[9] <= com_rx_byte[4];   // push6 -> R1
                                    player4_input_switch[10] <= com_rx_byte[3];  // push7 -> L2
                                    player4_input_switch[11] <= com_rx_byte[2];  // push8 -> R2
                                    // Clear unused upper bits for consistency
                                    player4_input_switch[13:12] <= 2'b00;
                                    // Advance to next player
                                    current_player <= current_player + 1;
                                    cmd_pos <= 0; // Reset for next player
                                    main_state <= STATE_RX_NEXT;
                                    com_rx_next <= 1'b1;
                                end
                            end
                        endcase
                    end
                end

                RX_PARSE_COININP: begin
                    if (com_rx_remaining > 0) begin
                        // Parse coin data (2 bytes per coin slot)
                        case (cmd_pos)
                            3'd1: begin // Parse byte 1 of current coin slot
                                // Format: [condition(2 bits) counter_MSB(6 bits)]
                                temp_coin_condition <= com_rx_byte[7:6];  // Top 2 bits = condition
                                temp_counter_msb <= com_rx_byte[5:0];     // Bottom 6 bits = counter MSB
                                return_state <= RX_PARSE_COININP;
                                main_state <= STATE_RX_NEXT;
                                com_rx_next <= 1'b1;
                            end
                            3'd2: begin // Parse byte 2 of current coin slot then jump to next slot if needed
                                // Store complete coin data for this slot
                                coin_count[current_coin] <= {temp_counter_msb, com_rx_byte}; // 14-bit counter stored in 16-bit
                                
                                // Set coin increase signals based on condition (10 = increase)
                                case (current_coin)
                                    0: coin1 <= (temp_coin_condition == 2'b10);
                                    1: coin2 <= (temp_coin_condition == 2'b10);
                                    2: coin3 <= (temp_coin_condition == 2'b10);
                                    3: coin4 <= (temp_coin_condition == 2'b10);
                                endcase
                                
                                // Check if we need to parse the next coin slot
                                if (current_coin >= (jvs_nodes_r.node_coin_slots[current_device_addr - 1] - 1)) begin
                                    // Coin parsing complete, advance to next command
                                    cmd_pos <= 0;
                                    com_src_cmd_next <= 1'b1;
                                    return_state <= RX_PARSE_INPUT_CMD;
                                    main_state <= STATE_RX_NEXT;
                                    com_rx_next <= 1'b1;
                                end else begin
                                    // Parse next coin slot
                                    current_coin <= current_coin + 1;
                                    cmd_pos <= 0; // Reset to parse next coin's first byte
                                    return_state <= RX_PARSE_COININP;
                                    main_state <= STATE_RX_NEXT;
                                    com_rx_next <= 1'b1;
                                end
                            end
                        endcase
                    end else begin
                        // No more data, return to command dispatcher
                        cmd_pos <= 0;
                        com_src_cmd_next <= 1'b1;
                        return_state <= RX_PARSE_INPUT_CMD;
                        main_state <= return_state;
                    end
                end

                RX_PARSE_ANLINP: begin
                    return_state <= RX_PARSE_ANLINP;
                    if (com_rx_remaining > 0) begin
                        case (cmd_pos)
                            3'd1: begin // Parse byte 1 of current coin slot
                                temp_high_byte <= com_rx_byte;
                                // Put MSB in temp
                                main_state <= STATE_RX_NEXT;
                                com_rx_next <= 1'b1;
                            end
                            3'd2: begin // Parse byte 2 of current channel then jump to next channel if needed
                                // Assign analog values based on current channel
                                case (current_channel)
                                    4'd0: begin // Channel 1 - Analog channel 1
                                        analog_ch1 <= {temp_high_byte, com_rx_byte};
                                    end
                                    4'd1: begin // Channel 2 - Analog channel 2
                                        analog_ch2 <= {temp_high_byte, com_rx_byte};
                                    end
                                    4'd2: begin // Channel 3 - Analog channel 3
                                        analog_ch3 <= {temp_high_byte, com_rx_byte};
                                        // Also update screen position if single player for compatibility
                                        if (jvs_nodes_r.node_players[current_device_addr - 1] == 1) begin
                                            screen_pos_x <= {temp_high_byte, com_rx_byte};
                                        end
                                    end
                                    4'd3: begin // Channel 4 - Analog channel 4
                                        analog_ch4 <= {temp_high_byte, com_rx_byte};
                                        // Also update screen position if single player for compatibility
                                        if (jvs_nodes_r.node_players[current_device_addr - 1] == 1) begin
                                            screen_pos_y <= {temp_high_byte, com_rx_byte};
                                        end
                                    end
                                    4'd4: begin // Channel 5 - Analog channel 5
                                        analog_ch5 <= {temp_high_byte, com_rx_byte};
                                        screen_pos_x <= {temp_high_byte, com_rx_byte}; // Keep screen compatibility
                                    end
                                    4'd5: begin // Channel 6 - Analog channel 6
                                        analog_ch6 <= {temp_high_byte, com_rx_byte};
                                        screen_pos_y <= {temp_high_byte, com_rx_byte}; // Keep screen compatibility
                                    end
                                    4'd6: begin // Channel 7 - Analog channel 7
                                        analog_ch7 <= {temp_high_byte, com_rx_byte};
                                    end
                                    4'd7: begin // Channel 8 - Analog channel 8
                                        analog_ch8 <= {temp_high_byte, com_rx_byte};
                                    end
                                    default: ; // Additional channels - no assignment
                                endcase

                                // Check if we need to parse the next channel
                                if (current_channel >= (jvs_nodes_r.node_analog_channels[current_device_addr - 1])) begin
                                    // Analog channels parsing complete, advance to next command
                                    current_channel <= 0;
                                    cmd_pos <= 0;
                                    return_state <= RX_PARSE_INPUT_CMD;
                                    main_state <= STATE_RX_NEXT;
                                    com_rx_next <= 1'b1;
                                    com_src_cmd_next <= 1'b1;
                                end else begin
                                    // Parse next channel
                                    current_channel <= current_channel + 1;
                                    cmd_pos <= 0; // Reset to parse next channel's first byte
                                    return_state <= RX_PARSE_ANLINP;
                                    main_state <= STATE_RX_NEXT;
                                    com_rx_next <= 1'b1;
                                end
                            end
                        endcase
                    end else begin
                        // No more data
                        cmd_pos <= 0;
                        current_channel <= 0;
                        com_src_cmd_next <= 1'b1;
                        return_state <= RX_PARSE_INPUT_CMD;
                        main_state <= STATE_RX_NEXT;
                        com_rx_next <= 1'b1;
                    end
                end

                //-------------------------------------------------------------
                // ADDITIONAL INPUT PARSING STATES - Not yet implemented
                //-------------------------------------------------------------
                RX_PARSE_ROTINP: begin
                    return_state <= RX_PARSE_ROTINP;
                    if (com_rx_remaining > 0) begin
                        case (cmd_pos)
                            3'd0: begin
                                // Check REPORT byte
                                if (com_rx_byte == REPORT_NORMAL) begin
                                    com_rx_next <= 1'b1;
                                    main_state <= STATE_RX_NEXT;
                                end else begin
                                    com_src_cmd_next <= 1'b1;
                                    return_state <= RX_PARSE_INPUT_CMD;
                                    main_state <= STATE_RX_NEXT;
                                    com_rx_next <= 1'b1;
                                end
                            end
                            default: begin
                                // Parse rotary data - not yet implemented
                                main_state <= STATE_RX_NEXT;
                                com_rx_next <= 1'b1;
                            end
                        endcase
                    end else begin
                        com_src_cmd_next <= 1'b1;
                        return_state <= RX_PARSE_INPUT_CMD;
                        main_state <= STATE_RX_NEXT;
                        com_rx_next <= 1'b1;
                    end
                end

                RX_PARSE_KEYINP: begin
                    return_state <= RX_PARSE_KEYINP;
                    if (com_rx_remaining > 0) begin
                        case (cmd_pos)
                            3'd0: begin
                                // Check REPORT byte
                                if (com_rx_byte == REPORT_NORMAL) begin
                                    com_rx_next <= 1'b1;
                                    main_state <= STATE_RX_NEXT;
                                end else begin
                                    com_src_cmd_next <= 1'b1;
                                    return_state <= RX_PARSE_INPUT_CMD;
                                    main_state <= STATE_RX_NEXT;
                                    com_rx_next <= 1'b1;
                                end
                            end
                            default: begin
                                // Parse keycode data - not yet implemented
                                main_state <= STATE_RX_NEXT;
                                com_rx_next <= 1'b1;
                            end
                        endcase
                    end else begin
                        com_src_cmd_next <= 1'b1;
                        return_state <= RX_PARSE_INPUT_CMD;
                        main_state <= STATE_RX_NEXT;
                        com_rx_next <= 1'b1;
                    end
                end

                RX_PARSE_SCRPOSINP: begin
                    return_state <= RX_PARSE_SCRPOSINP;
                    if (com_rx_remaining > 0) begin
                        // Parse screen position data (4 bytes: X_HIGH, X_LOW, Y_HIGH, Y_LOW)
                        // REPORT byte already consumed by RX_PARSE_INPUT_CMD, start parsing from cmd_pos=1
                        automatic logic [7:0] data_pos = cmd_pos - 1; // Adjust for REPORT byte
                        case (data_pos)
                            8'd0: begin // X coordinate high byte
                                screen_pos_x[15:8] <= com_rx_byte;
                                main_state <= STATE_RX_NEXT;
                                com_rx_next <= 1'b1;
                            end
                            8'd1: begin // X coordinate low byte
                                screen_pos_x[7:0] <= com_rx_byte;
                                main_state <= STATE_RX_NEXT;
                                com_rx_next <= 1'b1;
                            end
                            8'd2: begin // Y coordinate high byte
                                screen_pos_y[15:8] <= com_rx_byte;
                                main_state <= STATE_RX_NEXT;
                                com_rx_next <= 1'b1;
                            end
                            8'd3: begin // Y coordinate low byte
                                screen_pos_y[7:0] <= com_rx_byte;
                                // Screen position parsing complete, advance to next command
                                cmd_pos <= 0;
                                com_src_cmd_next <= 1'b1;
                                return_state <= RX_PARSE_INPUT_CMD;
                                main_state <= STATE_RX_NEXT;
                                com_rx_next <= 1'b1;
                            end
                            default: begin
                                // Unexpected data, skip
                                main_state <= STATE_RX_NEXT;
                                com_rx_next <= 1'b1;
                            end
                        endcase
                    end else begin
                        // No more data, return to command dispatcher
                        cmd_pos <= 0;
                        com_src_cmd_next <= 1'b1;
                        return_state <= RX_PARSE_INPUT_CMD;
                        main_state <= STATE_RX_NEXT;
                        com_rx_next <= 1'b1;
                    end
                end

                RX_PARSE_MISCSWINP: begin
                    return_state <= RX_PARSE_MISCSWINP;
                    if (com_rx_remaining > 0) begin
                        case (cmd_pos)
                            3'd0: begin
                                // Check REPORT byte
                                if (com_rx_byte == REPORT_NORMAL) begin
                                    com_rx_next <= 1'b1;
                                    main_state <= STATE_RX_NEXT;
                                end else begin
                                    com_src_cmd_next <= 1'b1;
                                    return_state <= RX_PARSE_INPUT_CMD;
                                    main_state <= STATE_RX_NEXT;
                                    com_rx_next <= 1'b1;
                                end
                            end
                            default: begin
                                // Parse misc digital data - not yet implemented
                                main_state <= STATE_RX_NEXT;
                                com_rx_next <= 1'b1;
                            end
                        endcase
                    end else begin
                        com_src_cmd_next <= 1'b1;
                        return_state <= RX_PARSE_INPUT_CMD;
                        main_state <= STATE_RX_NEXT;
                        com_rx_next <= 1'b1;
                    end
                end

                RX_PARSE_OUTPUT1: begin
                    return_state <= RX_PARSE_OUTPUT1;
                    if (com_rx_remaining > 0) begin
                        case (cmd_pos)
                            3'd0: begin
                                // Check REPORT byte
                                if (com_rx_byte == REPORT_NORMAL) begin
                                    com_rx_next <= 1'b1;
                                    main_state <= STATE_RX_NEXT;
                                end else begin
                                    com_src_cmd_next <= 1'b1;
                                    return_state <= RX_PARSE_INPUT_CMD;
                                    main_state <= STATE_RX_NEXT;
                                    com_rx_next <= 1'b1;
                                end
                            end
                            default: begin
                                // Parse output digital response - not yet implemented
                                main_state <= STATE_RX_NEXT;
                                com_rx_next <= 1'b1;
                            end
                        endcase
                    end else begin
                        com_src_cmd_next <= 1'b1;
                        return_state <= RX_PARSE_INPUT_CMD;
                        main_state <= STATE_RX_NEXT;
                        com_rx_next <= 1'b1;
                    end
                end

                //-------------------------------------------------------------
                // WAIT FOR DEVICE RESPONSE - Using edge detection for proper timing
                //-------------------------------------------------------------
                STATE_WAIT_RX: begin
                    if (com_rx_complete_negedge) begin
                        // Check STATUS byte decoded by jvs_com from received frame
                        if (com_src_cmd_status == STATUS_NORMAL) begin
                            timeout_counter <= 32'h0;
                            timeout_retry_count <= 8'h00;  // Reset retry count on success
                            // STATUS OK, dispatch to appropriate parser
                            cmd_pos <= 8'd0;
                            case (com_src_cmd)
                                CMD_SETADDR: main_state <= RX_PARSE_SETADDR;
                                CMD_IOIDENT: main_state <= RX_PARSE_IOIDENT;
                                CMD_CMDREV: main_state <= RX_PARSE_CMDREV;
                                CMD_JVSREV: main_state <= RX_PARSE_JVSREV;
                                CMD_COMMVER: main_state <= RX_PARSE_COMMVER;
                                CMD_FEATCHK: main_state <= RX_PARSE_FEATURES;
                                CMD_ANLINP: begin
                                    // Initialize analog parsing variables
                                    analog_ch1 <= 16'h8000;
                                    analog_ch2 <= 16'h8000;
                                    analog_ch3 <= 16'h8000;
                                    analog_ch4 <= 16'h8000;
                                    analog_ch5 <= 16'h8000;
                                    analog_ch6 <= 16'h8000;
                                    analog_ch7 <= 16'h8000;
                                    analog_ch8 <= 16'h8000;
                                    current_channel <= 4'd0;
                                    cmd_pos <= 1; // Initialize to 1 for generic parsing (STATE_RX_NEXT returns to 1, not 0)
                                    main_state <= RX_PARSE_ANLINP;
                                end
                                default: main_state <= RX_PARSE_INPUT_CMD; // For other commands, use unified parser
                            endcase
                        end else begin
                            // STATUS error, log and retry
                            case (com_src_cmd)
                                CMD_SETADDR: main_state <= STATE_FIRST_RESET;    // Critical - restart sequence
                                CMD_IOIDENT: main_state <= STATE_SEND_IOIDENT;     // Retry ID read
                                CMD_CMDREV: main_state <= STATE_SEND_CMDREV;     // Retry command revision
                                CMD_JVSREV: main_state <= STATE_SEND_JVSREV;     // Retry JVS revision
                                CMD_COMMVER: main_state <= STATE_SEND_COMMVER;   // Retry comm version
                                CMD_FEATCHK: main_state <= STATE_SEND_FEATCHK;   // Retry feature check
                                default: main_state <= STATE_NODES_POOLING;      // Continue with polling
                            endcase
                        end
                    //end else if (timeout_counter < 32'h0C3500) begin  // 10ms timeout - fast for responsive gaming
                    end else if (timeout_counter > 0) begin
                        timeout_counter <= timeout_counter - 1;
                    end else begin
                        // Timeout reached - increment retry count and go to configured timeout state
                        timeout_retry_count <= timeout_retry_count + 1;
                        main_state <= on_timeout_state;
                    end
                end

                //-------------------------------------------------------------
                // GENERIC TIMER DELAY STATE - Reusable delay for any state transition
                //-------------------------------------------------------------
                STATE_MAIN_TIMER_DELAY: begin
                    if (delay_counter > 0) begin
                        delay_counter <= delay_counter - 1;
                    end else begin
                        // Timer expired, return to caller state
                        main_state <= return_state;
                    end
                end

                //-------------------------------------------------------------
                // GENERIC TX NEXT STATE - Handles pulse cleanup and position increment
                //-------------------------------------------------------------
                STATE_TX_NEXT: begin
                    com_tx_cmd_push <= 1'b0;
                    com_tx_data_push <= 1'b0;
                    cmd_pos <= cmd_pos + 1;
                    if(com_commit == 1'b1) begin
                        // Keep com_commit high until JVS_COM accepts it (tx_ready goes low)
                        if(!com_tx_ready) begin
                            // JVS_COM has accepted the commit (tx_ready went low)
                            com_commit <= 1'b0;
                            cmd_pos <= 8'h00;
                            main_state <= STATE_WAIT_RX;
                        end
                        // else: keep com_commit high and stay in TX_NEXT until JVS_COM is ready
                    end else begin
                        main_state <= return_state;
                    end
                end
                STATE_RX_NEXT: begin
                    com_rx_next <= 0;
                    // Wait for BRAM read to complete (com_rx_ready = 1)
                    if (com_rx_ready) begin
                        cmd_pos <= cmd_pos + 1;
                        main_state <= return_state;
                    end
                    // Stay in this state until data is ready
                end

                //-------------------------------------------------------------
                // FATAL ERROR STATE - Stop execution and display error
                //-------------------------------------------------------------
                STATE_FATAL_ERROR: begin
                    // Stay in error state and continuously display error message
                    $display("[CONTROLLER][FATAL_ERROR] JVS Controller has entered fatal error state");
                    $display("[CONTROLLER][FATAL_ERROR] System stopped for debugging");
                    
                    // Display jvs_nodes_r content for debugging
                    $display("[CONTROLLER][FATAL_ERROR] === JVS_NODES_R STATE DUMP ===");
                    for (int dev = 0; dev < 2; dev++) begin
                        $display("[FATAL_ERROR] Device %d:", dev);
                        $display("  node_id: 0x%02X", jvs_nodes_r.node_id[dev]);
                        $display("  node_cmd_ver: 0x%02X", jvs_nodes_r.node_cmd_ver[dev]);
                        $display("  node_jvs_ver: 0x%02X", jvs_nodes_r.node_jvs_ver[dev]);
                        $display("  node_com_ver: 0x%02X", jvs_nodes_r.node_com_ver[dev]);
                        $display("  node_players: %d", jvs_nodes_r.node_players[dev]);
                        $display("  node_buttons: %d", jvs_nodes_r.node_buttons[dev]);
                        $display("  node_analog_channels: %d", jvs_nodes_r.node_analog_channels[dev]);
                        $display("  node_analog_bits: %d", jvs_nodes_r.node_analog_bits[dev]);
                        $display("  node_coin_slots: %d", jvs_nodes_r.node_coin_slots[dev]);
                        $display("  node_rotary_channels: %d", jvs_nodes_r.node_rotary_channels[dev]);
                        $display("  node_digital_outputs: %d", jvs_nodes_r.node_digital_outputs[dev]);
                        $display("  node_analog_output_channels: %d", jvs_nodes_r.node_analog_output_channels[dev]);
                        $display("  node_has_keycode_input: %b", jvs_nodes_r.node_has_keycode_input[dev]);
                        $display("  node_has_screen_pos: %b", jvs_nodes_r.node_has_screen_pos[dev]);
                        if (jvs_nodes_r.node_has_screen_pos[dev]) begin
                            $display("    screen_pos_x_bits: %d", jvs_nodes_r.node_screen_pos_x_bits[dev]);
                            $display("    screen_pos_y_bits: %d", jvs_nodes_r.node_screen_pos_y_bits[dev]);
                        end
                        $display("  node_misc_digital_inputs: 0x%04X", jvs_nodes_r.node_misc_digital_inputs[dev]);
                        $display("  node_has_char_display: %b", jvs_nodes_r.node_has_char_display[dev]);
                        if (jvs_nodes_r.node_has_char_display[dev]) begin
                            $display("    char_display_width: %d", jvs_nodes_r.node_char_display_width[dev]);
                            $display("    char_display_height: %d", jvs_nodes_r.node_char_display_height[dev]);
                            $display("    char_display_type: 0x%02X", jvs_nodes_r.node_char_display_type[dev]);
                        end
                        $display("  node_has_backup: %b", jvs_nodes_r.node_has_backup[dev]);
                        
                        // Display device name checksum (name stored in BRAM)
                        $write("  device_name_checksum: 0x%04x", jvs_nodes_r.node_name_checksum[dev]);
                        $write("  (name stored in BRAM at addr %d)", dev * jvs_node_info_pkg::NODE_NAME_SIZE);
                        $display("");
                    end
                    $display("[CONTROLLER][FATAL_ERROR] === END JVS_NODES_R DUMP ===");
                    
                    $finish; // Stop simulation immediately for debugging
                end

                //-------------------------------------------------------------
                // DEFAULT - Unknown state, go to fatal error
                //-------------------------------------------------------------
                default: begin
                    $display("[CONTROLLER][FATAL_ERROR] Unknown state 0x%02X - entering fatal error state", main_state);
                    main_state <= STATE_FATAL_ERROR;
                end
            endcase
        end
    end

endmodule