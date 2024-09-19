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
    Date: 22-9-2023 */

module jtshouse_obj(
    input             rst,
    input             clk,

    input             pxl_cen,

    input      [11:0] cpu_addr,
    input             cpu_rnw,
    input      [ 7:0] cpu_dout,
    input             cs,

    input             hs,
    input             lvbl,
    output            flip,
    input      [ 8:0] vrender,
    input      [ 8:0] hdump,

    // Video RAM
    output     [11:1] oram_addr,
    input      [15:0] oram_dout,
    output            oram_we,
    output     [15:0] oram_din,

    // Object tile readout (SDRAM)
    output            rom_cs,
    input             rom_ok,
    output     [19:2] rom_addr,
    input      [31:0] rom_data,

    // pixel output
    output     [10:0] pxl,
    output     [ 2:0] prio,

    input      [ 7:0] debug_bus,
    output     [ 7:0] st_dout,
    // IOCTL dump
    input      [ 3:0] ioctl_addr,
    output     [ 7:0] ioctl_din
);

parameter [8:0] VB_START=9'h0F8, VB_END=9'h110;

// Registers
wire [ 8:0] pre_xos;
wire [ 7:0] pre_yos;
reg  [ 8:0] xoffset,yoffset;
wire        mmr_cs;
// LUT Scan
wire [ 1:0] vsize, vos;
wire [17:2] pre_addr;
reg  [10:0] code;
reg  [ 9:0] attr;
reg  [ 9:0] xpos;
reg  [ 8:0] ydiff, ypos, xraw;
reg  [ 6:0] scan_obj;
wire [ 6:0] dma_obj;
reg  [ 4:0] ysub, nx_ysub;
wire [ 2:0] oram_sub;
reg  [ 1:0] scan_sub, dr_vmsb, st, hsize, hos, trunc,
            dr_hmsb, nx_hmsb, dr_hsize;
reg         inzone, vflip, hflip, draw, cen, scan_bsy, half, hs_l;
wire        dr_bsy, dma_bsy, dma_on;
wire [31:0] rom_swap;

assign {vos, vsize } = oram_dout[4:1];
assign mmr_cs  = &{ cs, cpu_addr[11:4] };
assign rom_swap = {
    rom_data[24+:4], rom_data[28+:4],
    rom_data[16+:4], rom_data[20+:4],
    rom_data[ 8+:4], rom_data[12+:4],
    rom_data[ 0+:4], rom_data[ 4+:4]
};

always @* begin
    case(vsize)
        0: ypos = -(oram_dout[15:8] - 8'd16); // 16
        1: ypos = -(oram_dout[15:8] - 8'd24); //  8
        2: ypos = -(oram_dout[15:8]);         // 32
        3: ypos = -(oram_dout[15:8] - 8'd28); //  4
    endcase

    ydiff = ({1'b0, (flip ? ~(vrender[7:0] - 8'h20) : vrender[7:0])} + yoffset + 8'h10) - ypos;
    ydiff[8] = 0;

    case(vsize)
        0: inzone = ydiff[8-:5]==0; // 16 pxl
        1: inzone = ydiff[8-:6]==0; //  8 pxl
        2: inzone = ydiff[8-:4]==0; // 32 pxl
        3: inzone = ydiff[8-:7]==0; //  4 pxl
    endcase

    nx_ysub = ydiff[4:0];
    case( vsize )
        0:   nx_ysub[4:3] = {vos[1], ydiff[3] ^ oram_dout[0]};
        1,3: nx_ysub[4:3] = vos[1:0];
        2:   nx_ysub[4:3] = ydiff[4:3] ^ {2{oram_dout[0]}};
        default:;
    endcase
    case( hsize )
        0: nx_hmsb = { hos[1], 1'b0}; // 16 pxl
        1,3: nx_hmsb = hos; // 8/4 pxl
        default: nx_hmsb = { hflip, 1'b0 }; // 32 pxl
    endcase
end

assign oram_addr = { 1'b1, dma_bsy ? {dma_obj, oram_sub } : {scan_obj, 1'b1, scan_sub} };
assign rom_addr  = { pre_addr[17-:11],
            dr_vmsb[1],      // V16
            dr_hmsb[1],      // H16
            dr_vmsb[0],      // V8
            pre_addr[2+:3],  // V4/2/1
            dr_hsize[0] ? dr_hmsb[0] : pre_addr[6] /* H8 */ };

always @(posedge clk) begin
    xoffset  <= pre_xos-(flip ? -9'd7 : 9'd8); //+{debug_bus[7],debug_bus};
    yoffset  <= pre_yos+(flip ? 9'd1 : -9'd1);
end

// LUT scan
always @(posedge clk, posedge rst) begin
    if( rst ) begin
        scan_obj <= 0;
        hs_l     <= 0;
        cen      <= 0;
        st       <= 0;
        draw     <= 0;
        half     <= 0;
        dr_vmsb  <= 0;
        dr_hmsb  <= 0;
    end else begin
        cen     <= ~cen;
        hs_l    <= hs;
        draw    <= 0;
        if( scan_bsy && cen)  begin
            if(!half) st <= st+1'd1;
            case( st )
                0: begin // read positions 15, 14
                    { attr[9:7], vflip } <= { oram_dout[7:5], oram_dout[0] };
                    scan_sub <= 2;
                    ysub     <= nx_ysub;
                    if( !inzone ) begin
                        scan_sub <= 3;
                        scan_obj <= scan_obj+7'd1;
                        st <= 0;
                        if( &scan_obj[6:1] ) scan_bsy <= 0;
                    end
                end
                1: begin // read 13, 12
                    attr[6:0] <= oram_dout[7:1];
                    // xraw      <= {oram_dout[0], oram_dout[15:8]};
                    xpos      <= ({1'b0,oram_dout[0], oram_dout[15:8]}+xoffset);
                    scan_sub   <= 1;
                end
                2: begin // read 11, 10
                    code  <= { oram_dout[2:0], oram_dout[15:8] };
                    hsize <= oram_dout[7:6];
                    hos   <= oram_dout[4:3]; // H offset
                    hflip <= oram_dout[5];
                end
                3: begin
                    if( !dr_bsy ) begin
                        dr_vmsb  <= ysub[4:3];
                        dr_hmsb  <= nx_hmsb;
                        dr_hsize <= hsize;
                        case( hsize )
                            1: trunc <= 2'b10;
                            3: trunc <= 2'b11;
                            default: trunc <= 0;
                        endcase
                        draw     <= 1;
                        if( half ) begin // half of 32-pxl object
                            half <= 0;
                            xpos <= xpos + 9'h10;
                            dr_hmsb[1] <= ~dr_hmsb[1];
                        end
                        if( hsize==2 && !half ) begin
                            st   <= 3;
                            half <= 1;
                        end
                        if( hsize!=2 || half ) begin
                            scan_obj <= scan_obj+7'd1;
                            scan_sub <= 3;
                            st       <= 0;
                            if( &scan_obj[6:1] ) scan_bsy <= 0;
                        end
                    end else begin
                        st <= 3;
                    end
                end
            endcase
        end
        if( hs && !hs_l ) begin
            scan_bsy <= 1;
            scan_sub <= 3;
            scan_obj <= 0;
            st       <= 0;
            cen      <= 0;
            half     <= 0;
        end
    end
end

jtshouse_obj_dma u_dma(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .lvbl       ( lvbl      ),
    .hs         ( hs        ),
    .dma_on     ( dma_on    ),
    .dma_bsy    ( dma_bsy   ),
    .dma_obj    ( dma_obj   ),
    .oram_sub   ( oram_sub  ),
    .oram_dout  ( oram_dout ),
    .oram_we    ( oram_we   ),
    .oram_din   ( oram_din  )
);

jtframe_objdraw_trunc #(
    .CW         (  11   ),
    .PW         (  14   ),
    // SWAPH =  0,
    .LATCH      (   1   ),
    // FLIP_OFFSET=0,
    .ALPHA      (  15   ),
    .PACKED     (   1   )
)u_draw(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .hs         ( hs        ),
    .flip       ( flip      ),
    .hdump      ( hdump     ),

    .draw       ( draw      ),
    .busy       ( dr_bsy    ),
    .code       ( code      ),
    .xpos       ( xpos[8:0] ),
    .ysub       ( ysub[3:0] ),
    // no zoom
    .hzoom      ( 6'd0      ),
    .hz_keep    ( 1'd0      ),
    .trunc      ( trunc     ),

    .hflip      ( hflip     ),
    .vflip      ( vflip     ),
    .pal        ( attr      ),

    .rom_addr   ( pre_addr  ),
    .rom_cs     ( rom_cs    ),
    .rom_ok     ( rom_ok    ),
    .rom_data   ( rom_swap  ),

    .pxl        ({prio, pxl})
);

jtshouse_obj_mmr #(.SEEK(32)) u_mmr(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cs         ( mmr_cs        ),
    .addr       ( cpu_addr[3:0] ),
    .rnw        ( cpu_rnw       ),
    .din        ( cpu_dout      ),
    .dout       (               ),
    .xoffset    ( pre_xos       ),
    .yoffset    ( pre_yos       ),
    .flip       ( flip          ),
    .dma_on     ( dma_on        ),
    .ioctl_addr ( ioctl_addr    ),
    .ioctl_din  ( ioctl_din     ),
    .debug_bus  ( debug_bus     ),
    .st_dout    ( st_dout       )
);

endmodule