module test;

`include "test_tasks.vh"

localparam DW=8;

reg clk, rst;

reg  [    15:0] commands [0:255];
wire [  DW-1:0] data_in, data_out;
wire [2*DW-1:0] dexp;
wire            high, ready, send;
reg             load=0,next=0, released=0;
integer         value=0, steps=0;


initial begin
    $dumpfile("test.lxt");
    $dumpvars;
    $dumpon;
    #2000000
    $display("FAIL");
    $finish;
end

initial begin
    clk=0;
    forever #10 clk=~clk;
end

assign data_in     = value[0+:DW];
assign dexp        = commands[value];
assign high        = dexp[15:8]==8'he0;

initial begin
    rst    = 1;
    released = 0;
    repeat (20) @(posedge clk);
    rst  = 0;
    repeat (20) @(posedge clk);

    repeat (2) begin
        for (value = 0; value < 256; value++) begin
            send_new_key();
            check_commands();
        end
        released = ~released;
    end
    pass();
end

task send_new_key();
    assert_msg( ready ==1,"Translator not ready");
    count_total_steps();
    @(posedge clk) load = 1;
    @(posedge clk) load = 0;
    if( dexp != 0 )
        @(posedge clk) assert_msg( ready ==0,"Translator should not be ready");
endtask

task count_total_steps();
    steps = 1;
    @(posedge clk);
    if( high     ) steps = steps+1;
    if( released ) steps = steps+1;
endtask

task check_current_output();
    @(posedge clk);
    if( steps==2 && released && dexp!=0 )
        @(posedge clk) assert_msg( data_out==8'hf0,"Released code was expected");
    else if( steps[1] && dexp!=0 )
        @(posedge clk) assert_msg( data_out==8'he0,"Extended code was expected");
    else
        @(posedge clk) assert_msg( data_out==dexp[7:0],"Received unexpected code");
endtask

task check_send(input exp);
    if( dexp == 0 || exp==0 )
        assert_msg( send==0, "Send signal should not be active");
    else
        assert_msg( send==1, "Send signal should be active");
endtask

task check_commands();
    repeat (steps) begin
        check_send(0);
        @(posedge clk) next=1;
        check_current_output();
        check_send(1);
        @(posedge clk) next=0;
        check_current_output();
        check_send(0);
        steps = steps-1;
        repeat (5) @(posedge clk);
    end
endtask

jtframe_hid_ps2_translator uut(
    .rst       ( rst      ),
    .clk       ( clk      ),
    .keycheck  ( data_in  ),
    .released  ( released ),
    .load_key  ( load     ),
    .tr_ready  ( ready    ),
    .tr_send   ( send     ),
    .next_code ( next     ),
    .ps2_code  ( data_out )
);

localparam [7:0]
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
    KEY_HID_KPCOMMA=8'h85,               KEY_PS2_KPCOMMA=8'h6d,
    KEY_HID_RO=8'h87,                    KEY_PS2_RO=8'h51,
    KEY_HID_KATAKANAHIRAGANA=8'h88,      KEY_PS2_KATAKANAHIRAGANA=8'h13,
    KEY_HID_YEN=8'h89,                   KEY_PS2_YEN=8'h6a,
    KEY_HID_HENKAN=8'h8a,                KEY_PS2_HENKAN=8'h64,
    KEY_HID_MUHENKAN=8'h8b,              KEY_PS2_MUHENKAN=8'h67,
    KEY_HID_KPJPCOMMA=8'h8c,             KEY_PS2_KPJPCOMMA=8'h27,
    KEY_HID_HANGEUL=8'h90,               KEY_PS2_HANGEUL=8'hf2,
    KEY_HID_HANJA=8'h91,                 KEY_PS2_HANJA=8'hf1,
    KEY_HID_KATAKANA=8'h92,              KEY_PS2_KATAKANA=8'h63,
    KEY_HID_HIRAGANA=8'h93,              KEY_PS2_HIRAGANA=8'h62,
    KEY_HID_ZENKAKUHANKAKU=8'h94,        KEY_PS2_ZENKAKUHANKAKU=8'h5f,
    KEY_HID_LEFTCTRL=8'he0,              KEY_PS2_LEFTCTRL=8'h14,
    KEY_HID_LEFTSHIFT=8'he1,             KEY_PS2_LEFTSHIFT=8'h12,
    KEY_HID_LEFTALT=8'he2,               KEY_PS2_LEFTALT=8'h11,
    KEY_HID_LEFTMETA=8'he3,              KEY_PS2_LEFTMETA=8'h1f,    // E0
    KEY_HID_RIGHTCTRL=8'he4,             KEY_PS2_RIGHTCTRL=8'h14,   // E0
    KEY_HID_RIGHTSHIFT=8'he5,            KEY_PS2_RIGHTSHIFT=8'h59,
    KEY_HID_RIGHTALT=8'he6,              KEY_PS2_RIGHTALT=8'h11,    // E0
    KEY_HID_RIGHTMETA=8'he7,             KEY_PS2_RIGHTMETA=8'h27,   // E0

    KEY_PS2_EXT=8'he0;

    initial begin
        for (int i = 0; i < 256; i++) begin
            commands[i] = 0;
        end
            commands[KEY_HID_A               ] =  KEY_PS2_A;
            commands[KEY_HID_B               ] =  KEY_PS2_B;
            commands[KEY_HID_C               ] =  KEY_PS2_C;
            commands[KEY_HID_D               ] =  KEY_PS2_D;
            commands[KEY_HID_E               ] =  KEY_PS2_E;
            commands[KEY_HID_F               ] =  KEY_PS2_F;
            commands[KEY_HID_G               ] =  KEY_PS2_G;
            commands[KEY_HID_H               ] =  KEY_PS2_H;
            commands[KEY_HID_I               ] =  KEY_PS2_I;
            commands[KEY_HID_J               ] =  KEY_PS2_J;
            commands[KEY_HID_K               ] =  KEY_PS2_K;
            commands[KEY_HID_L               ] =  KEY_PS2_L;
            commands[KEY_HID_M               ] =  KEY_PS2_M;
            commands[KEY_HID_N               ] =  KEY_PS2_N;
            commands[KEY_HID_O               ] =  KEY_PS2_O;
            commands[KEY_HID_P               ] =  KEY_PS2_P;
            commands[KEY_HID_Q               ] =  KEY_PS2_Q;
            commands[KEY_HID_R               ] =  KEY_PS2_R;
            commands[KEY_HID_S               ] =  KEY_PS2_S;
            commands[KEY_HID_T               ] =  KEY_PS2_T;
            commands[KEY_HID_U               ] =  KEY_PS2_U;
            commands[KEY_HID_V               ] =  KEY_PS2_V;
            commands[KEY_HID_W               ] =  KEY_PS2_W;
            commands[KEY_HID_X               ] =  KEY_PS2_X;
            commands[KEY_HID_Y               ] =  KEY_PS2_Y;
            commands[KEY_HID_Z               ] =  KEY_PS2_Z;
            commands[KEY_HID_1               ] =  KEY_PS2_1;
            commands[KEY_HID_2               ] =  KEY_PS2_2;
            commands[KEY_HID_3               ] =  KEY_PS2_3;
            commands[KEY_HID_4               ] =  KEY_PS2_4;
            commands[KEY_HID_5               ] =  KEY_PS2_5;
            commands[KEY_HID_6               ] =  KEY_PS2_6;
            commands[KEY_HID_7               ] =  KEY_PS2_7;
            commands[KEY_HID_8               ] =  KEY_PS2_8;
            commands[KEY_HID_9               ] =  KEY_PS2_9;
            commands[KEY_HID_0               ] =  KEY_PS2_0;
            commands[KEY_HID_ENTER           ] =  KEY_PS2_ENTER;
            commands[KEY_HID_ESC             ] =  KEY_PS2_ESC;
            commands[KEY_HID_BACKSPACE       ] =  KEY_PS2_BACKSPACE;
            commands[KEY_HID_TAB             ] =  KEY_PS2_TAB;
            commands[KEY_HID_SPACE           ] =  KEY_PS2_SPACE;
            commands[KEY_HID_MINUS           ] =  KEY_PS2_MINUS;
            commands[KEY_HID_EQUAL           ] =  KEY_PS2_EQUAL;
            commands[KEY_HID_LEFTBRACE       ] =  KEY_PS2_LEFTBRACE;
            commands[KEY_HID_RIGHTBRACE      ] =  KEY_PS2_RIGHTBRACE;
            commands[KEY_HID_BACKSLASH       ] =  KEY_PS2_BACKSLASH;
            commands[KEY_HID_HASHTILDE       ] =  KEY_PS2_HASHTILDE;
            commands[KEY_HID_SEMICOLON       ] =  KEY_PS2_SEMICOLON;
            commands[KEY_HID_APOSTROPHE      ] =  KEY_PS2_APOSTROPHE;
            commands[KEY_HID_GRAVE           ] =  KEY_PS2_GRAVE;
            commands[KEY_HID_COMMA           ] =  KEY_PS2_COMMA;
            commands[KEY_HID_DOT             ] =  KEY_PS2_DOT;
            commands[KEY_HID_SLASH           ] =  KEY_PS2_SLASH;
            commands[KEY_HID_CAPSLOCK        ] =  KEY_PS2_CAPSLOCK;
            commands[KEY_HID_F1              ] =  KEY_PS2_F1;
            commands[KEY_HID_F2              ] =  KEY_PS2_F2;
            commands[KEY_HID_F3              ] =  KEY_PS2_F3;
            commands[KEY_HID_F4              ] =  KEY_PS2_F4;
            commands[KEY_HID_F5              ] =  KEY_PS2_F5;
            commands[KEY_HID_F6              ] =  KEY_PS2_F6;
            commands[KEY_HID_F7              ] =  KEY_PS2_F7;
            commands[KEY_HID_F8              ] =  KEY_PS2_F8;
            commands[KEY_HID_F9              ] =  KEY_PS2_F9;
            commands[KEY_HID_F10             ] =  KEY_PS2_F10;
            commands[KEY_HID_F11             ] =  KEY_PS2_F11;
            commands[KEY_HID_F12             ] =  KEY_PS2_F12;
            commands[KEY_HID_SYSRQ           ] = {KEY_PS2_EXT, KEY_PS2_SYSRQ};      // E0
            commands[KEY_HID_SCROLLLOCK      ] =  KEY_PS2_SCROLLLOCK;
            commands[KEY_HID_INSERT          ] = {KEY_PS2_EXT, KEY_PS2_INSERT};     // E0
            commands[KEY_HID_HOME            ] = {KEY_PS2_EXT, KEY_PS2_HOME};       // E0
            commands[KEY_HID_PAGEUP          ] = {KEY_PS2_EXT, KEY_PS2_PAGEUP};     // E0
            commands[KEY_HID_DELETE          ] = {KEY_PS2_EXT, KEY_PS2_DELETE};     // E0
            commands[KEY_HID_END             ] = {KEY_PS2_EXT, KEY_PS2_END};        // E0
            commands[KEY_HID_PAGEDOWN        ] = {KEY_PS2_EXT, KEY_PS2_PAGEDOWN};   // E0
            commands[KEY_HID_RIGHT           ] = {KEY_PS2_EXT, KEY_PS2_RIGHT};      // E0
            commands[KEY_HID_LEFT            ] = {KEY_PS2_EXT, KEY_PS2_LEFT};       // E0
            commands[KEY_HID_DOWN            ] = {KEY_PS2_EXT, KEY_PS2_DOWN};       // E0
            commands[KEY_HID_UP              ] = {KEY_PS2_EXT, KEY_PS2_UP};         // E0
            commands[KEY_HID_NUMLOCK         ] =  KEY_PS2_NUMLOCK;
            commands[KEY_HID_KPSLASH         ] = {KEY_PS2_EXT, KEY_PS2_KPSLASH};    // E0
            commands[KEY_HID_KPASTERISK      ] =  KEY_PS2_KPASTERISK;
            commands[KEY_HID_KPMINUS         ] =  KEY_PS2_KPMINUS;
            commands[KEY_HID_KPPLUS          ] =  KEY_PS2_KPPLUS;
            commands[KEY_HID_KPENTER         ] = {KEY_PS2_EXT, KEY_PS2_KPENTER};    // E0
            commands[KEY_HID_KP1             ] =  KEY_PS2_KP1;
            commands[KEY_HID_KP2             ] =  KEY_PS2_KP2;
            commands[KEY_HID_KP3             ] =  KEY_PS2_KP3;
            commands[KEY_HID_KP4             ] =  KEY_PS2_KP4;
            commands[KEY_HID_KP5             ] =  KEY_PS2_KP5;
            commands[KEY_HID_KP6             ] =  KEY_PS2_KP6;
            commands[KEY_HID_KP7             ] =  KEY_PS2_KP7;
            commands[KEY_HID_KP8             ] =  KEY_PS2_KP8;
            commands[KEY_HID_KP9             ] =  KEY_PS2_KP9;
            commands[KEY_HID_KP0             ] =  KEY_PS2_KP0;
            commands[KEY_HID_KPDOT           ] =  KEY_PS2_KPDOT;
            commands[KEY_HID_102ND           ] =  KEY_PS2_102ND;
            commands[KEY_HID_COMPOSE         ] = {KEY_PS2_EXT, KEY_PS2_COMPOSE};   // E0
            commands[KEY_HID_POWER           ] = {KEY_PS2_EXT, KEY_PS2_POWER};     // E0
            commands[KEY_HID_KPEQUAL         ] =  KEY_PS2_KPEQUAL;
            commands[KEY_HID_F13             ] =  KEY_PS2_F13;
            commands[KEY_HID_F14             ] =  KEY_PS2_F14;
            commands[KEY_HID_F15             ] =  KEY_PS2_F15;
            commands[KEY_HID_F16             ] =  KEY_PS2_F16;
            commands[KEY_HID_F17             ] =  KEY_PS2_F17;
            commands[KEY_HID_F18             ] =  KEY_PS2_F18;
            commands[KEY_HID_F19             ] =  KEY_PS2_F19;
            commands[KEY_HID_F20             ] =  KEY_PS2_F20;
            commands[KEY_HID_F21             ] =  KEY_PS2_F21;
            commands[KEY_HID_F22             ] =  KEY_PS2_F22;
            commands[KEY_HID_F23             ] =  KEY_PS2_F23;
            commands[KEY_HID_F24             ] =  KEY_PS2_F24;
            commands[KEY_HID_KPCOMMA         ] =  KEY_PS2_KPCOMMA;
            commands[KEY_HID_RO              ] =  KEY_PS2_RO;
            commands[KEY_HID_KATAKANAHIRAGANA] =  KEY_PS2_KATAKANAHIRAGANA;
            commands[KEY_HID_YEN             ] =  KEY_PS2_YEN;
            commands[KEY_HID_HENKAN          ] =  KEY_PS2_HENKAN;
            commands[KEY_HID_MUHENKAN        ] =  KEY_PS2_MUHENKAN;
            commands[KEY_HID_KPJPCOMMA       ] =  KEY_PS2_KPJPCOMMA;
            commands[KEY_HID_HANGEUL         ] =  KEY_PS2_HANGEUL;
            commands[KEY_HID_HANJA           ] =  KEY_PS2_HANJA;
            commands[KEY_HID_KATAKANA        ] =  KEY_PS2_KATAKANA;
            commands[KEY_HID_HIRAGANA        ] =  KEY_PS2_HIRAGANA;
            commands[KEY_HID_ZENKAKUHANKAKU  ] =  KEY_PS2_ZENKAKUHANKAKU;
            commands[KEY_HID_LEFTCTRL        ] =  KEY_PS2_LEFTCTRL;
            commands[KEY_HID_LEFTSHIFT       ] =  KEY_PS2_LEFTSHIFT;
            commands[KEY_HID_LEFTALT         ] =  KEY_PS2_LEFTALT;
            commands[KEY_HID_LEFTMETA        ] = {KEY_PS2_EXT, KEY_PS2_LEFTMETA};    // E0
            commands[KEY_HID_RIGHTCTRL       ] = {KEY_PS2_EXT, KEY_PS2_RIGHTCTRL};   // E0
            commands[KEY_HID_RIGHTSHIFT      ] =  KEY_PS2_RIGHTSHIFT;
            commands[KEY_HID_RIGHTALT        ] = {KEY_PS2_EXT, KEY_PS2_RIGHTALT};    // E0
            commands[KEY_HID_RIGHTMETA       ] = {KEY_PS2_EXT, KEY_PS2_RIGHTMETA};   // E0
    end
endmodule