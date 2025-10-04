
// jvs_node_info_pkg.sv — Package defining the structure for JVS node information
package jvs_node_info_pkg;
  parameter int MAX_JVS_NODES   = 2;
  parameter int NODE_NAME_SIZE  = 100;
  parameter int JVS_COIN_MAX    = 4;

  // Parameters for BRAM-based name storage optimization
  parameter int NAME_BRAM_SIZE      = MAX_JVS_NODES * NODE_NAME_SIZE;  // Taille calculée: nodes × taille_nom
  parameter int NAME_BRAM_ADDR_BITS = $clog2(NAME_BRAM_SIZE);          // Bits d'adresse calculés automatiquement

	typedef struct {
		logic [7:0] node_count;
		logic [3:0] player_count;
		logic [7:0] node_id [0:MAX_JVS_NODES-1];           // Node ID (address)
		// Device name optimization: replaced full name storage with checksum + BRAM mapping
		// Names stored in BRAM at fixed positions: node_index * NODE_NAME_SIZE
		logic [15:0] node_name_checksum [0:MAX_JVS_NODES-1]; // Checksum du nom (16 bits)
		logic [7:0] node_cmd_ver [0:MAX_JVS_NODES-1];      // Command version for each node
		logic [7:0] node_jvs_ver [0:MAX_JVS_NODES-1];      // JVS version for each node  
		logic [7:0] node_com_ver [0:MAX_JVS_NODES-1];      // Communication version for each node
		// Feature/capability information extracted from feature check response
		logic [3:0] node_players [0:MAX_JVS_NODES-1];      // Number of players (digital inputs)
		logic [7:0] node_buttons [0:MAX_JVS_NODES-1];      // Number of buttons per player
		logic [3:0] node_analog_channels [0:MAX_JVS_NODES-1]; // Number of analog channels
		logic [7:0] node_analog_bits [0:MAX_JVS_NODES-1];    // Analog resolution in bits (0 mean unknown, all signifiant bits are moved on top to emulate a 16bits value)
		logic [3:0] node_rotary_channels [0:MAX_JVS_NODES-1]; // Number of rotary encoders
		logic [3:0] node_coin_slots [0:MAX_JVS_NODES-1];     // Number of coin slots
		// Additional input capabilities
		logic       node_has_keycode_input [0:MAX_JVS_NODES-1];  // Keycode input support (used on cabinet with keypad like Initial D8 - not tested)
		logic       node_has_screen_pos [0:MAX_JVS_NODES-1];     // Screen position input for touch screen support (IR gun on timecrisis 4 uses analogs channels)
		logic [7:0] node_screen_pos_x_bits [0:MAX_JVS_NODES-1];  // Screen X position resolution (bits)
		logic [7:0] node_screen_pos_y_bits [0:MAX_JVS_NODES-1];  // Screen Y position resolution (bits)
		logic [7:0] node_screen_pos_channels [0:MAX_JVS_NODES-1];  // Numbers of resolution bits ? or number of display ?
		logic [15:0] node_misc_digital_inputs [0:MAX_JVS_NODES-1]; // Miscellaneous digital input bit count (16-bit upto 65536)		
		// Output capabilities
		logic [7:0] node_digital_outputs [0:MAX_JVS_NODES-1]; // Number of digital outputs (maybe used to lightup starts buttons)
		logic [3:0] node_analog_output_channels [0:MAX_JVS_NODES-1]; // Number of analog output channels (maybe used to control light intensity or RGB leds colors)
		logic [7:0] node_card_system_slots [0:MAX_JVS_NODES-1]; // Number of card system slots (unknown usage yet, Initial D8 has a card dispenser)
		logic [7:0] node_medal_hopper_channels [0:MAX_JVS_NODES-1]; // Number of medal hopper channels (maybe used for redemption tickets dispenser)
		logic       node_has_char_display [0:MAX_JVS_NODES-1];   // Character display support (external character LCD display or Printer)
		logic [7:0] node_char_display_width [0:MAX_JVS_NODES-1];  // Character display width
		logic [7:0] node_char_display_height [0:MAX_JVS_NODES-1]; // Character display height
		logic [7:0] node_char_display_type [0:MAX_JVS_NODES-1];   // Character display type
		logic       node_has_backup [0:MAX_JVS_NODES-1];         // Backup data support (unknown usage)
	} jvs_node_info_t;

	typedef struct {
		logic [1:0]  condition;    // Coin condition (00=normal, 01=decrease, 10=increase, 11=no_data) 
		logic [13:0] counter;      // 14-bit coin counter (6 MSB + 8 LSB from protocol)
	} jvs_coin_slot_t;

	typedef struct {
		jvs_coin_slot_t slots[JVS_COIN_MAX];  // Up to 4 coin slots per node
		logic [3:0] active_slots;             // Number of active coin slots
	} jvs_coin_data_t;

endpackage : jvs_node_info_pkg