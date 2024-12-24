/*  This file is part of JTCORES.
    JTCORES program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTCORES program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTCORES.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. https://patreon.com/jotego
    Version: 1.0
    Date: 22-3-2022 */

module jtngp_obj #(
    parameter PXLW=5
)(
    input             rst,
    input             clk,

    input             HS,
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
    input             obj_cs,   // 64 objects, 4 bytes per object
    input             obj2_cs,  // additional byte in K2GE chip
    // Character RAM
    output reg [12:1] chram_addr,
    input      [15:0] chram_data,
    output reg        chram_rd,
    input             chram_ok,
    // video output
    input             en,
    output reg [PXLW-1:0] pxl
);

wire [ 1:0] we;
wire [ 6:0] scan_addr;
reg  [ 5:0] scan_obj;
reg  [ 2:0] scan_st;
wire [15:0] scan_dout;
reg         HSl;
wire        Hinit;
wire [PXLW-1:0] pre_pxl;

assign we    = ~dsn & {2{obj_cs}};
assign Hinit = ~HS & HSl;
assign scan_addr = { scan_obj, scan_st[0] };

always @(posedge clk) if(pxl_cen) begin
    pxl <= pre_pxl;
    if(!en) pxl[1:0] <= 0;
end
`ifdef SIMULATION
reg [15:0] chk_d=0;
reg [ 7:0] chk_a=0;
always @(posedge clk) if(we!=0) { chk_a, chk_d } <= { obj2_cs, cpu_addr, cpu_dout & {{8{we[1]}},{8{we[0]}}} };
`endif
// 256 bytes = 64 objects, extra 64 bytes in K2GE
// the extra byte is mapped up in the BRAM
jtframe_dual_ram16 #(
    .AW         (  8          ),
    .SIMFILE_LO ("obj_lo.bin" ),
    .SIMFILE_HI ("obj_hi.bin" )
    // ,.VERBOSE(1),.VERBOSE_OFFSET('h8800)
) u_objram(
    // Port 0
    .clk0   ( clk       ),
    .data0  ( cpu_dout  ),
    .addr0  ( { obj2_cs, cpu_addr } ),
    .we0    ( we        ),
    .q0     ( cpu_din   ),
    // Port 1
    .clk1   ( clk       ),
    .data1  (           ),
    // ignoring the extra NGPC byte for now...
    .addr1  ( { 1'b0, scan_addr } ),
    .we1    ( 2'b0      ),
    .q1     ( scan_dout )
);


// scan
reg        cen = 0;
reg  [8:0] code;
reg  [7:0] hpos;
reg [15:0] dr_attr_code;
reg        hflip, vflip, pal;
reg  [1:0] prio;
reg  [2:0] vsub;
reg  [7:0] ypos, ydelta, vlast, hlast;
reg        inzone, dr_start, dr_busy;
wire       done, hchain, vchain;
wire       hidden;

assign done   = &scan_addr[6:1];
assign { hchain, vchain } = dr_attr_code[10:9];
assign hidden = dr_attr_code[12:11]==0;

always @* begin
    ypos   = scan_dout[15:8] + (vchain ? vlast : voffset );
    ydelta = vrender - ypos[7:0];
    // objects that start out of the screen may be wrong, check scene #2
    inzone = ydelta < 8'h8 || (ydelta>248 && ypos[7] && vrender<8);
    vsub   = ydelta[2:0] ^ {3{dr_attr_code[14]}}; // vflip
end

always @(posedge clk) begin
    cen <= ~cen;
end

// scanner
always @(posedge clk, posedge rst) begin
    if( rst ) begin
        scan_obj  <= 0;
        scan_st   <= 0;
        HSl     <= 0;
        dr_start  <= 0;
        hlast     <= 0;
        vlast     <= 0;
        chram_addr<= 0;
    end else if( cen ) begin
        HSl <= HS;
        dr_start <= 0;
        case( scan_st )
            2: begin
                dr_attr_code <= scan_dout;
                scan_st      <= 3;
            end
            3: begin
                if( (inzone && !dr_busy) || !inzone ) begin
                    chram_addr <= { dr_attr_code[8:0], vsub };
                    dr_start <= inzone && !hidden;
                    hlast    <= scan_dout[7:0] + (hchain ? hlast : hoffset );
                    vlast    <= ypos;
                    // if( !hidden && vrender<10) begin
                    //     $display("(%d) -- %d (%d) -> %d",vrender,ypos, ydelta, inzone);
                    // end
                    scan_obj <= scan_obj + 6'd1;
                    scan_st  <= done ? 3'd0 : 3'd2;
                end
            end
            default: if( Hinit) begin
                scan_obj <= 0;
                hlast    <= 0;
                vlast    <= 0;
                scan_st  <= 2;
            end
        endcase
    end
end

reg  [15:0] obj_data;
reg  [ 3:0] dr_cnt;
wire [ 4:0] line_din;
reg         buff_we;

assign line_din   = { prio, pal, hflip ? obj_data[1:0] : obj_data[15:14]};

// drawing
always @(posedge clk, posedge rst) begin
    if( rst ) begin
        dr_busy  <= 0;
        chram_rd <= 0;
        buff_we  <= 0;
        obj_data <= 0;
        dr_cnt   <= 0;
    end else if(cen) begin
        if( dr_busy ) begin
            if( chram_rd ) begin
                if( chram_ok ) begin
                    obj_data <= chram_data;
                    chram_rd <= 0;
                    buff_we  <= 1;
                end
            end else begin
                dr_cnt <= dr_cnt - 1'd1;
                hpos <= hpos + 8'd1;
                obj_data <= hflip ? obj_data>>2 : obj_data<<2;
                if( dr_cnt==0 ) begin
                    dr_busy <= 0;
                    buff_we <= 0;
                end
            end
        end else if( dr_start ) begin
            { hflip, pal, prio } <= { dr_attr_code[15], dr_attr_code[13:11] };
            hpos     <= hlast;
            dr_busy  <= 1;
            chram_rd <= 1;
            dr_cnt   <= 7;
        end
    end
end

jtframe_obj_buffer #(.DW(PXLW),.ALPHA(0),.ALPHAW(2),.KEEP_OLD(1))
u_linebuffer(
    .clk    ( clk       ),
    .LHBL   ( ~HS       ),
    .flip   ( 1'b0      ),
    // New data writes
    .wr_data( line_din  ),
    .wr_addr( {1'd0,hpos} ),
    .we     ( buff_we   ),
    // Old data reads (and erases)
    .rd_addr( hdump - 9'd4    ),
    .rd     ( pxl_cen   ),
    .rd_data( pre_pxl   )
);


endmodule