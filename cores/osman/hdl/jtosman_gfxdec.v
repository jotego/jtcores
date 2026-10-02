/*  This file is part of JTCORES. GPLv3. See jtosman_game.v header.
    Author: Andrea Bogazzi.

    deco56 tile-gfx decrypt-at-fetch adapter. Sits between one jtframe_deco16
    (cninja DECO16IC renderer, 32-bit rom bus = 8px x 4 planes) and a 16-bit
    SDRAM port holding the deco56-ENCRYPTED tiles in load order. Per render word
    it issues TWO 16-bit reads (the two plane-pairs, 0x80000 decwords apart =
    the RGN_FRAC(1,2) half boundary), decrypts each, and assembles the 32-bit
    word jtframe_deco16 expects.

    The deco56 transform (address/xor/swap tables + deco_consts.vh masks) is the
    SAME static chip decrypt for every deco56 game — taken verbatim from the
    proven nslasher gfxdec (bit-exact vs MAME decocrpt.cpp deco56_decrypt_gfx).
    Osman-specific is only the W (decword index) derivation from jtframe_deco16's
    rom_addr and the final plane packing — tuned vs the real MAME screen.
        W        = rom_addr                                    (32-bit render-word index)
        a        = { W[18:11], address_table[W[10:0]] }        (encrypted source decword)
        decword  = BITSWAP16( E ^ xor_masks[xor_table[a&0x7ff]], swap_patterns[swap_table[W&0x7ff]] )
        rom_data = { byteswap(decword(W|0x80000)), byteswap(decword(W)) }
*/
module jtosman_gfxdec(
    input             rst,
    input             clk,
    // jtframe_deco16 gfx ROM bus (32-bit = 8px x 4 planes; BANKW=2 -> 19-bit render addr)
    input             rom_cs,
    input      [20:2] rom_addr,
    output reg [31:0] rom_data,
    output reg        rom_ok,
    // 16-bit SDRAM port (encrypted tiles, load order)
    output reg        sdr_cs,
    output reg [20:1] sdr_addr,
    input      [15:0] sdr_data,
    input             sdr_ok
);

`include "deco_consts.vh"

reg [10:0] addr_tab [0:2047];
reg [ 3:0] xor_tab  [0:2047];
reg [ 2:0] swap_tab [0:2047];
initial begin
    $readmemh("deco56_address.hex", addr_tab);
    $readmemh("deco56_xor.hex",     xor_tab);
    $readmemh("deco56_swap.hex",    swap_tab);
end

// W = render-word index (jtframe_deco16 rom_addr already includes the 2-bit bank -> 19-bit)
wire [18:0] W = rom_addr;

reg  [18:0] Wl;                                   // latched W
wire [10:0] wlo = Wl[10:0];
wire [10:0] ta  = addr_tab[wlo];                  // permuted source low-address
wire [ 3:0] xs  = xor_tab[ta];                    // xor-mask select (double lookup on ta)
wire [ 2:0] ss  = swap_tab[wlo];                  // swap-pattern select

function [15:0] xorm(input [3:0] x);
    case(x)
        4'd0:xorm=XORM0; 4'd1:xorm=XORM1; 4'd2:xorm=XORM2;  4'd3:xorm=XORM3;
        4'd4:xorm=XORM4; 4'd5:xorm=XORM5; 4'd6:xorm=XORM6;  4'd7:xorm=XORM7;
        4'd8:xorm=XORM8; 4'd9:xorm=XORM9; 4'd10:xorm=XORM10; 4'd11:xorm=XORM11;
        4'd12:xorm=XORM12;4'd13:xorm=XORM13;4'd14:xorm=XORM14;4'd15:xorm=XORM15;
    endcase
endfunction
function [15:0] swapf(input [2:0] s, input [15:0] v);
    case(s)
        3'd0:swapf=`SWAP0(v); 3'd1:swapf=`SWAP1(v); 3'd2:swapf=`SWAP2(v); 3'd3:swapf=`SWAP3(v);
        3'd4:swapf=`SWAP4(v); 3'd5:swapf=`SWAP5(v); 3'd6:swapf=`SWAP6(v); 3'd7:swapf=`SWAP7(v);
    endcase
endfunction
function [15:0] bswap(input [15:0] w); bswap = {w[7:0], w[15:8]}; endfunction
// SDRAM returns the 16-bit tile word little-endian; MAME's deco_decrypt works on the
// big-endian word, so byteswap the SDRAM read before the transform.
function [15:0] decode_word(input [15:0] e);
    decode_word = swapf(ss, bswap(e) ^ xorm(xs));
endfunction

reg [15:0] dec1;
localparam IDLE=3'd0, RD1=3'd1, GAP=3'd2, RD2=3'd3, HOLD=3'd4;
reg [2:0] st;

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        st<=IDLE; sdr_cs<=0; rom_ok<=0; rom_data<=0; sdr_addr<=0; Wl<=0; dec1<=0;
    end else begin
        case(st)
            IDLE: begin
                rom_ok <= 0;
                if( rom_cs ) begin
                    Wl     <= W;
                    st     <= RD1;
                    sdr_cs <= 0;           // addr/selects settle from Wl next clk
                end
            end
            RD1: begin                     // read decword W = FRAC(0,2) = planes 2,3 (high 16)
                sdr_cs   <= 1;
                sdr_addr <= { 1'b0, Wl[18:11], ta };
                if( sdr_cs && sdr_ok ) begin
                    dec1   <= decode_word(sdr_data);
                    sdr_cs <= 0;
                    st     <= GAP;
                end
            end
            GAP: begin
                sdr_cs   <= 1;
                sdr_addr <= { 1'b1, Wl[18:11], ta };   // W|0x80000 = FRAC(1,2) = planes 0,1 (low 16)
                st       <= RD2;
            end
            RD2: begin                     // read decword W|0x80000
                if( sdr_cs && sdr_ok ) begin
                    // jtframe_deco16 wants byte p = plane p (p0=byte0=LSB). Verified vs MAME
                    // gfxdecode (tile 0x555 rendered pixel-exact): the FRAC(1,2) word (planes 0,1)
                    // lands in the high 16, FRAC(0,2) (planes 2,3) in the low 16, each byteswapped.
                    rom_data <= { bswap(decode_word(sdr_data)), bswap(dec1) };
                    rom_ok   <= 1;
                    sdr_cs   <= 0;
                    st       <= HOLD;
                end
            end
            HOLD: begin                    // hold rom_ok until jtframe_deco16 drops rom_cs
                if( !rom_cs ) begin rom_ok <= 0; st <= IDLE; end
            end
            default: st <= IDLE;
        endcase
    end
end

endmodule
