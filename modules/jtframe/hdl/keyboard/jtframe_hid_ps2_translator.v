/*  This file is part of JTFRAME.
    JTFRAME program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTFRAME program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTFRAME.  If not, see <http://www.gnu.org/licenses/>.

    Author: Rafael Eduardo Paiva Feener. Copyright: Miki Saito
    Version: 1.0
    Date: 28-01-2025 */

module jtframe_hid_ps2_translator(
    input            rst,
    input            clk,

    input      [7:0] keycheck,
    input            released,
    input            next_code,
    input            load_key,
    output           tr_ready,
    output reg       tr_send,
    output reg [7:0] ps2_code
);

localparam [7:0]
	KEY_HID_NONE=8'h00,                  // KEY_PS2_NONE=8'h00,
	KEY_HID_ERR_OVF=8'h01,               // KEY_PS2_ERR_OVF=8'h01,
// 0x02 //  POST Fail
// 0x03 //  Error Undefined
	KEY_HID_A=8'h04,                     KEY_PS2_A=8'h1c,
	KEY_HID_B=8'h05,                     KEY_PS2_B=8'h32,
	KEY_HID_C=8'h06,                     KEY_PS2_C=8'h21,
	KEY_HID_D=8'h07,                     KEY_PS2_D=8'h23,
	KEY_HID_E=8'h08,                     KEY_PS2_E=8'h24,
	KEY_HID_F=8'h09,                     KEY_PS2_F=8'h2b,
	KEY_HID_G=8'h0a,                     KEY_PS2_G=8'h34,
	KEY_HID_H=8'h0b,                     KEY_PS2_H=8'h33,
	KEY_HID_I=8'h0c,                     KEY_PS2_I=8'h43,
	KEY_HID_J=8'h0d,                     KEY_PS2_J=8'h3b,
	KEY_HID_K=8'h0e,                     KEY_PS2_K=8'h42,
	KEY_HID_L=8'h0f,                     KEY_PS2_L=8'h4b,
	KEY_HID_M=8'h10,                     KEY_PS2_M=8'h3a,
	KEY_HID_N=8'h11,                     KEY_PS2_N=8'h31,
	KEY_HID_O=8'h12,                     KEY_PS2_O=8'h44,
	KEY_HID_P=8'h13,                     KEY_PS2_P=8'h4d,
	KEY_HID_Q=8'h14,                     KEY_PS2_Q=8'h15,
	KEY_HID_R=8'h15,                     KEY_PS2_R=8'h2d,
	KEY_HID_S=8'h16,                     KEY_PS2_S=8'h1b,
	KEY_HID_T=8'h17,                     KEY_PS2_T=8'h2c,
	KEY_HID_U=8'h18,                     KEY_PS2_U=8'h3c,
	KEY_HID_V=8'h19,                     KEY_PS2_V=8'h2a,
	KEY_HID_W=8'h1a,                     KEY_PS2_W=8'h1d,
	KEY_HID_X=8'h1b,                     KEY_PS2_X=8'h22,
	KEY_HID_Y=8'h1c,                     KEY_PS2_Y=8'h35,
	KEY_HID_Z=8'h1d,                     KEY_PS2_Z=8'h1a,

	KEY_HID_1=8'h1e,                     KEY_PS2_1=8'h16,
	KEY_HID_2=8'h1f,                     KEY_PS2_2=8'h1e,
	KEY_HID_3=8'h20,                     KEY_PS2_3=8'h26,
	KEY_HID_4=8'h21,                     KEY_PS2_4=8'h25,
	KEY_HID_5=8'h22,                     KEY_PS2_5=8'h2e,
	KEY_HID_6=8'h23,                     KEY_PS2_6=8'h36,
	KEY_HID_7=8'h24,                     KEY_PS2_7=8'h3d,
	KEY_HID_8=8'h25,                     KEY_PS2_8=8'h3e,
	KEY_HID_9=8'h26,                     KEY_PS2_9=8'h46,
	KEY_HID_0=8'h27,                     KEY_PS2_0=8'h45,

	KEY_HID_ENTER=8'h28,                 KEY_PS2_ENTER=8'h5a,
	KEY_HID_ESC=8'h29,                   KEY_PS2_ESC=8'h76,
	KEY_HID_BACKSPACE=8'h2a,             KEY_PS2_BACKSPACE=8'h66,
	KEY_HID_TAB=8'h2b,                   KEY_PS2_TAB=8'h0d,
	KEY_HID_SPACE=8'h2c,                 KEY_PS2_SPACE=8'h29,
	KEY_HID_MINUS=8'h2d,                 KEY_PS2_MINUS=8'h4e,
	KEY_HID_EQUAL=8'h2e,                 KEY_PS2_EQUAL=8'h55,
	KEY_HID_LEFTBRACE=8'h2f,             KEY_PS2_LEFTBRACE=8'h54,
	KEY_HID_RIGHTBRACE=8'h30,            KEY_PS2_RIGHTBRACE=8'h5b,
	KEY_HID_BACKSLASH=8'h31,             KEY_PS2_BACKSLASH=8'h5d,
	KEY_HID_HASHTILDE=8'h32,             KEY_PS2_HASHTILDE=8'h5d,
	KEY_HID_SEMICOLON=8'h33,             KEY_PS2_SEMICOLON=8'h4c,
	KEY_HID_APOSTROPHE=8'h34,            KEY_PS2_APOSTROPHE=8'h52,
	KEY_HID_GRAVE=8'h35,                 KEY_PS2_GRAVE=8'h0e,
	KEY_HID_COMMA=8'h36,                 KEY_PS2_COMMA=8'h41,
	KEY_HID_DOT=8'h37,                   KEY_PS2_DOT=8'h49,
	KEY_HID_SLASH=8'h38,                 KEY_PS2_SLASH=8'h4a,
	KEY_HID_CAPSLOCK=8'h39,              KEY_PS2_CAPSLOCK=8'h58,

	KEY_HID_F1=8'h3a,                    KEY_PS2_F1=8'h05,
	KEY_HID_F2=8'h3b,                    KEY_PS2_F2=8'h06,
	KEY_HID_F3=8'h3c,                    KEY_PS2_F3=8'h04,
	KEY_HID_F4=8'h3d,                    KEY_PS2_F4=8'h0c,
	KEY_HID_F5=8'h3e,                    KEY_PS2_F5=8'h03,
	KEY_HID_F6=8'h3f,                    KEY_PS2_F6=8'h0b,
	KEY_HID_F7=8'h40,                    KEY_PS2_F7=8'h83,
	KEY_HID_F8=8'h41,                    KEY_PS2_F8=8'h0a,
	KEY_HID_F9=8'h42,                    KEY_PS2_F9=8'h01,
	KEY_HID_F10=8'h43,                   KEY_PS2_F10=8'h09,
	KEY_HID_F11=8'h44,                   KEY_PS2_F11=8'h78,
	KEY_HID_F12=8'h45,                   KEY_PS2_F12=8'h07,

	KEY_HID_SYSRQ=8'h46,                 KEY_PS2_SYSRQ=8'h7c,      // E0
	KEY_HID_SCROLLLOCK=8'h47,            KEY_PS2_SCROLLLOCK=8'h7e,
	KEY_HID_PAUSE=8'h48,                 // KEY_PS2_PAUSE=8'h7e,   // E0
	KEY_HID_INSERT=8'h49,                KEY_PS2_INSERT=8'h70,     // E0
	KEY_HID_HOME=8'h4a,                  KEY_PS2_HOME=8'h6c,       // E0
	KEY_HID_PAGEUP=8'h4b,                KEY_PS2_PAGEUP=8'h7d,     // E0
	KEY_HID_DELETE=8'h4c,                KEY_PS2_DELETE=8'h71,     // E0
	KEY_HID_END=8'h4d,                   KEY_PS2_END=8'h69,        // E0
	KEY_HID_PAGEDOWN=8'h4e,              KEY_PS2_PAGEDOWN=8'h7a,   // E0
	KEY_HID_RIGHT=8'h4f,                 KEY_PS2_RIGHT=8'h74,      // E0
	KEY_HID_LEFT=8'h50,                  KEY_PS2_LEFT=8'h6b,       // E0
	KEY_HID_DOWN=8'h51,                  KEY_PS2_DOWN=8'h72,       // E0
	KEY_HID_UP=8'h52,                    KEY_PS2_UP=8'h75,         // E0

	KEY_HID_NUMLOCK=8'h53,               KEY_PS2_NUMLOCK=8'h77,
	KEY_HID_KPSLASH=8'h54,               KEY_PS2_KPSLASH=8'h4a,    // E0
	KEY_HID_KPASTERISK=8'h55,            KEY_PS2_KPASTERISK=8'h7c,
	KEY_HID_KPMINUS=8'h56,               KEY_PS2_KPMINUS=8'h7b,
	KEY_HID_KPPLUS=8'h57,                KEY_PS2_KPPLUS=8'h79,
	KEY_HID_KPENTER=8'h58,               KEY_PS2_KPENTER=8'h5a,    // E0
	KEY_HID_KP1=8'h59,                   KEY_PS2_KP1=8'h69,
	KEY_HID_KP2=8'h5a,                   KEY_PS2_KP2=8'h72,
	KEY_HID_KP3=8'h5b,                   KEY_PS2_KP3=8'h7a,
	KEY_HID_KP4=8'h5c,                   KEY_PS2_KP4=8'h6b,
	KEY_HID_KP5=8'h5d,                   KEY_PS2_KP5=8'h73,
	KEY_HID_KP6=8'h5e,                   KEY_PS2_KP6=8'h74,
	KEY_HID_KP7=8'h5f,                   KEY_PS2_KP7=8'h6c,
	KEY_HID_KP8=8'h60,                   KEY_PS2_KP8=8'h75,
	KEY_HID_KP9=8'h61,                   KEY_PS2_KP9=8'h7d,
	KEY_HID_KP0=8'h62,                   KEY_PS2_KP0=8'h70,
	KEY_HID_KPDOT=8'h63,                 KEY_PS2_KPDOT=8'h71,

	KEY_HID_102ND=8'h64,                 KEY_PS2_102ND=8'h61,
	KEY_HID_COMPOSE=8'h65,               KEY_PS2_COMPOSE=8'h2f,   // E0
	KEY_HID_POWER=8'h66,                 KEY_PS2_POWER=8'h37,     // E0
	KEY_HID_KPEQUAL=8'h67,               KEY_PS2_KPEQUAL=8'h0f,

	KEY_HID_F13=8'h68,                   KEY_PS2_F13=8'h08,
	KEY_HID_F14=8'h69,                   KEY_PS2_F14=8'h10,
	KEY_HID_F15=8'h6a,                   KEY_PS2_F15=8'h18,
	KEY_HID_F16=8'h6b,                   KEY_PS2_F16=8'h20,
	KEY_HID_F17=8'h6c,                   KEY_PS2_F17=8'h28,
	KEY_HID_F18=8'h6d,                   KEY_PS2_F18=8'h30,
	KEY_HID_F19=8'h6e,                   KEY_PS2_F19=8'h38,
	KEY_HID_F20=8'h6f,                   KEY_PS2_F20=8'h40,
	KEY_HID_F21=8'h70,                   KEY_PS2_F21=8'h48,
	KEY_HID_F22=8'h71,                   KEY_PS2_F22=8'h50,
	KEY_HID_F23=8'h72,                   KEY_PS2_F23=8'h57,
	KEY_HID_F24=8'h73,                   KEY_PS2_F24=8'h5f,

	KEY_HID_OPEN=8'h74,                  // KEY_PS2_OPEN=,       // unassigned
	KEY_HID_HELP=8'h75,                  // KEY_PS2_HELP=,       // unassigned
	KEY_HID_PROPS=8'h76,                 // KEY_PS2_PROPS=,      // unassigned
	KEY_HID_FRONT=8'h77,                 // KEY_PS2_FRONT=,      // unassigned
	KEY_HID_STOP=8'h78,                  // KEY_PS2_STOP=,       // unassigned
	KEY_HID_AGAIN=8'h79,                 // KEY_PS2_AGAIN=,      // unassigned
	KEY_HID_UNDO=8'h7a,                  // KEY_PS2_UNDO=,       // unassigned
	KEY_HID_CUT=8'h7b,                   // KEY_PS2_CUT=,        // unassigned
	KEY_HID_COPY=8'h7c,                  // KEY_PS2_COPY=,       // unassigned
	KEY_HID_PASTE=8'h7d,                 // KEY_PS2_PASTE=,      // unassigned
	KEY_HID_FIND=8'h7e,                  // KEY_PS2_FIND=,       // unassigned
	KEY_HID_MUTE=8'h7f,                  // KEY_PS2_MUTE=,       // unassigned
	KEY_HID_VOLUMEUP=8'h80,              // KEY_PS2_VOLUMEUP=,   // unassigned
	KEY_HID_VOLUMEDOWN=8'h81,            // KEY_PS2_VOLUMEDOWN=, // unassigned
// 0x82  Key Locking Tops Lock
// 0x83  Locking Total Lock
// 0x84  Locking Scroll Lock
	KEY_HID_KPCOMMA=8'h85,               KEY_PS2_KPCOMMA=8'h6d,
// 0x86  Keypad Equal Sign
	KEY_HID_RO=8'h87,                    KEY_PS2_RO=8'h51,
	KEY_HID_KATAKANAHIRAGANA=8'h88,      KEY_PS2_KATAKANAHIRAGANA=8'h13,
	KEY_HID_YEN=8'h89,                   KEY_PS2_YEN=8'h6a,
	KEY_HID_HENKAN=8'h8a,                KEY_PS2_HENKAN=8'h64,
	KEY_HID_MUHENKAN=8'h8b,              KEY_PS2_MUHENKAN=8'h67,
	KEY_HID_KPJPCOMMA=8'h8c,             KEY_PS2_KPJPCOMMA=8'h27,
// 0x8d  Key International7
// 0x8e  International8
// 0x8f  International9
	KEY_HID_HANGEUL=8'h90,               KEY_PS2_HANGEUL=8'hf2,
	KEY_HID_HANJA=8'h91,                 KEY_PS2_HANJA=8'hf1,
	KEY_HID_KATAKANA=8'h92,              KEY_PS2_KATAKANA=8'h63,
	KEY_HID_HIRAGANA=8'h93,              KEY_PS2_HIRAGANA=8'h62,
	KEY_HID_ZENKAKUHANKAKU=8'h94,        KEY_PS2_ZENKAKUHANKAKU=8'h5f,
// 0x95  LANG6
// 0x96  LANG7
// 0x97  LANG8
// 0x98  LANG9
// 0x99  Change Clearing
// 0x9a  Type SysReq/Attention
// 0x9b  Cancel
// 0x9c  Clear
// 0x9d  Prior
    KEY_HID_RETURN=8'h9e,            //  KEY_PS2_RETURN=8'h  , // unassigned
// 0x9f  Separator
// 0xa0  Ivories Out
// 0xa1  Press Oper
// 0xa2  Clear/Again
// 0xa3  G CrSel/Props
// 0xa4  ExSel

// 0xb0  Keypad 00
// 0xb1  Keypad 000
// 0xb2  Thousands Separator
// 0xb3  Denary Separator
// 0xb4  Currency Unit
// 0xb5  Currency Sub-unit
	KEY_HID_KPLEFTPAREN=8'hb6,       //  KEY_PS2_KPLEFTPAREN=,  // reseved
	KEY_HID_KPRIGHTPAREN=8'hb7,      //  KEY_PS2_KPRIGHTPAREN=, // reseved
// 0xb8  Keypad {
// 0xb9  Keypad }
// 0xba  Keypad Tab
// 0xbb  Keypad Press
// 0xbc  Keypad A
// 0xbd  Keypad B
// 0xbe  Keypad HUNDRED
// 0xbf  Keypads D
// 0xc0  Keypad E
// 0xc1  Keypad FLUORINE
// 0xc2  Layout XOR
// 0xc3  Keypad ^
// 0xc4  Control %
// 0xc5  Keypad <
// 0xc6  Keypad >
// 0xc7  Front &
// 0xc8  Keypad &&
// 0xc9  Keypad |
// 0xca  Keypad ||
// 0xcb  Keypad :
// 0xcc  Keypad #
// 0xcd  Fingerboard Space
// 0xce  Keypad @
// 0xcf  Keypad !
// 0xd0  Keypad Memory Store
// 0xd1  Keypad Memory Recall
// 0xd2  Keypad Memory Clear
// 0xd3  Keypads Memory Add
// 0xd4  Keypad Memory Substract
// 0xd5  Keypad Working Multiply
// 0xd6  Layout Memory Divide
// 0xd7  Keypad +/-
// 0xd8  Keypad Empty
// 0xd9  Keypad Clear Entry
// 0xda  Keypad Binary
// 0xdb  Push Octal
// 0xdc  Keypad Decimal
// 0xdd  Keypad Hexadecimal

	KEY_HID_LEFTCTRL=8'he0,              KEY_PS2_LEFTCTRL=8'h14,
	KEY_HID_LEFTSHIFT=8'he1,             KEY_PS2_LEFTSHIFT=8'h12,
	KEY_HID_LEFTALT=8'he2,               KEY_PS2_LEFTALT=8'h11,
	KEY_HID_LEFTMETA=8'he3,              KEY_PS2_LEFTMETA=8'h1f,    // E0
	KEY_HID_RIGHTCTRL=8'he4,             KEY_PS2_RIGHTCTRL=8'h14,   // E0
	KEY_HID_RIGHTSHIFT=8'he5,            KEY_PS2_RIGHTSHIFT=8'h59,
	KEY_HID_RIGHTALT=8'he6,              KEY_PS2_RIGHTALT=8'h11,    // E0
	KEY_HID_RIGHTMETA=8'he7,             KEY_PS2_RIGHTMETA=8'h27;   // E0

// KEY_HID_MEDIA_PLAYPAUSE=8'he8,    // KEY_PS2_MEDIA_PLAYPAUSE=,
// KEY_HID_MEDIA_STOPCD=8'he9,       // KEY_PS2_MEDIA_STOPCD=,
// KEY_HID_MEDIA_PREVIOUSSONG=8'hea, // KEY_PS2_MEDIA_PREVIOUSSONG=,
// KEY_HID_MEDIA_NEXTSONG=8'heb,     // KEY_PS2_MEDIA_NEXTSONG=,
// KEY_HID_MEDIA_EJECTCD=8'hec,      // KEY_PS2_MEDIA_EJECTCD=,
// KEY_HID_MEDIA_VOLUMEUP=8'hed,     // KEY_PS2_MEDIA_VOLUMEUP=,
// KEY_HID_MEDIA_VOLUMEDOWN=8'hee,   // KEY_PS2_MEDIA_VOLUMEDOWN=,
// KEY_HID_MEDIA_MUTE=8'hef,         // KEY_PS2_MEDIA_MUTE=,
// KEY_HID_MEDIA_WWW=8'hf0,          // KEY_PS2_MEDIA_WWW=,
// KEY_HID_MEDIA_BACK=8'hf1,         // KEY_PS2_MEDIA_BACK=,
// KEY_HID_MEDIA_FORWARD=8'hf2,      // KEY_PS2_MEDIA_FORWARD=,
// KEY_HID_MEDIA_STOP=8'hf3,         // KEY_PS2_MEDIA_STOP=,
// KEY_HID_MEDIA_FIND=8'hf4,         // KEY_PS2_MEDIA_FIND=,
// KEY_HID_MEDIA_SCROLLUP=8'hf5,     // KEY_PS2_MEDIA_SCROLLUP=,
// KEY_HID_MEDIA_SCROLLDOWN=8'hf6,   // KEY_PS2_MEDIA_SCROLLDOWN=,
// KEY_HID_MEDIA_EDIT=8'hf7,         // KEY_PS2_MEDIA_EDIT=,
// KEY_HID_MEDIA_SLEEP=8'hf8,        // KEY_PS2_MEDIA_SLEEP=,
// KEY_HID_MEDIA_COFFEE=8'hf9,       // KEY_PS2_MEDIA_COFFEE=,
// KEY_HID_MEDIA_REFRESH=8'hfa,      // KEY_PS2_MEDIA_REFRESH=,
// KEY_HID_MEDIA_CALC=8'hfb;         // KEY_PS2_MEDIA_CALC=;

reg [8:0] ps2_pre, ps2_pre_l;
reg [7:0] key;
wire[7:0] code_nx;
reg       rel, ph2_l, nx_l, high, new_key;
wire      t1, t2;
wire      ph2, ph3, last;

assign ph2      = ps2_pre == ps2_pre_l && !new_key;
assign ph3      = ph2 & ph2_l;
assign t1       = ps2_pre[8] &&  !ph2;
assign t2       = released   && (!ph2 || (!ph3 && high));
assign last     = code_nx == ps2_code || ps2_pre==0;
assign code_nx  = t1 ? 8'he0 : (t2 ? 8'hf0 : ps2_pre[7:0]);
assign tr_ready = last && !tr_send && !new_key || ps2_pre==0;

always @(posedge clk) begin
 	if(rst) begin
        ps2_code  <= 0;
        high      <= 0;
        ps2_pre_l <= 0;
        ph2_l     <= 0;
        tr_send   <= 0;
        nx_l      <= 0;
        new_key   <= 0;
        key       <= 0;
 	end else begin
 		nx_l <= next_code;
 		if( load_key && tr_ready ) begin
 			key     <= keycheck;
        	new_key <= 1;
 		end
        if( ps2_pre==0 ) begin
        	ps2_code <= 0;
        	tr_send  <= 0;
        	high     <= 0;
        	tr_send  <= 0;
        end else
 		if( next_code ) begin
 			if(!nx_l || new_key ) begin
            	ps2_code <= code_nx;
            	high     <= ps2_pre[8];
            	tr_send  <= 1;
            	new_key  <= 0;
 				{ps2_pre_l,ph2_l} <= {ps2_pre,ph2};
 			end
 		end else tr_send <= 0;
 	end
 end

always @(posedge clk) begin
		case(key)
			KEY_HID_A:                ps2_pre <= {1'b0,KEY_PS2_A};
			KEY_HID_B:                ps2_pre <= {1'b0,KEY_PS2_B};
			KEY_HID_C:                ps2_pre <= {1'b0,KEY_PS2_C};
			KEY_HID_D:                ps2_pre <= {1'b0,KEY_PS2_D};
			KEY_HID_E:                ps2_pre <= {1'b0,KEY_PS2_E};
			KEY_HID_F:                ps2_pre <= {1'b0,KEY_PS2_F};
			KEY_HID_G:                ps2_pre <= {1'b0,KEY_PS2_G};
			KEY_HID_H:                ps2_pre <= {1'b0,KEY_PS2_H};
			KEY_HID_I:                ps2_pre <= {1'b0,KEY_PS2_I};
			KEY_HID_J:                ps2_pre <= {1'b0,KEY_PS2_J};
			KEY_HID_K:                ps2_pre <= {1'b0,KEY_PS2_K};
			KEY_HID_L:                ps2_pre <= {1'b0,KEY_PS2_L};
			KEY_HID_M:                ps2_pre <= {1'b0,KEY_PS2_M};
			KEY_HID_N:                ps2_pre <= {1'b0,KEY_PS2_N};
			KEY_HID_O:                ps2_pre <= {1'b0,KEY_PS2_O};
			KEY_HID_P:                ps2_pre <= {1'b0,KEY_PS2_P};
			KEY_HID_Q:                ps2_pre <= {1'b0,KEY_PS2_Q};
			KEY_HID_R:                ps2_pre <= {1'b0,KEY_PS2_R};
			KEY_HID_S:                ps2_pre <= {1'b0,KEY_PS2_S};
			KEY_HID_T:                ps2_pre <= {1'b0,KEY_PS2_T};
			KEY_HID_U:                ps2_pre <= {1'b0,KEY_PS2_U};
			KEY_HID_V:                ps2_pre <= {1'b0,KEY_PS2_V};
			KEY_HID_W:                ps2_pre <= {1'b0,KEY_PS2_W};
			KEY_HID_X:                ps2_pre <= {1'b0,KEY_PS2_X};
			KEY_HID_Y:                ps2_pre <= {1'b0,KEY_PS2_Y};
			KEY_HID_Z:                ps2_pre <= {1'b0,KEY_PS2_Z};
			KEY_HID_1:                ps2_pre <= {1'b0,KEY_PS2_1};
			KEY_HID_2:                ps2_pre <= {1'b0,KEY_PS2_2};
			KEY_HID_3:                ps2_pre <= {1'b0,KEY_PS2_3};
			KEY_HID_4:                ps2_pre <= {1'b0,KEY_PS2_4};
			KEY_HID_5:                ps2_pre <= {1'b0,KEY_PS2_5};
			KEY_HID_6:                ps2_pre <= {1'b0,KEY_PS2_6};
			KEY_HID_7:                ps2_pre <= {1'b0,KEY_PS2_7};
			KEY_HID_8:                ps2_pre <= {1'b0,KEY_PS2_8};
			KEY_HID_9:                ps2_pre <= {1'b0,KEY_PS2_9};
			KEY_HID_0:                ps2_pre <= {1'b0,KEY_PS2_0};
			KEY_HID_ENTER:            ps2_pre <= {1'b0,KEY_PS2_ENTER};
			KEY_HID_ESC:              ps2_pre <= {1'b0,KEY_PS2_ESC};
			KEY_HID_BACKSPACE:        ps2_pre <= {1'b0,KEY_PS2_BACKSPACE};
			KEY_HID_TAB:              ps2_pre <= {1'b0,KEY_PS2_TAB};
			KEY_HID_SPACE:            ps2_pre <= {1'b0,KEY_PS2_SPACE};
			KEY_HID_MINUS:            ps2_pre <= {1'b0,KEY_PS2_MINUS};
			KEY_HID_EQUAL:            ps2_pre <= {1'b0,KEY_PS2_EQUAL};
			KEY_HID_LEFTBRACE:        ps2_pre <= {1'b0,KEY_PS2_LEFTBRACE};
			KEY_HID_RIGHTBRACE:       ps2_pre <= {1'b0,KEY_PS2_RIGHTBRACE};
			KEY_HID_BACKSLASH:        ps2_pre <= {1'b0,KEY_PS2_BACKSLASH};
			KEY_HID_HASHTILDE:        ps2_pre <= {1'b0,KEY_PS2_HASHTILDE};
			KEY_HID_SEMICOLON:        ps2_pre <= {1'b0,KEY_PS2_SEMICOLON};
			KEY_HID_APOSTROPHE:       ps2_pre <= {1'b0,KEY_PS2_APOSTROPHE};
			KEY_HID_GRAVE:            ps2_pre <= {1'b0,KEY_PS2_GRAVE};
			KEY_HID_COMMA:            ps2_pre <= {1'b0,KEY_PS2_COMMA};
			KEY_HID_DOT:              ps2_pre <= {1'b0,KEY_PS2_DOT};
			KEY_HID_SLASH:            ps2_pre <= {1'b0,KEY_PS2_SLASH};
			KEY_HID_CAPSLOCK:         ps2_pre <= {1'b0,KEY_PS2_CAPSLOCK};
			KEY_HID_F1:               ps2_pre <= {1'b0,KEY_PS2_F1};
			KEY_HID_F2:               ps2_pre <= {1'b0,KEY_PS2_F2};
			KEY_HID_F3:               ps2_pre <= {1'b0,KEY_PS2_F3};
			KEY_HID_F4:               ps2_pre <= {1'b0,KEY_PS2_F4};
			KEY_HID_F5:               ps2_pre <= {1'b0,KEY_PS2_F5};
			KEY_HID_F6:               ps2_pre <= {1'b0,KEY_PS2_F6};
			KEY_HID_F7:               ps2_pre <= {1'b0,KEY_PS2_F7};
			KEY_HID_F8:               ps2_pre <= {1'b0,KEY_PS2_F8};
			KEY_HID_F9:               ps2_pre <= {1'b0,KEY_PS2_F9};
			KEY_HID_F10:              ps2_pre <= {1'b0,KEY_PS2_F10};
			KEY_HID_F11:              ps2_pre <= {1'b0,KEY_PS2_F11};
			KEY_HID_F12:              ps2_pre <= {1'b0,KEY_PS2_F12};
			KEY_HID_SYSRQ:            ps2_pre <= {1'b1,KEY_PS2_SYSRQ};      // E0
			KEY_HID_SCROLLLOCK:       ps2_pre <= {1'b0,KEY_PS2_SCROLLLOCK};
			KEY_HID_INSERT:           ps2_pre <= {1'b1,KEY_PS2_INSERT};     // E0
			KEY_HID_HOME:             ps2_pre <= {1'b1,KEY_PS2_HOME};       // E0
			KEY_HID_PAGEUP:           ps2_pre <= {1'b1,KEY_PS2_PAGEUP};     // E0
			KEY_HID_DELETE:           ps2_pre <= {1'b1,KEY_PS2_DELETE};     // E0
			KEY_HID_END:              ps2_pre <= {1'b1,KEY_PS2_END};        // E0
			KEY_HID_PAGEDOWN:         ps2_pre <= {1'b1,KEY_PS2_PAGEDOWN};   // E0
			KEY_HID_RIGHT:            ps2_pre <= {1'b1,KEY_PS2_RIGHT};      // E0
			KEY_HID_LEFT:             ps2_pre <= {1'b1,KEY_PS2_LEFT};       // E0
			KEY_HID_DOWN:             ps2_pre <= {1'b1,KEY_PS2_DOWN};       // E0
			KEY_HID_UP:               ps2_pre <= {1'b1,KEY_PS2_UP};         // E0
			KEY_HID_NUMLOCK:          ps2_pre <= {1'b0,KEY_PS2_NUMLOCK};
			KEY_HID_KPSLASH:          ps2_pre <= {1'b1,KEY_PS2_KPSLASH};    // E0
			KEY_HID_KPASTERISK:       ps2_pre <= {1'b0,KEY_PS2_KPASTERISK};
			KEY_HID_KPMINUS:          ps2_pre <= {1'b0,KEY_PS2_KPMINUS};
			KEY_HID_KPPLUS:           ps2_pre <= {1'b0,KEY_PS2_KPPLUS};
			KEY_HID_KPENTER:          ps2_pre <= {1'b1,KEY_PS2_KPENTER};    // E0
			KEY_HID_KP1:              ps2_pre <= {1'b0,KEY_PS2_KP1};
			KEY_HID_KP2:              ps2_pre <= {1'b0,KEY_PS2_KP2};
			KEY_HID_KP3:              ps2_pre <= {1'b0,KEY_PS2_KP3};
			KEY_HID_KP4:              ps2_pre <= {1'b0,KEY_PS2_KP4};
			KEY_HID_KP5:              ps2_pre <= {1'b0,KEY_PS2_KP5};
			KEY_HID_KP6:              ps2_pre <= {1'b0,KEY_PS2_KP6};
			KEY_HID_KP7:              ps2_pre <= {1'b0,KEY_PS2_KP7};
			KEY_HID_KP8:              ps2_pre <= {1'b0,KEY_PS2_KP8};
			KEY_HID_KP9:              ps2_pre <= {1'b0,KEY_PS2_KP9};
			KEY_HID_KP0:              ps2_pre <= {1'b0,KEY_PS2_KP0};
			KEY_HID_KPDOT:            ps2_pre <= {1'b0,KEY_PS2_KPDOT};
			KEY_HID_102ND:            ps2_pre <= {1'b0,KEY_PS2_102ND};
			KEY_HID_COMPOSE:          ps2_pre <= {1'b1,KEY_PS2_COMPOSE};   // E0
			KEY_HID_POWER:            ps2_pre <= {1'b1,KEY_PS2_POWER};     // E0
			KEY_HID_KPEQUAL:          ps2_pre <= {1'b0,KEY_PS2_KPEQUAL};
			KEY_HID_F13:              ps2_pre <= {1'b0,KEY_PS2_F13};
			KEY_HID_F14:              ps2_pre <= {1'b0,KEY_PS2_F14};
			KEY_HID_F15:              ps2_pre <= {1'b0,KEY_PS2_F15};
			KEY_HID_F16:              ps2_pre <= {1'b0,KEY_PS2_F16};
			KEY_HID_F17:              ps2_pre <= {1'b0,KEY_PS2_F17};
			KEY_HID_F18:              ps2_pre <= {1'b0,KEY_PS2_F18};
			KEY_HID_F19:              ps2_pre <= {1'b0,KEY_PS2_F19};
			KEY_HID_F20:              ps2_pre <= {1'b0,KEY_PS2_F20};
			KEY_HID_F21:              ps2_pre <= {1'b0,KEY_PS2_F21};
			KEY_HID_F22:              ps2_pre <= {1'b0,KEY_PS2_F22};
			KEY_HID_F23:              ps2_pre <= {1'b0,KEY_PS2_F23};
			KEY_HID_F24:              ps2_pre <= {1'b0,KEY_PS2_F24};
			KEY_HID_KPCOMMA:          ps2_pre <= {1'b0,KEY_PS2_KPCOMMA};
			KEY_HID_RO:               ps2_pre <= {1'b0,KEY_PS2_RO};
			KEY_HID_KATAKANAHIRAGANA: ps2_pre <= {1'b0,KEY_PS2_KATAKANAHIRAGANA};
			KEY_HID_YEN:              ps2_pre <= {1'b0,KEY_PS2_YEN};
			KEY_HID_HENKAN:           ps2_pre <= {1'b0,KEY_PS2_HENKAN};
			KEY_HID_MUHENKAN:         ps2_pre <= {1'b0,KEY_PS2_MUHENKAN};
			KEY_HID_KPJPCOMMA:        ps2_pre <= {1'b0,KEY_PS2_KPJPCOMMA};
			KEY_HID_HANGEUL:          ps2_pre <= {1'b0,KEY_PS2_HANGEUL};
			KEY_HID_HANJA:            ps2_pre <= {1'b0,KEY_PS2_HANJA};
			KEY_HID_KATAKANA:         ps2_pre <= {1'b0,KEY_PS2_KATAKANA};
			KEY_HID_HIRAGANA:         ps2_pre <= {1'b0,KEY_PS2_HIRAGANA};
			KEY_HID_ZENKAKUHANKAKU:   ps2_pre <= {1'b0,KEY_PS2_ZENKAKUHANKAKU};
			KEY_HID_LEFTCTRL:         ps2_pre <= {1'b0,KEY_PS2_LEFTCTRL};
			KEY_HID_LEFTSHIFT:        ps2_pre <= {1'b0,KEY_PS2_LEFTSHIFT};
			KEY_HID_LEFTALT:          ps2_pre <= {1'b0,KEY_PS2_LEFTALT};
			KEY_HID_LEFTMETA:         ps2_pre <= {1'b1,KEY_PS2_LEFTMETA};    // E0
			KEY_HID_RIGHTCTRL:        ps2_pre <= {1'b1,KEY_PS2_RIGHTCTRL};   // E0
			KEY_HID_RIGHTSHIFT:       ps2_pre <= {1'b0,KEY_PS2_RIGHTSHIFT};
			KEY_HID_RIGHTALT:         ps2_pre <= {1'b1,KEY_PS2_RIGHTALT};    // E0
			KEY_HID_RIGHTMETA:        ps2_pre <= {1'b1,KEY_PS2_RIGHTMETA};   // E0
			default:                  ps2_pre <= 0;
		endcase
end
endmodule