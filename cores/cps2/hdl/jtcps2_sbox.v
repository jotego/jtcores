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

module jtcps2_sbox(
    input  [ 7:0] din,
    input  [ 5:0] key,
    output [ 1:0] dout
);

parameter [127:0] LUT=128'd0;
parameter [ 17:0] LOC=24'd0;
parameter [  5:0] OK=6'd0;

wire [5:0] dex;
wire [5:0] addr;

generate
    genvar aux;
    for( aux=0; aux<6; aux=aux+1 ) begin : mux
        if( OK[aux] )
            assign dex[aux] = din[ LOC[ 3*(aux+1)-1:3*aux ] ];
        else
            assign dex[aux] = 0;
    end
endgenerate

assign addr = dex ^ key;
assign dout = { LUT[{addr,1'b1}], LUT[{addr,1'b0}] };

endmodule