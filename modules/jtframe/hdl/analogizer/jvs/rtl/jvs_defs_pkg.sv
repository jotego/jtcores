//=========================================================================
// JVS DEFINITIONS PACKAGE (Based on JVS Specification)
//=========================================================================

package jvs_defs_pkg;

    //=========================================================================
    // Standard JVS protocol bytes
    //=========================================================================
    parameter JVS_SYNC_BYTE = 8'hE0;        // Frame start synchronization byte
    parameter JVS_BROADCAST_ADDR = 8'hFF;   // Broadcast address for all devices
    parameter JVS_HOST_ADDR = 8'h00;        // Host/Master address

    //=========================================================================
    // Global Commands - Work with any device address or broadcast (0xFF)
    //=========================================================================
    parameter CMD_RESET = 8'hF0;            // [F0 D9] Reset all devices on bus
                                             // Args: D9 (fixed argument)
                                             // Response: No response (devices reset)
    parameter CMD_RESET_ARG = 8'hD9;        // Argument byte that must follow CMD_RESET

    parameter CMD_SETADDR = 8'hF1;          // [F1 addr] Assign address to device
                                             // Args: addr (1-31, device address)
                                             // Response: [report] - report=01 if success

    parameter CMD_COMMCHG = 8'hF2;          // [F2 baudrate] Change communication speed
                                             // Args: baudrate (communication speed code)
                                             // Response: [report] - report=01 if success

    //=========================================================================
    // Initialize Commands - Device identification and capability discovery
    //=========================================================================
    parameter CMD_IOIDENT = 8'h10;          // [10] Read device identification string
                                             // Args: none
                                             // Response: [report name_string 00]
                                             //   name_string: ASCII device name (manufacturer;product;version;region,comment)

    parameter CMD_CMDREV = 8'h11;           // [11] Read command format revision
                                             // Args: none
                                             // Response: [report revision]
                                             //   revision: BCD format (e.g. 0x13 for v1.3)

    parameter CMD_JVSREV = 8'h12;           // [12] Read JVS specification revision
                                             // Args: none
                                             // Response: [report revision]
                                             //   revision: BCD format (e.g. 0x30 for v3.0)

    parameter CMD_COMMVER = 8'h13;          // [13] Read communication version
                                             // Args: none
                                             // Response: [report version]
                                             //   version: BCD format (e.g. 0x10 for v1.0)

    parameter CMD_FEATCHK = 8'h14;          // [14] Check device features/capabilities
                                             // Args: none
                                             // Response: [report func_data... 00]
                                             //   func_data: loop of 4-byte blocks [func_code param1 param2 param3] loop end with 00

    parameter CMD_MAINID = 8'h15;           // [15] Send main board ID to I/O device
                                             // Args: [main_pcb_id_string 00] - ASCII string up to 100 chars
                                             //   Format: "Maker;Game;Version;Details" separated by semicolons
                                             //   Example: "NAMCO LTD.;TEKKEN2;ver1.6; TEKKEN2 ver B"
                                             // Response: [report] - report=01 if success

    //=========================================================================
    // Data I/O Commands - Input reading and data retrieval
    //=========================================================================
    parameter CMD_SWINP = 8'h20;            // [20 players bytes] Read switch inputs (digital buttons)
                                             // Args: players (number of players), bytes (total bytes needed for bits per player)
                                             // Response: [report switch_data...]
                                             //   switch_data: players × bytes of digital input data

    parameter CMD_COININP = 8'h21;          // [21 slots] Read coin inputs and counter
                                             // Args: slots (number of coin slots to read)
                                             // Response: [report coin_status...]
                                             //   coin_status: loop of 2 bytes [condition(2 bits) counter_MSB(6 bits) counter_LSB]

    // Coin Input Condition Codes (Table 12)
    parameter COIN_CONDITION_NORMAL = 2'b00;        // Normal operation
    parameter COIN_CONDITION_JAM = 2'b01;           // Coin jam detected
    parameter COIN_CONDITION_DISCONNECTED = 2'b10;  // Coin mechanism disconnected
    parameter COIN_CONDITION_BUSY = 2'b11;          // Coin mechanism busy

    parameter CMD_ANLINP = 8'h22;           // [22 channels] Read analog inputs
                                             // Args: channels (number of analog channels)
                                             // Response: [report analog_data...]
                                             //   analog_data: 2 bytes per channel [data_MSB data_LSB]

    parameter CMD_ROTINP = 8'h23;           // [23 channels] Read rotary inputs
                                             // Args: channels (number of rotary channels to read)
                                             // Response: [report rotary_data...]
                                             //   rotary_data: 2 bytes per channel [data_MSB data_LSB]

    parameter CMD_KEYINP = 8'h24;           // [24] Read keycode inputs
                                             // Args: none
                                             // Response: [report keycode]
                                             //   keycode: ASCII key code or 00 if no key

    parameter CMD_SCRPOSINP = 8'h25;        // [25 channels] Read screen position inputs (light gun/touch)
                                             // Args: channel index to read
                                             // Response: [report pos_data...]
                                             //   pos_data: 4 bytes [x_MSB x_LSB y_MSB y_LSB]

    parameter CMD_MISCSWINP = 8'h26;        // [26 bytes] Read miscellaneous switch inputs
                                             // Args: bytes (number of misc input bytes, depends on bits defined in feature check)
                                             // Response: [report misc_data...]
                                             //   misc_data: specified number of misc input bytes

    parameter CMD_PAYCNT = 8'h2E;           // [2E channel_index] Payout coins/tokens aka. redemption
                                             // Args: channel_index
                                             // Response: [report hopper_status remaining_hi remaining_mid remaining_low]

    parameter CMD_RETRANSMIT = 8'h2F;       // [2F] Retransmit previous response
                                             // Args: none
                                             // Response: Previous response is retransmitted

    parameter CMD_COINDEC = 8'h30;          // [30 slots_index amount_msb amount_lsb] Decrease selected coin counter of specified value
                                             // Args: slot_index, amount_msb, amount_lsb
                                             // Response: [report] - report=01 if success

    parameter CMD_PAYINC = 8'h31;           // [31 slots payval...] Increase payout counters
                                             // Args: slots (number of payout slots), payval per slot (increase amount)
                                             // Response: [report] - report=01 if success

    parameter CMD_OUTPUT1 = 8'h32;          // [32 bytes data...] General purpose output 1
                                             // Args: bytes (number of output bytes), data per byte
                                             // Response: [report] - report=01 if success

    parameter CMD_ANLOUT = 8'h33;           // [33 channels data...] Analog output control
                                             // Args: channels (number of analog outputs), 2 bytes data per channel [MSB LSB]
                                             // Response: [report] - report=01 if success

    parameter CMD_CHAROUT = 8'h34;          // [34 line pos string...] Character display output
                                             // Args: line (display line), pos (position), string data
                                             // Response: [report] - report=01 if success

    parameter CMD_COININC = 8'h35;          // [35 slots incval...] Increase coin counters
                                             // Args: slots (number of coin slots), incval per slot (increase amount)
                                             // Response: [report] - report=01 if success

    parameter CMD_PAYDEC = 8'h36;           // [36 slots decval...] Decrease payout counters
                                             // Args: slots (number of payout slots), decval per slot (decrease amount)
                                             // Response: [report] - report=01 if success

    parameter CMD_OUTPUT2 = 8'h37;          // [37 bytes data...] General purpose output 2
                                             // Args: bytes (number of output bytes), data per byte
                                             // Response: [report] - report=01 if success

    parameter CMD_OUTPUT3 = 8'h38;          // [38 bytes data...] General purpose output 3
                                             // Args: bytes (number of output bytes), data per byte
                                             // Response: [report] - report=01 if success


    //=========================================================================
    // Status Codes - General response status (position 3 in frame)
    //=========================================================================
    parameter STATUS_NORMAL = 8'h01;        // Normal operation status
    parameter STATUS_UNKNOWN_CMD = 8'h02;   // Unknown command received
    parameter STATUS_SUM_ERROR = 8'h03;     // Checksum error in received data
    parameter STATUS_ACK_OVERFLOW = 8'h04;  // Acknowledgment overflow
    parameter STATUS_BUSY = 8'h05;          // Device busy, cannot process command

    //=========================================================================
    // Report Codes - Command-specific status (position 4+ in frame)
    //=========================================================================
    parameter REPORT_NORMAL = 8'h01;        // Normal operation
    parameter REPORT_PARAM_ERROR_COUNT = 8'h02; // Parameter error (incorrect number)
    parameter REPORT_PARAM_ERROR_DATA = 8'h03;  // Parameter error (invalid data)
    parameter REPORT_BUSY = 8'h04;          // Busy (cannot receive more commands)

    //=========================================================================
    // JVS Escape sequence constants for data byte escaping
    //=========================================================================
    parameter JVS_ESCAPE_BYTE = 8'hD0;      // Escape marker byte
    parameter JVS_ESCAPED_E0 = 8'hDF;       // E0 becomes D0 DF
    parameter JVS_ESCAPED_D0 = 8'hCF;       // D0 becomes D0 CF

    //=========================================================================
    // Function Codes - Used in feature check responses
    //=========================================================================
    parameter FUNC_INPUT_DIGITAL = 8'h01;    // [01 players bytesperplayer unused] Digital inputs
    parameter FUNC_INPUT_COIN = 8'h02;       // [02 slots unused unused] Coin inputs
    parameter FUNC_INPUT_ANALOG = 8'h03;     // [03 channels bits unused] Analog inputs (channels×bits resolution)
    parameter FUNC_INPUT_ROTARY = 8'h04;     // [04 channels unused unused] Rotary encoder inputs
    parameter FUNC_INPUT_KEYCODE = 8'h05;    // [05 unused unused unused] Keycode inputs
    parameter FUNC_INPUT_SCREEN_POS = 8'h06; // [06 channels bits unused] Screen position inputs (channels×bits)
    parameter FUNC_INPUT_MISC_DIGITAL = 8'h07; // [07 bytes unused unused] Miscellaneous digital inputs
    parameter FUNC_OUTPUT_CARD = 8'h10;      // [10 slots unused unused] Card system outputs
    parameter FUNC_OUTPUT_HOPPER = 8'h11;    // [11 slots unused unused] Medal/token hopper outputs
    parameter FUNC_OUTPUT_DIGITAL = 8'h12;   // [12 bytes unused unused] Digital outputs (lights/solenoids)
    parameter FUNC_OUTPUT_ANALOG = 8'h13;    // [13 channels unused unused] Analog outputs
    parameter FUNC_OUTPUT_CHAR = 8'h14;      // [14 lines columns type] Character display outputs
    parameter FUNC_OUTPUT_BACKUP = 8'h15;    // [15 unused unused unused] Backup data support

    parameter JVS_FUNC_LENGTH = 8'd4;          // Each function block is 4 bytes long

    //=========================================================================
    // Character Output Type codes (Table 9)
    //=========================================================================
    parameter JVS_CHAR_TYPE_UNKNOWN = 8'h00;           // Unknown
    parameter JVS_CHAR_TYPE_ASCII_NUMERIC = 8'h01;     // ASCII (numeric)
    parameter JVS_CHAR_TYPE_ASCII_ALPHANUM = 8'h02;    // ASCII (alphanumeric)
    parameter JVS_CHAR_TYPE_ASCII_KATAKANA = 8'h03;    // ASCII (alphanumeric, half-width katakana)
    parameter JVS_CHAR_TYPE_ASCII_KANJI = 8'h04;       // ASCII (kanji support, SHIFT-JIS)

endpackage