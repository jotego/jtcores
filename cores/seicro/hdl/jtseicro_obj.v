/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 15-10-2026 */

module jtseicro_obj(
    input             rst, clk, pxl_cen, HS, flip,
    input       [8:0] hdump, vrender,
    output      [6:0] ram0_addr,
    output      [4:0] ram1_addr,
    input       [7:0] ram0_data, ram1_data,
    output     [13:1] rom_addr,
    output            rom_cs,
    input      [15:0] rom_data,
    input             rom_ok,
    output      [7:0] pxl
);

localparam IDLE=0, FETCH=1, WAIT_RAM=2, LATCH_RAM=3, CHECK=4,
           START=5, WAIT_DRAW=6, NEXT=7;
reg [2:0] state;
reg [4:0] object;
reg [1:0] field;
reg [7:0] attr0, attr1, attr2, attr3;
reg [8:0] line_y;
reg hs_l, bank;
wire [7:0] ram_data;
wire signed [9:0] ypos, ydiff;
wire [7:0] xpos, code;
wire [12:0] draw_addr;
wire [31:0] planes;
wire busy, buf_we;
wire [8:0] buf_addr;
wire [7:0] buf_data;

assign ram0_addr = {object,field};
assign ram1_addr = {object[2:0],field};
assign ram_data = bank ? ram1_data : ram0_data;
assign ypos = flip ? $signed({2'b00,attr2}) : 10'sd240-$signed({2'b00,attr2});
assign ydiff = $signed({1'b0,line_y})-ypos;
assign xpos = flip ? 8'd240-attr3 : attr3;
assign code = {~bank,attr1[4],attr0[5:0]};
assign rom_addr = {draw_addr[12:5],draw_addr[3],draw_addr[4],draw_addr[2:0]};

genvar p;
generate for(p=0;p<4;p=p+1) begin : unpack
    assign planes[p]    = rom_data[3-p];
    assign planes[p+4]  = rom_data[11-p];
    assign planes[p+8]  = rom_data[7-p];
    assign planes[p+12] = rom_data[15-p];
end endgenerate
assign planes[31:16] = 0;

always @(posedge clk) begin
    hs_l <= HS;
    if(rst) begin
        state <= IDLE;
        object <= 0;
        field <= 0;
        bank <= 0;
        line_y <= 0;
        attr0 <= 0;
        attr1 <= 0;
        attr2 <= 0;
        attr3 <= 0;
        hs_l <= 0;
    end else if(HS && !hs_l && !busy) begin
        state <= FETCH;
        object <= 23;
        field <= 0;
        bank <= 0;
        line_y <= vrender;
    end else case(state)
        FETCH: state <= WAIT_RAM;
        WAIT_RAM: state <= LATCH_RAM;
        LATCH_RAM: begin
            case(field)
                0: attr0 <= ram_data;
                1: attr1 <= ram_data;
                2: attr2 <= ram_data;
                3: attr3 <= ram_data;
            endcase
            field <= field+2'd1;
            state <= field==3 ? CHECK : FETCH;
        end
        CHECK: state <= ydiff>=0 && ydiff<16 && line_y<256 ? START : NEXT;
        START: state <= WAIT_DRAW;
        WAIT_DRAW: if(!busy) state <= NEXT;
        NEXT: begin
            if(object!=0) begin
                object <= object-5'd1;
                state <= FETCH;
            end else if(!bank) begin
                bank <= 1;
                object <= 7;
                state <= FETCH;
            end else state <= IDLE;
        end
        default: state <= IDLE;
    endcase
end

jtframe_draw #(
    .AW ( 9 ),
    .CW ( 8 ),
    .PW ( 8 )
) u_draw(
    .rst      ( rst           ),
    .clk      ( clk           ),
    .draw     ( state==START  ),
    .busy     ( busy          ),
    .code     ( code          ),
    .xpos     ( {1'b0,xpos}   ),
    .ysub     ( ydiff[3:0]    ),
    .trunc    ( 2'd0          ),
    .hzoom    ( 6'd0          ),
    .hz_keep  ( 1'b0          ),
    .hflip    ( attr0[6]^flip ),
    .vflip    ( attr0[7]^flip ),
    .pal      ( attr1[3:0]    ),
    .rom_addr ( draw_addr     ),
    .rom_cs   ( rom_cs        ),
    .rom_ok   ( rom_ok        ),
    .rom_data ( planes        ),
    .buf_addr ( buf_addr      ),
    .buf_we   ( buf_we        ),
    .buf_din  ( buf_data      )
);

jtframe_obj_buffer #(
    .AW    ( 8 ),
    .DW    ( 8 ),
    .ALPHA ( 0 )
) u_buffer(
    .clk     ( clk                                        ),
    .LHBL    ( ~HS                                        ),
    .flip    ( 1'b0                                       ),
    .wr_data ( buf_data                                   ),
    .wr_addr ( buf_addr[7:0]                              ),
    .we      ( buf_we                                     ),
    .rd_addr ( hdump[7:0]                                 ),
    // the read lands on hdump+1: terms 0..254 read cells 1..255, the 383 term reads cell 0 past the wrap
    .rd      ( pxl_cen && (hdump<9'd255 || hdump==9'd383) ),
    .rd_data ( pxl                                        )
);

endmodule
