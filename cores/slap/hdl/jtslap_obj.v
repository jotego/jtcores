/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 4-10-2026 */

module jtslap_obj(
    input             rst,
    input             clk,
    input             pxl_cen,
    input             HS, LVBL,
    input       [8:0] hdump, vrender,
    input             flip,
    output     [10:0] vram_addr,
    input       [7:0] vram_data,
    output     [16:2] rom_addr,
    output            rom_cs,
    input      [31:0] rom_data,
    input             rom_ok,
    output      [7:0] pxl
);

localparam LOAD=0, CHECK=1, READY=2, DRAW=3, NEXT=4, DONE=5;

reg  [ 2:0] state;
reg  [10:0] copy_addr, copy_addr_l;
reg  [10:2] scan_addr;
reg         hs_l, copy_we;
wire [31:0] buf_data, copy_data, rom_sorted;
wire [ 3:0] copy_mask;
reg  [ 9:0] code;
reg  [ 8:0] xpos;
reg  [ 3:0] ysub, pal;
wire [ 7:0] ydiff;
wire [16:2] draw_addr;
wire        draw, busy;

assign vram_addr = copy_addr;
assign ydiff = flip ? vrender[7:0] + buf_data[31:24] - 8'd239 :
                      vrender[7:0] - buf_data[31:24] + 8'd1;
assign draw = state==DRAW;
assign copy_data = {4{vram_data}};
assign copy_mask = copy_we ? 4'b0001 << copy_addr_l[1:0] : 4'd0;
// The PCB addresses {code,Y,H}; the generic drawer exposes {code,H,Y}.
assign rom_addr = {draw_addr[16:7],draw_addr[5:2],draw_addr[6]};

genvar plane, bitpos;
generate
    for(plane=0;plane<4;plane=plane+1) begin : planes
        for(bitpos=0;bitpos<8;bitpos=bitpos+1) begin : bitswap
            assign rom_sorted[plane*8+bitpos] = rom_data[plane*8+7-bitpos];
        end
    end
endgenerate

// Attribute RAM refreshed during blanking, matching the PCB's buffered
// sprite path.
always @(posedge clk) begin
    if(rst) begin
        copy_addr   <= 0;
        copy_addr_l <= 0;
        copy_we     <= 0;
    end else begin
        copy_we <= !LVBL;
        copy_addr_l <= copy_addr;
        if(!LVBL) copy_addr <= copy_addr+11'd1;
    end
end

always @(posedge clk) begin
    hs_l <= HS;
end

always @(posedge clk) begin
    if(rst) begin
        state <= DONE;
        scan_addr <= 0;
        xpos <= 0;
        ysub <= 0;
        code <= 0;
        pal <= 0;
    end else if(HS && !hs_l) begin
        scan_addr <= 0;
        state <= LOAD;
    end else case(state)
        LOAD: state <= CHECK;
        CHECK: begin
            code <= {buf_data[23:22],buf_data[7:0]};
            pal <= buf_data[20:17];
            xpos <= flip ? 9'd297-{buf_data[16],buf_data[15:8]} :
                                 {buf_data[16],buf_data[15:8]}-9'd13;
            ysub <= ydiff[3:0];
            state <= ydiff[7:4]==0 ? READY : NEXT;
        end
        READY: if(!busy) state<=DRAW;
        DRAW: state <= NEXT;
        NEXT: if(!busy) begin
            if(scan_addr==9'h1ff) state<=DONE;
            else begin scan_addr<=scan_addr+9'd1; state<=LOAD; end
        end
        default: state<=DONE;
    endcase
end

jtframe_dual_ram32 #(.AW(11)) u_buffer(
    .clk0  ( clk          ),
    .addr0 ( copy_addr_l[10:2] ),
    .data0 ( copy_data    ),
    .we0   ( copy_mask    ),
    .q0    (              ),
    .clk1  ( clk          ),
    .addr1 ( scan_addr    ),
    .data1 ( 32'd0        ),
    .we1   ( 4'd0         ),
    .q1    ( buf_data     )
);

jtframe_objdraw #(.CW(10),.LATCH(1),.HFIX(0)) u_objdraw(
    .rst     ( rst           ),
    .clk     ( clk           ),
    .pxl_cen ( pxl_cen       ),
    .hs      ( HS            ),
    .hdump   ( hdump         ),
    .flip    ( 1'b0          ),
    .draw    ( draw          ),
    .busy    ( busy          ),
    .code    ( code          ),
    .xpos    ( xpos          ),
    .ysub    ( ysub          ),
    .hzoom   ( 6'd0          ),
    .hz_keep ( 1'b0          ),
    .hflip   ( flip          ),
    .vflip   ( flip          ),
    .pal     ( pal           ),
    .rom_addr( draw_addr     ),
    .rom_cs  ( rom_cs        ),
    .rom_data( rom_sorted    ),
    .rom_ok  ( rom_ok        ),
    .pxl     ( pxl           )
);
endmodule
