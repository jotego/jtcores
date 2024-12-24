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

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 3-9-2022 */

// In the original design up to 16 objects are compared to VPOS
// during HB, the VPOS value was updated after HB. That means
// that the LUT was filled with matched objects where Y==last scan line
// then the objects are buffered during the next scan line HB (Y+1),
// and dumped during Y+2

// The object buffer is strange because it is not cleared with a fixed
// null color but with the char video output. Then the objects are
// drawn on top of the char output. The RAM used is driven in a way
// that the line can be read while dumping it as it uses the two
// phases of the pixel clock. The RAM seems to be a 60ns one (16.7MHz)

// In this implementation we skip filling the intermmediate LUT buffer
// so in order to match the y, the comparison must be done with vdump+1
// The char output is not buffered either, but dumped in real time. As
// there is no scroll or raster Fx hardware, not buffering the char line
// produces the same final result

module jtkchamp_obj(
    input               clk,        // 48 MHz
    input               clk24,      // 24 MHz

    input               pxl_cen,

    input               hs,
    input        [ 8:0] hdump,
    input        [ 8:0] vdump,
    input               flip,
    input               enc,

    input        [ 7:0] cpu_addr,
    input        [ 7:0] cpu_dout,
    output       [ 7:0] cpu_din,
    input               oram_cs,
    input               cpu_rnw,

    output              rom_cs,
    input               rom_ok,
    output reg   [16:2] rom_addr,
    input        [31:0] rom_data,
    input        [ 7:0] debug_bus,

    output       [ 5:0] pxl
);

wire        we;
wire [ 7:0] scan_dout;
reg  [ 7:0] xpos, ypos;
wire [ 7:0] scan_addr;
reg  [ 5:0] obj_cnt;
reg         cen2;
reg  [ 1:0] st;
reg  [10:0] code;
reg         done, dr_bsy, dr_start, buf_we;
reg  [31:0] pxl_data;
reg  [ 3:0] dr_cnt, pal, cur_pal;
wire [ 5:0] buf_din;
reg         rst; // generated locally
reg         match, vflip;
reg  [ 7:0] ydiff, yoff, xoff;
reg  [ 8:0] buf_addr;

assign we        = oram_cs & ~cpu_rnw;
assign rom_cs    = dr_bsy & ~buf_we;
assign scan_addr = { obj_cnt, st };
assign buf_din   = { cur_pal, pxl_data[31], pxl_data[15]};

always @* begin
    ydiff = ypos + vdump[7:0] + yoff;
    match = &ydiff[7:4];
end

always @(posedge clk) begin
    //yoff <= enc ? (flip ? 8'hff : 8'h0) : (flip ? -8'd8 : -8'd6);
    yoff <= flip ? -8'd8 : -8'd6;
    xoff <= enc ?  8'd9 : (flip ? 8'd0 : 8'd1);
    cen2 <= ~cen2;
    rst  <= hdump[8] | vdump[8];
end

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        st       <= 0;
        done     <= 0;
        dr_start <= 0;
        xpos     <= 0;
        ypos     <= 0;
        code     <= 0;
        pal      <= 0;
        obj_cnt  <= 0;
    end else if(cen2) begin
        st       <= st + 1'd1;
        dr_start <= 0;
        if( !done ) case( st )
            0: ypos <= scan_dout;
            1: code[7:0] <= scan_dout;
            2: begin
                { vflip, code[8], pal } <= { scan_dout[7], scan_dout[4:0] };
                case( scan_dout[6:5] )
                    0: code[10:9] <= 2;
                    1: code[10:9] <= 1;
                    2: code[10:9] <= 0;
                    3: code[10:9] <= 3;
                endcase
            end
            3: begin
                xpos <= scan_dout;
                if( match && dr_bsy )
                    st <= 3; // wait here
                else begin
                    if( match ) begin
                        rom_addr <= { code, ydiff[3:0]^{4{vflip}} };
                        dr_start <= 1;
                    end
                    obj_cnt <= obj_cnt+1'd1;
                    done <= &obj_cnt;
                end
            end
        endcase
    end
end

// Draw
always @(posedge clk, posedge rst)  begin
    if( rst ) begin
        dr_bsy   <= 0;
        buf_we   <= 0;
        buf_addr <= 0;
        pxl_data <= 0;
        dr_cnt   <= 0;
        cur_pal  <= 0;
    end else begin
        if( dr_start ) begin
            buf_addr <= {1'b0, xpos + xoff };
            dr_bsy   <= 1;
            cur_pal  <= pal;
            buf_we   <= 0;
            dr_cnt   <= 0;
        end
        if( dr_bsy && (rom_ok||buf_we) ) begin
            if( !buf_we ) begin
                pxl_data <= rom_data;
                buf_we   <= 1;
            end else begin
                buf_addr <= buf_addr+1'd1;
                pxl_data <= pxl_data << 1;
                dr_cnt   <= dr_cnt + 1'd1;
                if (&dr_cnt) begin
                    dr_bsy <= 0;
                    buf_we <= 0;
                end
            end
        end
    end
end

jtframe_dual_ram #(.AW(8),.SIMFILE("obj.bin")) u_lut(
    // CPU
    .clk0   ( clk24     ),
    .data0  ( cpu_dout  ),
    .addr0  ( cpu_addr  ),
    .we0    ( we        ),
    .q0     ( cpu_din   ),
    // VIDEO
    .clk1   ( clk       ),
    .data1  (           ),
    .addr1  ( scan_addr ),
    .we1    ( 1'b0      ),
    .q1     ( scan_dout )
);

jtframe_obj_buffer #(.DW(6),.ALPHAW(2),.ALPHA(0),.FLIP_OFFSET(9'h110))
u_buffer (
    .clk    ( clk      ),
    .LHBL   (  ~hs     ),
    .flip   ( flip     ),
    .wr_data( buf_din  ),
    .wr_addr( buf_addr ),
    .we     ( buf_we   ),
    .rd_addr( hdump    ),
    .rd     ( pxl_cen  ),
    .rd_data( pxl      )
);

endmodule