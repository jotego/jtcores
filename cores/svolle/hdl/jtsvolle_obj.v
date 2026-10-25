/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 25-10-2026 */

module jtsvolle_obj(
    input             rst, clk, pxl_cen, hs, en,
    input      [8:0]  hdump, vrender,
    input      [5:0]  count, pri,
    input             pal_bank,
    output     [11:1] ram_addr,
    input      [15:0] ram_data,
    output     [18:2] rom_addr,
    output            rom_cs,
    input      [31:0] rom_data,
    input             rom_ok,
    output     [8:0]  pxl,
    output reg        overrun
);

localparam IDLE=4'd0, WAIT_Y=4'd1, READ_Y=4'd2, WAIT_A=4'd3,
           READ_A=4'd4, WAIT_X=4'd5, READ_X=4'd6, CHECK=4'd7,
           LAUNCH=4'd8, DRAWING=4'd9, NEXT=4'd10;
reg [3:0] state;
reg [5:0] index;
reg [1:0] word_sel;
reg [8:0] line_y, ypos, xpos;
reg [15:0] attr;
reg draw, hs_l;
wire busy;
wire [8:0] row = line_y-ypos;
wire [4:0] yrow = row[4:0] ^ {5{attr[11]}};
wire [18:2] raw_addr;
wire [31:0] packed_data = {rom_data[23:16],rom_data[31:24],
                           rom_data[7:0],rom_data[15:8]};

assign ram_addr = {3'd0,index,word_sel};
assign rom_addr = {raw_addr[18:7],raw_addr[5:2],raw_addr[6]};

always @(posedge clk) begin
    hs_l <= hs;
    if(rst) begin
        state <= IDLE;
        draw <= 0;
        index <= 0;
        word_sel <= 0;
        line_y <= 0;
        ypos <= 0;
        xpos <= 0;
        attr <= 0;
        overrun <= 0;
    end else begin
        draw <= 0;
        if(hs && !hs_l) begin
            if(state!=IDLE || busy) overrun <= 1;
            if(en && count!=0 && !busy) begin
                index <= count-6'd1;
                word_sel <= 0;
                line_y <= vrender;
                state <= WAIT_Y;
            end else state <= IDLE;
        end else case(state)
            WAIT_Y: state <= READ_Y;
            READ_Y: begin
                ypos <= 9'd1-ram_data[8:0];
                word_sel <= 1;
                state <= WAIT_A;
            end
            WAIT_A: state <= READ_A;
            READ_A: begin
                attr <= ram_data;
                word_sel <= 2;
                state <= WAIT_X;
            end
            WAIT_X: state <= READ_X;
            READ_X: begin
                xpos <= ram_data[8:0]+9'd4;
                state <= row<9'd32 &&
                    (ram_data[8:0]<=9'd287 || ram_data[8:0]>=9'd501) ? CHECK : NEXT;
            end
            CHECK: if(!busy) begin
                draw <= 1;
                state <= LAUNCH;
            end
            LAUNCH: state <= DRAWING;
            DRAWING: if(!busy) state <= NEXT;
            NEXT: begin
                if(index==0) state <= IDLE;
                else begin
                    index <= index-6'd1;
                    word_sel <= 0;
                    state <= WAIT_Y;
                end
            end
            default: state <= IDLE;
        endcase
    end
end

jtframe_objdraw #(
    .CW         ( 12            ),
    .PW         ( 9             ),
    .HFIX       ( 0             ),
    .KEEP_OLD   ( 1             ),
    .ALPHA      ( 15            ),
    .PACKED     ( 1             )
) u_draw(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .pxl_cen    ( pxl_cen       ),
    .hs         ( hs            ),
    .flip       ( 1'b0          ),
    .hdump      ( hdump         ),
    .draw       ( draw          ),
    .busy       ( busy          ),
    .code       ( {attr[10:0],yrow[4]} ),
    .xpos       ( xpos          ),
    .ysub       ( yrow[3:0]     ),
    .hzoom      ( 6'd0          ),
    .hz_keep    ( 1'b0          ),
    .hflip      ( attr[12]      ),
    .vflip      ( 1'b0          ),
    .pal        ( {index>=pri,pal_bank,attr[15:13]} ),
    .rom_addr   ( raw_addr      ),
    .rom_cs     ( rom_cs        ),
    .rom_ok     ( rom_ok        ),
    .rom_data   ( packed_data   ),
    .pxl        ( pxl           )
);

endmodule
