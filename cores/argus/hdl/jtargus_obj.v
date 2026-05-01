module jtargus_obj(
    input             rst,
    input             clk,
    input             pxl_cen,
    input             hs,
    input             blankn,
    input             flip,
    input      [ 8:0] hdump,
    input      [ 8:0] vrender,

    output reg [12:0] ram_addr,
    input      [ 7:0] ram_data,

    output            rom_cs,
    output     [16:2] rom_addr,
    input      [31:0] rom_data,
    input             rom_ok,

    output     [ 8:0] pxl
);

localparam SPR_BASE = 13'h1200;

reg        hs_l, draw, visible;
reg [10:0] scan;
reg [ 3:0] state;
reg [ 7:0] sy_b, sx_b, attr_b, code_b, color_b;
reg [ 9:0] sx_eff, sy_eff;
reg [ 9:0] line;
reg [ 9:0] code;
reg [ 3:0] pal;
reg        hflip, vflip, title_mask;
wire       busy;
wire [31:0] sorted;
wire [12:0] scan_ext = {2'd0,scan};
wire [ 9:0] code_next = {attr_b[7:6],code_b};
// FBNeo skips these Argus title mask sprites over plain BG0.
wire        title_mask_next = (code_next>=10'h3f0 && code_next<=10'h3f8) ||
                              (code_next>=10'h3b6 && code_next<=10'h3bf) ||
                              (code_next>=10'h3ac && code_next<=10'h3af);
wire [ 9:0] spr_line = flip ? {1'b0,vrender} + sy_eff - 10'd240 : {1'b0,vrender} - sy_eff;
wire        vis_next = !(color_b==8'd0 && sy_b==8'hf0) && spr_line[9:4]==6'd0;
wire [ 3:0] ysub = line[3:0] ^ {4{vflip}};

jtargus_obj_8x8x4_packed_msb u_conv(
    .raw    ( rom_data ),
    .sorted ( sorted   )
);

always @(posedge clk) begin
    if( rst ) begin
        hs_l     <= 1'b0;
        scan     <= 11'd0;
        state      <= 4'd0;
        draw       <= 1'b0;
        ram_addr   <= SPR_BASE;
        title_mask <= 1'b0;
    end else begin
        hs_l <= hs;
        draw <= 1'b0;

        if( hs && !hs_l ) begin
            scan     <= 11'd0;
            state    <= 4'd0;
            ram_addr <= SPR_BASE + 13'd11;
        end else if( blankn ) begin
            case( state )
                4'd0: begin ram_addr <= SPR_BASE + scan_ext + 13'd11; state <= 4'd1; end
                4'd1: begin ram_addr <= SPR_BASE + scan_ext + 13'd12; state <= 4'd2; end
                4'd2: begin sy_b <= ram_data; ram_addr <= SPR_BASE + scan_ext + 13'd13; state <= 4'd3; end
                4'd3: begin sx_b <= ram_data; ram_addr <= SPR_BASE + scan_ext + 13'd14; state <= 4'd4; end
                4'd4: begin attr_b <= ram_data; ram_addr <= SPR_BASE + scan_ext + 13'd15; state <= 4'd5; end
                4'd5: begin code_b <= ram_data; state <= 4'd6; end
                4'd6: begin
                    color_b <= ram_data;
                    sx_eff  <= attr_b[0] ? {2'b11,sx_b} : {2'b00,sx_b};
                    sy_eff  <= attr_b[1] ? {2'b00,sy_b} : {2'b11,sy_b};
                    state   <= 4'd7;
                end
                4'd7: begin
                    line    <= spr_line;
                    visible <= vis_next;
                    code    <= code_next;
                    title_mask <= title_mask_next;
                    pal     <= {color_b[3],color_b[2:0]};
                    hflip   <= flip ? ~attr_b[4] : attr_b[4];
                    vflip   <= flip ? ~attr_b[5] : attr_b[5];
                    if( flip )
                        sx_eff <= 10'd240 - sx_eff;
                    state <= 4'd8;
                end
                4'd8: begin
                    if( visible && !busy ) begin
                        draw  <= 1'b1;
                        state <= 4'd9;
                    end else if( !visible || !busy ) begin
                        state <= 4'd9;
                    end
                end
                4'd9: begin
                    if( scan>=11'h5f0 ) begin
                        state <= 4'd9;
                    end else begin
                        scan     <= scan + 11'd16;
                        ram_addr <= SPR_BASE + scan_ext + 13'd16 + 13'd11;
                        state    <= 4'd0;
                    end
                end
                default: state <= 4'd0;
            endcase
        end
    end
end

jtframe_objdraw #(.AW(9),.CW(10),.PW(9),.LATCH(1),.HJUMP(0),.HFIX(0),.ALPHA(9'h00f)) u_draw(
    .rst        ( rst          ),
    .clk        ( clk          ),
    .pxl_cen    ( pxl_cen      ),
    .hs         ( hs           ),
    .flip       ( 1'b0         ),
    .hdump      ( hdump        ),
    .draw       ( draw         ),
    .busy       ( busy         ),
    .code       ( code         ),
    .xpos       ( sx_eff[8:0]  ),
    .ysub       ( ysub         ),
    .hzoom      ( 6'd0         ),
    .hz_keep    ( 1'b0         ),
    .hflip      ( hflip        ),
    .vflip      ( vflip        ),
    .pal        ( {title_mask,pal} ),
    .rom_addr   ( rom_addr     ),
    .rom_cs     ( rom_cs       ),
    .rom_ok     ( rom_ok       ),
    .rom_data   ( sorted       ),
    .pxl        ( pxl          )
);

endmodule
