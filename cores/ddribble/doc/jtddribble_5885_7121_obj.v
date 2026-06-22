//============================================================================
//
//  Adapted from cores/contra/hdl/jtcontra_gfx_obj.v (Jotego, GPL3, 2020).
//  Renamed for use inside the Double Dribble core. Currently byte-identical
//  to the parent (modulo the module rename). MODE_5885 parameter gating to
//  be added in Phase 2 of the 005885 build plan. See top of
//  jtddribble_5885_gfx.v for the full provenance note and rationale.
//
//============================================================================

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
    Date: 02-05-2020 */

// Main features of Konami's 007121 hardware
// Some elements have been factored out one level up (H/S timing...)

module jtddribble_5885_7121_obj #(
    // 0 = Konami 007121 sprite-attribute layout (contra default).
    // 1 = Konami 005885 sprite-attribute layout (ddribble). The 5-byte-per-
    //     sprite OFFSET sequence is identical for both chips; only the bit
    //     POSITIONS inside the size/flip byte differ. Source for the 005885
    //     layout is k005885_REFERENCE.sv (Iron Horse, MIT) states 1-5 — this
    //     is chip-INTERNAL behaviour, NOT visible on the ddribble schematic,
    //     so it's reference-grounded (a hint), verified visually vs the
    //     service-mode COLOR TEST page.
    parameter MODE_5885 = 0
)(
    input                rst,
    input                clk,
    input                pxl_cen,
    input                HS,
    input                LVBL,
    input       [ 8:0]   vrender,
    input                flip,
    input                layout,
    output reg           done,
    output      [ 9:0]   scan_addr, // max 64 sprites in total
    // Object Colour Prom
    output reg  [ 7:0]   oprom_addr,
    input       [ 3:0]   oprom_data,
    // Line buffer
    input       [ 8:0]   hdump,
    input       [ 8:0]   dump_start,
    output      [ 7:0]   pxl, // upper half is the palette, used for MX5000
    // SDRAM
    output reg           rom_cs,
    output      [17:0]   rom_addr,
    input                rom_ok,
    input       [15:0]   rom_data,
    input       [ 7:0]   obj_scan
);

reg  [13:0] code;
reg  [ 3:0] pal;
reg         line_we;
reg         h4;
reg  [ 2:0] byte_sel;
reg  [ 3:0] st;
reg         last_HS;
reg  [ 8:0] hn, vn;
reg  [ 4:0] bank;
reg  [ 7:0] dump_cnt;
reg  [ 3:0] size_cnt;
reg  [15:0] pxl_data;
reg  [ 8:0] xpos;
reg  [ 9:0] scan_base;
reg         obj_we;
wire [ 8:0] line_addr;

reg  [ 2:0] height_comb;
reg  [ 8:0] upper_limit;
reg  [ 4:0] vsub;
reg  [ 2:0] size_attr;
reg         hflip, vflip;
reg  [ 8:0] pxl_cnt; // OBJ limit should be less than 64us*6MHz=384 pixels
wire [ 8:0] vf;

//assign      line_addr = { flip ? 9'h0EF-xpos + (layout ? 9'o50 : 0) : xpos };
assign      line_addr = { flip ? 9'h117-xpos : xpos };
assign      scan_addr = scan_base + { 7'd0, byte_sel };
assign      vf        = vrender ^ {1'b0, {8{flip}}};

always @(*) begin
    height_comb  = size_attr[2] ? 3'b100 : ( size_attr[0] ? 3'b001 : 3'b010 );
    upper_limit = {1'b0, obj_scan} + { 3'b0, height_comb, 3'd0 };
end

assign rom_addr = { code, vsub[2:0], h4 }; // 14+3+1 = 18

always @(posedge clk) begin
    if( rst ) begin
        done    <= 1;
        pal     <= 0;
        code    <= 0;
        line_we <= 0;
        st      <= 0;
        size_cnt<= 0;
        dump_cnt<= 0;
        h4      <= 0;
    end else begin
        last_HS <= HS;
        if( HS && !last_HS && LVBL) begin
            done      <= 0;
            rom_cs    <= 0;
            st        <= 0;
            scan_base <= 0;
            byte_sel  <= 3'd4;      // get obj size
            pxl_cnt   <= 0;
        end else begin
            if(!done) st <= st + 4'd1;
            case( st )
                0: begin
                    rom_cs   <= 0;
                    byte_sel <= 3'd2;   // get y position
                end
                1: begin
                    // Size/flip byte (sprite byte[4]). Bit positions differ
                    // by chip — see MODE_5885 note in the module header.
                    if( MODE_5885 ) begin
                        // 005885 (ddribble): vflip[6] hflip[5] size[4:2] x8[1:0]
                        xpos[8]     <= obj_scan[0]; // x8_vram (simple on-screen case)
                        size_attr   <= obj_scan[4:2];
                        hflip       <= obj_scan[5];
                        vflip       <= obj_scan[6];
                        code[13:12] <= 2'b00;       // 005885 sprite code is 12-bit
                    end else begin
                        // 007121 (contra): vflip[5] hflip[4] size[3:1] code[13:12]=[7:6]
                        xpos[8]     <= obj_scan[0];
                        size_attr   <= obj_scan[3:1];
                        hflip       <= obj_scan[4];
                        vflip       <= obj_scan[5];
                        code[13:12] <= obj_scan[7:6];
                    end
                    byte_sel    <= 3'd0;   // get code
                end
                2: begin
                    size_cnt <= size_attr[2] ? 4'b1111 : (
                                size_attr[1] ? 4'b0001 : 4'b0011 );
                    vsub     <= (vf[4:0]-obj_scan[4:0])^{5{vflip}};
                    h4       <= hflip;
                    if( obj_scan== 8'd240 && scan_base>=10'd80) begin
                        st     <= 0;
                        done   <= 1;
                        rom_cs <= 0;
                    end else begin
                        if( (vf < {1'b0,obj_scan} &&
                             {1'b1,vf[7:0]}>=upper_limit )
                            || vf[8:0] >= upper_limit[8:0] ) begin
                            st        <= 9; // next tile
                        end else begin
                            byte_sel <= 3'd1; // get colour
                        end
                    end
                end
                3: begin
                    code[9:2] <= obj_scan;
                    byte_sel  <= 3'd3; // x position
                end
                4: begin
                    // Base sprite number high bits (sprite byte[1]).
                    //   005885 (ddribble): number = {byte1[2:0], byte0} (11-bit,
                    //     indexes 16x16 tiles) -> code[12:10] = byte1[2:0].
                    //     code[13] stays 0 (set in st1). Per MAME draw_sprites.
                    //   007121 (contra): number = {byte4[7:6], byte1[1:0], byte0}
                    //     -> code[11:10] = byte1[1:0] (code[13:12] from byte4 in st1).
                    if( MODE_5885 )
                        code[12:10] <= obj_scan[2:0];
                    else
                        code[11:10] <= obj_scan[1:0];
                    // code[3] and code[1] => vertical size
                    if( size_attr[2] ) // 32px
                        { code[3],code[1] } <= vsub[4:3];
                    else if( size_attr[0] ) // 8px
                        code[1] <= obj_scan[3];
                    else begin
                        code[1] <= vflip ? &vsub[4:3] : vsub[3];
                    end
                    // code[2] and code[0] => horizontal size
                    if( size_attr[2] ) // 32px
                        { code[2],code[0] } <= {2{hflip}};
                    else if( size_attr[1] ) // 8px
                        code[0] <= obj_scan[2];
                    else
                        code[0] <= hflip;
                    pal         <= obj_scan[7:4];
                    rom_cs      <= 1;
                end
                5: begin
                    xpos <= {xpos[8], obj_scan} -9'd1 + dump_start;
                end
                6: begin
                      if( rom_ok ) begin
                        pxl_data <= rom_data;
                        rom_cs   <= 0;
                        dump_cnt <= 7;
                    end else st <= st;
                end
                7: begin // dumps 4 pixels
                    if( dump_cnt[0] ) st<=st;
                    dump_cnt <= dump_cnt>>1;
                    pxl_data <= hflip ? pxl_data>>4 : pxl_data << 4;
                    pxl_cnt  <= pxl_cnt + 9'd1;
                    xpos     <= xpos + 9'd1;
                    oprom_addr <= { pal,
                        hflip ? pxl_data[3:0] : pxl_data[15:12]
                        };
                    line_we  <= 1;
                end
                8: begin
                    line_we <= 0;
                    {code[2],code[0],h4} <= {code[2],code[0],h4} +
                        ( hflip ? -3'd1 : 3'd1 );
                    if( h4 ) size_cnt <= size_cnt>>1;
                    if( hflip ? (!size_cnt[0] && !h4) : (!size_cnt[1] && h4) ) begin
                        st      <= 9; // next tile
                    end else begin
                        rom_cs  <= 1;
                        st      <= 10; // wait for new ROM data
                    end
                end
                9: begin
                    byte_sel  <= 3'd4;
                    st        <= 0;
                    if( scan_base < 10'h13b && pxl_cnt<9'd384 ) begin
                        scan_base <= scan_base + 10'd5;
                    end else begin
                        done      <= 1;
                        rom_cs    <= 0;
                    end
                end
                10: st <= 6; // wait cycle for rom_ok
            endcase // st
        end
    end
end

// ---------------------------------------------------------------------------
// Task #30 address instrumentation (MODE_5885, sim only). Logs each sprite
// ROM fetch so we can check the COMPUTED rom_addr against the byte-perfect
// gfx blob: for a 005885 16x16 sprite `number`, the correct sprite-local
// word address = number*64 + quad*16 + vsub*2 + h4, i.e. rom_addr should be
// {number[10:0], quad[1:0], vsub[2:0], h4}. Bounded to first 400 fetches of
// non-zero sprites to keep the log small.
// ---------------------------------------------------------------------------
`ifdef SIMULATION
integer obj_dbg_cnt = 0;
always @(posedge clk) begin
    if( MODE_5885 && st==6 && rom_ok && (|code) && obj_dbg_cnt < 400 ) begin
        $display("[%0t] %m OBJdbg number=0x%03X quad=%0d code=0x%04X rom_addr=0x%05X vsub=%0d h4=%b hf=%b vf=%b pal=%X xpos=%0d",
                 $time, code[12:2], code[1:0], code, rom_addr,
                 vsub[2:0], h4, hflip, vflip, pal, xpos);
        obj_dbg_cnt <= obj_dbg_cnt + 1;
    end
end
`endif

jtframe_obj_buffer #(
    .DW   (8),
    .ALPHA(0),
    .BLANK(0)
) u_line(
    .clk    ( clk           ),
    .LHBL   ( ~HS           ),
    // New data writes
    .wr_data( { oprom_addr[7:4], oprom_data } ),
    .wr_addr( line_addr     ),
    .we     ( line_we       ),
    .flip   ( 1'b0          ),
    // Old data reads (and erases)
    .rd_addr( hdump         ),
    .rd     ( pxl_cen       ),  // data will be erased after the rd event
    .rd_data( pxl           )
);


endmodule