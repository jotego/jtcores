// SPDX-License-Identifier: GPL-3.0-or-later

module jtmzone_obj(
    input               rst,
    input               clk,
    input               clk24,
    input               pxl_cen,

    input        [ 9:0] objram_addr,
    input        [ 7:0] objram_din,
    input               objram_cs,
    input               cpu_rnw,
    output       [ 7:0] objram_dout,

    input               LVBL,
    input               HS,
    input        [ 8:0] hdump,
    input        [ 8:0] vdump,
    input               flip,

    output       [12:0] rom_addr,
    output              rom_cs,
    input        [31:0] rom_data,
    input               rom_ok,

    input        [ 3:0] prog_data,
    input        [ 7:0] prog_addr,
    input               prog_en,

    output       [ 3:0] pxl
);

// PCB scan/DMA timing and ROM layout: doc/timing.md, "PCB object hardware".

localparam [8:0] OBJ_START       = 9'd40;
localparam [8:0] OBJ_ARM         = OBJ_START - 9'd1;
localparam [9:0] OBJ_SCAN_LAST   = 10'd35;
localparam [9:0] OBJ_ENTRY_BYTES = 10'd4;
localparam [9:0] DMA_COPY_BYTES  = 10'd240;
localparam [9:0] DMA_HCOUNTS     = DMA_COPY_BYTES*10'd4 + 10'd1;

reg        lvbl_l, hs_l;
reg [ 9:0] oram_addr;
reg [ 9:0] scan_obj;
reg [ 2:0] scan_st;
reg        scan_last;
reg        cen2, scan_start_x;
reg [ 7:0] attr, ypos, code;
reg [ 9:0] dma_addr;
reg [ 7:0] dma_din;
reg        dma_en, dma_start_wait, dma_hs_wait, dma_wr;
reg [ 9:0] dma_hcnt;

reg        draw;
reg [ 7:0] dr_code;
reg [ 8:0] dr_xpos;
reg [ 3:0] dr_pal;
reg        dr_hflip, dr_vflip;
reg [ 3:0] dr_ysub;
wire       busy;
wire       scan_start = pxl_cen && hdump == OBJ_ARM;
wire       vblk_start = !LVBL && lvbl_l;
wire       hs_start = HS && !hs_l;
wire       dma_copy = pxl_cen && dma_hcnt[1:0]==2'd0 && dma_addr != DMA_COPY_BYTES;
wire       dma_we = dma_en && dma_wr;
wire       objram_we = objram_cs && !cpu_rnw;
wire [7:0] oram_dout;
wire [7:0] scan_dout;
// Real-PCB portrait comparison places the simulated sprites one pixel too
// far right. Use the raw vertical count; the previous +1 caused that shift.
wire [7:0] draw_vdump = vdump[7:0];
wire [8:0] ysum   = {1'b0,draw_vdump} + {1'b0,ypos};
wire       inzone = ysum[7:4] == 4'hf;
wire [3:0] ysub   = ysum[3:0] ^ {4{attr[7]}};
wire [1:0] scan_byte = scan_st==3'd1 ? 2'd0 :
                       scan_st==3'd2 ? 2'd1 :
                       scan_st==3'd3 ? 2'd2 : 2'd3;
wire [9:0] scan_addr = { scan_obj[7:0], scan_byte };
// Kicker-style object drawer. It reads the raw PCB/MRA object layout directly:
// one 32-bit SDRAM word contains two 16-bit {byte23,byte01} groups. The drawer
// writes decoded pixels into a one-line object buffer.

jtframe_dual_ram #(
`ifdef SIMSCENE
    .SIMFILE ( "obj.bin" ),
`endif
    .AW ( 10 ),
    .DW ( 8  )
) u_objram(
    .clk0   ( clk24        ),
    .data0  ( objram_din   ),
    .addr0  ( objram_addr  ),
    .we0    ( objram_we    ),
    .q0     ( objram_dout  ),

    .clk1   ( clk          ),
    .data1  ( 8'd0         ),
    .addr1  ( oram_addr    ),
    .we1    ( 1'b0         ),
    .q1     ( oram_dout    )
);

always @(posedge clk) begin
    lvbl_l <= LVBL;
    hs_l   <= HS;
    cen2   <= ~cen2;
    if( scan_start ) scan_start_x <= 1'b1;
    else if( cen2 )  scan_start_x <= 1'b0;
    if( rst ) begin
        scan_obj    <= 10'd0;
        scan_st     <= 3'd0;
        scan_last   <= 1'b0;
        cen2        <= 1'b0;
        scan_start_x<= 1'b0;
        draw        <= 1'b0;
        dr_code     <= 8'd0;
        dr_xpos     <= 9'd0;
        dr_pal      <= 4'd0;
        dr_hflip    <= 1'b0;
        dr_vflip    <= 1'b0;
        dr_ysub     <= 4'd0;
        lvbl_l    <= 1'b0;
        hs_l      <= 1'b0;
    end else begin
        if( vblk_start ) begin
            scan_st <= 3'd0;
            draw    <= 1'b0;
        end else if( cen2 ) begin
            draw <= 1'b0;
            case( scan_st )
                3'd0: if( scan_start_x ) begin
                    scan_obj <= OBJ_SCAN_LAST;
                    scan_st  <= 3'd1;
                end
                3'd1: if( !busy ) begin
                    attr    <= scan_dout;
                    scan_st <= 3'd2;
                end
                3'd2: begin
                    ypos    <= scan_dout;
                    scan_st <= 3'd3;
                end
                3'd3: begin
                    code     <= scan_dout;
                    scan_st  <= 3'd4;
                end
                3'd4: begin
                    dr_code      <= code;
                    // Preserve the raw PCB object coordinate in both screen
                    // orientations. Global flip changes the display origin,
                    // not the coordinate written into the line buffer.
                    dr_xpos      <= {1'b0, scan_dout};
                    dr_pal       <= attr[3:0];
                    // MAME and the 083 shifter behavior show this attribute
                    // bit is active-low for horizontal flip.
                    dr_hflip     <= ~attr[6];
                    dr_vflip     <= attr[7];
                    dr_ysub      <= ysub;
                    draw         <= inzone;
                    scan_last    <= scan_obj==10'd0;
                    if( scan_obj!=10'd0 ) scan_obj <= scan_obj-10'd1;
                    scan_st <= 3'd5;
                end
                3'd5: scan_st <= scan_last ? 3'd0 : 3'd1;
                default: scan_st <= 3'd0;
            endcase
        end
    end
end

always @(posedge clk) begin
    if( rst ) begin
        oram_addr <= 10'd0;
        dma_addr  <= 10'd0;
        dma_din   <= 8'd0;
        dma_en    <= 1'b0;
        dma_start_wait <= 1'b0;
        dma_hs_wait <= 1'b0;
        dma_wr    <= 1'b0;
        dma_hcnt  <= 10'd0;
    end else begin
        if( vblk_start ) begin
            dma_start_wait <= 1'b1;
            dma_hs_wait <= 1'b0;
            dma_en    <= 1'b0;
            dma_wr    <= 1'b0;
            dma_hcnt  <= 10'd0;
            oram_addr <= 10'd0;
            dma_addr  <= 10'd0;
            dma_din   <= 8'd0;
        end else if( dma_start_wait && hs_start ) begin
            dma_start_wait <= 1'b0;
            dma_hs_wait <= 1'b1;
        end else if( dma_hs_wait && pxl_cen ) begin
            dma_hs_wait <= 1'b0;
            dma_start_wait <= 1'b0;
            dma_en    <= 1'b1;
            dma_wr    <= 1'b0;
            oram_addr <= 10'd0;
            dma_addr  <= 10'd0;
            dma_din   <= 8'd0;
            dma_hcnt  <= 10'd0;
        end else if( dma_en ) begin
            if( dma_copy ) begin
                dma_din   <= oram_dout;
                oram_addr <= dma_addr + 10'd1;
                dma_wr    <= 1'b1;
            end else if( dma_wr ) begin
                dma_addr <= dma_addr + 10'd1;
                dma_wr <= 1'b0;
            end

            if( pxl_cen && dma_hcnt != DMA_HCOUNTS )
                dma_hcnt <= dma_hcnt + 10'd1;

            if( pxl_cen && dma_hcnt==DMA_HCOUNTS && dma_addr==DMA_COPY_BYTES && !dma_wr ) begin
                dma_en <= 1'b0;
            end
        end
    end
end

// DMA buffer
jtframe_dual_ram #(
    .AW ( 10 ),
    .DW ( 8  )
) u_table(
    .clk0   ( clk              ),
    .data0  ( dma_din          ),
    .addr0  ( dma_addr         ),
    .we0    ( dma_we           ),
    .q0     (                  ),

    .clk1   ( clk              ),
    .data1  ( 8'd0             ),
    .addr1  ( scan_addr        ),
    .we1    ( 1'b0             ),
    .q1     ( scan_dout        )
);

jtmzone_objdraw u_draw(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .pxl_cen    ( pxl_cen       ),
    .cen2       ( cen2          ),
    .HS         ( HS            ),
    .hdump      ( hdump         ),
    .flip       ( flip          ),

    .draw       ( draw          ),
    .busy       ( busy          ),

    .code       ( dr_code       ),
    .xpos       ( dr_xpos       ),
    .pal        ( dr_pal        ),
    .hflip      ( dr_hflip      ),
    .ysub       ( dr_ysub       ),

    .prog_data  ( prog_data     ),
    .prog_addr  ( prog_addr     ),
    .prog_en    ( prog_en       ),

    .rom_addr   ( rom_addr      ),
    .rom_cs     ( rom_cs        ),
    .rom_ok     ( rom_ok        ),
    .rom_data   ( rom_data      ),

    .pxl        ( pxl           )
);

endmodule
