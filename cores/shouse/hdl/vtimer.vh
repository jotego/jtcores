localparam [8:0]
    V_START  = 9'h100,
    VCNT_END = 9'h007,
    VB_START = 9'h000,
    VB_END   = 9'h120,
    VS_START = 9'h108,
    VS_END   = 9'h110,
    HS_START = 9'h177,
    HS_END   = 9'h017,
    HB_START = 9'h160, // 288 visible, 384 total (96 pxl=HB)
    HB_END   = 9'h040;