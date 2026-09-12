/* SPDX-FileCopyrightText: 2026 Marc Emmerson
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Frame bench for jtwardner_video. Loads a snapshot of the video RAMs taken
 * by ../main/tb_main.v (+snap=) and the graphics ROM images built by
 * mkgfx.py, runs the video engine for a few frames and writes one of them as
 * a PPM, to be compared pixel for pixel with render_ref.py's output.
 *
 * The RAM models are registered like jtframe_dual_ram, the ROM models answer
 * one clock after the address changes (+lat=N adds N clocks) and drop rom_ok
 * as soon as the address changes, which is what an SDRAM controller does.
 *
 * plusargs: +snap=<dir> +gfx=<dir> +out=<file.ppm> +lat=<n> +frames=<n>
 */
`timescale 1ns/1ps

module tb_video;

reg         clk = 0, rst = 1;
reg  [2:0]  cpx = 0;
reg         pxl_cen = 0;

// 42 MHz base clock, pixel enable every sixth clock (7 MHz)
always #11.905 clk = ~clk;
always @(posedge clk) begin
    cpx     <= cpx == 3'd5 ? 3'd0 : cpx + 3'd1;
    pxl_cen <= cpx == 3'd5;
end

// ---- snapshot: registers and RAMs
reg [15:0] tx_scrx, tx_scry, bg_scrx, bg_scry, fg_scrx, fg_scry;
reg        flip, bg_bank, fg_bank, video_on;
reg [31:0] gfxen;
reg [15:0] tx_ram [0:2047], bg_ram[0:8191], fg_ram[0:4095],
           pal_ram[0:2047], obj_ram[0:2047];
wire [10:0] tx_vaddr, pal_vaddr, obj_vaddr;
wire [12:0] bg_vaddr;
wire [11:0] fg_vaddr;
reg  [15:0] tx_vq, bg_vq, fg_vq, pal_vq, obj_vq;

always @(posedge clk) begin
    tx_vq  <= tx_ram [tx_vaddr ];
    bg_vq  <= bg_ram [bg_vaddr ];
    fg_vq  <= fg_ram [fg_vaddr ];
    pal_vq <= pal_ram[pal_vaddr];
    obj_vq <= obj_ram[obj_vaddr];
end

// ---- graphics ROMs, MAME region layout: plane p of a tile is the p-th
//      slice of the region. The engine asks for a whole tile row: a byte
//      from each plane, plane 0 in the low byte.
reg [7:0] chars[0:3*16384-1];
reg [7:0] fgrom[0:4*32768-1];
reg [7:0] bgrom[0:4*32768-1];
reg [7:0] objrom[0:4*65536-1];

wire [13:0] char_addr; wire [15:0] fg_addr; wire [14:0] bg_addr; wire [15:0] obj_addr;
wire        char_cs, fg_cs, bg_cs, obj_cs;
reg  [31:0] char_data, fg_data, bg_data, obj_data;
wire        char_ok, fg_ok, bg_ok, obj_ok;
integer     lat;

rom_model #(.AW(14)) u_chars(.clk(clk),.lat(lat),.addr(char_addr),.ok(char_ok));
rom_model #(.AW(16)) u_fg   (.clk(clk),.lat(lat),.addr(fg_addr),  .ok(fg_ok));
rom_model #(.AW(15)) u_bg   (.clk(clk),.lat(lat),.addr(bg_addr),  .ok(bg_ok));
rom_model #(.AW(16)) u_obj  (.clk(clk),.lat(lat),.addr(obj_addr), .ok(obj_ok));

// the data the models hand back; fg wraps the bank bit off like code % total
always @(*) begin
    char_data = { 8'h00, chars[2*16384 + u_chars.al], chars[16384 + u_chars.al], chars[u_chars.al] };
    fg_data   = { fgrom[3*32768 + u_fg.al[14:0]], fgrom[2*32768 + u_fg.al[14:0]],
                  fgrom[  32768 + u_fg.al[14:0]], fgrom[u_fg.al[14:0]] };
    bg_data   = { bgrom[3*32768 + u_bg.al], bgrom[2*32768 + u_bg.al],
                  bgrom[  32768 + u_bg.al], bgrom[u_bg.al] };
    obj_data  = { objrom[3*65536 + u_obj.al], objrom[2*65536 + u_obj.al],
                  objrom[  65536 + u_obj.al], objrom[u_obj.al] };
end

// ---- DUT
wire        LVBL, LHBL, HS, VS, obj_ovf;
wire [8:0]  hdump, vdump;
wire [4:0]  red, green, blue;

jtwardner_video uut(
    .rst(rst), .clk(clk), .pxl_cen(pxl_cen),
    .tx_scrx(tx_scrx), .tx_scry(tx_scry), .bg_scrx(bg_scrx), .bg_scry(bg_scry),
    .fg_scrx(fg_scrx), .fg_scry(fg_scry),
    .flip(flip), .bg_bank(bg_bank), .fg_bank(fg_bank), .video_on(video_on),
    .gfx_en(gfxen[3:0]),                // +gfxen=N switches layers off, the same
                                        // bits the OSD debug keys drive:
                                        // 0 text, 1 bg, 2 fg, 3 sprites
    .tx_vaddr(tx_vaddr), .tx_vq(tx_vq), .bg_vaddr(bg_vaddr), .bg_vq(bg_vq),
    .fg_vaddr(fg_vaddr), .fg_vq(fg_vq), .pal_vaddr(pal_vaddr), .pal_vq(pal_vq),
    .obj_vaddr(obj_vaddr), .obj_vq(obj_vq),
    .char_addr(char_addr), .char_data(char_data), .char_cs(char_cs), .char_ok(char_ok),
    .fg_addr(fg_addr), .fg_data(fg_data), .fg_cs(fg_cs), .fg_ok(fg_ok),
    .bg_addr(bg_addr), .bg_data(bg_data), .bg_cs(bg_cs), .bg_ok(bg_ok),
    .obj_addr(obj_addr), .obj_data(obj_data), .obj_cs(obj_cs), .obj_ok(obj_ok),
    .LVBL(LVBL), .LHBL(LHBL), .HS(HS), .VS(VS), .hdump(hdump), .vdump(vdump),
    .red(red), .green(green), .blue(blue), .obj_ovf(obj_ovf)
);

// ---- frame capture. Colour lags hdump by two pixel enables (see the
//      pipeline note in jtwardner_video), so the coordinates are delayed
//      the same way before a pixel is stored.
reg  [7:0] frame_r[0:76799], frame_g[0:76799], frame_b[0:76799];
reg  [8:0] h1, h2, v1, v2;
reg        vis1, vis2;
integer    nframes, frames, fout, i, x, y;
reg        LVBL_l = 0, capture = 0;
reg [255:0] snapdir, gfxdir, outf;
reg [1023:0] fn;
reg [15:0]   regs[0:9];

function [7:0] x5; input [4:0] v; x5 = {v, v[4:2]}; endfunction

always @(posedge clk) if( pxl_cen ) begin
    h1 <= hdump; v1 <= vdump; vis1 <= LVBL && LHBL;
    h2 <= h1;    v2 <= v1;    vis2 <= vis1;
    if( capture && vis2 && h2 < 9'd320 && v2 < 9'd240 ) begin
        frame_r[v2*320 + h2] <= x5(red);
        frame_g[v2*320 + h2] <= x5(green);
        frame_b[v2*320 + h2] <= x5(blue);
    end
end

// count frames on the rise of LVBL; capture the one after the sprite copy
// has happened at least once
always @(posedge clk) begin
    LVBL_l <= LVBL;
    if( LVBL && !LVBL_l && !rst ) begin
        nframes <= nframes + 1;
        if( nframes == frames-1 ) capture <= 1;
        if( nframes == frames ) begin
            capture <= 0;
            write_ppm;
            $display("tb_video: frame %0d written to %0s, sprite overflow=%0d", frames, outf, obj_ovf);
            $finish;
        end
    end
end

task write_ppm;
    begin
        fout = $fopen(outf, "w");
        $fwrite(fout, "P3\n320 240\n255\n");
        for( i = 0; i < 76800; i = i + 1 )
            $fwrite(fout, "%0d %0d %0d\n", frame_r[i], frame_g[i], frame_b[i]);
        $fclose(fout);
    end
endtask


initial begin
    if( !$value$plusargs("snap=%s", snapdir) ) snapdir = "../main";
    if( !$value$plusargs("gfxen=%d", gfxen) ) gfxen = 32'hf;
    if( !$value$plusargs("gfx=%s",  gfxdir ) ) gfxdir  = ".";
    if( !$value$plusargs("out=%s",  outf   ) ) outf    = "rtl.ppm";
    if( !$value$plusargs("lat=%d",  lat    ) ) lat     = 0;
    if( !$value$plusargs("frames=%d", frames) ) frames = 3;
    nframes = 0;
    $sformat(fn, "%0s/snap_tx.hex",  snapdir); $readmemh(fn, tx_ram);
    $sformat(fn, "%0s/snap_bg.hex",  snapdir); $readmemh(fn, bg_ram);
    $sformat(fn, "%0s/snap_fg.hex",  snapdir); $readmemh(fn, fg_ram);
    $sformat(fn, "%0s/snap_pal.hex", snapdir); $readmemh(fn, pal_ram);
    $sformat(fn, "%0s/snap_obj.hex", snapdir); $readmemh(fn, obj_ram);
    $sformat(fn, "%0s/gfx_chars.hex", gfxdir); $readmemh(fn, chars);
    $sformat(fn, "%0s/gfx_fg.hex",    gfxdir); $readmemh(fn, fgrom);
    $sformat(fn, "%0s/gfx_bg.hex",    gfxdir); $readmemh(fn, bgrom);
    $sformat(fn, "%0s/gfx_obj.hex",   gfxdir); $readmemh(fn, objrom);
    // registers: ten words made from snap_regs.txt by run.sh
    $sformat(fn, "%0s/snap_regs.hex", snapdir); $readmemh(fn, regs);
    tx_scrx = regs[0]; tx_scry = regs[1]; bg_scrx = regs[2]; bg_scry = regs[3];
    fg_scrx = regs[4]; fg_scry = regs[5];
    flip = regs[6][0]; bg_bank = regs[7][0]; fg_bank = regs[8][0]; video_on = regs[9][0];
    $display("tb_video: scroll tx %0d,%0d bg %0d,%0d fg %0d,%0d banks %0d/%0d video_on=%0d lat=%0d",
        tx_scrx, tx_scry, bg_scrx, bg_scry, fg_scrx, fg_scry, bg_bank, fg_bank, video_on, lat);
    for( i = 0; i < 76800; i = i + 1 ) begin frame_r[i] = 0; frame_g[i] = 0; frame_b[i] = 0; end
    repeat(20) @(posedge clk);
    rst = 0;
end

// safety: 8 frames at 18.2 ms
initial begin
    #(8 * 18_300_000);
    $display("tb_video: timeout");
    $finish;
end

endmodule

// ROM model: data is valid one clock after the address is stable, plus `lat`
// extra clocks; ok drops as soon as the address moves.
module rom_model #(parameter AW=16)(
    input clk, input integer lat,
    input [AW-1:0] addr, output ok
);
reg [AW-1:0] al = 0;
integer cnt = 0;
always @(posedge clk) begin
    al <= addr;
    if( addr != al ) cnt <= 0; else if( cnt < lat + 1 ) cnt <= cnt + 1;
end
assign ok = addr == al && cnt >= lat + 1;
endmodule
