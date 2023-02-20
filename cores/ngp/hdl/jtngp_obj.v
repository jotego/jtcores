/*  This file is part of JTNGP.
    JTNGP program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTNGP program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTNGP.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. https://patreon.com/jotego
    Version: 1.0
    Date: 22-3-2022 */

module jtngp_obj #(
    parameter PXLW=5
)(
    input             rst,
    input             clk,

    input             LHBL,
    input             pxl_cen,
    input      [ 8:0] hdump,
    input      [ 7:0] vrender,
    input      [ 7:0] hoffset,
    input      [ 7:0] voffset,
    // CPU access
    input      [ 7:1] cpu_addr,
    output     [15:0] cpu_din,
    input      [15:0] cpu_dout,
    input      [ 1:0] dsn,
    input             obj_cs,
    // Character RAM
    output     [12:1] chram_addr,
    input      [15:0] chram_data,
    output reg        chram_rd,
    input             chram_ok,
    // video output
    output [PXLW-1:0] pxl
);

wire [ 1:0] we;
reg  [ 6:0] scan_addr;
reg  [ 2:0] scan_st;
wire [15:0] scan_dout;
reg         LHBLl;
wire        Hinit;

assign we    = ~dsn & {2{obj_cs}};
assign Hinit = LHBL & ~LHBLl;

// 256 bytes = 64 objects
jtframe_dual_ram16 #(
    .aw         (  7          ),
    .simfile_lo ("obj_lo.bin" ),
    .simfile_hi ("obj_hi.bin" )
) u_objram(
    // Port 0
    .clk0   ( clk       ),
    .data0  ( cpu_dout  ),
    .addr0  ( cpu_addr  ),
    .we0    ( we        ),
    .q0     ( cpu_din   ),
    // Port 1
    .clk1   ( clk       ),
    .data1  (           ),
    .addr1  ( scan_addr^7'h7e ), // inverts the scan order
    .we1    ( 2'b0      ),
    .q1     ( scan_dout )
);


// scan
reg        cen = 0;
reg  [8:0] code, hpos;
reg [15:0] dr_attr_code;
reg        hflip, vflip, pal, vchain;
reg  [1:0] prio;
reg  [2:0] vsub;
reg  [8:0] ypos, ydelta, vlast, hlast;
reg        inzone, dr_start, dr_busy;
wire       done, hchain;
wire       hidden;

assign done   = &scan_addr[6:1];
assign hchain = dr_attr_code[10];
assign hidden = dr_attr_code[12:11]==0;

always @* begin
    ypos   = {1'b0,scan_dout[15:8]} + (vchain ? vlast : 9'd0) + voffset;
    ydelta = vrender - ypos[7:0];
    // objects that start out of the screen may be wrong, check scene #2
    inzone = ydelta < 9'h8 || (ydelta>248 && ypos[7] && vrender<8);
end

always @(posedge clk) begin
    cen <= ~cen;
end

// scanner
always @(posedge clk, posedge rst) begin
    if( rst ) begin
        scan_addr <= 0;
        scan_st   <= 0;
        LHBLl     <= 0;
        dr_start  <= 0;
    end else if( cen ) begin
        LHBLl <= LHBL;
        dr_start <= 0;
        case( scan_st )
            0: if( Hinit) begin
                scan_addr <= 0;
                scan_st   <= 1;
            end
            1: begin
                dr_attr_code <= scan_dout;
                vchain       <= scan_dout[10];
                scan_st      <= 2;
                scan_addr    <= scan_addr + 7'd1;
            end
            2: begin
                if( (inzone && !dr_busy) || !inzone ) begin
                    vlast     <= ypos;
                    dr_start  <= inzone && !hidden;
                    // if( !hidden && vrender<10) begin
                    //     $display("(%d) -- %d (%d) -> %d",vrender,ypos, ydelta, inzone);
                    // end
                    scan_addr <= scan_addr + 7'd1;
                    scan_st   <= done ? 0 : 1;
                end
            end
        endcase
    end
end

reg  [15:0] obj_data;
reg  [ 3:0] dr_cnt;
wire [ 4:0] line_din;
reg         buff_we;

assign line_din   = { prio, pal, hflip ? obj_data[1:0] : obj_data[15:14]};
assign chram_addr = { code, vsub };

// drawing
always @(posedge clk, posedge rst) begin
    if( rst ) begin
        dr_busy  <= 0;
        chram_rd <= 0;
        buff_we  <= 0;
        obj_data <= 0;
        dr_cnt   <= 0;
    end else begin
        if( dr_busy ) begin
            if( chram_rd ) begin
                if( chram_ok ) begin
                    obj_data <= chram_data;
                    chram_rd <= 0;
                    buff_we  <= 1;
                end
            end else begin
                dr_cnt <= dr_cnt - 1;
                hpos <= hpos + 9'd1;
                obj_data <= hflip ? obj_data>>2 : obj_data<<2;
                if( dr_cnt==0 ) begin
                    dr_busy <= 0;
                    buff_we <= 0;
                end
            end
        end else if( dr_start ) begin
            { hflip, pal, prio } <= { dr_attr_code[15], dr_attr_code[13:11] };
            code     <= dr_attr_code[8:0];
            hpos     <= {1'b0,scan_dout[7:0]} + (hchain ? hlast : 9'd0) + {1'b0,hoffset};
            hlast    <= {1'b0,scan_dout[7:0]};
            vsub     <= ydelta[2:0] ^ {3{dr_attr_code[14]}}; // vflip
            dr_busy  <= 1;
            chram_rd <= 1;
            dr_cnt   <= 7;
        end
    end
end

jtframe_obj_buffer #(.DW(PXLW),.ALPHA(0))
u_linebuffer(
    .clk    ( clk       ),
    .LHBL   ( LHBL      ),
    .flip   ( 1'b0      ),
    // New data writes
    .wr_data( line_din  ),
    .wr_addr( hpos      ),
    .we     ( buff_we   ),
    // Old data reads (and erases)
    .rd_addr( hdump - 9'd16    ),
    .rd     ( pxl_cen   ),
    .rd_data( pxl       )
);


endmodule