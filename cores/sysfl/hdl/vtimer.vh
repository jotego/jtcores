// 288x224 in 384x264: H porches 8/24/64, V porches 3/4/33 (PCB timing)
localparam [8:0]
    V_START  = 9'h0F8,
    VB_START = 9'h0F8,
    VB_END   = 9'h120,
    VS_START = 9'h0FB, // 3 lines after blank start
    VS_END   = 9'h0FF, // 4-line sync, 33-line back porch
    VCNT_END = 9'h1FF,
    HS_START = 9'h168, // 8 pxl after blank start
    HS_END   = 9'h000, // 24 pxl sync, 64 pxl back porch
    HB_START = 9'h160, // 288 visible, 384 total (96 pxl=HB)
    HB_END   = 9'h040;
