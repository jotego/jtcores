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

module jtdd_obj #(parameter
    LAYOUT = 0,
    // do not assign
    DD    = 0,
    DD2   = 1,
    WWFSS = 2,
    OW    = LAYOUT==DD  ? 19 : // Double Dragon
            LAYOUT==DD2 ? 20 : // Double Dragon II
                          21,  // WWF SuperStars
    IDW=OW-15
)(
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
    output   [OW-1:2]  rom_addr,
    output             rom_cs,
    input      [31:0]  rom_data,
    input              rom_ok,
    output     [ 7:0]  pxl,

    input      [ 7:0]  debug_bus
);

localparam E = LAYOUT==WWFSS ? 0 : 7, // enable bit
           Y = LAYOUT==WWFSS ? 2 : 0, // y MSB
           L = LAYOUT==WWFSS ? 1 : 4; // Large sprite (16x32)

localparam [8:0] HOFFSET = LAYOUT==WWFSS ? 9'd6 : 9'd9;

// RAM area shared with CPU
reg  [ 8:0] scan;
reg  [ 2:0] offset;
reg  [ 4:0] maxline;
wire [ 8:0] next_scan = scan + 9'd5;
wire        scan_done = next_scan == 9'd510;

reg  HBL_l, wait_mem;
wire negedge_HBL = !HBL && HBL_l;

wire [31:0] sorted;
wire [ 3:0] pal;
reg  [ 7:0] ypos, scan_attr, scan_attr2, id;
reg  [ 8:0] xpos;
wire [ 8:0] sumy = {1'b0, VPOS } + { 1'b0, ypos };
wire inzone = &{ sumy[7:5], ~(oram_data[Y]^sumy[8]), sumy[4]|oram_data[L] };

reg [2:0] st;
wire      dr_busy;
reg       line, draw;

wire hflip, vflip, aux;
wire [IDW-1:0] id_msb;

assign sorted =
{rom_data[12], rom_data[13], rom_data[14], rom_data[15], rom_data[28], rom_data[29], rom_data[30], rom_data[31],
 rom_data[ 8], rom_data[ 9], rom_data[10], rom_data[11], rom_data[24], rom_data[25], rom_data[26], rom_data[27],
 rom_data[ 4], rom_data[ 5], rom_data[ 6], rom_data[ 7], rom_data[20], rom_data[21], rom_data[22], rom_data[23],
 rom_data[ 0], rom_data[ 1], rom_data[ 2], rom_data[ 3], rom_data[16], rom_data[17], rom_data[18], rom_data[19]  };

assign rom_addr[2] = ~aux;
assign hflip  = LAYOUT==WWFSS ? ~scan_attr2[7] : ~scan_attr[3];
assign vflip  = LAYOUT==WWFSS ?  scan_attr2[6] :  scan_attr[2];
assign id_msb = scan_attr2[0+:IDW];
assign pal    = LAYOUT==DD  ? scan_attr2[7:4] :
                LAYOUT==DD2 ? {1'b0, scan_attr2[7:5]} : scan_attr[7:4];

assign oram_addr = scan + {5'd0,offset};

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        HBL_l   <= 1'b0;
        scan    <= 9'd0;
        offset  <= 3'd0;
        line    <= 1'b1;
        st      <= 3'd0;
        maxline <= 5'd0;
    end else begin
        HBL_l <= HBL;
        draw  <= 0;
        case( st )
            3'd0: if(negedge_HBL) begin // wait for non blanking
                st       <= st+3'd1;
                line     <= ~line;
                scan     <= 9'd0;
                offset   <= 3'd0;
                wait_mem <= 1'b1;
                maxline  <= 5'd0;
            end
            3'd1: begin // get object's y
                wait_mem <= 1'b0;
                if( !wait_mem ) begin
                    ypos     <= oram_data; // +0
                    offset   <= 3'd1;
                    wait_mem <= 1'b1;
                    st       <= st+3'd1;
                end
            end
            3'd2: begin // advance until a visible object is found
                wait_mem  <= 1'b0;
                if( !wait_mem ) begin
                    scan_attr <= oram_data; // +1
                    xpos[8] <= LAYOUT==WWFSS ? oram_data[3] : oram_data[1];
                    if( !inzone || !oram_data[E] /*enable bit*/ ) begin
                        if( !scan_done ) begin
                            st       <= 3'd1;
                            offset   <= 3'd0; // try next object
                            scan     <= next_scan;
                            wait_mem <= 1'b1;
                        end else begin
                            st <= 3'd0; // wait for next line
                        end
                    end
                    else begin
                        ypos   <= sumy[7:0]; // update the value
                        offset <= 3'd3;
                        st     <= 3'd3;
                    end
                end else begin
                    offset <= 3'd2;
                end
            end
            3'd3: begin
                offset     <= 3'd4;
                scan_attr2 <= oram_data; // +2
                st         <= 3'd4;
            end
            3'd4: begin
                id <= oram_data; // +3
                st <= 3'd5;
            end
            3'd5: begin
                xpos[7:0] <= ~oram_data; // +4
                case(LAYOUT)
                    DD2: if( scan_attr[5:4]!=2'b00 )
                            id[1:0] <= id[1:0] + {1'b0, ypos[4] };
                    default:
                         if( scan_attr[L] )
                            id[0]   <= id[0]^ypos[4];
                endcase
                st <= 3'd6;
            end
            3'd6: begin
                if( !dr_busy ) begin
                    draw <= 1;
                    if( !scan_done & ~&maxline ) begin
                        st       <= 3'd1;
                        offset   <= 3'd0; // try next object
                        scan     <= next_scan;
                        wait_mem <= 1'b1;
                        maxline  <= maxline + 5'd1;
                    end else begin
                        st <= 3'd0; // wait for next line
                    end
                end
            end
            default: st <= 3'd0;
        endcase
    end
end

jtframe_objdraw #(
    .CW     ( OW-7 ),
    .HJUMP  (    1 ),
    .LATCH  (    1 ),
    .SWAPH  (    0 ),
    .PACKED (    0 )
) u_draw (
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .hs         ( hs        ),
    .flip       ( flip      ),
    .hdump      ( hdump     ),

    .draw       ( draw      ),
    .busy       ( dr_busy   ),
    .code       ( { id_msb, id } ),
    .xpos       ( xpos-HOFFSET ),
    .ysub       ( ypos[3:0] ),
    // optional zoom, keep at zero for no zoom
    .hzoom      ( 6'd0      ),
    .hz_keep    ( 1'b0      ), // set at 1 for the first tile

    .hflip      ( hflip     ),
    .vflip      ( vflip     ),
    .pal        ( pal       ),

    .rom_addr   ( { rom_addr[OW-1:7], aux, rom_addr[3+:4] } ),
    .rom_cs     ( rom_cs    ),
    .rom_ok     ( rom_ok    ),
    .rom_data   ( sorted    ),

    .pxl        ( pxl       )
);

endmodule