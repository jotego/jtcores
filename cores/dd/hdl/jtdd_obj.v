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
    Date: 2-12-2019 */

// Schematics 3-7/10 OBJ
// Object layer
// Max 32 sprites per line

module jtdd_obj(
    input              clk,
    input              rst,
    input              pxl_cen,
    // screen
    input      [ 8:0]  hdump,
    input      [ 7:0]  VPOS,
    input              flip,
    input              HBL,
    input              hs,
    // RAM
    output     [ 8:0]  oram_addr,
    input      [ 7:0]  oram_data,
    // ROM access
    output     [19:2]  rom_addr,
    output             rom_cs,
    input      [31:0]  rom_data,
    input              rom_ok,
    output     [ 7:0]  pxl,

    input      [7:0]   debug_bus
);

// RAM area shared with CPU
reg  [ 8:0] ram_addr, scan;
reg  [ 2:0] offset;
reg  [ 4:0] maxline;
wire [ 8:0] next_scan = scan + 9'd5;
wire        scan_done = next_scan == 9'd510;

reg  HBL_l, wait_mem;
wire negedge_HBL = !HBL && HBL_l;

reg  [ 7:0] scan_y, scan_attr, scan_attr2, scan_id;
reg  [ 8:0] scan_x;
wire [ 8:0] sumy = {1'b0, VPOS } + { 1'b0, scan_y };
wire inzone = &{ sumy[7:5], ~(oram_data[0]^sumy[8]), sumy[4]|oram_data[4] };

wire dr_busy;
reg  line, draw;

reg [2:0] state;

assign oram_addr = scan + {5'd0,offset};

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        HBL_l   <= 1'b0;
        scan    <= 9'd0;
        offset  <= 3'd0;
        line    <= 1'b1;
        state   <= 3'd0;
        maxline <= 5'd0;
    end else begin
        HBL_l <= HBL;
        draw  <= 0;
        case( state )
            3'd0: if(negedge_HBL) begin // wait for non blanking
                state    <= state+3'd1;
                line     <= ~line;
                scan     <= 9'd0;
                offset   <= 3'd0;
                wait_mem <= 1'b1;
                maxline  <= 5'd0;
            end
            3'd1: begin // get object's y
                wait_mem <= 1'b0;
                if( !wait_mem ) begin
                    scan_y    <= oram_data; // +0
                    offset   <= 3'd1;
                    wait_mem <= 1'b1;
                    state    <= state+3'd1;
                end
            end
            3'd2: begin // advance until a visible object is found
                wait_mem  <= 1'b0;
                if( !wait_mem ) begin
                    scan_attr <= oram_data; // +1
                    scan_x[8] <= oram_data[1];
                    if( !inzone || !oram_data[7] /*enable bit*/ ) begin
                        if( !scan_done ) begin
                            state    <= 3'd1;
                            offset   <= 3'd0; // try next object
                            scan     <= next_scan;
                            wait_mem <= 1'b1;
                        end else begin
                            state    <= 3'd0; // wait for next line
                        end
                    end
                    else begin
                        scan_y <= sumy[7:0]; // update the value
                        offset <= 3'd3;
                        state  <= 3'd3;
                    end
                end else begin
                    offset <= 3'd2;
                end
            end
            3'd3: begin
                offset     <= 3'd4;
                scan_attr2 <= oram_data; // +2
                state      <= 3'd4;
            end
            3'd4: begin
                scan_id <= oram_data; // +3
                state   <= 3'd5;
            end
            3'd5: begin
                scan_x[7:0] <= ~oram_data; // +4
                `ifdef DD2
                if( scan_attr[5:4]!=2'b00 )
                    scan_id[1:0] <= scan_id[1:0] + {1'b0, scan_y[4] };
                `else
                if( scan_attr[4])
                    scan_id[0] <= scan_id[0]^scan_y[4];
                `endif
                state <= 3'd6;
            end
            3'd6: begin
                if( !dr_busy ) begin
                    draw <= 1;
                    if( !scan_done & ~&maxline ) begin
                        state    <= 3'd1;
                        offset   <= 3'd0; // try next object
                        scan     <= next_scan;
                        wait_mem <= 1'b1;
                        maxline  <= maxline + 5'd1;
                    end else begin
                        state    <= 3'd0; // wait for next line
                    end
                end
            end
            default: state <= 3'd0;
        endcase
    end
end

wire        hflip = ~scan_attr[3];
wire        vflip = scan_attr[2];
`ifdef DD2
wire [ 4:0] id_top= scan_attr2[4:0];
wire [ 3:0] pal   = {1'b0, scan_attr2[7:5]};
`else
wire [ 4:0] id_top= {1'b0, scan_attr2[3:0]};
wire [ 3:0] pal   = scan_attr2[7:4];
`endif

wire [31:0] sorted =
{rom_data[12], rom_data[13], rom_data[14], rom_data[15], rom_data[28], rom_data[29], rom_data[30], rom_data[31],
 rom_data[ 8], rom_data[ 9], rom_data[10], rom_data[11], rom_data[24], rom_data[25], rom_data[26], rom_data[27],
 rom_data[ 4], rom_data[ 5], rom_data[ 6], rom_data[ 7], rom_data[20], rom_data[21], rom_data[22], rom_data[23],
 rom_data[ 0], rom_data[ 1], rom_data[ 2], rom_data[ 3], rom_data[16], rom_data[17], rom_data[18], rom_data[19]  };
wire aux;

assign rom_addr[2] = ~aux;

jtframe_objdraw #(
    .CW     ( 13 ),
    .HJUMP  (  1 ),
    .LATCH  (  1 ),
    .SWAPH  (  0 ),
    .PACKED (  0 )
) u_draw (
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .hs         ( hs        ),
    .flip       ( flip      ),
    .hdump      ( hdump     ),

    .draw       ( draw      ),
    .busy       ( dr_busy   ),
    .code       ( { id_top, scan_id } ),
    .xpos       (scan_x-9'h8),
    .ysub       ( scan_y[3:0] ),
    // optional zoom, keep at zero for no zoom
    .hzoom      ( 6'd0      ),
    .hz_keep    ( 1'b0      ), // set at 1 for the first tile

    .hflip      ( hflip     ),
    .vflip      ( vflip     ),
    .pal        ( pal       ),

    .rom_addr   ( { rom_addr[19:7], aux, rom_addr[3+:4] } ),
    .rom_cs     ( rom_cs    ),
    .rom_ok     ( rom_ok    ),
    .rom_data   ( sorted    ),

    .pxl        ( pxl       )
);

endmodule