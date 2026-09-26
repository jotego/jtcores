localparam [8:0]
    V_START  = 9'h100,
    VCNT_END = 9'h007,
    VB_START = 9'h1EF,
    VB_END   = 9'h10F,
    VS_START = 9'h006,
    VS_END   = 9'h101,
    HS_START = 9'h177,
    HS_END   = 9'h017,
    HB_START = 9'h162, // 288 visible, 384 total (96 pxl=HB)
    HB_END   = 9'h042;