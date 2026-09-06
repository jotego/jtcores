/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 2-4-2022 */

// This module implements the pc090oj logic

module jtrastan_obj(
    input           rst,
    input           clk,
    input           pxl_cen,

    input           HS,
    input           flip,
    input    [8:0]  hdump,
    input    [8:0]  vrender,

    output   [12:1] ram_addr,
    input    [15:0] ram_data,
    output          dtackn,

    output   [19:2] rom_addr,
    input    [31:0] rom_data,
    output          rom_cs,
    input           rom_ok,
    input    [ 7:0] debug_bus,
    output   [ 7:0] pxl
);

wire [15:0] scan_dout;
wire [19:2] draw_addr;
wire [31:0] sorted;
wire [ 8:0] draw_xpos;
wire        draw_vflip, dr_busy;
reg  [15:0] attr, ypos, xpos, code;
reg         HSl;
reg  [ 7:0] obj_cnt;
reg         done;
wire        last_obj;
reg         inzone, dr_start;
reg  [ 2:0] scan_st;
reg  [ 1:0] scan_cnt;
reg  [ 8:0] ydiff;

assign last_obj = obj_cnt==0;
assign ram_addr = {2'b0, obj_cnt, scan_cnt};
assign scan_dout = ram_data;
assign dtackn = 1;
wire [8:0] yeff = flip ? 9'd240 - ypos[8:0] : ypos[8:0];
wire [8:0] xeff = flip ? 9'd304 - xpos[8:0] : xpos[8:0];
assign draw_xpos  = xeff + 9'd13;
assign draw_vflip = ~(attr[15]^flip);
assign rom_addr   = { draw_addr[19:7], draw_addr[5:2], draw_addr[6] };
assign sorted     = { rom_data[27:24], rom_data[31:28],
                      rom_data[19:16], rom_data[23:20],
                      rom_data[11: 8], rom_data[15:12],
                      rom_data[ 3: 0], rom_data[ 7: 4] };

always @* begin
    ydiff  = yeff - (vrender-9'd8);
    inzone = ydiff<16;
end

// Scanner
always @(posedge clk, posedge rst) begin
    if( rst ) begin
        scan_st <= 0;
        obj_cnt <= 0;
        HSl     <= 0;
        done    <= 0;
        dr_start <= 0;
    end else begin
        HSl <= HS;
        dr_start <= 0;

        if( scan_st != 6 ) begin
            scan_st  <= scan_st + 3'd1;
            scan_cnt <= scan_cnt+ 2'd1;
        end
        case( scan_st )
            0:  if( !HS && HSl ) begin
                    obj_cnt <= 8'hff;
                    scan_cnt <= 0;
                    scan_st  <= 1;
                    done     <= 0;
                end else begin
                    scan_st <= 0;
                end
            2: attr <= scan_dout;
            3: ypos <= scan_dout;
            4: begin
                code <= scan_dout;
                obj_cnt <= obj_cnt-8'd1;
                done    <= last_obj;
            end
            5: begin
                xpos <= scan_dout;
                scan_cnt <= 0;
                if( !inzone ) begin
                    scan_st <= done ? 3'd0 : 3'd1;
                end
            end
            6: if( !dr_busy ) begin
                dr_start <= 1;
                scan_st  <= done ? 3'd0 : 3'd1;
            end
        endcase
    end
end

jtframe_objdraw #(
    .CW     ( 13 ),
    .PW     (  8 ),
    .HJUMP  (  0 ),
    .HFIX   (  0 ),
    .LATCH  (  1 ),
    .PACKED (  1 )
) u_draw(
    .rst      ( rst          ),
    .clk      ( clk          ),
    .pxl_cen  ( pxl_cen      ),
    .hs       ( HS           ),
    .flip     ( 1'b0         ),
    .hdump    ( hdump        ),

    .draw     ( dr_start     ),
    .busy     ( dr_busy      ),
    .code     ( code[12:0]   ),
    .xpos     ( draw_xpos    ),
    .ysub     ( ydiff[3:0]   ),
    .hzoom    ( 6'd0         ),
    .hz_keep  ( 1'b0         ),
    .hflip    ( attr[14]^flip),
    .vflip    ( draw_vflip   ),
    .pal      ( attr[3:0]    ),

    .rom_addr ( draw_addr    ),
    .rom_cs   ( rom_cs       ),
    .rom_ok   ( rom_ok       ),
    .rom_data ( sorted       ),
    .pxl      ( pxl          )
);

endmodule
