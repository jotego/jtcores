module test;

reg clk, rst;
`include "test_tasks.vh"

localparam DW=8;


reg  [6*DW-1:0] keys;
wire [    31:0] joy;
wire [    15:0] trig;
reg  [    15:0] cont3_key=0;
reg  [    15:0] commands [0:255];
wire            sclk, sdout;
reg             clr;

wire [9:0] joy1, joy2, joy3, joy4;
wire [3:0] coin, start;
wire       p,t,f2,f3,f4,f5,b9, plus, minus, shift, ctrl, alt,
           x,z,l_shift,space,l_alt, l_ctrl, up, down,left,right,
           k2,e,w,q,s,a,r,f,d,g,
           ret,r_shift,r_crtl,i,k3,j,l,
           kpenter,kpdot,kp0,kp8,kp2,kp4,kp6,
           b1,b2,b3,b4,b5,b6,b7,b8;

assign {x,      z,      l_shift,space,l_alt,l_ctrl,up, down,left,right} = joy1;
assign {k2,     e,      w,      q,    s,    a,     r,  f,   d,   g    } = joy2;
assign {ret,    r_shift,r_crtl, i,    k3,   j,     l                  } = joy3[6:0];
assign {kpenter,kpdot,  kp0,    kp8,  kp2,  kp4,   kp6                } = joy4[6:0];
assign {b1,     b2,     b3,     b4,   b5,   b6,    b7, b8             } = {coin,start};

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

assign {trig, joy} = clr ? 0 : keys;

initial begin
    rst    = 1;
    clr    = 1;
    release_all_keys();
    repeat (20) @(posedge clk);
    rst  = 0;
    press_key("P");
    repeat (20) @(posedge clk);
    clr = 0;
    wait( p==1 );
    repeat (20) @(posedge clk);
    clr = 1;
    wait( p==0 );
    repeat (20) @(posedge clk);
    clr = 0;
    wait( p==1 );
    repeat (20) @(posedge clk);
    press_key("1");
    wait(  start[0] && p);
    repeat (20) @(posedge clk);
    press_key("2");
    wait( &start[1:0] && p);
    repeat (20) @(posedge clk);
    press_key("3");
    wait( &start[2:0] && p);
    repeat (20) @(posedge clk);
    press_key("4");
    wait( &start      && p);
    repeat (20) @(posedge clk);
    press_key("5");
    wait( &start      && p &&   coin[0]);
    repeat (20) @(posedge clk);
    press_key("6");
    wait( &start      && !p && &coin[1:0]);
    repeat (20) @(posedge clk);
    press_key("UP");
    press_key("LEFT");
    repeat (20) @(posedge clk);
    wait( up && left);
    release_all_keys();
    repeat (4000) @(posedge clk);
    check_all_released();
    repeat (20) @(posedge clk);
    press_key("F");
    press_key("G");
    press_key("S");
    press_key("A");
    repeat (20) @(posedge clk);
    wait( f && g && s && a);
    release_all_keys();
    repeat (4000) @(posedge clk);
    check_all_released();
    repeat (20) @(posedge clk);
    cont3_key = {8'b1,8'b0};
    repeat (20) @(posedge clk);
    wait( l_ctrl);
    cont3_key = {8'h2,8'b0};
    repeat (20) @(posedge clk);
    wait( !l_ctrl && l_shift);
    release_all_keys();
    repeat (4000) @(posedge clk);
    check_all_released();
    pass();
end

jtframe_pocket_keyboard uuu(
    .rst       ( rst        ),
    .clk       ( clk        ),
    .key_en    ( 1'b1       ),
    .cont3_joy ( joy        ),
    .cont3_trig( trig       ),
    .cont3_key ( cont3_key  ),
    .ps2_clk   ( sclk       ),
    .ps2_data  ( sdout      ),
    .last_key  (            )
);

jtframe_keyboard u_keyboard(
    .clk         ( clk           ),
    .rst         ( rst           ),
    // ps2 interface
    .ps2_clk     ( sclk   ),
    .ps2_data    ( sdout  ),
    // decoded keys
    .joy1        ( joy1   ),
    .joy2        ( joy2   ),
    .joy3        ( joy3   ),
    .joy4        ( joy4   ),
    .start       ( start  ),
    .coin        ( coin   ),
    .reset       ( f3     ),
    .test        ( f2     ),
    .pause       ( p      ),
    .service     ( b9     ),
    .tilt        ( t      ),
    .digit       (   ),

    .shift       ( shift  ),
    .ctrl        ( ctrl   ),
    .alt         ( alt    ),
    .vol_up      ( f4     ),
    .vol_down    ( f5     ),
    .func_key    (   ),
    .plus        ( plus   ),
    .minus       ( minus  )
);

task release_all_keys();
    keys = 0;
    cont3_key = 0;
endtask

task check_released_keys();
    clr  = 1;
endtask

task press_key_code(input [7:0] hid);
    keys = {keys[0+:DW*5],hid};
endtask

task release_key_n(input int n);
    keys[n+:8] = 8'b0;
endtask

task check_all_released();
    assert_msg({joy1,joy2,joy3,joy4,coin,start}==0,"Everything should be released");
endtask

task press_key( string name );
    if(     name=="A"               ) press_key_code(8'h04);
    else if(name=="B"               ) press_key_code(8'h05);
    else if(name=="C"               ) press_key_code(8'h06);
    else if(name=="D"               ) press_key_code(8'h07);
    else if(name=="E"               ) press_key_code(8'h08);
    else if(name=="F"               ) press_key_code(8'h09);
    else if(name=="G"               ) press_key_code(8'h0a);
    else if(name=="H"               ) press_key_code(8'h0b);
    else if(name=="I"               ) press_key_code(8'h0c);
    else if(name=="J"               ) press_key_code(8'h0d);
    else if(name=="K"               ) press_key_code(8'h0e);
    else if(name=="L"               ) press_key_code(8'h0f);
    else if(name=="M"               ) press_key_code(8'h10);
    else if(name=="N"               ) press_key_code(8'h11);
    else if(name=="O"               ) press_key_code(8'h12);
    else if(name=="P"               ) press_key_code(8'h13);
    else if(name=="Q"               ) press_key_code(8'h14);
    else if(name=="R"               ) press_key_code(8'h15);
    else if(name=="S"               ) press_key_code(8'h16);
    else if(name=="T"               ) press_key_code(8'h17);
    else if(name=="U"               ) press_key_code(8'h18);
    else if(name=="V"               ) press_key_code(8'h19);
    else if(name=="W"               ) press_key_code(8'h1a);
    else if(name=="X"               ) press_key_code(8'h1b);
    else if(name=="Y"               ) press_key_code(8'h1c);
    else if(name=="Z"               ) press_key_code(8'h1d);
    else if(name=="1"               ) press_key_code(8'h1e);
    else if(name=="2"               ) press_key_code(8'h1f);
    else if(name=="3"               ) press_key_code(8'h20);
    else if(name=="4"               ) press_key_code(8'h21);
    else if(name=="5"               ) press_key_code(8'h22);
    else if(name=="6"               ) press_key_code(8'h23);
    else if(name=="7"               ) press_key_code(8'h24);
    else if(name=="8"               ) press_key_code(8'h25);
    else if(name=="9"               ) press_key_code(8'h26);
    else if(name=="0"               ) press_key_code(8'h27);
    else if(name=="ENTER"           ) press_key_code(8'h28);
    else if(name=="ESC"             ) press_key_code(8'h29);
    else if(name=="BACKSPACE"       ) press_key_code(8'h2a);
    else if(name=="TAB"             ) press_key_code(8'h2b);
    else if(name=="SPACE"           ) press_key_code(8'h2c);
    else if(name=="MINUS"           ) press_key_code(8'h2d);
    else if(name=="EQUAL"           ) press_key_code(8'h2e);
    else if(name=="LEFTBRACE"       ) press_key_code(8'h2f);
    else if(name=="RIGHTBRACE"      ) press_key_code(8'h30);
    else if(name=="BACKSLASH"       ) press_key_code(8'h31);
    else if(name=="HASHTILDE"       ) press_key_code(8'h32);
    else if(name=="SEMICOLON"       ) press_key_code(8'h33);
    else if(name=="APOSTROPHE"      ) press_key_code(8'h34);
    else if(name=="GRAVE"           ) press_key_code(8'h35);
    else if(name=="COMMA"           ) press_key_code(8'h36);
    else if(name=="DOT"             ) press_key_code(8'h37);
    else if(name=="SLASH"           ) press_key_code(8'h38);
    else if(name=="CAPSLOCK"        ) press_key_code(8'h39);
    else if(name=="F1"              ) press_key_code(8'h3a);
    else if(name=="F2"              ) press_key_code(8'h3b);
    else if(name=="F3"              ) press_key_code(8'h3c);
    else if(name=="F4"              ) press_key_code(8'h3d);
    else if(name=="F5"              ) press_key_code(8'h3e);
    else if(name=="F6"              ) press_key_code(8'h3f);
    else if(name=="F7"              ) press_key_code(8'h40);
    else if(name=="F8"              ) press_key_code(8'h41);
    else if(name=="F9"              ) press_key_code(8'h42);
    else if(name=="F10"             ) press_key_code(8'h43);
    else if(name=="F11"             ) press_key_code(8'h44);
    else if(name=="F12"             ) press_key_code(8'h45);
    else if(name=="SYSRQ"           ) press_key_code(8'h46);
    else if(name=="SCROLLLOCK"      ) press_key_code(8'h47);
    else if(name=="INSERT"          ) press_key_code(8'h49);
    else if(name=="HOME"            ) press_key_code(8'h4a);
    else if(name=="PAGEUP"          ) press_key_code(8'h4b);
    else if(name=="DELETE"          ) press_key_code(8'h4c);
    else if(name=="END"             ) press_key_code(8'h4d);
    else if(name=="PAGEDOWN"        ) press_key_code(8'h4e);
    else if(name=="RIGHT"           ) press_key_code(8'h4f);
    else if(name=="LEFT"            ) press_key_code(8'h50);
    else if(name=="DOWN"            ) press_key_code(8'h51);
    else if(name=="UP"              ) press_key_code(8'h52);
    else if(name=="NUMLOCK"         ) press_key_code(8'h53);
    else if(name=="KPSLASH"         ) press_key_code(8'h54);
    else if(name=="KPASTERISK"      ) press_key_code(8'h55);
    else if(name=="KPMINUS"         ) press_key_code(8'h56);
    else if(name=="KPPLUS"          ) press_key_code(8'h57);
    else if(name=="KPENTER"         ) press_key_code(8'h58);
    else if(name=="KP1"             ) press_key_code(8'h59);
    else if(name=="KP2"             ) press_key_code(8'h5a);
    else if(name=="KP3"             ) press_key_code(8'h5b);
    else if(name=="KP4"             ) press_key_code(8'h5c);
    else if(name=="KP5"             ) press_key_code(8'h5d);
    else if(name=="KP6"             ) press_key_code(8'h5e);
    else if(name=="KP7"             ) press_key_code(8'h5f);
    else if(name=="KP8"             ) press_key_code(8'h60);
    else if(name=="KP9"             ) press_key_code(8'h61);
    else if(name=="KP0"             ) press_key_code(8'h62);
    else if(name=="KPDOT"           ) press_key_code(8'h63);
    else if(name=="102ND"           ) press_key_code(8'h64);
    else if(name=="COMPOSE"         ) press_key_code(8'h65);
    else if(name=="POWER"           ) press_key_code(8'h66);
    else if(name=="KPEQUAL"         ) press_key_code(8'h67);
    else if(name=="F13"             ) press_key_code(8'h68);
    else if(name=="F14"             ) press_key_code(8'h69);
    else if(name=="F15"             ) press_key_code(8'h6a);
    else if(name=="F16"             ) press_key_code(8'h6b);
    else if(name=="F17"             ) press_key_code(8'h6c);
    else if(name=="F18"             ) press_key_code(8'h6d);
    else if(name=="F19"             ) press_key_code(8'h6e);
    else if(name=="F20"             ) press_key_code(8'h6f);
    else if(name=="F21"             ) press_key_code(8'h70);
    else if(name=="F22"             ) press_key_code(8'h71);
    else if(name=="F23"             ) press_key_code(8'h72);
    else if(name=="F24"             ) press_key_code(8'h73);
    else if(name=="KPCOMMA"         ) press_key_code(8'h85);
    else if(name=="RO"              ) press_key_code(8'h87);
    else if(name=="KATAKANAHIRAGANA") press_key_code(8'h88);
    else if(name=="YEN"             ) press_key_code(8'h89);
    else if(name=="HENKAN"          ) press_key_code(8'h8a);
    else if(name=="MUHENKAN"        ) press_key_code(8'h8b);
    else if(name=="KPJPCOMMA"       ) press_key_code(8'h8c);
    else if(name=="HANGEUL"         ) press_key_code(8'h90);
    else if(name=="HANJA"           ) press_key_code(8'h91);
    else if(name=="KATAKANA"        ) press_key_code(8'h92);
    else if(name=="HIRAGANA"        ) press_key_code(8'h93);
    else if(name=="ZENKAKUHANKAKU"  ) press_key_code(8'h94);
    else if(name=="LEFTCTRL"        ) press_key_code(8'he0);
    else if(name=="LEFTSHIFT"       ) press_key_code(8'he1);
    else if(name=="LEFTALT"         ) press_key_code(8'he2);
    else if(name=="LEFTMETA"        ) press_key_code(8'he3);
    else if(name=="RIGHTCTRL"       ) press_key_code(8'he4);
    else if(name=="RIGHTSHIFT"      ) press_key_code(8'he5);
    else if(name=="RIGHTALT"        ) press_key_code(8'he6);
    else if(name=="RIGHTMETA"       ) press_key_code(8'he7);
    else $display("Unknown option %s",name);
endtask

endmodule