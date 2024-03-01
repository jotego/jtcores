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
    Date: 24-9-2021 */

// Largest ROM seen
// As   | Size
// -----|------------------
// gfx1 | 0x20000 =  64 kB
// gfx2 | 0x40000 = 128 kB
// gfx3 | 0x40000 = 256 kB  (midres)

// The memory connected to the BAC06 is divided in two regions
// by the MSB. The lower region corresponds to the tilemap
// and is selected by the /NMAPSEL pin (#95).
// The upper region contains the row/column scroll information.
// The CPU selects it with pin /FSFT
// The BAC-06 outputs a /NMAP pin to the memory, which gets
// renamed in the schematics to BxMSFT, signalling the use
// for each memory half

// The BAC06 lets 12 address bits pass through to the memory
// but only the BAC06 used for B0 (background 0) has a 12+1 A
// memory connected. The other two chips had 10+1 A memories
// The 8x8 pixel tilemaps require the 12-line memories, whereas
// the 16x16 pixel tilemaps only need 10-line memories

// The /NUDS and /NLDS inputs of all chips are gated via a 74LS32
// chip by the /DSP chip select signal. That signal has a synchronization
// with the pixel clock. The BAC06 probably gives priority to the
// CPU when accessing memory, and the synchronization is done
// outside


module jtcop_bac06 #(
    parameter MASTER=0,     // One BAC06 chip will be the timing master
              SIMFILE="ba0.bin"
) (
    input             rst,
    input             clk,        // 12MHz original
    input             clk_cpu,
    inout             pxl2_cen,   // 12 MHz
    inout             pxl_cen,    //  6 MHz

    input             mode_cs,
    inout             flip,       // set by master BAC06

    // CPU interface
    input      [15:0] cpu_dout,
    output reg [15:0] cpu_din,
    input      [12:1] cpu_addr,
    input             cpu_rnw,
    input      [ 1:0] cpu_dsn,

    // Timer signals
    inout      [8:0]  vdump,
    inout      [8:0]  vrender,
    inout      [8:0]  hdump,
    inout             LHBL,
    inout             LVBL,
    inout             HS,
    inout             VS,
    inout             vload,
    inout             hinit,

    // VRAM
    output reg        ram_cs,
    output reg [13:1] ram_addr, // normally 4kB (AW=11, 16 bits), it can be 16kB too (AW=13)
    input      [15:0] ram_data,
    input             ram_ok,

    // ROMs
    output reg        rom_cs,
    output reg [17:1] rom_addr,
    input      [31:0] rom_data,
    input             rom_ok,

    output     [ 7:0] pxl,          // pixel output
    // Status
    input      [ 7:0] st_addr,
    output reg [ 7:0] st_dout
);


reg  [ 7:0] mode[0:3];
reg  [15:0] hscr;
wire [ 9:0] veff0;  // vrender + vscroll, without col scroll
reg  [15:0] vscr;
reg  [ 3:0] colscr_sh, rowscr_sh;

reg  [15:0] mmr_mux;
wire [15:0] cpu_ram;
wire [ 1:0] ncgsel;
reg  [ 6:0] row_addr, col_addr;
// reg  [ 9:0] rowscr_data;

// aliases for mode bits
wire        tile16_en,  // 16x16 tiles when high, 8x8 otherwise
            msbrow_en,  // 1 sets row bits at the upper scan address
            rowscr_en, colscr_en;
wire [1:0]  geometry; // 0 => 4x1, 1 => 2x2, 2 => 1x4

                               //  8x8 tiles | 16x16 tiles
localparam [1:0] GEOM_4X1 = 0, // 128 x  32  |   64 x 16
                 GEOM_2X2 = 1, //  64 x  64  |   32 x 32
                 GEOM_1X4 = 2; //  32 x 128  |   16 x 64

assign tile16_en = ~mode[0][0];
assign msbrow_en = mode[0][1];
assign rowscr_en = mode[0][2];
assign colscr_en = mode[0][3];
assign geometry  = mode[3][1:0];
assign veff0     = {1'd0, flip ? 9'd256-vrender : vrender } + vscr[9:0];

`ifdef SIMULATION
    wire [7:0] mode0 = mode[0];
    wire [7:0] mode1 = mode[1];
    wire [7:0] mode2 = mode[2];
    wire [7:0] mode3 = mode[3];
`endif

always @* begin
    case(cpu_addr[2:1])
        0: cpu_din = {8'hff,mode[0]};
        1: cpu_din = {8'hff,mode[0]};
        2: cpu_din = {8'hff,mode[0]};
        3: cpu_din = {8'hff,mode[0]};
    endcase
end

// Status report
always @(posedge clk) begin
    case(st_addr[3:0])
        0,1,2,3: st_dout <= mode[st_addr[1:0]];
        4: st_dout <= hscr[7:0];
        5: st_dout <= hscr[15:8];
        6: st_dout <= vscr[7:0];
        7: st_dout <= vscr[15:8];
        8: st_dout <= {colscr_sh,rowscr_sh};
        default: st_dout <= 0;
    endcase
end

function [15:0] combine( input [15:0] din );
    combine = { cpu_dsn[1] ? din[15:8] : cpu_dout[15:8],
                cpu_dsn[0] ? din[ 7:0] : cpu_dout[ 7:0]  };
endfunction

reg [7:0] def_cfg[0:15];
`ifdef SIMULATION
    integer f,k;
    initial begin
        for(k=0;k<16;k=k+1) def_cfg[k]=0;
        f=$fopen(SIMFILE,"rb");
        $fread( def_cfg, f );
        $fclose(f);
    end
`else
    integer k;
    initial begin
        for(k=0;k<16;k=k+1) def_cfg[k]=0;
    end
`endif

always @(posedge clk) begin
    if( rst ) begin
        mode[0]   <= def_cfg[0];
        mode[1]   <= def_cfg[1];
        mode[2]   <= def_cfg[2];
        mode[3]   <= def_cfg[3];
        hscr      <= {def_cfg[5],def_cfg[4]};
        vscr      <= {def_cfg[7],def_cfg[6]};
        colscr_sh <= def_cfg[8][7:4];
        rowscr_sh <= def_cfg[8][3:0];
    end else begin
        if( !cpu_rnw && mode_cs ) begin
            if( !cpu_addr[4] ) begin
                if( !cpu_dsn[0] ) mode[cpu_addr[2:1]] <= cpu_dout[7:0];
            end else begin
                case( cpu_addr[2:1] )
                    0: hscr <= combine( hscr );
                    1: vscr <= combine( vscr );
                    2: if( !cpu_dsn[0] ) colscr_sh <= cpu_dout[3:0];
                    3: if( !cpu_dsn[0] ) rowscr_sh <= cpu_dout[3:0];
                endcase
            end
        end
    end
end

generate
    if( MASTER ) begin
        wire [8:0] vrender1;
        assign flip  = mode[0][7];
        assign vload = vrender1==7; // second last line before the end of V blank

        jtframe_cen48 u_cen(
            .clk    ( clk       ),    // 48 MHz
            .cen6   ( pxl_cen   ),
            .cen12  ( pxl2_cen  ),
            // unused
            .cen16(), .cen8(), .cen4(), .cen4_12(), .cen3(),
            .cen3q(), .cen1p5(), .cen16b(), .cen12b(),
            .cen6b(), .cen3b(), .cen3qb(), .cen1p5b()
        );

        jtframe_vtimer #(
            .VB_START   ( 9'hf7     ),
            .VB_END     ( 9'd7      ),
            .VCNT_END   ( 9'd271    ),
            .VS_START   ( 9'h106    ),
            .HS_START   ( 9'h130    ),
            .HB_START   ( 9'd255    ),
            .HB_END     ( 9'd383    ),
            .HINIT      ( 9'd255    )
        )   u_vtimer(
            .clk        ( clk       ),
            .pxl_cen    ( pxl_cen   ),
            .vdump      ( vdump     ),
            .vrender    ( vrender   ),
            .vrender1   ( vrender1  ),
            .H          ( hdump     ),
            .Hinit      ( hinit     ),
            .Vinit      (           ),
            .LHBL       ( LHBL      ),
            .LVBL       ( LVBL      ),
            .HS         ( HS        ),
            .VS         ( VS        )
        );
    end
endgenerate

reg  [8:0] buf_waddr;
wire [7:0] buf_wdata;
reg        buf_we;
wire [8:0] buf_waflip;

assign buf_waflip = !flip ? buf_waddr : 9'h100-buf_waddr;

jtframe_linebuf #(
    .DW (       8   ),
    .AW (       9   )
) u_buffer (
    .clk        ( clk       ),
    .LHBL       ( LHBL      ),
    // New data writes
    .wr_addr    ( buf_waflip),
    .wr_data    ( buf_wdata ),
    .we         ( buf_we    ),
    // Old data reads (and erases)
    .rd_addr    ( hdump     ),
    .rd_data    (           ),
    .rd_gated   ( pxl       )
);

reg  draw, HSl;
reg  scan_busy;
reg [ 9:0] veff, heff_col;
reg [ 8:0] veff_row;
reg [ 9:0] hn;
reg [12:1] pre_ram;
reg [11:0] tile_id;
reg [ 3:0] tile_pal;
reg        pre_cs, rowscr_cs, colscr_cs;
reg [ 1:0] ram_good;
reg [ 5:0] tilecnt;

// drawing
reg  draw_busy, rom_good, get_hsub;
reg  hflip = 1;

always @* begin
    veff_row = veff[8:0] >> rowscr_sh;
    heff_col = hn >> colscr_sh;
end

always @* begin
    row_addr = 0;
    col_addr = 0;
    pre_ram  = 0;
    case( geometry )
        GEOM_4X1: begin
            row_addr[4:0] = veff[7:3]; // 32 or 16 rows
            col_addr[6:0] = hn[9:3];   //128 or 64 cols
            if( tile16_en )
                pre_ram = msbrow_en ? { 2'd0, col_addr[6:5], row_addr[4:1], col_addr[4:1] } : // 10 bits
                                      { 2'd0, col_addr[6:1], row_addr[4:1] };
            else
                pre_ram = msbrow_en ? { col_addr[6:5], row_addr[4:0], col_addr[4:0] } : // 12 bits
                                      { col_addr[6:0], row_addr[4:0] };
        end
        GEOM_2X2: begin
            row_addr[5:0] = veff[8:3]; // 64 or 32 rows
            col_addr[5:0] = hn[8:3];   // 64 or 32 rows
            if( tile16_en )
                pre_ram = msbrow_en ? { 2'd0, col_addr[5], row_addr[5:1], col_addr[4:1] } : // 10 bits
                                      { 2'd0, col_addr[5:1], row_addr[5:1] };
            else
                pre_ram = msbrow_en ? { col_addr[5], row_addr[5:0], col_addr[4:0] } : // 12 bits
                                      { col_addr[5:0], row_addr[5:0] };
        end
        default: begin // GEOM_1X4
            row_addr[6:0] = veff[9:3]; //128 or 64 rows
            col_addr[4:0] = hn[7:3];   // 32 or 16 cols
            if( tile16_en )
                pre_ram = msbrow_en ? { 2'd0, row_addr[6:1], col_addr[4:1] } : // 10 bits
                                      { 2'd0, col_addr[4:1], row_addr[6:1] };
            else
                pre_ram = msbrow_en ? { row_addr[6:0], col_addr[4:0] } : // 12 bits
                                      { col_addr[4:0], row_addr[6:0] };
        end
    endcase
end

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        ram_cs   <= 0;
        ram_addr <= 0;
    end else begin
        ram_cs   <= pre_cs;
        ram_addr <= 0;
        if( rowscr_cs ) begin
            ram_addr[10] <= 1; // row scroll
            ram_addr[9:1] <= veff_row;
        end else if( colscr_cs ) begin
            ram_addr[6:1] <= heff_col[8:3];
        end else begin // The tile map takes the upper half of the memory
            ram_addr <= { 1'b1, pre_ram };
        end
    end
end

// Obtain tile information
always @(posedge clk, posedge rst) begin
    if( rst ) begin
        pre_cs <= 0;
        rowscr_cs <= 0;
        colscr_cs <= 0;
        scan_busy <= 0;
        HSl <= 0;
        hn  <= 0;
        ram_good <= 0;
        draw <= 0;
    end else begin
        ram_good <= { ram_good[0] & ram_ok, ram_ok };
        HSl <= HS;
        draw <= 0;
        if( HSl && !HS ) begin
            hn       <= hscr[9:0];
            tilecnt  <= 0;
            ram_good <= 0;
            pre_cs   <= 1;
            draw     <= 0;
            veff     <= veff0;
            scan_busy<= 1;
            colscr_cs<= 0;
            if( rowscr_en ) begin
                rowscr_cs <= 1;
            end else begin
                rowscr_cs <= 0;
            end
        end
        if( scan_busy && ram_good[1] && ram_ok ) begin
            if( rowscr_cs ) begin
                hn <= hn + ram_data[9:0]; // adds row scroll portion
                // rowscr_data <= ram_data[9:0];
                rowscr_cs <= 0;
                ram_good  <= 0;
                if( colscr_en ) colscr_cs <= 1;
            end else if( colscr_cs ) begin
                veff <= veff0 + ram_data[9:0];
                colscr_cs <= 0;
                ram_good  <= 0;
            end else if( !draw && !draw_busy ) begin
                //tile_id  <= { vrender[8:3], hn[7:3] }; //ram_data[11:0];
                tile_id  <= ram_data[11:0];
                tile_pal <= ram_data[15:12];
                draw     <= 1;
                hn       <= hn + (10'd8 << tile16_en );
                tilecnt  <= tilecnt + 1'd1;
                ram_good <= 0;
                if( colscr_en ) colscr_cs <= 1;
                if( buf_waddr[8] && tilecnt > 1 ) begin
                    scan_busy <= 0;
                    pre_cs    <= 0;
                end
            end
        end
    end
end

// Draw the tile
reg  [31:0] draw_data;
wire [ 3:0] draw_pxl;
reg  [ 3:0] draw_cnt;
reg         half;

assign draw_pxl  = hflip ? { draw_data[23], draw_data[31], draw_data[7], draw_data[15] } :
                           { draw_data[16], draw_data[24], draw_data[0], draw_data[ 8] };
assign buf_wdata = { tile_pal, draw_pxl };

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        draw_busy <= 0;
        draw_cnt  <= 0;
        buf_waddr <= 0;
        rom_good  <= 0;
        buf_we    <= 0;
        rom_cs    <= 0;
        half      <= 0;
        get_hsub  <= 0;
    end else begin
        rom_good <= rom_ok;
        if( HSl && !HS ) get_hsub <= 1;
        if( draw ) begin
            draw_busy <= 1;
            half      <= 0;
            if( tile16_en )
                rom_addr <= { tile_id, 1'b1, veff[3:0] };
            else
                rom_addr <= { 2'd0, tile_id, veff[2:0] };
            draw_cnt <= 0;
            rom_cs   <= 1;
            rom_good <= 0;
            get_hsub <= 0;
            if( get_hsub ) begin // subtile scroll adjustment on first tile drawn
                if(tile16_en)
                    buf_waddr <= 9'd0 - {5'd0,hn[3:0]};
                else
                    buf_waddr <= 9'd0 - {6'd0,hn[2:0]};
            end
        end
        if( !buf_we && rom_cs && rom_good && rom_ok && draw_cnt==0 ) begin
            draw_data <= rom_data;
            rom_cs    <= 0;
            buf_we    <= 1;
            draw_cnt  <= 7;
        end
        if( buf_we ) begin
            draw_data <= hflip ? draw_data<<1 : draw_data>>1;
            draw_cnt <= draw_cnt-1'd1;
            buf_waddr<= buf_waddr+9'd1;
            if( draw_cnt==0 ) begin
                buf_we    <= 0;
                if( !tile16_en || half) begin
                    draw_busy <= 0;
                    rom_cs    <= 0;
                end else begin // second half of 16-pxl tile
                    rom_addr[5] <= ~rom_addr[5];
                    rom_cs      <= 1;
                    rom_good    <= 0;
                    half        <= 1;
                    draw_cnt    <= 0;
                end
            end
        end
    end
end

endmodule