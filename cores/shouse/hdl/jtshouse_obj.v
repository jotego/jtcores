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
    input             flip,
    input      [ 8:0] vrender,
    input      [ 8:0] hdump,

    // Video RAM
    output     [11:1] oram_addr,
    input      [15:0] oram_dout,
    output reg        oram_we,
    output reg [15:0] oram_din,

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
    input      [ 2:0] ioctl_addr,
    output     [ 7:0] ioctl_din
);

// Registers
wire [ 7:0] pre_yos;
wire [ 8:0] pre_xos;
reg  [ 7:0] yoffset;
reg  [ 8:0] xoffset;
wire        mmr_cs;
// DMA
reg         nx_dma, dma_bsy, hs_l, lvbl_l;
reg  [ 6:0] dma_obj;
reg  [ 2:0] oram_sub, dma_sub;
reg  [ 1:0] dma_st;
wire        dma_on, vb_edge;
// LUT Scan
wire [ 1:0] vsize, vos;
wire [17:2] pre_addr;
reg  [10:0] code;
reg  [ 9:0] attr;
reg  [ 8:0] xpos;
reg  [ 8:0] ydiff, ypos;
reg  [ 6:0] scan_obj;
reg  [ 4:0] ysub, nx_ysub;
reg  [ 1:0] scan_sub, dr_vmsb, st, hsize, hos,
            dr_hmsb, nx_hmsb, dr_hsize, dr_hos;
reg         inzone, vflip, hflip, draw, cen, scan_bsy, half;
wire        dr_bsy;
wire [31:0] rom_swap;

assign {vos, vsize } = oram_dout[4:1];
assign vb_edge = ~lvbl & lvbl_l;
assign mmr_cs  = &{ cs, cpu_addr[11:4] };
assign rom_swap = {
    rom_data[24+:4], rom_data[28+:4],
    rom_data[16+:4], rom_data[20+:4],
    rom_data[ 8+:4], rom_data[12+:4],
    rom_data[ 0+:4], rom_data[ 4+:4]
};

always @* begin
    ypos  = 9'h28+{1'b0,oram_dout[15:8]}+{1'b0,yoffset};
    ydiff = ypos+{1'b0,vrender[7:0]};
    if(debug_bus[4]) ydiff[8] = 0;
    case(vsize)
        0: inzone = ydiff[8-:5]==0; // 16 pxl
        1: inzone = ydiff[8-:6]==0; //  8 pxl
        2: inzone = ydiff[8-:4]==0; // 32 pxl
        3: inzone = ydiff[8-:7]==0; //  4 pxl
    endcase
    nx_ysub = ydiff[4:0];
    case( vsize )
        0:   nx_ysub[4]   = vos[1];
        1,3: nx_ysub[4:3] = vos[1:0];
        default:;
    endcase
    case( hsize )
        0: nx_hmsb = { hos[1], 1'b0}; // 16 pxl
        1,3: nx_hmsb = hos; // 8/4 pxl
        default: nx_hmsb = { hflip, 1'b0 };
    endcase
end

assign oram_addr = { 1'b1, dma_bsy ? {dma_obj, oram_sub } : {scan_obj, 1'b1, scan_sub} };
assign rom_addr  = { pre_addr[17-:11],
            dr_vmsb[1],      // V16
            dr_hmsb[1],      // H16
            dr_vmsb[0],      // V8
            pre_addr[2+:3],  // V4/2/1
            dr_hsize[0] ? dr_hmsb[0] : pre_addr[6] /* H8 */ };

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
                    { xpos[7:0], attr[6:0], xpos[8] } <= oram_dout;
                    scan_sub   <= 1;
                end
                2: begin // read 11, 10
                    { code[7:0], hsize, hflip, hos, code[10:8] } <= oram_dout;
                    xpos <= xpos + xoffset + 9'h43;
                end
                3: begin
                    if( !dr_bsy ) begin
                        dr_vmsb  <= ysub[4:3]^{2{vflip}};
                        dr_hmsb  <= nx_hmsb;
                        dr_hsize <= hsize;
                        dr_hos   <= hos;
                        draw     <= 1;
                        if( half ) begin
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
        if( hs && !hs_l && vrender<9'h1f0 && vrender>'h10e ) begin
            scan_bsy <= 1;
            scan_sub <= 3;
            scan_obj <= 0;
            st       <= 0;
            cen      <= 0;
        end
    end
end

jtframe_objdraw #(
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
    .xpos       ( xpos      ),
    .ysub       ( ysub[3:0] ),
    // no zoom
    .hzoom      ( 6'd0      ),
    .hz_keep    ( 1'd0      ),

    .hflip      ( hflip     ),
    .vflip      ( vflip     ),
    .pal        ( attr      ),

    .rom_addr   ( pre_addr  ),
    .rom_cs     ( rom_cs    ),
    .rom_ok     ( rom_ok    ),
    .rom_data   ( rom_swap  ),

    .pxl        ({prio, pxl})
);

// DMA - sequence length NOT measured on PCB yet
always @* begin
    case( {oram_we, dma_sub} )
        4'b0_001: oram_sub = 3'b010; // 4-5
        4'b0_010: oram_sub = 3'b011; // 6-7
        4'b0_100: oram_sub = 3'b100; // 8-9

        4'b1_001: oram_sub = 3'b101; // 10-11
        4'b1_010: oram_sub = 3'b110; // 12-13
        4'b1_100: oram_sub = 3'b111; // 14-15
        default:  oram_sub = 3'b111;
    endcase
end

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        nx_dma   <= 0;
        dma_bsy  <= 0;
        dma_st   <= 0;
        dma_obj  <= 0;
        dma_sub  <= 0;
        lvbl_l   <= 0;
    end else begin
        dma_st <= dma_st+2'd1;
        lvbl_l <= lvbl;

        if( dma_on `ifdef SIMSCENE || (hs&&lvbl) `endif ) nx_dma <= 1;
        if( nx_dma && vb_edge ) begin
            nx_dma   <= 0;
            dma_bsy  <= 1;
            dma_st   <= 0;
            dma_obj  <= 0;
            dma_sub  <= 1;
            // the global offsets are changed by the CPU in the middle of the frame
            // so they must be registered during blanking
            xoffset  <= pre_xos-9'd2;
            yoffset  <= pre_yos;
        end
        if( dma_bsy ) case(dma_st)
            2: begin
                oram_din <= oram_dout;
                oram_we  <= 1;
            end
            3: begin
                oram_we <= 0;
                if( dma_sub[2] ) begin
                    dma_obj <= dma_obj+7'd1;
                    if( &dma_obj[6:1] ) dma_bsy <= 0;
                end
                dma_sub <= { dma_sub[1:0], dma_sub[2] };
            end
            default:;
        endcase
    end
end

jtshouse_obj_mmr #(.SEEK(32)) u_mmr(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cs         ( mmr_cs        ),
    .addr       ( cpu_addr[2:0] ),
    .rnw        ( cpu_rnw       ),
    .din        ( cpu_dout      ),
    .dout       (               ),
    .xoffset    ( pre_xos       ),
    .yoffset    ( pre_yos       ),
    .dma_on     ( dma_on        ),
    .ioctl_addr ( ioctl_addr    ),
    .ioctl_din  ( ioctl_din     ),
    .debug_bus  ( debug_bus     ),
    .st_dout    ( st_dout       )
);

endmodule