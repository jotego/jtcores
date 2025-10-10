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
    Date: 1-10-2025 */

module jtriders_tmnt2(
    input                rst,
    input                clk,
    input                cen,   // 16 MHz

    input                cs,
    input         [ 4:1] addr,
    input         [ 1:0] dsn,
    input         [15:0] din,
    input                cpu_we,
    input                dtack_n,

    // DMA
    output reg           bus_asn,
    output        [23:1] bus_addr,
    output reg    [15:0] bus_din,
    input         [15:0] bus_dout,
    output        [ 1:0] bus_dsn,
    output reg           bus_wrn,

    output reg           BRn,
    input                BGn,
    output reg           BGACKn
);
`ifndef NOTMNT2
wire        dma_on, enable, zlock, hflip, xylock;
wire [23:0] src, dst, mod_addr;
reg  [23:1] a;
wire [23:1] next_a, next_aw, cmod_a, attr_a, xmod_a, ymod_a, zmod_a, xzoom_a, yzoom_a;
reg  [15:0] code, cmod, xoff, yoff, xpos, ypos, xzoom, yzoom, xoff_lock, yoff_lock;
wire [14:0] xlin, ylin;
wire [15:0] xadj, yadj;
wire [ 9:0] xmant, xlog, ymant, ylog;
wire [ 8:0] xfrac, yfrac;
reg  [ 7:0] attr1;
reg  [ 9:5] attr2;
reg  [ 4:0] cbase, color;
reg  [ 5:0] st;
reg  [ 1:0] xztype, yztype;
wire [ 1:0] pre_xztype, pre_yztype;
reg         start;

assign bus_addr = a;
assign bus_dsn  = 0;
assign hflip    = bus_dout[14];
// address aliases
assign next_a  = a + 23'd1;
assign next_aw = a + 23'd2;
assign cmod_a  = mod_addr[23:1] + (23'h2a>>1);
assign attr_a  = mod_addr[23:1];
assign xmod_a  = mod_addr[23:1] + 23'h6;
assign ymod_a  = mod_addr[23:1] + 23'h7;
assign zmod_a  = mod_addr[23:1] + 23'h8;
assign xzoom_a = mod_addr[23:1] + (23'h1c>>1);
assign yzoom_a = mod_addr[23:1] + (23'h1e>>1);
assign xylock  = attr2[5] && (~|{xzoom[15:9],xzoom[7:0]});

jtriders_tmnt2_mmr u_mmr(
    .rst        ( rst       ),
    .clk        ( clk       ),

    .cs         ( cs        ),
    .addr       ( addr      ),
    .rnw        (~cpu_we    ),
    .din        ( din       ),
    .dsn        ( dsn       ),

    .dma_on     ( dma_on    ),
    .enable     ( enable    ),
    .src        ( src       ),
    .dst        ( dst       ),
    .mod        ( mod_addr  ),
    .zlock      ( zlock     ),

    // IOCTL dump
    .ioctl_addr (  5'd0     ),
    .ioctl_din  (           ),
    // Debug
    .debug_bus  (  8'd0     ),
    .st_dout    (           )
);

jtriders_tmnt2_zoom u_xzoom(
    .clk        ( clk       ),
    .xylock     ( xylock    ),

    .mant       ( xmant     ),
    .frac       ( xfrac     ),
    .log        ( xlog      ),
    .lin        ( xlin      ),
    .offset     ( xoff      ),
    .zoom       ( xzoom     ),
    .ztype      ( pre_xztype),
    .adj        ( xadj      )
);

jtriders_tmnt2_zoom u_yzoom(
    .clk        ( clk       ),
    .xylock     ( xylock    ),

    .mant       ( ymant     ),
    .frac       ( yfrac     ),
    .log        ( ylog      ),
    .lin        ( ylin      ),
    .offset     ( yoff      ),
    .zoom       ( yzoom     ),
    .ztype      ( pre_yztype),
    .adj        ( yadj      )
);

jtframe_dual_ram #(
    .DW        ( 9                  ),
    .SYNFILE   ("../../hdl/log2.hex")
)u_log(
    .clk0       ( clk               ),
    .clk1       ( clk               ),
    // Port 0
    .data0      ( 9'h0              ),
    .addr0      ( xmant             ),
    .we0        ( 1'b0              ),
    .q0         ( xfrac             ),
    // Port 1
    .data1      ( 9'h0              ),
    .addr1      ( ymant             ),
    .we1        ( 1'b0              ),
    .q1         ( yfrac             )
);

jtframe_dual_ram #(
    .DW        ( 15                 ),
    .AW        ( 10                 ),
    .SYNFILE   ("../../hdl/exp2.hex")
)u_exp(
    .clk0       ( clk               ),
    .clk1       ( clk               ),
    // Port 0
    .data0      ( 15'h0             ),
    .addr0      ( xlog[9:0]         ),
    .we0        ( 1'b0              ),
    .q0         ( xlin              ),
    // Port 1
    .data1      ( 15'h0             ),
    .addr1      ( 10'b0             ),
    .we1        ( 1'b0              ),
    .q1         ( ylin              )
);

always @(posedge clk) begin
    if(dma_on) start <= enable;
    if( cen  ) start <= 0;
end

always @(posedge clk) begin
    if( rst ) begin
        st      <= 0;
        BRn     <= 1;
        BGACKn  <= 1;
        bus_asn <= 1;
        bus_wrn <= 1;
    end else if(cen) begin
        st <= st + 1'd1;
        case(st)
             0: begin if(!start) st <= st; end
             1: begin BRn <= 0; bus_wrn <= 1; bus_asn <= 1; if(BGn) st <= st; end
             2: begin BGACKn <= 0; end
            // code
             3: begin a <= src[23:1]; bus_asn <= 0; if(dtack_n) st <= st; end
             4: begin bus_asn <= 1; code <= bus_dout; a <= next_a; end
            // attributes
             5: begin bus_asn <= 0; if(dtack_n) st <= st; end
             6: begin
                    // flip y, flip x and sprite size; mirror y, mirror x, shadow
                    {attr1[5:0],attr2[9:7]} <= bus_dout[15:7];
                    cbase <= bus_dout[4:0];
                    bus_asn <= 1;
                    a <= next_a;
                end
             7: begin bus_asn <= 0; if(dtack_n) st <= st; end
             8: begin xoff <= bus_dout; bus_asn <= 1; a <= next_a; end
             9: begin bus_asn <= 0; if(dtack_n) st <= st; end
            10: begin yoff <= bus_dout; bus_asn <= 1; end
            11: begin a <= cmod_a; bus_asn <= 0; if(dtack_n) st <= st; end
            12: begin color <= (cbase!=5'hf && bus_dout[15:8]<=8'h1f && !zlock) ?
                               bus_dout[8+:5] : cbase;
                      bus_asn <= 1;
                end
            13: begin a <= attr_a; bus_asn <= 0; if(dtack_n) st <= st; end
            14: begin attr2[6:5] <=  bus_dout[6:5];       // priority
                      attr1[7]   <=  bus_dout[15];        // active
                      attr1[6]   <=&{bus_dout[4],bus_dout[2]}; // keep aspect
                      attr1[4]   <= attr1[4]^hflip;
                      if(hflip) xoff <= -xoff;
                      bus_asn <= 1;
                end

            15: begin a <= xzoom_a;      bus_asn <= 0; if(dtack_n) st <= st; end
            16: begin xzoom <= bus_dout; bus_asn <= 1; end
            17: begin a <= yzoom_a;      bus_asn <= 0; if(dtack_n) st <= st; end
            18: begin
                yzoom     <= attr1[6] ? xzoom : bus_dout;
                bus_asn   <= 1;
                xztype    <= pre_xztype;
                xoff_lock <= xadj;
            end
            19: begin a <= xmod_a; bus_asn <= 0; if(dtack_n) st <= st; end
            20: begin
                xpos      <= xoff_lock + bus_dout;
                bus_asn   <= 1;
                yztype    <= pre_yztype;
                yoff_lock <= yadj;
            end
            21: begin a <= ymod_a; bus_asn <= 0; if(dtack_n) st <= st; end
            22: begin ypos <= yoff_lock + bus_dout; bus_asn <= 1; end
            23: begin a <= zmod_a; bus_asn <= 0; if(dtack_n) st <= st; end
            24: begin if(!zlock) ypos <= ypos + bus_dout; bus_asn <= 1; end

            25: begin a <= dst[23:1]; bus_asn <= 0; bus_wrn <= 0; bus_din <= {attr1,8'd0}; if(dtack_n) st<=st; end
            26: begin a <= next_aw;   bus_asn <= 1; end // +2
            27: begin                 bus_asn <= 0; bus_din <= code; if(dtack_n) st<=st; end
            28: begin a <= next_aw;   bus_asn <= 1; end // +4
            29: begin                 bus_asn <= 0; bus_din <= ypos; if(dtack_n) st<=st; end
            30: begin a <= next_aw;   bus_asn <= 1; end // +6
            31: begin                 bus_asn <= 0; bus_din <= xpos; if(dtack_n) st<=st; end
            32: begin a <= next_aw;   bus_asn <= 1; end // +8
            33: begin a <= next_aw;   bus_asn <= 1; end // +10
            34: begin a <= next_aw;   bus_asn <= 1; end // +12
            35: begin                 bus_asn <= 0; bus_din <= {6'd0,attr2,color}; if(dtack_n) st<=st; end
            36: begin                 bus_asn <= 1; BRn<= 1; bus_wrn <= 1; if(!BGn) st <= st; end
            37: begin BGACKn <= 1; st <= 0; end
        endcase
    end
end
`else
assign bus_addr = 0;
assign bus_dsn  = 3;
initial begin
    bus_asn     = 1;
    bus_din     = 1;
    bus_wrn     = 1;
    BRn         = 1;
    BGACKn      = 1;
end
`endif
endmodule
