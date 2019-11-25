`timescale 1ns/1ps

module rom_test;

    reg clk;
    reg rst;
    reg  [12:0] char_addr;
    reg  [17:0] main_addr;
    reg  [14:0] snd_addr;
    reg  [14:0] obj_addr;
    reg  [14:0] scr_addr;

    wire [15:0] char_dout;
    wire [ 7:0] main_dout;
    wire [ 7:0] snd_dout;
    wire [15:0] obj_dout;
    wire [23:0] scr_dout;

initial begin
    clk = 1'b0;
    forever #5.2 clk=~clk;
end

reg [7:0] cen_cnt;
always @(posedge clk)
    if(rst) cen_cnt <= 8'd0;
    else cen_cnt <= cen_cnt+1'd1;

reg cen6,cen3,cen1p5,cen0p7;

always @(negedge clk) begin
    cen6   <= &cen_cnt[3:0];
    cen3   <= &cen_cnt[4:0];
    cen1p5 <= &cen_cnt[5:0];
    cen0p7 <= &cen_cnt[6:0];
end

initial begin
    rst = 1'b0;
    scr_addr   = 4;
    #10 rst=1'b1;
    #100 rst=1'b0;
end

reg addr_rst;
initial begin
    addr_rst = 1'b1;
    #104_000 addr_rst=1'b0;
end

always @(posedge clk)
    if(addr_rst)
        snd_addr   <= 0;
    else if(cen3)
        snd_addr   <= snd_addr  + 1'b1;

always @(posedge clk)
    if(addr_rst)
        main_addr  <= 0;
    else if(cen1p5)
        main_addr  <= main_addr + 1'b1;

always @(posedge clk)
    if(addr_rst) begin
        char_addr  <= 0;
        obj_addr   <= 0;
    end else if(cen0p7) begin
        char_addr  <= char_addr + 1'b1;
        obj_addr   <= obj_addr  + 1'b1;
    end

initial begin
    $display("DUMP ON");
    $dumpfile("test.lxt");
    $dumpvars;
    $dumpon;
end

initial #(110*1000) $finish;

// SDRAM interface
wire [15:0] SDRAM_DQ;       // SDRAM Data bus 16 Bits
wire [12:0] SDRAM_A;        // SDRAM Address bus 13 Bits
wire        SDRAM_DQML;     // SDRAM Low-byte Data Mask
wire        SDRAM_DQMH;     // SDRAM High-byte Data Mask
wire        SDRAM_nWE;      // SDRAM Write Enable
wire        SDRAM_nCAS;     // SDRAM Column Address Strobe
wire        SDRAM_nRAS;     // SDRAM Row Address Strobe
wire        SDRAM_nCS;      // SDRAM Chip Select
wire  [1:0] SDRAM_BA;       // SDRAM Bank Address
wire        SDRAM_CKE;      // SDRAM Clock Enable

jtgng_rom uut (
    .clk        (clk      ),
    .rst        (rst      ),
    .char_addr  (char_addr),
    .main_addr  (main_addr),
    .snd_addr   (snd_addr ),
    .obj_addr   (obj_addr ),
    .scr_addr   (scr_addr ),
    .char_dout  (char_dout),
    .main_dout  (main_dout),
    .snd_dout   (snd_dout ),
    .obj_dout   (obj_dout ),
    .scr_dout   (scr_dout ),
    .downloading(    1'b0 ),
    // SDRAM interface
    .SDRAM_DQ   ( SDRAM_DQ   ),   // SDRAM Data bus 16 Bits
    .SDRAM_A    ( SDRAM_A    ),   // SDRAM Address bus 13 Bits
    .SDRAM_DQML ( SDRAM_DQML ),   // SDRAM Low-byte Data Mask
    .SDRAM_DQMH ( SDRAM_DQMH ),   // SDRAM High-byte Data Mask
    .SDRAM_nWE  ( SDRAM_nWE  ),   // SDRAM Write Enable
    .SDRAM_nCAS ( SDRAM_nCAS ),   // SDRAM Column Address Strobe
    .SDRAM_nRAS ( SDRAM_nRAS ),   // SDRAM Row Address Strobe
    .SDRAM_nCS  ( SDRAM_nCS  ),   // SDRAM Chip Select
    .SDRAM_BA   ( SDRAM_BA   ),   // SDRAM Bank Address
    .SDRAM_CKE  ( SDRAM_CKE  )    // SDRAM Clock Enable
);

wire [1:0] Dqm = { SDRAM_DQMH, SDRAM_DQML };

mt48lc16m16a2 SDRAM(
    .Dq     ( SDRAM_DQ   ),
    .Addr   ( SDRAM_A    ),
    .Ba     ( SDRAM_BA   ),
    .Clk    ( clk        ),
    .Cke    ( SDRAM_CKE  ),
    .Cs_n   ( SDRAM_nCS  ),
    .Ras_n  ( SDRAM_nRAS ),
    .Cas_n  ( SDRAM_nCAS ),
    .We_n   ( SDRAM_nWE  ),
    .Dqm    ( Dqm        )
);

endmodule