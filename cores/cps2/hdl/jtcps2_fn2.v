/*  This file is part of JTCORES1.
    JTCORES1 program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTCORES1.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 16-2-2021 */

module jtcps2_fn2(
    input          clk,
    input   [15:0] din,
    input   [15:0] key,
    input   [63:0] master_key,
    output  [15:0] dout
);

reg  [63:0] kext, kpre;
reg  [95:0] full_keys;
reg  [23:0] key1, key2, key3, key4;

wire [ 7:0] pre_r1, pre_r2, pre_r3, pre_r4;
wire [ 7:0] r0, r1, r2, r3, r4,
            l0, l1, l2, l3, l4;
wire [15:0] pre_out;

reg  [ 7:0] latch_r3;

assign r1 = pre_r1 ^ l0;
assign r2 = pre_r2 ^ l1;
assign r3 = latch_r3 ^ l2;
assign r4 = pre_r4 ^ l3;
assign pre_out = { l4, r4 };

assign l0 = { din[11], din[12], din[15], din[8], din[10], din[9], din[5], din[3] };
assign r0 = { din[ 7], din[14], din[ 4], din[1], din[13], din[2], din[0], din[6] };
assign l1 = r0;
assign l2 = r1;
assign l3 = r2;
assign l4 = r3;

assign {
    dout[ 7], dout[14], dout[ 4], dout[ 1],
    dout[13], dout[ 2], dout[ 0], dout[ 6],
    dout[11], dout[12], dout[15], dout[ 8],
    dout[10], dout[ 9], dout[ 5], dout[ 3]
} = pre_out;

always @(posedge clk) begin
    latch_r3 <= pre_r3;
end

always @(*) begin
    kpre = {
        key[ 3], key[13], key[ 6], key[ 8], key[ 9], key[ 0], key[15], key[ 1],
        key[10], key[ 2], key[ 5], key[ 4], key[ 7], key[12], key[11], key[14],
        key[ 3], key[14], key[ 5], key[13], key[ 8], key[15], key[ 7], key[11],
        key[ 1], key[12], key[ 9], key[ 6], key[ 0], key[ 2], key[10], key[ 4],
        key[ 3], key[15], key[ 0], key[ 8], key[10], key[ 6], key[ 1], key[ 4],
        key[14], key[ 9], key[11], key[13], key[ 2], key[ 7], key[12], key[ 5],
        key[11], key[13], key[ 7], key[12], key[ 2], key[ 3], key[ 8], key[ 1],
        key[ 6], key[15], key[ 0], key[ 4], key[ 9], key[14], key[10], key[ 5]
    };

    kext = kpre ^ master_key;

    full_keys = {
        kext[26], kext[ 8], kext[28], kext[23], kext[52], kext[55], kext[33], kext[21],
        kext[ 2], kext[44], kext[45], kext[51], kext[49], kext[14], kext[59], kext[ 3],
        kext[35], kext[50], kext[ 0], kext[10], kext[48], kext[53], kext[30], kext[12],
        kext[32], kext[59], kext[60], kext[48], kext[62], kext[56], kext[16], kext[33],
        kext[63], kext[11], kext[36], kext[24], kext[27], kext[26], kext[41], kext[31],
        kext[57], kext[49], kext[30], kext[12], kext[39], kext[29], kext[37], kext[46],
        kext[19], kext[ 2], kext[ 7], kext[22], kext[42], kext[15], kext[ 4], kext[ 5],
        kext[57], kext[55], kext[38], kext[47], kext[25], kext[17], kext[61], kext[56],
        kext[ 3], kext[31], kext[40], kext[54], kext[62], kext[16], kext[23], kext[63],
        kext[19], kext[39], kext[43], kext[11], kext[ 6], kext[15], kext[60], kext[20],
        kext[ 1], kext[18], kext[58], kext[29], kext[ 7], kext[28], kext[13], kext[47],
        kext[61], kext[38], kext[54], kext[44], kext[24], kext[32], kext[ 9], kext[34]
    };

    full_keys[  5  ] = full_keys[5    ] ^ full_keys[0   ];
    full_keys[ 11  ] = full_keys[11   ] ^ full_keys[6   ];
    full_keys[24+5 ] = full_keys[24+5 ] ^ full_keys[24  ];
    full_keys[24+4 ] = full_keys[24+4 ] ^ full_keys[24+1];
    full_keys[48+5 ] = full_keys[48+5 ] ^ full_keys[48+2];
    full_keys[48+4 ] = full_keys[48+4 ] ^ full_keys[48+3];
    full_keys[48+11] = full_keys[48+11] ^ full_keys[48+7];
    full_keys[72+5 ] = full_keys[72+5 ] ^ full_keys[72+1];
    {key4, key3, key2, key1 } = full_keys;
end


jtcps2_sbox_fn2_r1 u_r1(
    .din    (   r0      ),
    .key    ( key1      ),
    .dout   ( pre_r1    )
);

jtcps2_sbox_fn2_r2 u_r2(
    .din    (   r1      ),
    .key    ( key2      ),
    .dout   ( pre_r2    )
);

jtcps2_sbox_fn2_r3 u_r3(
    .din    (   r2      ),
    .key    ( key3      ),
    .dout   ( pre_r3    )
);

jtcps2_sbox_fn2_r4 u_r4(
    .din    (   r3      ),
    .key    ( key4      ),
    .dout   ( pre_r4    )
);

endmodule
