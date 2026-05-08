module test;

`include "test_tasks.vh"

localparam [3:1] OBJ_PRIO = 3'b010;

reg         rst;
reg         clk;
reg         LVBL;
reg         pxl_cen;
reg         objcfg_cs;
reg  [15:0] cpu_dout;
reg  [15:0] layer_ctrl;
reg  [ 1:0] dsn;
reg  [ 3:1] addr;
reg  [11:0] scr_pxl;
reg  [11:0] obj_pxl;
reg         obj_en;
wire [11:0] pxl;

initial begin
    clk = 0;
    forever #5 clk = ~clk;
end

task tick;
begin
    @(posedge clk);
end
endtask

task latch_prio(input [15:0] value);
begin
    objcfg_cs = 1;
    cpu_dout  = value;
    dsn       = 2'b11;
    addr      = OBJ_PRIO;
    tick();
    objcfg_cs = 0;
    LVBL      = 1;
    tick();
    LVBL      = 0;
    tick();
end
endtask

task expect_pxl(input [11:0] exp, input [255:0] msg);
begin
    tick();
    #1;
    assert_msg(pxl == exp, msg);
end
endtask

initial begin
    rst       = 1;
    LVBL      = 1;
    pxl_cen   = 1;
    objcfg_cs = 0;
    cpu_dout  = 0;
    layer_ctrl= 0;
    dsn       = 0;
    addr      = 0;
    scr_pxl   = 12'hfff;
    obj_pxl   = 12'h00f;
    obj_en    = 0;

    repeat(2) tick();
    rst = 0;

    // Priority order: layer 1 -> 1, layer 2 -> 2, layer 3 -> 4, layer 4 -> 6.
    latch_prio(16'h6421);

    // Transparent scroll pixels must still block priority-0 sprites.
    obj_en  = 1;
    scr_pxl = 12'hfff;
    obj_pxl = {3'd0, 9'h080};
    expect_pxl(12'hfff, "priority-0 sprite must stay hidden on transparent background");

    // Priority-1 sprite becomes visible over a transparent background.
    obj_pxl = {3'd1, 9'h080};
    expect_pxl(12'h080, "priority-1 sprite must be visible over transparent background");

    // Non-transparent layer 3 pixel with priority 6 still hides priority-6 sprites.
    scr_pxl = {3'd3, 9'h008};
    obj_pxl = {3'd6, 9'h080};
    expect_pxl({3'd3, 9'h008}, "equal-priority sprite must stay behind the scroll layer");

    // A higher-priority sprite must appear over the same layer 3 pixel.
    obj_pxl = {3'd7, 9'h080};
    expect_pxl(12'h080, "higher-priority sprite must appear over the scroll layer");

    pass();
end

jtcps2_colmix uut(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .LVBL       ( LVBL      ),
    .pxl_cen    ( pxl_cen   ),
    .objcfg_cs  ( objcfg_cs ),
    .cpu_dout   ( cpu_dout  ),
    .layer_ctrl ( layer_ctrl),
    .dsn        ( dsn       ),
    .addr       ( addr      ),
    .scr_pxl    ( scr_pxl   ),
    .obj_pxl    ( obj_pxl   ),
    .obj_en     ( obj_en    ),
    .pxl        ( pxl       ),
    .debug_bus  ( 8'd0      )
);

initial begin
    $dumpfile("test.lxt");
    $dumpvars;
    $dumpon;
end

endmodule
