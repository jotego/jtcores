/*  This file is part of JTS16.
    JTS16 program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTS16 program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTS16.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 20-3-2021 */

module jts16_fd1089(
    input             rst,
    input             clk,

    // Key access
    output     [12:0] key_addr,
    input      [ 7:0] key_data,

    // Configuration
    input      [12:0] prog_addr,
    input             fd1089_we,
    input      [ 7:0] prog_data,

    // Operation
    input             dec_type, // 0=a, 1=b
    input             dec_en,

    input             op_n,     // OP (0) or data (1)
    input      [23:1] addr,
    input      [15:0] enc,
    output reg [15:0] dec,

    input             rom_ok,
    output            ok_dly
    `ifdef DEBUG
    ,output [ 7:0] debug_key
    ,output [12:0] debug_luta
    ,output [ 7:0] debug_lut2_a
    ,output [ 7:0] debug_preval
    ,output [ 3:0] debug_family
    ,output [ 7:0] debug_last_in
    `endif
);

reg  [ 7:0] encbyte, decbyte, last_dout, last_in, lastb, val_a, val_b;
reg  [ 3:0] family;
reg  [12:0] lut_a;
wire [ 7:0] shkey, preval;
reg  [ 7:0] key, lut2_addr;
wire [ 7:0] second[0:15];
wire [ 7:0] last[0:15];
wire [ 7:0] xored_last_in[0:15];
reg         bypass, lsbxor;
reg         ok_latch;

assign key_addr = lut_a;
assign shkey    = key_data;

`ifdef DEBUG
assign debug_key     = key;
assign debug_luta    = lut_a;
assign debug_lut2_a  = lut2_addr;
assign debug_preval  = preval;
assign debug_family  = family;
assign debug_last_in = last_in;
`endif

`define BITSWAP( v, b7, b6, b5, b4, b3, b2, b1, b0 ) {v[b7], v[b6], v[b5], v[b4], v[b3], v[b2], v[b1], v[b0] }
`define BITXOR(v, b, x) v[b]=v[b]^(x)

// Common to 1089A and 1089B
assign second[ 0] = 8'h23 ^ `BITSWAP( encbyte, 6,4,5,7,3,0,1,2 );
assign second[ 1] = 8'h92 ^ `BITSWAP( encbyte, 2,5,3,6,7,1,0,4 );
assign second[ 2] = 8'hb8 ^ `BITSWAP( encbyte, 6,7,4,2,0,5,1,3 );
assign second[ 3] = 8'h74 ^ `BITSWAP( encbyte, 5,3,7,1,4,6,0,2 );
assign second[ 4] = 8'hcf ^ `BITSWAP( encbyte, 7,4,1,0,6,2,3,5 );
assign second[ 5] = 8'hc4 ^ `BITSWAP( encbyte, 3,1,6,4,5,0,2,7 );
assign second[ 6] = 8'h51 ^ `BITSWAP( encbyte, 5,7,2,4,3,1,6,0 );
assign second[ 7] = 8'h14 ^ `BITSWAP( encbyte, 7,2,0,6,1,3,4,5 );
assign second[ 8] = 8'h7f ^ `BITSWAP( encbyte, 3,5,6,0,2,1,7,4 );
assign second[ 9] = 8'h03 ^ `BITSWAP( encbyte, 2,3,4,0,6,7,5,1 );
assign second[10] = 8'h96 ^ `BITSWAP( encbyte, 3,1,7,5,2,4,6,0 );
assign second[11] = 8'h30 ^ `BITSWAP( encbyte, 7,6,2,3,0,4,5,1 );
assign second[12] = 8'he2 ^ `BITSWAP( encbyte, 1,0,3,7,4,5,2,6 );
assign second[13] = 8'h72 ^ `BITSWAP( encbyte, 1,6,0,5,7,2,4,3 );
assign second[14] = 8'hf5 ^ `BITSWAP( encbyte, 0,4,1,2,6,5,7,3 );
assign second[15] = 8'h5b ^ `BITSWAP( encbyte, 0,7,5,3,1,4,2,6 );

assign xored_last_in[ 0] = 8'h55 ^ last_in;
assign xored_last_in[ 1] = 8'h94 ^ last_in;
assign xored_last_in[ 2] = 8'h8d ^ last_in;
assign xored_last_in[ 3] = 8'h9a ^ last_in;
assign xored_last_in[ 4] = 8'h72 ^ last_in;
assign xored_last_in[ 5] = 8'hff ^ last_in;
assign xored_last_in[ 6] = 8'h06 ^ last_in;
assign xored_last_in[ 7] = 8'hc5 ^ last_in;
assign xored_last_in[ 8] = 8'hec ^ last_in;
assign xored_last_in[ 9] = 8'h89 ^ last_in;
assign xored_last_in[10] = 8'h5c ^ last_in;
assign xored_last_in[11] = 8'h3f ^ last_in;
assign xored_last_in[12] = 8'h57 ^ last_in;
assign xored_last_in[13] = 8'hf7 ^ last_in;
assign xored_last_in[14] = 8'h3a ^ last_in;
assign xored_last_in[15] = 8'hac ^ last_in;

assign last[ 0] = `BITSWAP( xored_last_in[ 0], 6,5,1,0,7,4,2,3 );
assign last[ 1] = `BITSWAP( xored_last_in[ 1], 7,6,4,2,0,5,1,3 );
assign last[ 2] = `BITSWAP( xored_last_in[ 2], 1,4,2,3,0,6,7,5 );
assign last[ 3] = `BITSWAP( xored_last_in[ 3], 4,3,5,6,0,2,1,7 );
assign last[ 4] = `BITSWAP( xored_last_in[ 4], 4,3,7,0,5,6,1,2 );
assign last[ 5] = `BITSWAP( xored_last_in[ 5], 1,7,2,3,6,4,5,0 );
assign last[ 6] = `BITSWAP( xored_last_in[ 6], 6,5,3,2,4,1,0,7 );
assign last[ 7] = `BITSWAP( xored_last_in[ 7], 3,5,1,4,2,7,0,6 );
assign last[ 8] = `BITSWAP( xored_last_in[ 8], 4,7,5,1,6,0,2,3 );
assign last[ 9] = `BITSWAP( xored_last_in[ 9], 3,5,0,6,1,2,7,4 );
assign last[10] = `BITSWAP( xored_last_in[10], 1,3,0,7,5,2,4,6 );
assign last[11] = `BITSWAP( xored_last_in[11], 7,3,0,2,4,6,1,5 );
assign last[12] = `BITSWAP( xored_last_in[12], 6,4,7,2,1,5,3,0 );
assign last[13] = `BITSWAP( xored_last_in[13], 6,3,7,0,5,4,2,1 );
assign last[14] = `BITSWAP( xored_last_in[14], 6,1,3,2,7,4,5,0 );
assign last[15] = `BITSWAP( xored_last_in[15], 1,6,3,5,0,7,4,2 );

assign ok_dly = dec_en ? ok_latch : rom_ok;

always @(posedge clk) ok_latch <= rom_ok;

always @(addr,op_n,enc,dec_type,dec_en,bypass,val_a,val_b) begin
    // LUT Address
    lut_a = {
        op_n,
        addr[23:16],
        addr[9],
        addr[5],
        addr[3],
        addr[1]
    };
    // Encoded byte
    encbyte = {
        enc[15:10],
        enc[6],
        enc[3]
    };
    // Decoded data
    dec        = enc;
    decbyte    = dec_type ? val_b : val_a;
    if( dec_en && !bypass ) begin
        dec[15:10] = decbyte[7:2];
        dec[6]     = decbyte[1];
        dec[3]     = decbyte[0];
    end
end


always @(shkey,op_n) begin
    bypass = shkey==0;
    key = shkey;
    // unshuffle the key
    if( op_n ) begin // not an OP
        key[5:4] = ~key[5:4];

        if(!key[3])
            key[1] = ~key[1];
        key = `BITSWAP( key,1,0,6,4,3,5,2,7 );
        if(key[6])
            key = `BITSWAP( key,7,6,2,4,5,3,1,0 );
    end else begin // an OP
        key[4:2] = ~key[4:2];

        if( !key[3] )
            key[5] = ~key[5];

        if( key[7] )
            key[6] = ~key[6];

        key = `BITSWAP( key,5,7,6,4,2,3,1,0 );

        if(key[6])
            key = `BITSWAP( key,7,6,5,3,2,4,1,0 );
    end

    if( key[6] ) begin
        key[4] = key[4] ^ key[5];
    end else begin
        key[5] = key[5] ^ ~key[4];
    end
end

always @* begin
    // Second LUT address
    lut2_addr = second[ key[7:4] ];
    if( key[3] ) lut2_addr[0] = ~lut2_addr[0];
    if( key[0] ) lut2_addr    =  lut2_addr ^ 8'hb1;
    if( !op_n )
        lut2_addr = lut2_addr ^ 8'h34;
    else
        lut2_addr[0] = lut2_addr[0] ^ key[6];
end

// FD1089A variant
always @(preval,key,op_n) begin
    family = {1'b0,key[2:0]};
    if( op_n ) begin
        family[3] = family[3] ^(~key[6] & key[2]);
        family[3] = family[3] ^  key[4];
    end else begin
        family[3] = family[3] ^ (key[6] & key[2]);
        family[3] = family[3] ^  key[5];
    end

    last_in = preval;
    if( key[0] ) begin
        if( last_in[0] ) last_in[7:6] = ~last_in[7:6];
        if(~last_in[6] ^ last_in[4] )
            last_in=`BITSWAP(last_in,7,6,5,4,1,0,2,3);
    end else begin
        if( ~last_in[6] ^ last_in[4] )
            last_in=`BITSWAP(last_in, 7,6,5,4,0,1,3,2);
    end
    if( !last_in[6] )
        last_in = `BITSWAP(last_in, 7,6,5,4,2,3,0,1);
    val_a = last[ family ];
end

// FD1089B variant
always @(preval,key,op_n) begin
    lsbxor= 0;
    lastb = preval;
    if( op_n ) begin
        lsbxor = lsbxor ^(~key[6] & key[2]);
        lsbxor = lsbxor ^  key[4];
    end else begin
        lsbxor = lsbxor ^ (key[6] & key[2]);
        lsbxor = lsbxor ^  key[5];
    end
    lastb[0] = lastb[0] ^ lsbxor;

    if( key[2] ) begin
        lastb=`BITSWAP(lastb,7,6,5,4,1,0,3,2);
        if( key[0] ^ key[1])
            lastb=`BITSWAP(lastb,7,6,5,4,0,1,3,2);
    end else begin
        lastb=`BITSWAP(lastb,7,6,5,4,3,2,0,1);
        if( key[0] ^ key[1] )
            lastb=`BITSWAP(lastb,7,6,5,4,1,0,2,3);
    end
    val_b = lastb;
end

jtframe_prom #(.AW(8),.SIMFILE("fd1089.bin")) u_lut(
    .clk    ( clk            ),
    .cen    ( 1'b1           ),
    .data   ( prog_data      ),
    .rd_addr( lut2_addr      ),
    .wr_addr( prog_addr[7:0] ),
    .we     ( fd1089_we      ),
    .q      ( preval         )
);

`undef BITSWAP

endmodule

