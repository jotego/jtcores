`timescale 1ns/1ps

module test;

reg         rst, clk, start, vram_ok, rom_ok=1'b1;
reg  [ 7:0] v;

reg  [15:0] vram_data;
wire [15:0] hpos, vpos, vram_base;
reg  [31:0] rom_data;
wire        done, vram_cs, rom_cs, buf_wr, rom_half;
wire [22:0] rom_addr;
reg  [22:0] last_rom;
wire [23:1] vram_addr;
reg  [23:0] last_vram;
wire [ 8:0] buf_addr;
wire [ 8:0] buf_data;
reg  [15:0] vram[0:98303]; // a bit less than 17 bits
reg  [16:0] vram_dec;
wire [ 2:0] buf_cs;
wire [ 4:1] gfx_cen;
reg  [63:0] gfx_rom[0:393218]; // 19 bits
reg  [ 7:0] frame_buffer[0:131071];

assign      buf_cs[0] = vram_addr[23:16] == 8'b1001_0000;
assign      buf_cs[1] = vram_addr[23:16] == 8'b1001_0001;
assign      buf_cs[2] = vram_addr[23:16] == 8'b1001_0010;

//`define SNAP1
`define SNAPVIDEO32

`ifdef SNAP0
assign      hpos = 16'hffc0;
assign      vpos = 16'h0;
assign      vram_base=16'h9000;
localparam  SIZE=8;
`endif

`ifdef SNAP1
assign      hpos = 16'h3c0; // 960
assign      vpos = 16'h100;
assign      vram_base=16'h9040;
localparam  SIZE=16;
`endif

`ifdef SNAP2
assign      hpos = 16'h7c0;
assign      vpos = 16'h700;
assign      vram_base=16'h9080;
localparam  SIZE=32;
`endif

`ifdef SNAPVIDEO8
assign      hpos = 16'hffc0;
assign      vpos = 16'h00;
assign      vram_base=16'h9000;
localparam  SIZE=8;
assign gfx_cen=1;
`endif

`ifdef SNAPVIDEO32
assign      hpos = 16'h07c0;
assign      vpos = 16'h0700;
assign      vram_base=16'h9080;
localparam  SIZE=32;
assign gfx_cen=4;
`endif
//    .hpos1      ( 16'hffc0      ),
//    .vpos1      ( 16'h0000      ),
//    .hpos2      ( 16'h03c0      ),
//    .vpos2      ( 16'h0300      ),
//    .hpos3      ( 16'h07c0      ),
//    .vpos3      ( 16'h0700      ),
//    .vram1_base ( 16'h9000      ),
//    .vram2_base ( 16'h9040      ),
//    .vram3_base ( 16'h9080      ),


always @(*) begin
    //case( buf_cs )
    //    3'b001: vram_dec[16:15] = 2'b00;
    //    3'b010: vram_dec[16:15] = 2'b01;
    //    3'b100: vram_dec[16:15] = 2'b10;
    //endcase    
    vram_dec[16:15] = vram_addr[17:16]; // no need for the PAL
    vram_dec[14:0] = vram_addr[15:1];
end


// GFX ROM
reg  [19:0] gfx_addr;
reg  [63:0] gfx_long;

always @(rom_addr) begin // using * here breaks iverilog
    if( !gfx_cen[2]) begin
        gfx_addr = rom_addr[19:0];
    end else begin
        gfx_addr = rom_addr[17:0] + 20'h4_0000;
    end
    gfx_long = gfx_rom[ gfx_addr ];
end

always @(posedge clk) begin
    last_rom <= rom_addr;
    //rom_data <= !gfx_cen[1] ? ~32'd0 : (rom_addr[0] ? gfx_long[63:32] : gfx_long[31:0]);
    if( |gfx_cen )
        rom_data <= rom_half ? gfx_long[63:32] : gfx_long[31:0];
    else
        rom_data <= ~32'd0;
    rom_ok   <= last_rom == rom_addr;
end

initial begin
    $readmemh( "gfx.hex", gfx_rom );
end

jtcps1_tilemap #(.SIZE(SIZE)) UUT(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .v          ( v             ),
    .vram_base  ( vram_base     ),
    .hpos       ( hpos          ),
    .vpos       ( vpos          ),
    .start      ( start         ),
    .done       ( done          ),
    .vram_addr  ( vram_addr     ),
    .vram_data  ( vram_data     ),
    .vram_ok    ( vram_ok       ),
    .vram_cs    ( vram_cs       ),
    .rom_addr   ( rom_addr      ),
    .rom_data   ( rom_data      ),
    .rom_cs     ( rom_cs        ),
    .rom_ok     ( rom_ok        ),
    .rom_half   ( rom_half      ),
    .buf_addr   ( buf_addr      ),
    .buf_data   ( buf_data      ),
    .buf_wr     ( buf_wr        )
);

//jtcps1_gfx_pal u_palb(
//    .scr1 ( rom_addr[22:10] ),
//    .bank1( gfx_cen         )
//);

initial begin
    rst = 1'b0;
    #20 rst = 1'b1;
    #400 rst = 1'b0;
end

initial begin
    clk = 1'b0;
    forever #10.417 clk = ~clk;
end

initial begin
    $readmemh("vram.hex",vram);
    $display("INFO: VRAM loaded");
end

integer pxlcnt, framecnt;

integer dumpcnt, fout;

always @(posedge clk, posedge rst) begin
    if(rst) begin
        pxlcnt <= 0;
        framecnt <= 0;
        v <= 8'd0;
        vram_data <= 16'd0;
        vram_ok   <= 1'b0;
        start     <= 1'b1;
    end else begin
        start <= 1'b0;
        last_vram <= vram_addr;
        vram_ok   <= last_vram == vram_addr;
        vram_data <= |buf_cs ?  vram[ vram_dec ] : ~16'h0;
        pxlcnt <= pxlcnt+1;
        if(pxlcnt==3124) begin
            pxlcnt <= 0;
            v     <= v+1;
            start <= 1;
            if(&v) begin
                framecnt <= framecnt+1;
                $display("FRAME");
            end
        end
        if ( framecnt==2 ) begin
            fout=$fopen("video.raw","wb");
            for( dumpcnt=0; dumpcnt<512*256; dumpcnt=dumpcnt+1 ) begin
                $fwrite(fout,"%u", { 8'hff, {3{frame_buffer[dumpcnt]}} });
            end
            $finish;
        end
    end
end

// frame buffer
always @(posedge clk) begin
    if( buf_wr ) begin
        frame_buffer[ { v, buf_addr } ] <= ~{2{buf_data[3:0]}};
    end
end

`ifndef NCVERILOG
    initial begin
        $dumpfile("test.lxt");
        $dumpvars(0,test);
        $dumpon;
    end
`else
    initial begin
        $shm_open("test.shm");
        $shm_probe(test,"AS");
    end
`endif

endmodule
