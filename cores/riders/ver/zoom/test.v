module test;

`include "test_tasks.vh"

wire xylock=1'b0;

wire [14:0] xlin;
wire signed [15:0] xadj;
reg  [15:0] xzoom;
reg signed [15:0] xoff;
reg signed [15:0] expected;
wire [ 9:0] xmant, xlog;
wire [ 8:0] xfrac;
wire [ 1:0] ztype;
wire        cen;

wire signed [15:0] diff = xadj-expected;
wire        [15:0] err  = diff<0 ? -diff : diff;
integer cnt=0;

always @(posedge clk) if(cen) begin
    cnt <= cnt+1;
    if(cnt==550) pass;
    if(err>16'd25) begin
        $display("0x%04X, %05d: %d <-> %d (%d) type = %d",
            xzoom, xoff,
            xadj,expected,err,ztype);
        $display("At entry %d",cnt);
        fail;
    end
end

jtriders_tmnt2_zoom u_xzoom(
    .clk        ( clk       ),
    .xylock     ( xylock    ),

    .mant       ( xmant     ),
    .frac       ( xfrac     ),
    .log        ( xlog      ),
    .lin        ( xlin      ),
    .offset     ( xoff      ),
    .zoom       ( xzoom     ),
    .ztype      ( ztype     ),
    .adj        ( xadj      )
);

jtframe_dual_ram #(
    .DW        ( 9                  ),
    .SYNFILE   ("../../hdl/log2.hex")
)u_log(
    .clk0       ( clk               ),
    .clk1       ( clk               ),
    // Port 0
    .data0      ( 9'h0              ),
    .addr0      ( xmant             ),
    .we0        ( 1'b0              ),
    .q0         ( xfrac             ),
    // Port 1
    .data1      ( 9'h0              ),
    .addr1      ( 10'b0             ),
    .we1        ( 1'b0              ),
    .q1         (                   )
);

jtframe_dual_ram #(
    .DW        ( 15                 ),
    .AW        ( 10                 ),
    .SYNFILE   ("../../hdl/exp2.hex")
)u_exp(
    .clk0       ( clk               ),
    .clk1       ( clk               ),
    // Port 0
    .data0      ( 15'h0             ),
    .addr0      ( xlog[9:0]         ),
    .we0        ( 1'b0              ),
    .q0         ( xlin              ),
    // Port 1
    .data1      ( 15'h0             ),
    .addr1      ( 10'b0             ),
    .we1        ( 1'b0              ),
    .q1         (                   )
);

jtframe_test_clocks clocks(
    .rst        (               ),
    .clk        ( clk           ),
    .pxl_cen    ( cen           ),
    .lhbl       (               ),
    .lvbl       (               ),
    .v          (               ),  // for faster simulation
    .framecnt   (               )
);

always @* begin
    xzoom=18176; xoff=117; expected=102;
    case(cnt)
        0: begin xzoom=18176; xoff=117; expected=102; end
        1: begin xzoom=18688; xoff=117; expected=106; end
        2: begin xzoom=10496; xoff=117; expected=47; end
        3: begin xzoom=10496; xoff=109; expected=44; end
        4: begin xzoom=12032; xoff=117; expected=58; end
        5: begin xzoom=12032; xoff=109; expected=54; end
        6: begin xzoom=19456; xoff=117; expected=111; end
        7: begin xzoom=19456; xoff=109; expected=103; end
        8: begin xzoom=13568; xoff=117; expected=69; end
        9: begin xzoom=13568; xoff=109; expected=64; end
        10: begin xzoom=14848; xoff=117; expected=78; end
        11: begin xzoom=14848; xoff=109; expected=73; end
        12: begin xzoom=19712; xoff=117; expected=113; end
        13: begin xzoom=19712; xoff=109; expected=105; end
        14: begin xzoom=16128; xoff=117; expected=87; end
        15: begin xzoom=16128; xoff=109; expected=81; end
        16: begin xzoom=17152; xoff=117; expected=95; end
        17: begin xzoom=17152; xoff=109; expected=88; end
        18: begin xzoom=19968; xoff=117; expected=115; end
        19: begin xzoom=19968; xoff=109; expected=107; end
        20: begin xzoom=18176; xoff=109; expected=95; end
        21: begin xzoom=18688; xoff=109; expected=98; end
        22: begin xzoom=6144; xoff=117; expected=16; end
        23: begin xzoom=6144; xoff=109; expected=15; end
        24: begin xzoom=7168; xoff=117; expected=23; end
        25: begin xzoom=7168; xoff=109; expected=22; end
        26: begin xzoom=8960; xoff=117; expected=36; end
        27: begin xzoom=8960; xoff=109; expected=34; end
        28: begin xzoom=10496; xoff=97; expected=39; end
        29: begin xzoom=10496; xoff=93; expected=37; end
        30: begin xzoom=10496; xoff=90; expected=36; end
        31: begin xzoom=10496; xoff=87; expected=35; end
        32: begin xzoom=10496; xoff=85; expected=34; end
        33: begin xzoom=10496; xoff=81; expected=32; end
        34: begin xzoom=10496; xoff=77; expected=31; end
        35: begin xzoom=10496; xoff=72; expected=29; end
        36: begin xzoom=10496; xoff=65; expected=26; end
        37: begin xzoom=10496; xoff=61; expected=24; end
        38: begin xzoom=10496; xoff=49; expected=19; end
        39: begin xzoom=10496; xoff=33; expected=13; end
        40: begin xzoom=12032; xoff=97; expected=48; end
        41: begin xzoom=12032; xoff=93; expected=46; end
        42: begin xzoom=12032; xoff=90; expected=45; end
        43: begin xzoom=12032; xoff=87; expected=43; end
        44: begin xzoom=12032; xoff=85; expected=42; end
        45: begin xzoom=12032; xoff=81; expected=40; end
        46: begin xzoom=12032; xoff=77; expected=38; end
        47: begin xzoom=12032; xoff=72; expected=36; end
        48: begin xzoom=12032; xoff=65; expected=32; end
        49: begin xzoom=12032; xoff=61; expected=30; end
        50: begin xzoom=12032; xoff=49; expected=24; end
        51: begin xzoom=12032; xoff=33; expected=16; end
        52: begin xzoom=13568; xoff=97; expected=57; end
        53: begin xzoom=13568; xoff=93; expected=55; end
        54: begin xzoom=13568; xoff=90; expected=53; end
        55: begin xzoom=13568; xoff=87; expected=51; end
        56: begin xzoom=13568; xoff=85; expected=50; end
        57: begin xzoom=13568; xoff=81; expected=48; end
        58: begin xzoom=13568; xoff=77; expected=45; end
        59: begin xzoom=13568; xoff=72; expected=42; end
        60: begin xzoom=13568; xoff=65; expected=38; end
        61: begin xzoom=13568; xoff=61; expected=36; end
        62: begin xzoom=13568; xoff=49; expected=29; end
        63: begin xzoom=13568; xoff=33; expected=19; end
        64: begin xzoom=13568; xoff=19; expected=11; end
        65: begin xzoom=14848; xoff=97; expected=65; end
        66: begin xzoom=14848; xoff=93; expected=62; end
        67: begin xzoom=14848; xoff=90; expected=60; end
        68: begin xzoom=14848; xoff=87; expected=58; end
        69: begin xzoom=14848; xoff=85; expected=57; end
        70: begin xzoom=14848; xoff=81; expected=54; end
        71: begin xzoom=14848; xoff=77; expected=51; end
        72: begin xzoom=14848; xoff=72; expected=48; end
        73: begin xzoom=14848; xoff=65; expected=43; end
        74: begin xzoom=14848; xoff=61; expected=40; end
        75: begin xzoom=14848; xoff=49; expected=32; end
        76: begin xzoom=14848; xoff=33; expected=22; end
        77: begin xzoom=14848; xoff=19; expected=12; end
        78: begin xzoom=16128; xoff=97; expected=72; end
        79: begin xzoom=16128; xoff=93; expected=69; end
        80: begin xzoom=16128; xoff=90; expected=67; end
        81: begin xzoom=16128; xoff=87; expected=65; end
        82: begin xzoom=16128; xoff=85; expected=63; end
        83: begin xzoom=16128; xoff=81; expected=60; end
        84: begin xzoom=16128; xoff=77; expected=57; end
        85: begin xzoom=16128; xoff=72; expected=54; end
        86: begin xzoom=16128; xoff=65; expected=48; end
        87: begin xzoom=16128; xoff=61; expected=45; end
        88: begin xzoom=16128; xoff=49; expected=36; end
        89: begin xzoom=16128; xoff=33; expected=24; end
        90: begin xzoom=16128; xoff=19; expected=14; end
        91: begin xzoom=17152; xoff=97; expected=78; end
        92: begin xzoom=17152; xoff=93; expected=75; end
        93: begin xzoom=17152; xoff=90; expected=73; end
        94: begin xzoom=17152; xoff=87; expected=70; end
        95: begin xzoom=17152; xoff=85; expected=69; end
        96: begin xzoom=17152; xoff=81; expected=65; end
        97: begin xzoom=17152; xoff=77; expected=62; end
        98: begin xzoom=17152; xoff=72; expected=58; end
        99: begin xzoom=17152; xoff=65; expected=52; end
        100: begin xzoom=17152; xoff=61; expected=49; end
        101: begin xzoom=17152; xoff=49; expected=39; end
        102: begin xzoom=17152; xoff=33; expected=26; end
        103: begin xzoom=17152; xoff=19; expected=15; end
        104: begin xzoom=18176; xoff=97; expected=84; end
        105: begin xzoom=18176; xoff=93; expected=81; end
        106: begin xzoom=18176; xoff=90; expected=78; end
        107: begin xzoom=18176; xoff=87; expected=76; end
        108: begin xzoom=18176; xoff=85; expected=74; end
        109: begin xzoom=18176; xoff=81; expected=70; end
        110: begin xzoom=18176; xoff=77; expected=67; end
        111: begin xzoom=18176; xoff=72; expected=63; end
        112: begin xzoom=18176; xoff=65; expected=56; end
        113: begin xzoom=18176; xoff=61; expected=53; end
        114: begin xzoom=18176; xoff=49; expected=42; end
        115: begin xzoom=18176; xoff=33; expected=28; end
        116: begin xzoom=18176; xoff=19; expected=16; end
        117: begin xzoom=18688; xoff=97; expected=87; end
        118: begin xzoom=18688; xoff=93; expected=84; end
        119: begin xzoom=18688; xoff=90; expected=81; end
        120: begin xzoom=18688; xoff=87; expected=78; end
        121: begin xzoom=18688; xoff=85; expected=77; end
        122: begin xzoom=18688; xoff=81; expected=73; end
        123: begin xzoom=18688; xoff=77; expected=69; end
        124: begin xzoom=18688; xoff=72; expected=65; end
        125: begin xzoom=18688; xoff=65; expected=58; end
        126: begin xzoom=18688; xoff=61; expected=55; end
        127: begin xzoom=18688; xoff=49; expected=44; end
        128: begin xzoom=18688; xoff=33; expected=29; end
        129: begin xzoom=18688; xoff=19; expected=17; end
        130: begin xzoom=6144; xoff=97; expected=13; end
        131: begin xzoom=6144; xoff=93; expected=13; end
        132: begin xzoom=6144; xoff=90; expected=12; end
        133: begin xzoom=6144; xoff=87; expected=12; end
        134: begin xzoom=6144; xoff=85; expected=11; end
        135: begin xzoom=6144; xoff=81; expected=11; end
        136: begin xzoom=6144; xoff=77; expected=10; end
        137: begin xzoom=6144; xoff=72; expected=10; end
        138: begin xzoom=7168; xoff=97; expected=19; end
        139: begin xzoom=7168; xoff=93; expected=18; end
        140: begin xzoom=7168; xoff=90; expected=18; end
        141: begin xzoom=7168; xoff=87; expected=17; end
        142: begin xzoom=7168; xoff=85; expected=17; end
        143: begin xzoom=7168; xoff=81; expected=16; end
        144: begin xzoom=7168; xoff=77; expected=15; end
        145: begin xzoom=7168; xoff=72; expected=14; end
        146: begin xzoom=7168; xoff=65; expected=13; end
        147: begin xzoom=7168; xoff=61; expected=12; end
        148: begin xzoom=8960; xoff=97; expected=30; end
        149: begin xzoom=8960; xoff=93; expected=29; end
        150: begin xzoom=8960; xoff=90; expected=28; end
        151: begin xzoom=8960; xoff=87; expected=27; end
        152: begin xzoom=8960; xoff=85; expected=26; end
        153: begin xzoom=8960; xoff=81; expected=25; end
        154: begin xzoom=8960; xoff=77; expected=24; end
        155: begin xzoom=8960; xoff=72; expected=22; end
        156: begin xzoom=8960; xoff=65; expected=20; end
        157: begin xzoom=8960; xoff=61; expected=19; end
        158: begin xzoom=8960; xoff=49; expected=15; end
        159: begin xzoom=8960; xoff=33; expected=10; end
        160: begin xzoom=10496; xoff=19; expected=7; end
        161: begin xzoom=10496; xoff=10; expected=4; end
        162: begin xzoom=12032; xoff=19; expected=9; end
        163: begin xzoom=12032; xoff=10; expected=5; end
        164: begin xzoom=19456; xoff=97; expected=92; end
        165: begin xzoom=19456; xoff=93; expected=88; end
        166: begin xzoom=19456; xoff=90; expected=85; end
        167: begin xzoom=19456; xoff=87; expected=82; end
        168: begin xzoom=19456; xoff=85; expected=81; end
        169: begin xzoom=19456; xoff=81; expected=77; end
        170: begin xzoom=19456; xoff=77; expected=73; end
        171: begin xzoom=19456; xoff=72; expected=68; end
        172: begin xzoom=19456; xoff=65; expected=61; end
        173: begin xzoom=19456; xoff=61; expected=58; end
        174: begin xzoom=19456; xoff=49; expected=46; end
        175: begin xzoom=19456; xoff=33; expected=31; end
        176: begin xzoom=19456; xoff=19; expected=18; end
        177: begin xzoom=13568; xoff=10; expected=5; end
        178: begin xzoom=14848; xoff=10; expected=6; end
        179: begin xzoom=19712; xoff=97; expected=93; end
        180: begin xzoom=19712; xoff=93; expected=90; end
        181: begin xzoom=19712; xoff=90; expected=87; end
        182: begin xzoom=19712; xoff=87; expected=84; end
        183: begin xzoom=19712; xoff=85; expected=82; end
        184: begin xzoom=19712; xoff=81; expected=78; end
        185: begin xzoom=19712; xoff=77; expected=74; end
        186: begin xzoom=19712; xoff=72; expected=69; end
        187: begin xzoom=19712; xoff=65; expected=62; end
        188: begin xzoom=19712; xoff=61; expected=59; end
        189: begin xzoom=19712; xoff=49; expected=47; end
        190: begin xzoom=19712; xoff=33; expected=31; end
        191: begin xzoom=19712; xoff=19; expected=18; end
        192: begin xzoom=16128; xoff=10; expected=7; end
        193: begin xzoom=17152; xoff=10; expected=8; end
        194: begin xzoom=19968; xoff=97; expected=95; end
        195: begin xzoom=19968; xoff=93; expected=91; end
        196: begin xzoom=19968; xoff=90; expected=88; end
        197: begin xzoom=19968; xoff=87; expected=85; end
        198: begin xzoom=19968; xoff=85; expected=83; end
        199: begin xzoom=19968; xoff=81; expected=79; end
        200: begin xzoom=19968; xoff=77; expected=75; end
        201: begin xzoom=19968; xoff=72; expected=70; end
        202: begin xzoom=19968; xoff=65; expected=63; end
        203: begin xzoom=19968; xoff=61; expected=60; end
        204: begin xzoom=19968; xoff=49; expected=48; end
        205: begin xzoom=19968; xoff=33; expected=32; end
        206: begin xzoom=19968; xoff=19; expected=18; end
        207: begin xzoom=18176; xoff=10; expected=8; end
        208: begin xzoom=18688; xoff=10; expected=9; end
        209: begin xzoom=6144; xoff=65; expected=9; end
        210: begin xzoom=6144; xoff=61; expected=8; end
        211: begin xzoom=6144; xoff=49; expected=6; end
        212: begin xzoom=6144; xoff=33; expected=4; end
        213: begin xzoom=6144; xoff=19; expected=2; end
        214: begin xzoom=6144; xoff=10; expected=1; end
        215: begin xzoom=7168; xoff=49; expected=9; end
        216: begin xzoom=7168; xoff=33; expected=6; end
        217: begin xzoom=7168; xoff=19; expected=3; end
        218: begin xzoom=7168; xoff=10; expected=2; end
        219: begin xzoom=8960; xoff=19; expected=5; end
        220: begin xzoom=8960; xoff=10; expected=3; end
        221: begin xzoom=10496; xoff=9; expected=3; end
        222: begin xzoom=10496; xoff=1; expected=0; end
        223: begin xzoom=11264; xoff=2; expected=0; end
        224: begin xzoom=11264; xoff=0; expected=0; end
        225: begin xzoom=12032; xoff=9; expected=4; end
        226: begin xzoom=12032; xoff=1; expected=0; end
        227: begin xzoom=12064; xoff=2; expected=1; end
        228: begin xzoom=12064; xoff=0; expected=0; end
        229: begin xzoom=19456; xoff=10; expected=9; end
        230: begin xzoom=12864; xoff=2; expected=1; end
        231: begin xzoom=12864; xoff=0; expected=0; end
        232: begin xzoom=13568; xoff=9; expected=5; end
        233: begin xzoom=13568; xoff=1; expected=0; end
        234: begin xzoom=13664; xoff=2; expected=1; end
        235: begin xzoom=13664; xoff=0; expected=0; end
        236: begin xzoom=14464; xoff=2; expected=1; end
        237: begin xzoom=14464; xoff=0; expected=0; end
        238: begin xzoom=14848; xoff=9; expected=6; end
        239: begin xzoom=14848; xoff=1; expected=0; end
        240: begin xzoom=19712; xoff=10; expected=9; end
        241: begin xzoom=15264; xoff=2; expected=1; end
        242: begin xzoom=15264; xoff=0; expected=0; end
        243: begin xzoom=16064; xoff=2; expected=1; end
        244: begin xzoom=16064; xoff=0; expected=0; end
        245: begin xzoom=16128; xoff=9; expected=6; end
        246: begin xzoom=16128; xoff=1; expected=0; end
        247: begin xzoom=16864; xoff=2; expected=1; end
        248: begin xzoom=16864; xoff=0; expected=0; end
        249: begin xzoom=17152; xoff=9; expected=7; end
        250: begin xzoom=17152; xoff=1; expected=0; end
        251: begin xzoom=19968; xoff=10; expected=9; end
        252: begin xzoom=17664; xoff=2; expected=1; end
        253: begin xzoom=17664; xoff=0; expected=0; end
        254: begin xzoom=18176; xoff=9; expected=7; end
        255: begin xzoom=18176; xoff=1; expected=0; end
        256: begin xzoom=18464; xoff=2; expected=1; end
        257: begin xzoom=18464; xoff=0; expected=0; end
        258: begin xzoom=18688; xoff=9; expected=8; end
        259: begin xzoom=18688; xoff=1; expected=0; end
        260: begin xzoom=6144; xoff=9; expected=1; end
        261: begin xzoom=6144; xoff=1; expected=0; end
        262: begin xzoom=7168; xoff=9; expected=1; end
        263: begin xzoom=7168; xoff=1; expected=0; end
        264: begin xzoom=8960; xoff=9; expected=2; end
        265: begin xzoom=8960; xoff=1; expected=0; end
        266: begin xzoom=19264; xoff=2; expected=1; end
        267: begin xzoom=19264; xoff=0; expected=0; end
        268: begin xzoom=19456; xoff=9; expected=8; end
        269: begin xzoom=19456; xoff=1; expected=0; end
        270: begin xzoom=19712; xoff=9; expected=8; end
        271: begin xzoom=19712; xoff=1; expected=0; end
        272: begin xzoom=19968; xoff=9; expected=8; end
        273: begin xzoom=19968; xoff=1; expected=0; end
        274: begin xzoom=0; xoff=117; expected=0; end
        275: begin xzoom=0; xoff=109; expected=0; end
        276: begin xzoom=20064; xoff=2; expected=1; end
        277: begin xzoom=20064; xoff=0; expected=0; end
        278: begin xzoom=10496; xoff=-107; expected=-43; end
        279: begin xzoom=10496; xoff=-15; expected=-6; end
        280: begin xzoom=10496; xoff=-18; expected=-7; end
        281: begin xzoom=10496; xoff=-23; expected=-9; end
        282: begin xzoom=10496; xoff=-31; expected=-12; end
        283: begin xzoom=10496; xoff=-42; expected=-17; end
        284: begin xzoom=10496; xoff=-48; expected=-19; end
        285: begin xzoom=10496; xoff=-50; expected=-20; end
        286: begin xzoom=10496; xoff=-55; expected=-22; end
        287: begin xzoom=10496; xoff=-62; expected=-25; end
        288: begin xzoom=10496; xoff=-63; expected=-25; end
        289: begin xzoom=10496; xoff=-75; expected=-30; end
        290: begin xzoom=10496; xoff=-83; expected=-33; end
        291: begin xzoom=10496; xoff=-85; expected=-34; end
        292: begin xzoom=10496; xoff=-88; expected=-35; end
        293: begin xzoom=10496; xoff=-90; expected=-36; end
        294: begin xzoom=11264; xoff=-1; expected=0; end
        295: begin xzoom=11264; xoff=-6; expected=-2; end
        296: begin xzoom=12032; xoff=-107; expected=-53; end
        297: begin xzoom=12032; xoff=-15; expected=-7; end
        298: begin xzoom=12032; xoff=-18; expected=-9; end
        299: begin xzoom=12032; xoff=-23; expected=-11; end
        300: begin xzoom=12032; xoff=-31; expected=-15; end
        301: begin xzoom=12032; xoff=-42; expected=-21; end
        302: begin xzoom=12032; xoff=-48; expected=-24; end
        303: begin xzoom=12032; xoff=-50; expected=-25; end
        304: begin xzoom=12032; xoff=-55; expected=-27; end
        305: begin xzoom=12032; xoff=-62; expected=-31; end
        306: begin xzoom=12032; xoff=-63; expected=-31; end
        307: begin xzoom=12032; xoff=-75; expected=-37; end
        308: begin xzoom=12032; xoff=-83; expected=-41; end
        309: begin xzoom=12032; xoff=-85; expected=-42; end
        310: begin xzoom=12032; xoff=-88; expected=-44; end
        311: begin xzoom=12032; xoff=-90; expected=-45; end
        312: begin xzoom=12064; xoff=-1; expected=0; end
        313: begin xzoom=12064; xoff=-6; expected=-3; end
        314: begin xzoom=12864; xoff=-1; expected=0; end
        315: begin xzoom=12864; xoff=-6; expected=-3; end
        316: begin xzoom=13568; xoff=-107; expected=-63; end
        317: begin xzoom=13568; xoff=-15; expected=-8; end
        318: begin xzoom=13568; xoff=-18; expected=-10; end
        319: begin xzoom=13568; xoff=-23; expected=-13; end
        320: begin xzoom=13568; xoff=-31; expected=-18; end
        321: begin xzoom=13568; xoff=-42; expected=-24; end
        322: begin xzoom=13568; xoff=-48; expected=-28; end
        323: begin xzoom=13568; xoff=-50; expected=-29; end
        324: begin xzoom=13568; xoff=-55; expected=-32; end
        325: begin xzoom=13568; xoff=-62; expected=-36; end
        326: begin xzoom=13568; xoff=-63; expected=-37; end
        327: begin xzoom=13568; xoff=-75; expected=-44; end
        328: begin xzoom=13568; xoff=-83; expected=-49; end
        329: begin xzoom=13568; xoff=-85; expected=-50; end
        330: begin xzoom=13568; xoff=-88; expected=-52; end
        331: begin xzoom=13568; xoff=-90; expected=-53; end
        332: begin xzoom=13664; xoff=-1; expected=0; end
        333: begin xzoom=13664; xoff=-6; expected=-3; end
        334: begin xzoom=14464; xoff=-1; expected=0; end
        335: begin xzoom=14464; xoff=-6; expected=-3; end
        336: begin xzoom=14848; xoff=-107; expected=-71; end
        337: begin xzoom=14848; xoff=-15; expected=-10; end
        338: begin xzoom=14848; xoff=-18; expected=-12; end
        339: begin xzoom=14848; xoff=-23; expected=-15; end
        340: begin xzoom=14848; xoff=-31; expected=-20; end
        341: begin xzoom=14848; xoff=-42; expected=-28; end
        342: begin xzoom=14848; xoff=-48; expected=-32; end
        343: begin xzoom=14848; xoff=-50; expected=-33; end
        344: begin xzoom=14848; xoff=-55; expected=-36; end
        345: begin xzoom=14848; xoff=-62; expected=-41; end
        346: begin xzoom=14848; xoff=-63; expected=-42; end
        347: begin xzoom=14848; xoff=-75; expected=-50; end
        348: begin xzoom=14848; xoff=-83; expected=-55; end
        349: begin xzoom=14848; xoff=-85; expected=-57; end
        350: begin xzoom=14848; xoff=-88; expected=-59; end
        351: begin xzoom=14848; xoff=-90; expected=-60; end
        352: begin xzoom=15264; xoff=-1; expected=0; end
        353: begin xzoom=15264; xoff=-6; expected=-4; end
        354: begin xzoom=16064; xoff=-1; expected=0; end
        355: begin xzoom=16064; xoff=-6; expected=-4; end
        356: begin xzoom=16128; xoff=-107; expected=-80; end
        357: begin xzoom=16128; xoff=-15; expected=-11; end
        358: begin xzoom=16128; xoff=-18; expected=-13; end
        359: begin xzoom=16128; xoff=-23; expected=-17; end
        360: begin xzoom=16128; xoff=-31; expected=-23; end
        361: begin xzoom=16128; xoff=-42; expected=-31; end
        362: begin xzoom=16128; xoff=-48; expected=-36; end
        363: begin xzoom=16128; xoff=-50; expected=-37; end
        364: begin xzoom=16128; xoff=-55; expected=-41; end
        365: begin xzoom=16128; xoff=-62; expected=-46; end
        366: begin xzoom=16128; xoff=-63; expected=-47; end
        367: begin xzoom=16128; xoff=-75; expected=-56; end
        368: begin xzoom=16128; xoff=-83; expected=-62; end
        369: begin xzoom=16128; xoff=-85; expected=-63; end
        370: begin xzoom=16128; xoff=-88; expected=-66; end
        371: begin xzoom=16128; xoff=-90; expected=-67; end
        372: begin xzoom=16864; xoff=-1; expected=0; end
        373: begin xzoom=16864; xoff=-6; expected=-4; end
        374: begin xzoom=17152; xoff=-107; expected=-86; end
        375: begin xzoom=17152; xoff=-15; expected=-12; end
        376: begin xzoom=17152; xoff=-18; expected=-14; end
        377: begin xzoom=17152; xoff=-23; expected=-18; end
        378: begin xzoom=17152; xoff=-31; expected=-25; end
        379: begin xzoom=17152; xoff=-42; expected=-34; end
        380: begin xzoom=17152; xoff=-48; expected=-39; end
        381: begin xzoom=17152; xoff=-50; expected=-40; end
        382: begin xzoom=17152; xoff=-55; expected=-44; end
        383: begin xzoom=17152; xoff=-62; expected=-50; end
        384: begin xzoom=17152; xoff=-63; expected=-51; end
        385: begin xzoom=17152; xoff=-75; expected=-60; end
        386: begin xzoom=17152; xoff=-83; expected=-67; end
        387: begin xzoom=17152; xoff=-85; expected=-69; end
        388: begin xzoom=17152; xoff=-88; expected=-71; end
        389: begin xzoom=17152; xoff=-90; expected=-73; end
        390: begin xzoom=17664; xoff=-1; expected=0; end
        391: begin xzoom=17664; xoff=-6; expected=-5; end
        392: begin xzoom=18176; xoff=-107; expected=-93; end
        393: begin xzoom=18176; xoff=-15; expected=-13; end
        394: begin xzoom=18176; xoff=-18; expected=-15; end
        395: begin xzoom=18176; xoff=-23; expected=-20; end
        396: begin xzoom=18176; xoff=-31; expected=-27; end
        397: begin xzoom=18176; xoff=-42; expected=-36; end
        398: begin xzoom=18176; xoff=-48; expected=-42; end
        399: begin xzoom=18176; xoff=-50; expected=-43; end
        400: begin xzoom=18176; xoff=-55; expected=-48; end
        401: begin xzoom=18176; xoff=-62; expected=-54; end
        402: begin xzoom=18176; xoff=-63; expected=-55; end
        403: begin xzoom=18176; xoff=-75; expected=-65; end
        404: begin xzoom=18176; xoff=-83; expected=-72; end
        405: begin xzoom=18176; xoff=-85; expected=-74; end
        406: begin xzoom=18176; xoff=-88; expected=-77; end
        407: begin xzoom=18176; xoff=-90; expected=-78; end
        408: begin xzoom=0; xoff=97; expected=0; end
        409: begin xzoom=0; xoff=93; expected=0; end
        410: begin xzoom=0; xoff=90; expected=0; end
        411: begin xzoom=0; xoff=87; expected=0; end
        412: begin xzoom=0; xoff=85; expected=0; end
        413: begin xzoom=0; xoff=81; expected=0; end
        414: begin xzoom=0; xoff=77; expected=0; end
        415: begin xzoom=0; xoff=72; expected=0; end
        416: begin xzoom=0; xoff=65; expected=0; end
        417: begin xzoom=0; xoff=61; expected=0; end
        418: begin xzoom=0; xoff=49; expected=0; end
        419: begin xzoom=0; xoff=33; expected=0; end
        420: begin xzoom=0; xoff=19; expected=0; end
        421: begin xzoom=0; xoff=10; expected=0; end
        422: begin xzoom=18464; xoff=-1; expected=0; end
        423: begin xzoom=18464; xoff=-6; expected=-5; end
        424: begin xzoom=18688; xoff=-107; expected=-96; end
        425: begin xzoom=18688; xoff=-15; expected=-13; end
        426: begin xzoom=18688; xoff=-18; expected=-16; end
        427: begin xzoom=18688; xoff=-23; expected=-20; end
        428: begin xzoom=18688; xoff=-31; expected=-28; end
        429: begin xzoom=18688; xoff=-42; expected=-38; end
        430: begin xzoom=18688; xoff=-48; expected=-43; end
        431: begin xzoom=18688; xoff=-50; expected=-45; end
        432: begin xzoom=18688; xoff=-55; expected=-49; end
        433: begin xzoom=18688; xoff=-62; expected=-56; end
        434: begin xzoom=18688; xoff=-63; expected=-57; end
        435: begin xzoom=18688; xoff=-75; expected=-67; end
        436: begin xzoom=18688; xoff=-83; expected=-75; end
        437: begin xzoom=18688; xoff=-85; expected=-77; end
        438: begin xzoom=18688; xoff=-88; expected=-79; end
        439: begin xzoom=18688; xoff=-90; expected=-81; end
        440: begin xzoom=6144; xoff=-107; expected=-15; end
        441: begin xzoom=6144; xoff=-15; expected=-2; end
        442: begin xzoom=6144; xoff=-18; expected=-2; end
        443: begin xzoom=6144; xoff=-23; expected=-3; end
        444: begin xzoom=6144; xoff=-31; expected=-4; end
        445: begin xzoom=6144; xoff=-42; expected=-5; end
        446: begin xzoom=6144; xoff=-48; expected=-6; end
        447: begin xzoom=6144; xoff=-50; expected=-7; end
        448: begin xzoom=6144; xoff=-55; expected=-7; end
        449: begin xzoom=6144; xoff=-62; expected=-8; end
        450: begin xzoom=6144; xoff=-63; expected=-8; end
        451: begin xzoom=6144; xoff=-75; expected=-10; end
        452: begin xzoom=6144; xoff=-83; expected=-11; end
        453: begin xzoom=6144; xoff=-85; expected=-11; end
        454: begin xzoom=6144; xoff=-88; expected=-12; end
        455: begin xzoom=6144; xoff=-90; expected=-12; end
        456: begin xzoom=7168; xoff=-107; expected=-21; end
        457: begin xzoom=7168; xoff=-15; expected=-3; end
        458: begin xzoom=7168; xoff=-18; expected=-3; end
        459: begin xzoom=7168; xoff=-23; expected=-4; end
        460: begin xzoom=7168; xoff=-31; expected=-6; end
        461: begin xzoom=7168; xoff=-42; expected=-8; end
        462: begin xzoom=7168; xoff=-48; expected=-9; end
        463: begin xzoom=7168; xoff=-50; expected=-10; end
        464: begin xzoom=7168; xoff=-55; expected=-11; end
        465: begin xzoom=7168; xoff=-62; expected=-12; end
        466: begin xzoom=7168; xoff=-63; expected=-12; end
        467: begin xzoom=7168; xoff=-75; expected=-15; end
        468: begin xzoom=7168; xoff=-83; expected=-16; end
        469: begin xzoom=7168; xoff=-85; expected=-17; end
        470: begin xzoom=7168; xoff=-88; expected=-17; end
        471: begin xzoom=7168; xoff=-90; expected=-18; end
        472: begin xzoom=8960; xoff=-107; expected=-33; end
        473: begin xzoom=8960; xoff=-15; expected=-4; end
        474: begin xzoom=8960; xoff=-18; expected=-5; end
        475: begin xzoom=8960; xoff=-23; expected=-7; end
        476: begin xzoom=8960; xoff=-31; expected=-9; end
        477: begin xzoom=8960; xoff=-42; expected=-13; end
        478: begin xzoom=8960; xoff=-48; expected=-15; end
        479: begin xzoom=8960; xoff=-50; expected=-15; end
        480: begin xzoom=8960; xoff=-55; expected=-17; end
        481: begin xzoom=8960; xoff=-62; expected=-19; end
        482: begin xzoom=8960; xoff=-63; expected=-19; end
        483: begin xzoom=8960; xoff=-75; expected=-23; end
        484: begin xzoom=8960; xoff=-83; expected=-25; end
        485: begin xzoom=8960; xoff=-85; expected=-26; end
        486: begin xzoom=8960; xoff=-88; expected=-27; end
        487: begin xzoom=8960; xoff=-90; expected=-28; end
        488: begin xzoom=19264; xoff=-1; expected=0; end
        489: begin xzoom=19264; xoff=-6; expected=-5; end
        490: begin xzoom=19456; xoff=-107; expected=-101; end
        491: begin xzoom=19456; xoff=-15; expected=-14; end
        492: begin xzoom=19456; xoff=-18; expected=-17; end
        493: begin xzoom=19456; xoff=-23; expected=-21; end
        494: begin xzoom=19456; xoff=-31; expected=-29; end
        495: begin xzoom=19456; xoff=-42; expected=-40; end
        496: begin xzoom=19456; xoff=-48; expected=-45; end
        497: begin xzoom=19456; xoff=-50; expected=-47; end
        498: begin xzoom=19456; xoff=-55; expected=-52; end
        499: begin xzoom=19456; xoff=-62; expected=-59; end
        500: begin xzoom=19456; xoff=-63; expected=-60; end
        501: begin xzoom=19456; xoff=-75; expected=-71; end
        502: begin xzoom=19456; xoff=-83; expected=-79; end
        503: begin xzoom=19456; xoff=-85; expected=-81; end
        504: begin xzoom=19456; xoff=-88; expected=-83; end
        505: begin xzoom=19456; xoff=-90; expected=-85; end
        506: begin xzoom=19712; xoff=-107; expected=-103; end
        507: begin xzoom=19712; xoff=-15; expected=-14; end
        508: begin xzoom=19712; xoff=-18; expected=-17; end
        509: begin xzoom=19712; xoff=-23; expected=-22; end
        510: begin xzoom=19712; xoff=-31; expected=-30; end
        511: begin xzoom=19712; xoff=-42; expected=-40; end
        512: begin xzoom=19712; xoff=-48; expected=-46; end
        513: begin xzoom=19712; xoff=-50; expected=-48; end
        514: begin xzoom=19712; xoff=-55; expected=-53; end
        515: begin xzoom=19712; xoff=-62; expected=-60; end
        516: begin xzoom=19712; xoff=-63; expected=-61; end
        517: begin xzoom=19712; xoff=-75; expected=-72; end
        518: begin xzoom=19712; xoff=-83; expected=-80; end
        519: begin xzoom=19712; xoff=-85; expected=-82; end
        520: begin xzoom=19712; xoff=-88; expected=-85; end
        521: begin xzoom=19712; xoff=-90; expected=-87; end
        522: begin xzoom=19968; xoff=-107; expected=-105; end
        523: begin xzoom=19968; xoff=-15; expected=-14; end
        524: begin xzoom=19968; xoff=-18; expected=-17; end
        525: begin xzoom=19968; xoff=-23; expected=-22; end
        526: begin xzoom=19968; xoff=-31; expected=-30; end
        527: begin xzoom=19968; xoff=-42; expected=-41; end
        528: begin xzoom=19968; xoff=-48; expected=-47; end
        529: begin xzoom=19968; xoff=-50; expected=-49; end
        530: begin xzoom=19968; xoff=-55; expected=-54; end
        531: begin xzoom=19968; xoff=-62; expected=-61; end
        532: begin xzoom=19968; xoff=-63; expected=-62; end
        533: begin xzoom=19968; xoff=-75; expected=-73; end
        534: begin xzoom=19968; xoff=-83; expected=-81; end
        535: begin xzoom=19968; xoff=-85; expected=-83; end
        536: begin xzoom=19968; xoff=-88; expected=-86; end
        537: begin xzoom=19968; xoff=-90; expected=-88; end
        538: begin xzoom=0; xoff=9; expected=0; end
        539: begin xzoom=0; xoff=1; expected=0; end
        540: begin xzoom=20064; xoff=-1; expected=0; end
        541: begin xzoom=20064; xoff=-6; expected=-5; end
        542: begin xzoom=0; xoff=-107; expected=0; end
        543: begin xzoom=0; xoff=-15; expected=0; end
        544: begin xzoom=0; xoff=-18; expected=0; end
        545: begin xzoom=0; xoff=-23; expected=0; end
        546: begin xzoom=0; xoff=-31; expected=0; end
        547: begin xzoom=0; xoff=-42; expected=0; end
        548: begin xzoom=0; xoff=-48; expected=0; end
        549: begin xzoom=0; xoff=-50; expected=0; end
        550: begin xzoom=0; xoff=-55; expected=0; end
        551: begin xzoom=0; xoff=-62; expected=0; end
        552: begin xzoom=0; xoff=-63; expected=0; end
        553: begin xzoom=0; xoff=-75; expected=0; end
        554: begin xzoom=0; xoff=-83; expected=0; end
        555: begin xzoom=0; xoff=-85; expected=0; end
        556: begin xzoom=0; xoff=-88; expected=0; end
        557: begin xzoom=0; xoff=-90; expected=0; end
    endcase
end

endmodule
