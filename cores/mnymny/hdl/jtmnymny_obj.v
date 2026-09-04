/*  jtmnymny_obj.v — 1B11140 object engine
    Table scanner (behavioural, the 6J/6K customs and 82S100 PLAs are
    undumped) + jtframe_objdraw. 24 sprites, 16x16x3, MAME draw order:
    spriteram1[0x00] (colour 2), spriteram0 (colour 1), spriteram1[0x20] (colour 0).
    GPL3 — see jtcores LICENSE
*/

module jtmnymny_obj(
    input               rst,
    input               clk,
    input               pxl_cen,
    input               hs,
    input       [ 8:0]  hdump,
    input       [ 8:0]  vrender,
    input               flip,
    // object RAM (0x6800-0x68FF page)
    output reg  [ 7:0]  objram_addr,
    input       [ 7:0]  objram_data,
    // GFX ROM (SDRAM, 3 planes + padding in one word)
    output      [12:0]  rom_addr,
    output              rom_cs,
    input       [31:0]  rom_data,
    input               rom_ok,
    // pixel out: { pal[4:0], pix[3:0] }
    output      [ 8:0]  pxl
);

reg  [ 1:0] pass;
reg  [ 2:0] entry;
reg  [ 3:0] st;
reg  [ 7:0] b0, bo1, bo2;
reg  [ 7:0] code;
reg  [ 4:0] pal;
reg  [ 3:0] ysub;
reg  [ 8:0] xpos;
reg         hflip, vflip, draw, hs_l;
wire        dr_busy;
wire [14:2] dr_addr;

wire [ 7:0] base     = pass==2'd0 ? 8'h81 : pass==2'd1 ? 8'h40 : 8'hA1;
wire [ 1:0] pass_pal = pass==2'd0 ? 2'd2 : pass==2'd1 ? 2'd1 : 2'd0;
wire        sec1     = pass!=2'd1;          // spriteram2 swaps offsets 1 and 2
wire [ 7:0] sy       = 8'd242 - objram_data;
wire [ 8:0] ydiff    = {1'b0,vrender[7:0]} - {1'b0,b0};
wire        inzone   = !ydiff[8] && ydiff[7:4]==0;

// ROM layout is {code, y[3], half, y[2:0]}; objdraw emits {code, half, y[3:0]}
assign rom_addr = { dr_addr[14:7], dr_addr[5], dr_addr[6], dr_addr[4:2] };

always @(posedge clk) begin
    if( rst ) begin
        st    <= 0;
        pass  <= 0;
        entry <= 0;
        draw  <= 0;
        hs_l  <= 0;
    end else begin
        hs_l <= hs;
        draw <= 0;
        case( st )
            4'd0: if( hs & ~hs_l ) begin
                pass  <= 0;
                entry <= 0;
                st    <= 1;
            end
            4'd1: begin
                objram_addr <= base + {3'd0,entry,2'd0};
                st <= 2;
            end
            4'd2: st <= 3;                        // BRAM latency
            4'd3: begin
                b0 <= sy;                         // screen top line of the sprite
                objram_addr <= base + {3'd0,entry,2'd0} + (sec1 ? 8'd2 : 8'd1);
                st <= 4;
            end
            4'd4: st <= 5;
            4'd5: begin
                bo1 <= objram_data;
                objram_addr <= base + {3'd0,entry,2'd0} + (sec1 ? 8'd1 : 8'd2);
                st <= 6;
            end
            4'd6: st <= 7;
            4'd7: begin
                bo2 <= objram_data;
                objram_addr <= base + {3'd0,entry,2'd0} + 8'd3;
                st <= 8;
            end
            4'd8: st <= 9;
            4'd9: begin
                if( !inzone || objram_data==8'd0 ) begin
                    st <= 11;                     // skip: off line or x=0 (sx==1 in MAME)
                end else begin
                    code  <= { bo2[7:6], bo1[5:0] };
                    pal   <= { bo2[2:0], pass_pal };
                    hflip <= bo1[6];
                    vflip <= bo1[7];
                    ysub  <= ydiff[3:0];
                    xpos  <= {1'b0, objram_data} + 9'd1;
                    st    <= 10;
                end
            end
            4'd10: if( !dr_busy ) begin
                draw <= 1;
                st   <= 11;
            end
            4'd11: begin
                if( entry != 3'd7 ) begin
                    entry <= entry + 1'd1;
                    st <= 1;
                end else if( pass != 2'd2 ) begin
                    pass  <= pass + 1'd1;
                    entry <= 0;
                    st <= 1;
                end else begin
                    st <= 0;
                end
            end
            default: st <= 0;
        endcase
    end
end

jtframe_objdraw #(
    .CW     (  8 ),
    .PW     (  9 ),
    .LATCH  (  1 )
) u_draw(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .hs         ( hs        ),
    .flip       ( flip      ),
    .hdump      ( hdump     ),
    .draw       ( draw      ),
    .busy       ( dr_busy   ),
    .code       ( code      ),
    .xpos       ( xpos      ),
    .ysub       ( ysub      ),
    .hzoom      ( 6'd0      ),
    .hz_keep    ( 1'b0      ),
    .hflip      ( hflip     ),
    .vflip      ( vflip     ),
    .pal        ( pal       ),
    .rom_addr   ( dr_addr   ),
    .rom_cs     ( rom_cs    ),
    .rom_ok     ( rom_ok    ),
    .rom_data   ( rom_data  ),
    .pxl        ( pxl       )
);

endmodule
