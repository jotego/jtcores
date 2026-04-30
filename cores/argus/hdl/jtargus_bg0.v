module jtargus_bg0(
    input             rst,
    input             clk,
    input             pxl_cen,
    input             hs,
    input             blankn,
    input             flip,
    input      [ 8:0] vdump,
    input      [ 8:0] hdump,
    input      [ 9:0] scrx,
    input      [ 8:0] scry,
    input      [ 7:0] vrom_offset,

    output            rom_cs,
    output     [16:2] rom_addr,
    input      [31:0] rom_data,
    input             rom_ok,

    output reg [15:0] vrom_addr,
    input      [ 7:0] vrom_data,
    output reg        vrom_cs,
    input             vrom_ok,

    output     [ 7:0] pxl
);

localparam [19:0] VROM2_DIFF = `VROM2_START-`VROM1_START;
localparam [15:0] VROM2_BASE = VROM2_DIFF[15:0];

wire [10:0] map_addr;
wire [31:0] sorted;
wire [15:0] cache_q;
wire [16:0] fill_tile = ({fill_vrom,9'd0} + {6'd0,fill_addr}) & 17'h1ffff;
wire [17:0] fill_tile_byte = {fill_tile,1'b0};
wire [15:0] fill_vrom1_addr = {1'b0,fill_tile_byte[17:3]} & 16'hfffe;
wire [14:0] fill_pat_addr = {vrom1_hi[2:0],vrom1_lo,4'd0} | {11'd0,tile_byte_l[3:0]};
wire [15:0] cache_din = { vrom_data[5], vrom_data[4], vrom_data[3:0],
                          vrom_data[7:6], vrom2_lo };

reg  [ 7:0] vrom1_lo, vrom1_hi, vrom2_lo;
reg  [ 3:0] phase;
reg  [10:0] fill_addr;
reg  [10:0] cache_waddr;
reg  [ 7:0] fill_vrom;
reg  [17:0] tile_byte_l;
reg  [15:0] cache_wdata;
reg         cache_we;
wire [ 9:0] code  = cache_q[9:0];
wire [ 3:0] pal   = cache_q[13:10];
wire        hflip = cache_q[14];
wire        vflip = cache_q[15];

jtargus_8x8x4_packed_msb u_conv(
    .raw    ( rom_data ),
    .sorted ( sorted   )
);

always @(posedge clk) begin
    if( rst ) begin
        phase     <= 4'd0;
        vrom_cs   <= 1'b0;
        vrom_addr <= 16'd0;
        vrom1_lo  <= 8'd0;
        vrom1_hi  <= 8'd0;
        vrom2_lo  <= 8'd0;
        fill_addr <= 11'd0;
        cache_waddr <= 11'd0;
        fill_vrom <= 8'd0;
        tile_byte_l <= 18'd0;
        cache_wdata <= 16'd0;
        cache_we  <= 1'b0;
    end else begin
        vrom_cs <= 1'b0;
        cache_we <= 1'b0;
        if( fill_vrom != vrom_offset ) begin
            fill_vrom <= vrom_offset;
            fill_addr <= 11'd0;
            phase     <= 4'd0;
        end else case( phase )
            4'd0: begin
                tile_byte_l <= fill_tile_byte;
                vrom_addr   <= fill_vrom1_addr;
                phase       <= 4'd1;
            end
            4'd1: begin
                vrom_cs     <= 1'b1;
                phase       <= 4'd2;
            end
            4'd2: begin
                vrom_cs <= 1'b1;
                if( vrom_ok ) begin
                    vrom1_lo <= vrom_data;
                    vrom_cs  <= 1'b0;
                    phase    <= 4'd3;
                end
            end
            4'd3: begin
                vrom_addr <= ({1'b0,tile_byte_l[17:3]} & 16'hfffe) | 16'd1;
                phase     <= 4'd4;
            end
            4'd4: begin
                vrom_cs <= 1'b1;
                phase   <= 4'd5;
            end
            4'd5: begin
                vrom_cs <= 1'b1;
                if( vrom_ok ) begin
                    vrom1_hi <= vrom_data;
                    vrom_cs  <= 1'b0;
                    phase    <= 4'd6;
                end
            end
            4'd6: begin
                vrom_addr <= VROM2_BASE + fill_pat_addr;
                phase     <= 4'd7;
            end
            4'd7: begin
                vrom_cs <= 1'b1;
                phase   <= 4'd8;
            end
            4'd8: begin
                vrom_cs <= 1'b1;
                if( vrom_ok ) begin
                    vrom2_lo <= vrom_data;
                    vrom_cs  <= 1'b0;
                    phase    <= 4'd9;
                end
            end
            4'd9: begin
                vrom_addr <= VROM2_BASE + ({1'b0,fill_pat_addr} | 16'd1);
                phase     <= 4'd10;
            end
            4'd10: begin
                vrom_cs <= 1'b1;
                phase   <= 4'd11;
            end
            default: begin
                vrom_cs <= 1'b1;
                if( vrom_ok ) begin
                    cache_waddr <= fill_addr;
                    cache_wdata <= cache_din;
                    cache_we  <= 1'b1;
                    vrom_cs   <= 1'b0;
                    fill_addr <= fill_addr + 11'd1;
                    phase     <= 4'd0;
                end
            end
        endcase
    end
end

jtframe_dual_ram #(
    .DW ( 16 ),
    .AW ( 11 )
) u_meta_cache(
    .clk0   ( clk        ),
    .data0  ( 16'd0      ),
    .addr0  ( map_addr   ),
    .we0    ( 1'b0       ),
    .q0     ( cache_q    ),
    .clk1   ( clk        ),
    .data1  ( cache_wdata ),
    .addr1  ( cache_waddr ),
    .we1    ( cache_we   ),
    .q1     (            )
);

jtframe_scroll #(
    .SIZE       ( 16    ),
    .VA         ( 11    ),
    .CW         ( 10    ),
    .PW         ( 8     ),
    .MAP_HW     ( 10    ),
    .MAP_VW     ( 9     ),
    .SCAN_COLS  ( 1     ),
    .HJUMP      ( 0     )
) u_scroll(
    .rst        ( rst        ),
    .clk        ( clk        ),
    .pxl_cen    ( pxl_cen    ),
    .hs         ( hs         ),
    .vdump      ( vdump      ),
    .hdump      ( {1'b0,hdump[7:0]} ),
    .blankn     ( blankn     ),
    .flip       ( flip       ),
    .scrx       ( scrx       ),
    .scry       ( scry       ),
    .vram_addr  ( map_addr   ),
    .code       ( code       ),
    .pal        ( pal        ),
    .hflip      ( hflip      ),
    .vflip      ( vflip      ),
    .rom_addr   ( rom_addr   ),
    .rom_data   ( sorted     ),
    .rom_cs     ( rom_cs     ),
    .rom_ok     ( rom_ok     ),
    .pxl        ( pxl        )
);

endmodule
