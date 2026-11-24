/* SPDX-FileCopyrightText: 2026 Ulf Skutnabba
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 23-10-2026 */

module jtmzone_obj(
    input              rst,
    input              clk,
    input              pxl_cen,

    output reg [ 9:0]  oram_addr,
    input      [ 7:0]  oram_dout,

    input              LVBL,
    input              HS,
    input      [ 8:0]  hdump,
    input      [ 8:0]  vdump,
    input              flip,

    output     [12:0]  rom_addr,
    output             rom_cs,
    input      [31:0]  rom_data,
    input              rom_ok,

    input      [ 3:0]  prog_data,
    input      [ 7:0]  prog_addr,
    input              prog_en,

    output     [ 3:0]  pxl
);

// PCB scan/DMA timing and ROM layout: doc/timing.md, "PCB object hardware".
// JTFRAME helper comparison and retained scan/readout controls: doc/renderers.md.

localparam [ 8:0]  OBJ_START       = 9'd40;
localparam [ 8:0]  OBJ_ARM         = OBJ_START - 9'd1;
localparam [ 2:0]  IDLE=0, LOAD=1, CHECK=2, START=3, WAIT=4;
localparam [ 9:0]  DMA_COPY_BYTES  = 10'd240;
localparam [ 9:0]  DMA_HCOUNTS     = DMA_COPY_BYTES*10'd4 + 10'd1;

reg          lvbl_l,hs_l;
reg  [ 5:0]  scan_obj;
reg  [ 2:0]  scan_st;
reg  [ 9:0]  dma_addr;
reg  [ 7:0]  dma_din;
reg          dma_en, dma_start_wait, dma_hs_wait, dma_wr;
reg  [ 9:0]  dma_hcnt;

reg          draw;
reg  [ 7:0]  dr_code;
reg  [ 8:0]  dr_xpos;
reg  [ 3:0]  dr_pal;
reg          dr_hflip;
reg  [ 3:0]  dr_ysub;
wire         busy;
wire         scan_start = pxl_cen && hdump == OBJ_ARM;
wire         vblk_start = !LVBL && lvbl_l;
wire         hs_start = HS && !hs_l;
wire         dma_copy = pxl_cen && dma_hcnt[1:0]==2'd0 && dma_addr != DMA_COPY_BYTES;
wire         dma_we = dma_en && dma_wr;
wire [31:0]  scan_dout;
wire [ 8:0]  ysum={1'b0,vdump[7:0]}+{1'b0,scan_dout[15:8]};
wire         inzone=ysum[7:4]==4'hf;
wire [ 3:0]  ysub=ysum[3:0]^{4{scan_dout[7]}};
// The byte-wide DMA port writes lanes of a packed entry. Allow one RAM
// clock after changing scan_obj before consuming all four attributes.
always @(posedge clk) begin
    lvbl_l <= LVBL;
    hs_l   <= HS;
    draw   <= 1'b0;
    if( rst ) begin
        scan_obj <= 6'd0;
        scan_st  <= IDLE;
        dr_code  <= 8'd0;
        dr_xpos  <= 9'd0;
        dr_pal   <= 4'd0;
        dr_hflip <= 1'b0;
        dr_ysub  <= 4'd0;
        lvbl_l   <= 1'b0;
        hs_l     <= 1'b0;
    end else if( vblk_start ) scan_st <= IDLE;
    else case( scan_st )
        IDLE: if( scan_start ) begin
            scan_obj <= 6'd35;
            scan_st  <= LOAD;
        end
        LOAD: scan_st <= CHECK;
        CHECK: begin
            dr_code  <= scan_dout[23:16];
            dr_xpos  <= {1'b0,scan_dout[31:24]};
            dr_pal   <= scan_dout[3:0];
            dr_hflip <= ~scan_dout[6];
            dr_ysub  <= ysub;
            if( inzone ) scan_st <= START;
            else if( scan_obj==0 ) scan_st <= IDLE;
            else begin
                scan_obj <= scan_obj-1'b1;
                scan_st  <= LOAD;
            end
        end
        START: if( !busy ) begin
            draw    <= 1'b1;
            scan_st <= WAIT;
        end
        // Wait for the registered request to be accepted before checking
        // completion; otherwise the next entry could replace its attributes.
        WAIT: if( !draw && !busy ) begin
            if( scan_obj==0 ) scan_st <= IDLE;
            else begin
                scan_obj <= scan_obj-1'b1;
                scan_st  <= LOAD;
            end
        end
        default: scan_st <= IDLE;
    endcase
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

jtframe_dual_ram32 #(.AW(10)) u_table(
    .clk0            ( clk                                  ),
    .data0           ( {4{dma_din}}                         ),
    .addr0           ( dma_addr[9:2]                        ),
    .we0             ( dma_we?(4'b1<<dma_addr[1:0]):4'd0    ),
    .q0              (                                      ),
    .clk1            ( clk                                  ),
    .data1           ( 32'd0                                ),
    .addr1           ( {2'd0,scan_obj}                      ),
    .we1             ( 4'd0                                 ),
    .q1              ( scan_dout                            )
);

jtmzone_objdraw u_draw(
    .rst             ( rst                                  ),
    .clk             ( clk                                  ),
    .pxl_cen         ( pxl_cen                              ),
    .HS              ( HS                                   ),
    .hdump           ( hdump                                ),
    .flip            ( flip                                 ),
    .draw            ( draw                                 ),
    .busy            ( busy                                 ),
    .code            ( dr_code                              ),
    .xpos            ( dr_xpos                              ),
    .pal             ( dr_pal                               ),
    .hflip           ( dr_hflip                             ),
    .ysub            ( dr_ysub                              ),
    .prog_data       ( prog_data                            ),
    .prog_addr       ( prog_addr                            ),
    .prog_en         ( prog_en                              ),
    .rom_addr        ( rom_addr                             ),
    .rom_cs          ( rom_cs                               ),
    .rom_data        ( rom_data                             ),
    .rom_ok          ( rom_ok                               ),
    .pxl             ( pxl                                  )
);

endmodule
