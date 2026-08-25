`timescale 1ns/1ps

module test;

reg         rst=0, clk=0, pxl_cen=0, hs=0, vs=0, dtackn=1, cs=0;
reg  [15:0] din=0, line_dout=0;
reg  [ 4:1] addr=0;
reg  [ 1:0] dsn=2'b11;
reg         blankn=1, rom_ok=0;
reg  [23:0] vram_dout=0;
reg  [ 7:0] rom_data=0;
reg  [ 3:0] gfx_en=4'hf;
reg  [ 4:0] ioctl_addr=0;
wire [10:1] line_addr;
wire [13:0] vram_addr;
wire [20:0] rom_addr;
wire        dma_n, rom_cs;
wire [ 7:0] pxl, ioctl_din;

always #5 clk = ~clk;

jtrungun_psac uut(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .hs         ( hs        ),
    .vs         ( vs        ),
    .dtackn     ( dtackn    ),
    .cs         ( cs        ),
    .din        ( din       ),
    .addr       ( addr      ),
    .dsn        ( dsn       ),
    .blankn     ( blankn    ),
    .dma_n      ( dma_n     ),
    .line_addr  ( line_addr ),
    .line_dout  ( line_dout ),
    .vram_addr  ( vram_addr ),
    .vram_dout  ( vram_dout ),
    .rom_addr   ( rom_addr  ),
    .rom_data   ( rom_data  ),
    .rom_cs     ( rom_cs    ),
    .rom_ok     ( rom_ok    ),
    .pxl        ( pxl       ),
    .gfx_en     ( gfx_en    ),
    .ioctl_addr ( ioctl_addr),
    .ioctl_din  ( ioctl_din )
);

initial begin
    // Isolate the ROM handoff from the coordinate generator.  A registered
    // pxl output would retain its prior value until the next pxl_cen edge.
    force uut.ob      = 1'b0;
    force uut.pre_pxl = 8'ha5;
    #1;
    if(pxl !== 8'h00) begin
        $display("FAIL: invalid ROM response produced %h",pxl);
        $finish;
    end
    rom_ok = 1;
    #1;
    if(pxl !== 8'ha5) begin
        $display("FAIL: accepted ROM pixel was delayed (%h)",pxl);
        $finish;
    end
    force uut.ob = 1'b1;
    #1;
    if(pxl !== 8'h00) begin
        $display("FAIL: out-of-bounds pixel was not transparent (%h)",pxl);
        $finish;
    end
    $display("PASS");
    $finish;
end

endmodule
