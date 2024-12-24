/*  This file is part of JTKUNIO.
    JTKUNIO program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTKUNIO program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTKUNIO.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 30-7-2022 */

module jtkunio_obj(
    input              rst,
    input              clk,
    input              pxl_cen,

    input              flip,
    input              hs,
    input      [ 7:0]  vrender,
    input      [ 8:0]  hdump,

    input      [ 8:0]  cpu_addr,
    input              objram_cs,
    input              cpu_wrn,
    input      [ 7:0]  cpu_dout,
    output     [ 7:0]  cpu_din,
    // ROM access
    output reg         rom_cs,
    output     [18:2]  rom_addr,
    input      [31:0]  rom_data,
    input              rom_ok,
    output     [ 4:0]  pxl,
    input      [ 7:0]  debug_bus
);


wire        vram_we;
wire [ 7:0] scan_dout;
wire [ 8:0] scan_addr;
reg  [ 6:0] obj_cnt;
wire [ 4:0] buf_din;
reg         cen = 0;
reg  [ 7:0] x, y, ydiff;
reg  [ 8:0] buf_addr;
reg  [ 1:0] dr_pal, pal;
reg  [ 2:0] st;
reg         tall, dr_hflip, hflip, done, dr_busy,
            half, inzone, dr_start;
reg  [11:0] code;
reg  [11:0] dr_code;
reg  [ 4:0] rom_msb;
reg  [ 3:0] dr_ysub, pxl_cnt;

reg  [47:0] pxl_data;
reg  [15:0] plane0;
wire        buf_we;

assign scan_addr = { obj_cnt, st[1:0] };
assign vram_we   = objram_cs & ~cpu_wrn;
assign rom_addr  = { rom_msb, dr_code[7:0], dr_ysub }; // 5+8+4=17

always @* begin
    ydiff  = vrender + y;
    inzone = &ydiff[7:5] && (tall || ydiff[4]);
end

always @(posedge clk) begin
    cen <= ~cen;
end

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        st       <= 0;
        done     <= 0;
        obj_cnt  <= 0;
        dr_start <= 0;
    end else begin
        if( hs ) begin
            st       <= 0;
            obj_cnt  <= 0;
            done     <= 0;
            dr_start <= 0;
        end else if( cen && !done ) begin
            if( st != 4 ) st <= st+3'd1;
            dr_start <= 0;
            case( st )
                0: y <= scan_dout;
                1: { tall, hflip, pal, code[11:8] } <= scan_dout;
                2: code[7:0] <= scan_dout;
                3: begin
                    x <= scan_dout;
                    if( tall && ydiff[4] ) code[0] <= 1;
                end
                4: if( !inzone || !dr_busy ) begin
                    st <= 0;
                    dr_start <= inzone;
                    obj_cnt  <= obj_cnt + 1'd1;
                    done     <= &obj_cnt;
                end
            endcase
        end
    end
end

assign buf_din = { dr_pal, dr_hflip ?
    {pxl_data[47], pxl_data[31], pxl_data[15] } :
    {pxl_data[32], pxl_data[16], pxl_data[0]} };
assign buf_we = dr_busy & ~rom_cs;

always @(posedge clk) begin
    if( dr_busy ) begin
        if( rom_cs ) begin
            pxl_cnt <= 0;
            if( rom_ok && cen ) begin
                if( !half ) begin
                    plane0 <= dr_code[8] ?
                        { rom_data[31:28], rom_data[23:20], rom_data[15:12], rom_data[7:4] } :
                        { rom_data[27:24], rom_data[19:16], rom_data[11: 8], rom_data[3:0] };
                    half <= 1;
                end else begin
                    pxl_data <= { plane0,
                        { rom_data[31:28], rom_data[23:20], rom_data[15:12], rom_data[7:4] }, // plane 1
                        { rom_data[27:24], rom_data[19:16], rom_data[11: 8], rom_data[3:0] }  // plane 2
                    };
                    rom_cs  <= 0;
                end
            end
        end else begin
            pxl_cnt   <= pxl_cnt + 4'd1;
            dr_busy   <= ~&pxl_cnt;
            pxl_data  <= dr_hflip ? pxl_data<<1 : pxl_data>>1;
            buf_addr <= buf_addr + 1'd1;
        end
    end
    if( dr_start && cen ) begin
        dr_busy   <= 1;
        buf_addr  <= {1'd0,x+8'd9}; // the carry bit would break sprites on the left border
        dr_pal    <= pal;
        dr_hflip  <= hflip;
        dr_code   <= code;
        dr_ysub   <= ydiff[3:0];
        rom_cs    <= 1;
        half      <= 0;
    end
    if( hs ) begin
        dr_busy <= 0;
        rom_cs  <= 0;
    end
end

always @* begin
    case( {half, dr_code[11:8]} )
        5'h00: rom_msb = 5'd0;
        5'h10: rom_msb = 5'd2;
        5'h01: rom_msb = 5'd0;
        5'h11: rom_msb = 5'd3;

        5'h02: rom_msb = 5'd1;
        5'h12: rom_msb = 5'd4;
        5'h03: rom_msb = 5'd1;
        5'h13: rom_msb = 5'd5;

        5'h04: rom_msb = 5'd6;
        5'h14: rom_msb = 5'd8;
        5'h05: rom_msb = 5'd6;
        5'h15: rom_msb = 5'd9;

        5'h06: rom_msb = 5'd7;
        5'h16: rom_msb = 5'd10;
        5'h07: rom_msb = 5'd7;
        5'h17: rom_msb = 5'd11;

        5'h08: rom_msb = 5'd12;
        5'h18: rom_msb = 5'd14;
        5'h09: rom_msb = 5'd12;
        5'h19: rom_msb = 5'd15;

        5'h0a: rom_msb = 5'd13;
        5'h1a: rom_msb = 5'd16;
        5'h0b: rom_msb = 5'd13;
        5'h1b: rom_msb = 5'd17;

        5'h0c: rom_msb = 5'd18;
        5'h1c: rom_msb = 5'd20;
        5'h0d: rom_msb = 5'd18;
        5'h1d: rom_msb = 5'd21;

        5'h0e: rom_msb = 5'd19;
        5'h1e: rom_msb = 5'd22;
        5'h0f: rom_msb = 5'd19;
        5'h1f: rom_msb = 5'd23;
    endcase
end

jtframe_dual_ram #(.AW(9),.SIMFILE("obj.bin")) u_ram(
    .clk0   ( clk         ),
    .data0  ( cpu_dout    ),
    .addr0  ( cpu_addr    ),
    .we0    ( vram_we     ),
    .q0     ( cpu_din     ),

    .clk1   ( clk         ),
    .data1  ( 8'd0        ),
    .addr1  ( scan_addr   ),
    .we1    ( 1'b0        ),
    .q1     ( scan_dout   )
);

jtframe_obj_buffer #(
    .DW     ( 5     ),
    .AW     ( 9     ),
    .ALPHAW ( 3     ),
    .ALPHA  ( 32'd0 )
) u_buffer(
    .clk    ( clk       ),
    .LHBL   ( ~hs       ),
    .flip   ( flip      ),
    // New data writes
    .wr_data( buf_din   ),
    .wr_addr( buf_addr  ),
    .we     ( buf_we    ),
    // Old data reads (and erases)
    .rd_addr( hdump     ),
    .rd     ( pxl_cen   ),
    .rd_data( pxl       )
);

endmodule