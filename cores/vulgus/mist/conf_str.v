// Vulgus MiST/er

// 11111111112222222222
// 01234567890123456789
// ABCDEFGHIJKLMNOPQRST

`ifdef VULGUS
`define CORE_OSD \
    "OIJ,Lives,3,1,2,5;", \
    "OGH,Bonus,20/60,10/50,10/60,10/70,20/70,20/80,30/70,None;", \
    "OK,Demo sound,OFF,ON;", \
    "OL,Demo music,OFF,ON;", 
`else
// 1942
`define CORE_OSD \
    "OIJ,Lives,2,1,3,5;", \
    "OGH,Bonus,30/100,30/80,20/100,20/80;", \
    "OKL,Difficulty,Normal,Easy,Hard,Very hard;",
`endif

`define CORE_KEYMAP \
    "J1,Fire,Special,1P Start,2P Start,Coin,Credits;", \
    "jn,A,B,R,L,X,Start;",

