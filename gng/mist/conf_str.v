// Ghosts'n Goblins MiST/er

`ifdef MISTER
`define SEPARATOR "-;",
`define RESET "R0,RST;",
`else 
`define SEPARATOR
`define RESET "T0,RST;",
`endif

localparam CONF_STR = {
    "JTGNG;;", // Remember to change the core name when you copy the file
    "O1,Pause,OFF,ON;",
    `SEPARATOR
    "F,rom;",
    `ifdef MISTER
    "O2,Aspect Ratio,Original,Wide;",
    "O5,Orientation,Vert,Horz;",
    "O34,Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%,CRT 75%;",
    `else
    "O9,Screen filter,ON,OFF;",
    `endif
    "O6,Test mode,OFF,ON;",
    "O7,PSG,ON,OFF;",
    "O8,FM ,ON,OFF;",
    "OAB,FX volume, high, very high, very low, low;",
    // "OC,Flip screen,OFF,ON;",
    `SEPARATOR
    "OGH,Difficulty,normal,easy,hard,very hard;",
    "OIJ,Lives,3,4,5,7;",
    `RESET
    "V,http://patreon.com/topapate;"
};

`undef SEPARATOR
`undef RESET