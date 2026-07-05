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

    output reg [14:1] vrom1_addr,
    input      [15:0] vrom1_data,
    output reg        vrom1_cs,
    input             vrom1_ok,

    output reg [14:1] vrom2_addr,
    input      [15:0] vrom2_data,
    output reg        vrom2_cs,
    input             vrom2_ok,

    output     [ 7:0] pxl
);

localparam [2:0] REQ_VROM1 = 3'd0,
                 WAIT_VROM1= 3'd1,
                 LATCH_VROM1=3'd2,
                 REQ_VROM2 = 3'd3,
                 WAIT_VROM2= 3'd4,
                 LATCH_VROM2=3'd5;

wire [10:0] map_addr;
wire [31:0] sorted;
wire [15:0] cache_q;
wire [16:0] fill_tile       = {fill_vrom,9'd0} + {6'd0,fill_addr};
wire [17:0] fill_tile_byte  = {fill_tile,1'b0};
wire [14:1] fill_vrom1_addr = fill_tile_byte[17:4];
wire [14:0] fill_pat_addr   = {vrom1_l[10:8],vrom1_l[7:0],tile_byte_l[3:0]};
wire [ 7:0] vrom2_lo        = fill_pat_addr[0] ? vrom2_data[15:8] : vrom2_data[7:0];
wire [ 7:0] vrom2_hi        = vrom2_data[15:8];
wire [15:0] cache_din       = { vrom2_hi[5:0],vrom2_hi[7:6],vrom2_lo };

reg  [15:0] vrom1_l;
reg  [ 2:0] phase;
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
        phase     <= REQ_VROM1;
        vrom1_cs  <= 1'b0;
        vrom2_cs  <= 1'b0;
        vrom1_addr <= 14'd0;
        vrom2_addr <= 14'd0;
        vrom1_l   <= 16'd0;
        fill_addr <= 11'd0;
        cache_waddr <= 11'd0;
        fill_vrom <= 8'd0;
        tile_byte_l <= 18'd0;
        cache_wdata <= 16'd0;
        cache_we  <= 1'b0;
    end else begin
        vrom1_cs <= 1'b0;
        vrom2_cs <= 1'b0;
        cache_we <= 1'b0;
        if( fill_vrom != vrom_offset ) begin
            fill_vrom <= vrom_offset;
            fill_addr <= 11'd0;
            phase     <= REQ_VROM1;
        end else case( phase )
            REQ_VROM1: begin
                tile_byte_l <= fill_tile_byte;
                vrom1_addr  <= fill_vrom1_addr;
                phase       <= WAIT_VROM1;
            end
            WAIT_VROM1: begin
                vrom1_cs <= 1'b1;
                phase    <= LATCH_VROM1;
            end
            LATCH_VROM1: begin
                vrom1_cs <= 1'b1;
                if( vrom1_ok ) begin
                    vrom1_l  <= vrom1_data;
                    vrom1_cs <= 1'b0;
                    phase    <= REQ_VROM2;
                end
            end
            REQ_VROM2: begin
                vrom2_addr <= fill_pat_addr[14:1];
                phase      <= WAIT_VROM2;
            end
            WAIT_VROM2: begin
                vrom2_cs <= 1'b1;
                phase    <= LATCH_VROM2;
            end
            default: begin
                vrom2_cs <= 1'b1;
                if( vrom2_ok ) begin
                    cache_waddr <= fill_addr;
                    cache_wdata <= cache_din;
                    cache_we    <= 1'b1;
                    vrom2_cs    <= 1'b0;
                    fill_addr   <= fill_addr + 11'd1;
                    phase       <= REQ_VROM1;
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
    .hdump      ( hdump      ),
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
