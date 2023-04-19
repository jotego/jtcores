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

module jtcps2_fn1(
    input             clk,
    input      [15:0] din,
    input      [63:0] key,
    output reg [15:0] dout
);

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

assign l0 = { din[12], din[11], din[ 9], din[8], din[5], din[3], din[1], din[ 0] };
assign r0 = { din[14], din[15], din[13], din[2], din[7], din[6], din[4], din[10] };
assign l1 = r0;
assign l2 = r1;
assign l3 = r2;
assign l4 = r3;

always @(posedge clk) begin
    {
    dout[14], dout[15], dout[13], dout[ 2],
    dout[ 7], dout[ 6], dout[ 4], dout[10],
    dout[12], dout[11], dout[ 9], dout[ 8],
    dout[ 5], dout[ 3], dout[ 1], dout[ 0]
    } <= pre_out;

    latch_r3 <= pre_r3;
end

always @(*) begin
    full_keys = {
        key[17], key[44], key[28], key[52], key[31], key[ 2], key[14], key[23],
        key[40], key[45], key[42], key[26], key[ 7], key[22], key[63], key[24],
        key[ 9], key[54], key[57], key[51], key[56], key[62], key[61], key[59],
        key[ 2], key[48], key[29], key[62], key[11], key[13], key[25], key[38],
        key[51], key[45], key[ 4], key[ 5], key[46], key[16], key[44], key[50],
        key[ 1], key[63], key[15], key[ 8], key[18], key[35], key[33], key[27],
        key[60], key[59], key[54], key[55], key[ 8], key[20], key[53], key[57],
        key[37], key[46], key[47], key[18], key[25], key[52], key[41], key[21],
        key[14], key[43], key[42], key[ 6], key[35], key[32], key[13], key[48],
        key[21], key[61], key[12], key[34], key[ 6], key[43], key[39], key[27],
        key[19], key[23], key[41], key[10], key[53], key[ 5], key[16], key[ 3],
        key[30], key[22], key[31], key[ 0], key[36], key[49], key[58], key[33]
    };
    full_keys[5:4  ] = full_keys[5:4  ] ^ full_keys[2:1 ];
    full_keys[ 11  ] = full_keys[11   ] ^ full_keys[8   ];
    full_keys[24+5 ] = full_keys[24+5 ] ^ full_keys[24  ];
    full_keys[24+11] = full_keys[24+11] ^ full_keys[24+8];
    full_keys[48+5 ] = full_keys[48+5 ] ^ full_keys[48+1];
    full_keys[48+11] = full_keys[48+11] ^ full_keys[48+8];
    {key4, key3, key2, key1 } = full_keys;
end


jtcps2_sbox_fn1_r1 u_r1(
    .din    (   r0      ),
    .key    ( key1      ),
    .dout   ( pre_r1    )
);

jtcps2_sbox_fn1_r2 u_r2(
    .din    (   r1      ),
    .key    ( key2      ),
    .dout   ( pre_r2    )
);

jtcps2_sbox_fn1_r3 u_r3(
    .din    (   r2      ),
    .key    ( key3      ),
    .dout   ( pre_r3    )
);

jtcps2_sbox_fn1_r4 u_r4(
    .din    (   r3      ),
    .key    ( key4      ),
    .dout   ( pre_r4    )
);

endmodule
