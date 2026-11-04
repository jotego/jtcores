/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 01-11-2026 */

module jtttnose_obj #(
    parameter YOFFSET=0
)(
    input             rst, clk, pxl_cen, hs, en, flip,
    input      [8:0]  hdump, vrender,
    output     [9:1]  ram_addr,
    input      [15:0] ram_data,
    output reg [18:2] rom_addr,
    output reg        rom_cs,
    input      [31:0] rom_data,
    input             rom_ok,
    output     [6:0]  pxl,
    output reg        overrun
);

localparam IDLE=4'd0, WAIT_Y=4'd1, READ_Y=4'd2, WAIT_X=4'd3,
           READ_X=4'd4, WAIT_A=4'd5, READ_A=4'd6, CHECK=4'd7,
           LAUNCH=4'd8, DRAWING=4'd9, NEXT=4'd10;
reg [3:0] state;
reg [6:0] index;
reg [1:0] word_sel;
reg [8:0] line_y;
reg [15:0] ypos, xpos_raw, attr;
reg draw, hs_l;
wire busy;
wire [15:0] sx = flip ? 16'd305-xpos_raw : xpos_raw+16'd3;
wire [15:0] sy = flip ? 16'd217+ypos+YOFFSET[15:0] : 16'd1-ypos-YOFFSET[15:0];
wire [15:0] row = {7'd0,line_y}-sy;
wire [4:0] yrow = row[4:0] ^ {5{attr[11]^flip}};
wire [18:2] raw_addr;
wire raw_cs;
wire raw_ok;
reg [31:0] packed_data, first_data;
reg [18:2] request;
reg [2:0] fetch_state;
wire [15:0] first_half = request[6] ? first_data[31:16] : first_data[15:0];
wire [15:0] second_half = request[6] ? rom_data[31:16] : rom_data[15:0];

assign ram_addr = {index,word_sel};
assign raw_ok = fetch_state==4 && raw_cs && raw_addr==request;

always @(posedge clk) begin
    hs_l <= hs;
    if(rst) begin
        state <= IDLE;
        draw <= 0;
        index <= 0;
        word_sel <= 0;
        line_y <= 0;
        ypos <= 0;
        xpos_raw <= 0;
        attr <= 0;
        overrun <= 0;
    end else begin
        draw <= 0;
        if(hs && !hs_l) begin
            if(state!=IDLE || busy) overrun <= 1;
            if(en && !busy) begin
                index <= 0;
                word_sel <= 0;
                line_y <= vrender;
                state <= WAIT_Y;
            end else state <= IDLE;
        end else case(state)
            WAIT_Y: state <= READ_Y;
            READ_Y: begin
                ypos <= ram_data;
                word_sel <= 1;
                state <= WAIT_X;
            end
            WAIT_X: state <= READ_X;
            READ_X: begin
                xpos_raw <= ram_data;
                word_sel <= 2;
                state <= WAIT_A;
            end
            WAIT_A: state <= READ_A;
            READ_A: begin
                attr <= ram_data;
                state <= CHECK;
            end
            CHECK: begin
                if(row>=16'd32 || !($signed(sx)>-16'sd16 && $signed(sx)<16'sd320))
                    state <= NEXT;
                else if(!busy) begin
                    draw <= 1;
                    state <= LAUNCH;
                end
            end
            LAUNCH: state <= DRAWING;
            DRAWING: if(!busy) state <= NEXT;
            NEXT: begin
                if(index==7'd95) state <= IDLE;
                else begin
                    index <= index+7'd1;
                    word_sel <= 0;
                    state <= WAIT_Y;
                end
            end
            default: state <= IDLE;
        endcase
    end
end

always @(posedge clk) begin
    if(rst) begin
        fetch_state <= 0;
        rom_cs <= 0;
        rom_addr <= 0;
        request <= 0;
        first_data <= 0;
        packed_data <= 0;
    end else case(fetch_state)
        0: if(raw_cs) begin
            request <= raw_addr;
            rom_addr <= {1'b0,raw_addr[18:8],raw_addr[7],raw_addr[5:2]};
            rom_cs <= 1;
            fetch_state <= 1;
        end
        1: if(rom_ok) begin
            first_data <= rom_data;
            rom_cs <= 0;
            fetch_state <= 2;
        end
        2: begin
            rom_addr <= {1'b1,request[18:8],request[7],request[5:2]};
            rom_cs <= 1;
            fetch_state <= 3;
        end
        3: if(rom_ok) begin
            packed_data <= {second_half,first_half};
            rom_cs <= 0;
            fetch_state <= 4;
        end
        4: begin
            if(!raw_cs || raw_addr!=request) fetch_state <= 0;
        end
        default: fetch_state <= 0;
    endcase
end

jtframe_objdraw #(
    .CW       ( 12 ),
    .PW       ( 7  ),
    .HFIX     ( 0  ),
    .KEEP_OLD ( 0  ),
    .ALPHA    ( 15 ),
    .PACKED   ( 1  )
) u_draw(
    .rst      ( rst                  ),
    .clk      ( clk                  ),
    .pxl_cen  ( pxl_cen              ),
    .hs       ( hs                   ),
    .flip     ( 1'b0                 ),
    .hdump    ( hdump                ),
    .draw     ( draw                 ),
    .busy     ( busy                 ),
    .code     ( {attr[10:0],yrow[4]} ),
    .xpos     ( sx[8:0]              ),
    .ysub     ( yrow[3:0]            ),
    .hzoom    ( 6'd0                 ),
    .hz_keep  ( 1'b0                 ),
    .hflip    ( attr[12]^flip        ),
    .vflip    ( 1'b0                 ),
    .pal      ( attr[15:13]          ),
    .rom_addr ( raw_addr             ),
    .rom_cs   ( raw_cs               ),
    .rom_ok   ( raw_ok               ),
    .rom_data ( packed_data          ),
    .pxl      ( pxl                  )
);

endmodule
