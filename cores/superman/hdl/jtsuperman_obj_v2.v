/*  This file is part of JTCORES.
    JTCORES program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    Author: Andrea Bogazzi
    Date: 2026-05-18                                                   */

// ─────────────────────────────────────────────────────────────────────────────
// Superman / X1-001A sprite-position renderer — first cut.
//
// Pre-loads up to 32 sprites from OBJ RAM during VBLANK, then per-pixel
// tests each sprite's 16x16 bounding box during the visible scan and
// outputs a 9-bit palette index when a sprite covers (hdump, vdump).
//
// No gfx ROM fetch yet — each sprite renders as a SOLID-COLOURED 16x16
// square using its palette base.  Enough to see where the title-screen
// sprites SHOULD be (the "1UP 00" text, the "TAITO" text, etc.).
//
// X1-001A OBJ RAM layout (verified against MAME's RAM dump):
//   OBJ word [N]          : {ctrl, char}     for sprite N (N = 0..255)
//   OBJ word [0x200 + N]  : {color, x_low}   for sprite N
//   VRAM word [N] low byte: sprite Y
// ─────────────────────────────────────────────────────────────────────────────

module jtsuperman_obj_v2(
    input              rst,
    input              clk,
    input              pxl_cen,
    input              LVBL,
    input        [8:0] hdump,
    input        [8:0] vdump,

    // OBJ RAM port-B (we drive these continuously; module steals them
    // during VBLANK to refresh the shadow buffer, idles during visible)
    output reg  [12:0] oram_addr,
    input       [15:0] oram_data,

    // VRAM port-B
    output reg   [9:0] vram_addr,
    input       [15:0] vram_data,

    // Pixel output:
    //   bit 9    : 1 = sprite covers this pixel (opaque)
    //   bits 8-4 : 5-bit palette
    //   bits 3-0 : dx[3:0] inside the sprite (gives stripes so we can
    //              recognise the per-sprite extents in debug video)
    output reg   [9:0] pxl
);

localparam NSP = 128;           // sprites shadowed (half the X1-001A list)

reg [13:0] sp_code   [0:NSP-1];
reg [ 4:0] sp_pal    [0:NSP-1];
reg [ 8:0] sp_x      [0:NSP-1]; // 9-bit unsigned X
reg [ 7:0] sp_y      [0:NSP-1];
reg        sp_active [0:NSP-1];

// ─── load FSM (runs during VBLANK) ─────────────────────────────────────────
reg [7:0] load_i;
reg [2:0] load_st;

integer init_k;
initial begin
    for (init_k = 0; init_k < NSP; init_k = init_k + 1) begin
        sp_code  [init_k] = 14'd0;
        sp_pal   [init_k] = 5'd0;
        sp_x     [init_k] = 9'd0;
        sp_y     [init_k] = 8'd0;
        sp_active[init_k] = 1'b0;
    end
end

always @(posedge clk, posedge rst) begin
    if (rst) begin
        load_i    <= 5'd0;
        load_st   <= 3'd0;
        oram_addr <= 13'd0;
        vram_addr <= 10'd0;
    end else begin
        // Load FSM runs continuously — REFRESHES the shadow buffer each
        // pass so newly-written sprite data picks up.  Previously gated
        // on LVBL or one-shot, both broke for different reasons.
        case (load_st)
        3'd0: begin
            // Issue read of sprite N's code+ctrl word + Y
            oram_addr <= {5'd0, load_i};                  // word N (13 bits)
            vram_addr <= {2'd0, load_i};                  // word N (10 bits)
            load_st <= 3'd1;
        end
        3'd1: load_st <= 3'd2;                            // BRAM latency
        3'd2: begin
            sp_code[load_i] <= {oram_data[13:8], oram_data[7:0]};
            sp_y   [load_i] <= vram_data[7:0];
            // Issue read of x+color word at offset 0x200 + N
            oram_addr <= 13'h200 | {5'd0, load_i};
            load_st <= 3'd3;
        end
        3'd3: load_st <= 3'd4;                            // BRAM latency
        3'd4: begin
            sp_x     [load_i] <= {oram_data[8], oram_data[7:0]};
            sp_pal   [load_i] <= oram_data[15:11];
            // Active if the sprite has ANY non-zero state across code/Y/X.
            // Sprites with palette=0 AND X=0 can still be valid (e.g.
            // sprite 1 at Y=10, code=02 with palette=0 — the boot uses
            // palette 0 for some title-screen text).
            sp_active[load_i] <= (sp_code[load_i] != 14'd0) ||
                                 (sp_y[load_i]    != 8'd0)  ||
                                 (oram_data[7:0]  != 8'd0)  ||
                                 (oram_data[15:11]!= 5'd0);
            if (load_i == NSP-1) begin
                load_i  <= 8'd0;
                load_st <= 3'd0;
            end else begin
                load_i  <= load_i + 1'd1;
                load_st <= 3'd0;
            end
        end
        default: load_st <= 3'd0;
        endcase
    end
end

// ─── per-pixel sprite hit test (combinational) ─────────────────────────────
// Per-pixel hit test (combinational).  Output uses color index 1 (non-
// transparent slot) for the sub-pixel so each sprite renders as a SOLID
// 16x16 block of palette[$100 | (pal<<4) | 1] — one colour per sprite
// palette, much cleaner than the dx stride for debug viewing.  When real
// tile gfx lands, the color index will come from the gfx ROM data.
reg [9:0] hit_pxl;
integer k;
reg [8:0] dx9;
reg [7:0] dy8;
always @* begin
    hit_pxl = 10'd0;
    for (k = 0; k < NSP; k = k + 1) begin
        dx9 = hdump - sp_x[k];
        dy8 = vdump[7:0] - sp_y[k];
        if (!hit_pxl[9] && sp_active[k] && dx9 < 9'd16 && dy8 < 8'd16) begin
            hit_pxl = {1'b1, sp_pal[k], 4'd1};
        end
    end
end

always @(posedge clk, posedge rst) begin
    if (rst) pxl <= 10'd0;
    else if (pxl_cen) pxl <= hit_pxl;
end

`ifdef SIMULATION
// Diagnostic: count how many sprite hits we render per frame
integer hit_count = 0;
integer frame_count = 0;
integer pxl_cen_count = 0;
integer red_nonzero_count = 0;
reg lvbl_q;
always @(posedge clk) begin
    lvbl_q <= LVBL;
    if (pxl_cen) pxl_cen_count = pxl_cen_count + 1;
    if (pxl_cen && hit_pxl[9]) hit_count = hit_count + 1;
    if (pxl_cen && pxl[9]) red_nonzero_count = red_nonzero_count + 1;
    if (~lvbl_q & LVBL) begin
        frame_count = frame_count + 1;
        if (frame_count % 10 == 0 || frame_count < 5)
            $display("[%0t] OBJ f=%0d  pxl_cen=%0d  hits=%0d  pxl9_ticks=%0d  sp[1]={x=%0d y=%0d act=%0d}",
                     $time, frame_count, pxl_cen_count, hit_count, red_nonzero_count,
                     sp_x[1],  sp_y[1],  sp_active[1]);
    end
end
`endif

endmodule
