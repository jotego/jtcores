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
    Date: 29-8-2021 */

// This module is based in blackwine's MC8123_rom_decrypt
// module, found in Arcade-SEGASYS1_MiSTer repository

module jtmc8123(
    input             clk,

    // interface to Z80 CPU
    input             m1_n,
    input      [15:0] a,
    input             enc_en,

    // connect to program ROM
    input       [7:0] enc,
    input             rom_ok,

    // Decoded
    output reg  [7:0] dec,
    output reg        dec_ok,

    // Keys
    output     [12:0] key_addr,
    input      [ 7:0] key_data
);

wire [ 7:0] key;

assign key = key_data;
assign key_addr = {m1_n,a[15:10],a[8],a[6],a[4],a[2:0]};

wire [2:0] decrypt_type = {key[4]^key[5],
                   key[0]^key[1]^key[2]^key[4],
                   key[0]^key[2]^m1_n};

wire [1:0] swap = {key[2]^key[3], key[0]^key[1]};

wire [3:0] param = {key[1]^key[6]^key[7],
                key[0]^key[1]^key[6],
                key[0]^key[2]^key[3],
                key[0]^m1_n};

always @(posedge clk) begin
    dec_ok <= rom_ok;
    if( !enc_en )
        dec <= enc;
    else
        case(decrypt_type)
            0: dec <= decrypt_type_0 (enc, param, swap);
            1: dec <= decrypt_type_0 (enc, param, swap);
            2: dec <= decrypt_type_1a(enc, param, swap);
            3: dec <= decrypt_type_1b(enc, param, swap);
            4: dec <= decrypt_type_2a(enc, param, swap);
            5: dec <= decrypt_type_2b(enc, param, swap);
            6: dec <= decrypt_type_3a(enc, param, swap);
            7: dec <= decrypt_type_3b(enc, param, swap);
        endcase
end

`define bitswap8(a,b,c,d,e,f,g,h) {v[a],v[b],v[c],v[d],v[e],v[f],v[g],v[h]}

reg [7:0] v;
reg s;
reg t;

function [7:0] decrypt_type_0;
    input [7:0] value;
    input [3:0] p; // param
    input [1:0] swap;
begin
    v = value;
    case (swap)
        0: v = `bitswap8(7,5,3,1,2,0,6,4);
        1: v = `bitswap8(5,3,7,2,1,0,4,6);
        2: v = `bitswap8(0,3,4,6,7,1,5,2);
        3: v = `bitswap8(0,7,3,2,6,4,1,5);
    endcase

    s = p[3] & v[7];
    t = p[2] & v[6];

    v = {
         v[7] ^ t ^ v[6] ^ p[1],
         v[6] ^ (p[1] & (v[7] ^ t ^ v[6])) ^ p[1],
         v[5] ^ s ^ v[2] ^ t ^ p[2] ^ p[0],
        ~v[4],
        ~v[3] ^ s,
         v[2] ^ t ^ p[2],
        ~v[1] ^ t,
         v[0] ^ s ^ v[2] ^ t ^ p[2] ^ p[0]
    };

    decrypt_type_0 = p[0] ? `bitswap8(7,6,5,1,4,3,2,0) : v;
end
endfunction

// decrypt type 1a

function [7:0] decrypt_type_1a;
    input [7:0] value;
    input [3:0] p; // param
    input [1:0] swap;
begin
    v = value;
    case (swap)
        0: v = `bitswap8(4,2,6,5,3,7,1,0);
        1: v = `bitswap8(6,0,5,4,3,2,1,7);
        2: v = `bitswap8(2,3,6,1,4,0,7,5);
        3: v = `bitswap8(6,5,1,3,2,7,0,4);
    endcase

    v = p[2] ? `bitswap8(7,6,1,5,3,2,4,0) : v;

    v = {
         v[7] ^ v[4] ^ p[3],
        ~v[6] ^ v[7] ^ v[2] ^ v[4] ^ p[1],
         v[5],
         v[4] ^ v[7] ^ v[2],
        ~v[3] ^ v[7] ^ v[6] ^ v[2] ^ p[1],
         v[2] ^ v[4] ^ p[3],
        ~v[1] ^ v[2],
        ~v[0] ^ v[1]
    };

    decrypt_type_1a = p[0] ? `bitswap8(7,6,1,4,3,2,5,0) : v;
end
endfunction

// decrypt type 1b

function [7:0] decrypt_type_1b;
    input [7:0] value;
    input [3:0] p; // param
    input [1:0] swap;
begin
    v = value;
    case (swap)
        0: v = `bitswap8(1,0,3,2,5,6,4,7);
        1: v = `bitswap8(2,0,5,1,7,4,6,3);
        2: v = `bitswap8(6,4,7,2,0,5,1,3);
        3: v = `bitswap8(7,1,3,6,0,2,5,4);
    endcase

    s = v[2] & v[0];
    v = {
         v[7] ^ s ^ v[5] ^ v[3] ^ p[2],
        ~v[6] ^ v[4] ^ s ^ v[0] ^ v[3] ^ p[2] ^ p[0],
         v[5] ^ v[4] ^ s ^ v[1],
        ~v[4] ^ s ^ p[3] ^ p[1],
         v[3] ^ p[1] ^ p[2],
         v[2] ^ v[7] ^ s ^ v[5] ^ v[0] ^ v[3] ^ p[0],
         v[1] ^ v[6] ^ v[0] ^ v[3] ^ p[3] ^ p[0],
        ~v[0] ^ v[3] ^ p[0] ^ p[2]
    };

    decrypt_type_1b = v;
end
endfunction

// decrypt type 2a

function [7:0] decrypt_type_2a;
    input [7:0] value;
    input [3:0] p; // param
    input [1:0] swap;
begin
    v = value;
    case (swap)
        0: v = `bitswap8(0,1,4,3,5,6,2,7);
        1: v = `bitswap8(6,3,0,5,7,4,1,2);
        2: v = `bitswap8(1,6,4,5,0,3,7,2);
        3: v = `bitswap8(4,6,7,5,2,3,1,0);
    endcase

    v = (v[3] || (p[1] & v[2])) ? `bitswap8(6,0,7,4,3,2,1,5) : v;
    v = {
        ~v[7] ^ v[5],
        ~v[6] ^ v[0],
        ~v[5] ^ v[6],
        ~v[4] ^ p[2],
         v[3] ^ v[4] ^ p[2],
         v[2] ^ v[1] ^ p[2],
        ~v[1] ^ p[2],
         v[0] ^ v[4] ^ p[2]
    };

    case({p[3],p[0]})
        1: v = `bitswap8(7,6,5,2,1,3,4,0);
        2: v = `bitswap8(7,6,5,1,2,4,3,0);
        3: v = `bitswap8(7,6,5,3,4,1,2,0);
        default:;
    endcase

    decrypt_type_2a = v;
end
endfunction

// decrypt type 2b

function [7:0] decrypt_type_2b;
    input [7:0] value;
    input [3:0] p; // param
    input [1:0] swap;
begin
    v = value;
    case (swap)
        0: v = `bitswap8(1,3,4,6,5,7,0,2);
        1: v = `bitswap8(0,1,5,4,7,3,2,6);
        2: v = `bitswap8(3,5,4,1,6,2,0,7);
        3: v = `bitswap8(5,2,3,0,4,7,6,1);
    endcase

    s = v[7] & v[3];
    v = {
        v[7] ^ v[5] ^ s ^ v[4],
        v[6] ^ s,
        v[5] ^ v[1] ^ s ^ v[4],
        v[4] ^ s,
        v[3] ^ v[5] ^ s ^ v[4],
        v[2] ^ v[7],
        v[1] ^ s ^ v[4],
        v[0] ^ s
    };

    s = v[5] & (v[7] ^ v[1]);
    v = {
        ~v[7] ^ v[6] ^ v[3] ^ p[2] ^ p[1],
         v[6] ^ v[3] ^ p[3] ^ p[2],
         v[5] ^ v[6] ^ v[3] ^ p[2] ^ p[0],
         v[4] ^ s,
        ~v[3] ^ v[2] ^ p[3] ^ p[2],
        ~v[2] ^ p[2] ^ p[0],
        ~v[1] ^ v[3] ^ v[2] ^ p[3] ^ p[2],
         v[0] ^ s
    };
    decrypt_type_2b = v;
end
endfunction

// decrypt type 3a

function [7:0] decrypt_type_3a;
    input [7:0] value;
    input [3:0] p; // param
    input [1:0] swap;
begin
    v = value;
    case (swap)
        0: v = `bitswap8(5,3,1,7,0,2,6,4);
        1: v = `bitswap8(3,1,2,5,4,7,0,6);
        2: v = `bitswap8(5,6,1,2,7,0,4,3);
        3: v = `bitswap8(5,6,7,0,4,2,1,3);
    endcase

    v = {
        v[7] ^ v[2],
        v[6],
        v[5] ^ v[2],
        v[4] ^ v[2],
        v[3],
        v[2],
        v[1],
        v[0] ^ v[3]
    };

    v = p[0] ? `bitswap8(7,2,5,4,3,1,0,6) : v;

    v = {
        v[7],
        v[6] ^ v[1],
        v[5],
        v[4] ^ v[3] ^ p[3],
        v[3] ^ p[3],
        v[2] ^ v[3],
        v[1] ^ v[3],
        v[0] ^ v[1]
    };

    v = v[3] ? `bitswap8(5,6,7,4,3,2,1,0) : v;

    v = {
         v[7] ^ p[2],
        ~v[6],
        ~v[5],
        ~v[4] ^ p[1],
        ~v[3],
         v[2] ^ v[5],
         v[1] ^ v[5],
         v[0] ^ p[0]
    };
    decrypt_type_3a = v;
end
endfunction


// decrypt type 3b

function [7:0] decrypt_type_3b;
    input [7:0] value;
    input [3:0] p; // param
    input [1:0] swap;
begin
    v = value;
    case (swap)
        0: v = `bitswap8(3,7,5,4,0,6,2,1);
        1: v = `bitswap8(7,5,4,6,1,2,0,3);
        2: v = `bitswap8(7,4,3,0,5,1,6,2);
        3: v = `bitswap8(2,6,4,1,3,7,0,5);
    endcase

    v = (v[2] ^ v[7]) ? `bitswap8(7,6,3,4,5,2,1,0) : v;

    s = v[2] ^ p[3];
    t = v[4] ^ v[1];
    v = {
        v[7] ^ s ^ p[3],
        v[6] ^ t,
        v[5],
        v[4] ^ v[1],
        v[3],
        v[2] ^ v[1],
        v[1] ^ ((v[7] ^ s) & (v[6] ^ t) ^ v[7] ^ s),
        v[0] ^ p[2]
    };

    v = p[3] ? `bitswap8(4,6,3,2,5,0,1,7) : v;
    v = {
         v[7] ^ p[1],
         v[6],
        ~v[5],
         v[4] ^ v[5],
        ~v[3] ^ p[0],
        ~v[2] ^ v[7],
         v[1] ^ v[4],
         v[0]
    };

    decrypt_type_3b = v;
end
endfunction

endmodule
