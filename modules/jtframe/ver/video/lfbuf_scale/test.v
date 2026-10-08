`timescale 1ns/1ps

module test;

`include "test_tasks.vh"

localparam DW = 8;
localparam HW = 6;
localparam VW = 6;
localparam FW = 8;

localparam H_START  = 8;
localparam H_ACTIVE = 40;
localparam H_END    = H_START + H_ACTIVE;
localparam H_TOTAL  = 64;
localparam H_SYNC0  = 52;
localparam H_SYNC1  = 55;
localparam V_START  = 8;
localparam V_ACTIVE = 32;
localparam V_END    = V_START + V_ACTIVE;
localparam V_TOTAL  = 52;
localparam V_SYNC0  = 2;
localparam V_SYNC1  = 4;

localparam [FW:0] STEP_ONE = 9'h100;
localparam [FW:0] STEP_ZOOM = 9'h0fc; // 0.984375x, as seen near frame 857

reg rst = 1;
reg clk = 0;
reg pxl_cen = 1;
reg [FW:0] h_step = STEP_ONE;
reg [FW:0] v_step = STEP_ONE;

reg [HW-1:0] hcnt = 0;
reg [VW-1:0] vcnt = 0;
reg          hs = 0;
reg          vs = 0;
reg          lhbl = 0;
reg          lvbl = 0;

wire [VW-1:0] vread;
wire          ln_hs, ln_vs, ln_lvbl;
wire [VW-1:0] ln_v;
reg  [HW-1:0] ln_addr = 0;
reg  [DW-1:0] ln_data = 0;
reg           ln_we = 0;
wire [DW-1:0] ln_dout;
wire [DW-1:0] ln_pxl;

reg  [HW-1:0] fb_addr = 0;
reg  [HW-1:0] rd_addr = 0;
wire [15:0]   fb_din;
reg           fb_clr = 0;
reg           fb_done = 0;
wire          fb_blank;
reg  [15:0]   fb_dout = 0;
reg           line = 0;
reg           scr_we = 0;

reg [7:0] base_h [0:15];
reg [7:0] next_h [0:15];
reg [7:0] base_v [0:V_ACTIVE-1];
reg [7:0] next_v [0:V_ACTIVE-1];

integer frame = 0;
integer warm_frames = 0;
integer h_samples = 0;
reg arm_zoom = 0;
reg vs_l = 0;
integer i;

wire active_pxl = lhbl && lvbl;
wire [VW-1:0] active_v = vcnt - V_START[VW-1:0];

initial begin
    $dumpfile("test.lxt");
    $dumpvars;
    $dumpon;
end

always #5 clk = ~clk;

initial begin
    repeat(4) @(posedge clk);
    rst <= 0;
end

initial begin
    repeat(2_000_000) @(posedge clk);
    $display("FAIL timeout");
    $finish;
end

always @(posedge clk) begin
    if (rst) begin
        hcnt <= 0;
        vcnt <= 0;
        hs <= 0;
        vs <= 0;
        lhbl <= 0;
        lvbl <= 0;
    end else begin
        lhbl <= hcnt >= H_START && hcnt < H_END;
        lvbl <= vcnt >= V_START && vcnt < V_END;
        hs   <= hcnt >= H_SYNC0 && hcnt < H_SYNC1;
        vs   <= vcnt >= V_SYNC0 && vcnt < V_SYNC1;

        if (hcnt == H_TOTAL-1) begin
            hcnt <= 0;
            vcnt <= vcnt == V_TOTAL-1 ? 0 : vcnt + 1'd1;
        end else begin
            hcnt <= hcnt + 1'd1;
        end
    end
end

// Fill the scanout line buffer with an address-coded pattern whenever the
// visible area is idle. The scale path turns its read address into ln_pxl.
always @(posedge clk) begin
    scr_we  <= 0;
    rd_addr <= hcnt;
    fb_dout <= { 8'd0, hcnt };
    if (rst || !active_pxl) begin
        scr_we <= 1;
    end
end

// Emulate the memory controller acknowledging each requested line quickly.
reg [3:0] done_delay = 0;

always @(posedge clk) begin
    fb_done <= 0;
    if (rst) begin
        done_delay <= 0;
    end else if (ln_hs) begin
        done_delay <= 4'd5;
    end else if (done_delay != 0) begin
        done_delay <= done_delay - 1'd1;
        if (done_delay == 1) fb_done <= 1;
    end
end

always @(posedge clk) begin
    if (rst) begin
        frame <= 0;
        warm_frames <= 0;
        h_samples <= 0;
        arm_zoom <= 0;
        vs_l <= 0;
    end else begin
        vs_l <= vs;
        if (arm_zoom && vs && !vs_l) begin
            h_step <= STEP_ZOOM;
            v_step <= STEP_ZOOM;
            arm_zoom <= 0;
        end

        if (hcnt == 0 && vcnt == 0) begin
            if (warm_frames < 4) begin
                if (warm_frames == 3) begin
                    arm_zoom <= 1;
                end
                warm_frames <= warm_frames + 1;
            end else begin
                if (frame == 2) begin
                    assert_msg(h_samples == 16, "missing horizontal samples");
                    for (i = 0; i < 16; i = i + 1)
                        assert_msg(base_h[i] == next_h[i],
                            $sformatf("horizontal scale start changed at sample %0d: %0d != %0d",
                                      i, base_h[i], next_h[i]));
                    for (i = 0; i < V_ACTIVE; i = i + 1)
                        assert_msg(base_v[i] == next_v[i],
                            $sformatf("vertical scale start changed at line %0d: %0d != %0d",
                                      i, base_v[i], next_v[i]));
                    pass();
                end
                frame <= frame + 1;
                h_samples <= 0;
            end
        end

        if (warm_frames >= 4 && frame < 3 && hcnt == H_START + 1 && lvbl) begin
            if (frame == 1)
                base_v[active_v] <= vread;
            else if (frame == 2)
                next_v[active_v] <= vread;
        end

        if (warm_frames >= 4 && frame < 3 && vcnt == V_START + 8 && active_pxl &&
            hcnt >= H_START + 8 && hcnt < H_START + 24) begin
            if (frame == 1)
                base_h[h_samples] <= uut.h_rd[HW-1:0];
            else if (frame == 2)
                next_h[h_samples] <= uut.h_rd[HW-1:0];
            h_samples <= h_samples + 1;
        end

    end
end

jtframe_lfbuf_line #(
    .DW ( DW ),
    .VW ( VW ),
    .HW ( HW ),
    .FW ( FW )
) uut (
    .rst        ( rst       ),
    .clk        ( clk       ),
    .clk_ctrl   ( clk       ),
    .pxl_cen    ( pxl_cen   ),

    .vrender    ( vcnt      ),
    .vread      ( vread     ),
    .hdump      ( hcnt      ),
    .hs         ( hs        ),
    .lhbl       ( lhbl      ),
    .vs         ( vs        ),
    .lvbl       ( lvbl      ),

    .h_step     ( h_step    ),
    .v_step     ( v_step    ),

    .ln_hs      ( ln_hs     ),
    .ln_vs      ( ln_vs     ),
    .ln_lvbl    ( ln_lvbl   ),
    .ln_v       ( ln_v      ),
    .ln_addr    ( ln_addr   ),
    .ln_data    ( ln_data   ),
    .ln_we      ( ln_we     ),
    .ln_dout    ( ln_dout   ),
    .ln_pxl     ( ln_pxl    ),

    .frame      (           ),
    .fb_addr    ( fb_addr   ),
    .rd_addr    ( rd_addr   ),
    .fb_din     ( fb_din    ),
    .fb_clr     ( fb_clr    ),
    .fb_done    ( fb_done   ),
    .fb_blank   ( fb_blank  ),

    .fb_dout    ( fb_dout   ),
    .line       ( line      ),
    .scr_we     ( scr_we    )
);

endmodule
