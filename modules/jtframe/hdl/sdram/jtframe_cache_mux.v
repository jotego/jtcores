/*  This file is part of JTFRAME.
    JTFRAME program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTFRAME program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTFRAME.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 21-3-2026 */

module jtframe_cache_mux #(
    parameter SDRAM_AW  = 23,
              ENDIAN    = 0,
              AW0       = 23,
              BLOCKS0   = 8,
              BLKSIZE0  = 1024,
              DW0       = 8,
              AW0_0     = DW0==32 ? 2 : DW0==16 ? 1 : 0,
              BA0       = 0,
              OFFSET0   = 0,
              AW1       = 23,
              BLOCKS1   = 8,
              BLKSIZE1  = 1024,
              DW1       = 8,
              AW0_1     = DW1==32 ? 2 : DW1==16 ? 1 : 0,
              BA1       = 0,
              OFFSET1   = 0,
              AW2       = 23,
              BLOCKS2   = 8,
              BLKSIZE2  = 1024,
              DW2       = 8,
              AW0_2     = DW2==32 ? 2 : DW2==16 ? 1 : 0,
              BA2       = 0,
              OFFSET2   = 0,
              AW3       = 23,
              BLOCKS3   = 8,
              BLKSIZE3  = 1024,
              DW3       = 8,
              AW0_3     = DW3==32 ? 2 : DW3==16 ? 1 : 0,
              BA3       = 0,
              OFFSET3   = 0,
              AW4       = 23,
              BLOCKS4   = 8,
              BLKSIZE4  = 1024,
              DW4       = 8,
              AW0_4     = DW4==32 ? 2 : DW4==16 ? 1 : 0,
              BA4       = 0,
              OFFSET4   = 0,
              AW5       = 23,
              BLOCKS5   = 8,
              BLKSIZE5  = 1024,
              DW5       = 8,
              AW0_5     = DW5==32 ? 2 : DW5==16 ? 1 : 0,
              BA5       = 0,
              OFFSET5   = 0,
              AW6       = 23,
              BLOCKS6   = 8,
              BLKSIZE6  = 1024,
              DW6       = 8,
              AW0_6     = DW6==32 ? 2 : DW6==16 ? 1 : 0,
              BA6       = 0,
              OFFSET6   = 0,
              AW7       = 23,
              BLOCKS7   = 8,
              BLKSIZE7  = 1024,
              DW7       = 8,
              AW0_7     = DW7==32 ? 2 : DW7==16 ? 1 : 0,
              BA7       = 0,
              OFFSET7   = 0
)(
    input                       rst,
    input                       clk,

    input      [AW0-1:AW0_0]    addr0,
    output     [DW0-1:0]        dout0,
    input                       rd0,
    output                      ok0,

    input      [AW1-1:AW0_1]    addr1,
    output     [DW1-1:0]        dout1,
    input                       rd1,
    output                      ok1,

    input      [AW2-1:AW0_2]    addr2,
    output     [DW2-1:0]        dout2,
    input                       rd2,
    output                      ok2,

    input      [AW3-1:AW0_3]    addr3,
    output     [DW3-1:0]        dout3,
    input                       rd3,
    output                      ok3,

    input      [AW4-1:AW0_4]    addr4,
    output     [DW4-1:0]        dout4,
    input                       rd4,
    output                      ok4,

    input      [AW5-1:AW0_5]    addr5,
    output     [DW5-1:0]        dout5,
    input                       rd5,
    output                      ok5,

    input      [AW6-1:AW0_6]    addr6,
    output     [DW6-1:0]        dout6,
    input                       rd6,
    output                      ok6,

    input      [AW7-1:AW0_7]    addr7,
    output     [DW7-1:0]        dout7,
    input                       rd7,
    output                      ok7,

    output reg [SDRAM_AW-1:1]   addr,
    output reg [1:0]            ba,
    output                      rd,
    input      [15:0]           din,
    input                       ack,
    input                       dst,
    input                       dok,
    input                       rdy
);

wire [SDRAM_AW-1:1] ext_addr0;
wire [SDRAM_AW-1:1] ext_addr1;
wire [SDRAM_AW-1:1] ext_addr2;
wire [SDRAM_AW-1:1] ext_addr3;
wire [SDRAM_AW-1:1] ext_addr4;
wire [SDRAM_AW-1:1] ext_addr5;
wire [SDRAM_AW-1:1] ext_addr6;
wire [SDRAM_AW-1:1] ext_addr7;

wire ext_rd0, ext_rd1, ext_rd2, ext_rd3;
wire ext_rd4, ext_rd5, ext_rd6, ext_rd7;
wire [7:0] ext_ack;
wire [7:0] ext_dst;
wire [7:0] ext_dok;
wire [7:0] ext_rdy;

wire [7:0] req = {
    ext_rd7, ext_rd6, ext_rd5, ext_rd4,
    ext_rd3, ext_rd2, ext_rd1, ext_rd0
};

assign ext_ack = {
    active && active_sel==3'd7 && ack,
    active && active_sel==3'd6 && ack,
    active && active_sel==3'd5 && ack,
    active && active_sel==3'd4 && ack,
    active && active_sel==3'd3 && ack,
    active && active_sel==3'd2 && ack,
    active && active_sel==3'd1 && ack,
    active && active_sel==3'd0 && ack
};

assign ext_dst = {
    active && active_sel==3'd7 && dst,
    active && active_sel==3'd6 && dst,
    active && active_sel==3'd5 && dst,
    active && active_sel==3'd4 && dst,
    active && active_sel==3'd3 && dst,
    active && active_sel==3'd2 && dst,
    active && active_sel==3'd1 && dst,
    active && active_sel==3'd0 && dst
};

assign ext_dok = {
    active && active_sel==3'd7 && dok,
    active && active_sel==3'd6 && dok,
    active && active_sel==3'd5 && dok,
    active && active_sel==3'd4 && dok,
    active && active_sel==3'd3 && dok,
    active && active_sel==3'd2 && dok,
    active && active_sel==3'd1 && dok,
    active && active_sel==3'd0 && dok
};

assign ext_rdy = {
    active && active_sel==3'd7 && rdy,
    active && active_sel==3'd6 && rdy,
    active && active_sel==3'd5 && rdy,
    active && active_sel==3'd4 && rdy,
    active && active_sel==3'd3 && rdy,
    active && active_sel==3'd2 && rdy,
    active && active_sel==3'd1 && rdy,
    active && active_sel==3'd0 && rdy
};

reg        active;
reg [2:0]  active_sel;
reg [2:0]  last_sel;
reg [2:0]  next_sel;
reg        next_valid;

assign rd = active && (
    (active_sel == 3'd0 && ext_rd0) ||
    (active_sel == 3'd1 && ext_rd1) ||
    (active_sel == 3'd2 && ext_rd2) ||
    (active_sel == 3'd3 && ext_rd3) ||
    (active_sel == 3'd4 && ext_rd4) ||
    (active_sel == 3'd5 && ext_rd5) ||
    (active_sel == 3'd6 && ext_rd6) ||
    (active_sel == 3'd7 && ext_rd7)
);

always @(*) begin
    next_valid = 1'b0;
    next_sel   = 3'd0;
    case( last_sel )
        3'd0: begin
            if( req[1] ) begin next_valid = 1'b1; next_sel = 3'd1; end
            else if( req[2] ) begin next_valid = 1'b1; next_sel = 3'd2; end
            else if( req[3] ) begin next_valid = 1'b1; next_sel = 3'd3; end
            else if( req[4] ) begin next_valid = 1'b1; next_sel = 3'd4; end
            else if( req[5] ) begin next_valid = 1'b1; next_sel = 3'd5; end
            else if( req[6] ) begin next_valid = 1'b1; next_sel = 3'd6; end
            else if( req[7] ) begin next_valid = 1'b1; next_sel = 3'd7; end
            else if( req[0] ) begin next_valid = 1'b1; next_sel = 3'd0; end
        end
        3'd1: begin
            if( req[2] ) begin next_valid = 1'b1; next_sel = 3'd2; end
            else if( req[3] ) begin next_valid = 1'b1; next_sel = 3'd3; end
            else if( req[4] ) begin next_valid = 1'b1; next_sel = 3'd4; end
            else if( req[5] ) begin next_valid = 1'b1; next_sel = 3'd5; end
            else if( req[6] ) begin next_valid = 1'b1; next_sel = 3'd6; end
            else if( req[7] ) begin next_valid = 1'b1; next_sel = 3'd7; end
            else if( req[0] ) begin next_valid = 1'b1; next_sel = 3'd0; end
            else if( req[1] ) begin next_valid = 1'b1; next_sel = 3'd1; end
        end
        3'd2: begin
            if( req[3] ) begin next_valid = 1'b1; next_sel = 3'd3; end
            else if( req[4] ) begin next_valid = 1'b1; next_sel = 3'd4; end
            else if( req[5] ) begin next_valid = 1'b1; next_sel = 3'd5; end
            else if( req[6] ) begin next_valid = 1'b1; next_sel = 3'd6; end
            else if( req[7] ) begin next_valid = 1'b1; next_sel = 3'd7; end
            else if( req[0] ) begin next_valid = 1'b1; next_sel = 3'd0; end
            else if( req[1] ) begin next_valid = 1'b1; next_sel = 3'd1; end
            else if( req[2] ) begin next_valid = 1'b1; next_sel = 3'd2; end
        end
        3'd3: begin
            if( req[4] ) begin next_valid = 1'b1; next_sel = 3'd4; end
            else if( req[5] ) begin next_valid = 1'b1; next_sel = 3'd5; end
            else if( req[6] ) begin next_valid = 1'b1; next_sel = 3'd6; end
            else if( req[7] ) begin next_valid = 1'b1; next_sel = 3'd7; end
            else if( req[0] ) begin next_valid = 1'b1; next_sel = 3'd0; end
            else if( req[1] ) begin next_valid = 1'b1; next_sel = 3'd1; end
            else if( req[2] ) begin next_valid = 1'b1; next_sel = 3'd2; end
            else if( req[3] ) begin next_valid = 1'b1; next_sel = 3'd3; end
        end
        3'd4: begin
            if( req[5] ) begin next_valid = 1'b1; next_sel = 3'd5; end
            else if( req[6] ) begin next_valid = 1'b1; next_sel = 3'd6; end
            else if( req[7] ) begin next_valid = 1'b1; next_sel = 3'd7; end
            else if( req[0] ) begin next_valid = 1'b1; next_sel = 3'd0; end
            else if( req[1] ) begin next_valid = 1'b1; next_sel = 3'd1; end
            else if( req[2] ) begin next_valid = 1'b1; next_sel = 3'd2; end
            else if( req[3] ) begin next_valid = 1'b1; next_sel = 3'd3; end
            else if( req[4] ) begin next_valid = 1'b1; next_sel = 3'd4; end
        end
        3'd5: begin
            if( req[6] ) begin next_valid = 1'b1; next_sel = 3'd6; end
            else if( req[7] ) begin next_valid = 1'b1; next_sel = 3'd7; end
            else if( req[0] ) begin next_valid = 1'b1; next_sel = 3'd0; end
            else if( req[1] ) begin next_valid = 1'b1; next_sel = 3'd1; end
            else if( req[2] ) begin next_valid = 1'b1; next_sel = 3'd2; end
            else if( req[3] ) begin next_valid = 1'b1; next_sel = 3'd3; end
            else if( req[4] ) begin next_valid = 1'b1; next_sel = 3'd4; end
            else if( req[5] ) begin next_valid = 1'b1; next_sel = 3'd5; end
        end
        3'd6: begin
            if( req[7] ) begin next_valid = 1'b1; next_sel = 3'd7; end
            else if( req[0] ) begin next_valid = 1'b1; next_sel = 3'd0; end
            else if( req[1] ) begin next_valid = 1'b1; next_sel = 3'd1; end
            else if( req[2] ) begin next_valid = 1'b1; next_sel = 3'd2; end
            else if( req[3] ) begin next_valid = 1'b1; next_sel = 3'd3; end
            else if( req[4] ) begin next_valid = 1'b1; next_sel = 3'd4; end
            else if( req[5] ) begin next_valid = 1'b1; next_sel = 3'd5; end
            else if( req[6] ) begin next_valid = 1'b1; next_sel = 3'd6; end
        end
        default: begin
            if( req[0] ) begin next_valid = 1'b1; next_sel = 3'd0; end
            else if( req[1] ) begin next_valid = 1'b1; next_sel = 3'd1; end
            else if( req[2] ) begin next_valid = 1'b1; next_sel = 3'd2; end
            else if( req[3] ) begin next_valid = 1'b1; next_sel = 3'd3; end
            else if( req[4] ) begin next_valid = 1'b1; next_sel = 3'd4; end
            else if( req[5] ) begin next_valid = 1'b1; next_sel = 3'd5; end
            else if( req[6] ) begin next_valid = 1'b1; next_sel = 3'd6; end
            else if( req[7] ) begin next_valid = 1'b1; next_sel = 3'd7; end
        end
    endcase
end

always @(posedge clk) begin
    if( rst ) begin
        active     <= 1'b0;
        active_sel <= 3'd0;
        last_sel   <= 3'd7;
        addr       <= {SDRAM_AW-1{1'b0}};
        ba         <= 2'd0;
    end else begin
        if( active ) begin
            if( rdy ) begin
                active   <= 1'b0;
                last_sel <= active_sel;
            end
        end else if( next_valid ) begin
            active     <= 1'b1;
            active_sel <= next_sel;
            case( next_sel )
                3'd0: begin addr <= ext_addr0 + OFFSET0[0+:SDRAM_AW-1]; ba <= BA0[1:0]; end
                3'd1: begin addr <= ext_addr1 + OFFSET1[0+:SDRAM_AW-1]; ba <= BA1[1:0]; end
                3'd2: begin addr <= ext_addr2 + OFFSET2[0+:SDRAM_AW-1]; ba <= BA2[1:0]; end
                3'd3: begin addr <= ext_addr3 + OFFSET3[0+:SDRAM_AW-1]; ba <= BA3[1:0]; end
                3'd4: begin addr <= ext_addr4 + OFFSET4[0+:SDRAM_AW-1]; ba <= BA4[1:0]; end
                3'd5: begin addr <= ext_addr5 + OFFSET5[0+:SDRAM_AW-1]; ba <= BA5[1:0]; end
                3'd6: begin addr <= ext_addr6 + OFFSET6[0+:SDRAM_AW-1]; ba <= BA6[1:0]; end
                default: begin addr <= ext_addr7 + OFFSET7[0+:SDRAM_AW-1]; ba <= BA7[1:0]; end
            endcase
        end
    end
end

jtframe_cache #(
    .AW     ( AW0      ),
    .BLOCKS ( BLOCKS0  ),
    .BLKSIZE( BLKSIZE0 ),
    .DW     ( DW0      ),
    .ENDIAN ( ENDIAN   ),
    .EW     ( SDRAM_AW )
) u_cache0 (
    .rst        ( rst                           ),
    .clk        ( clk                           ),
    .addr       ( addr0                         ),
    .dout       ( dout0                         ),
    .rd         ( rd0                           ),
    .ok         ( ok0                           ),
    .ext_addr   ( ext_addr0                     ),
    .ext_din    ( din                           ),
    .ext_rd     ( ext_rd0                       ),
    .ext_ack    ( ext_ack[0]                    ),
    .ext_dst    ( ext_dst[0]                    ),
    .ext_dok    ( ext_dok[0]                    ),
    .ext_rdy    ( ext_rdy[0]                    )
);

jtframe_cache #(
    .AW     ( AW1      ),
    .BLOCKS ( BLOCKS1  ),
    .BLKSIZE( BLKSIZE1 ),
    .DW     ( DW1      ),
    .ENDIAN ( ENDIAN   ),
    .EW     ( SDRAM_AW )
) u_cache1 (
    .rst        ( rst                           ),
    .clk        ( clk                           ),
    .addr       ( addr1                         ),
    .dout       ( dout1                         ),
    .rd         ( rd1                           ),
    .ok         ( ok1                           ),
    .ext_addr   ( ext_addr1                     ),
    .ext_din    ( din                           ),
    .ext_rd     ( ext_rd1                       ),
    .ext_ack    ( ext_ack[1]                    ),
    .ext_dst    ( ext_dst[1]                    ),
    .ext_dok    ( ext_dok[1]                    ),
    .ext_rdy    ( ext_rdy[1]                    )
);

jtframe_cache #(
    .AW     ( AW2      ),
    .BLOCKS ( BLOCKS2  ),
    .BLKSIZE( BLKSIZE2 ),
    .DW     ( DW2      ),
    .ENDIAN ( ENDIAN   ),
    .EW     ( SDRAM_AW )
) u_cache2 (
    .rst        ( rst                           ),
    .clk        ( clk                           ),
    .addr       ( addr2                         ),
    .dout       ( dout2                         ),
    .rd         ( rd2                           ),
    .ok         ( ok2                           ),
    .ext_addr   ( ext_addr2                     ),
    .ext_din    ( din                           ),
    .ext_rd     ( ext_rd2                       ),
    .ext_ack    ( ext_ack[2]                    ),
    .ext_dst    ( ext_dst[2]                    ),
    .ext_dok    ( ext_dok[2]                    ),
    .ext_rdy    ( ext_rdy[2]                    )
);

jtframe_cache #(
    .AW     ( AW3      ),
    .BLOCKS ( BLOCKS3  ),
    .BLKSIZE( BLKSIZE3 ),
    .DW     ( DW3      ),
    .ENDIAN ( ENDIAN   ),
    .EW     ( SDRAM_AW )
) u_cache3 (
    .rst        ( rst                           ),
    .clk        ( clk                           ),
    .addr       ( addr3                         ),
    .dout       ( dout3                         ),
    .rd         ( rd3                           ),
    .ok         ( ok3                           ),
    .ext_addr   ( ext_addr3                     ),
    .ext_din    ( din                           ),
    .ext_rd     ( ext_rd3                       ),
    .ext_ack    ( ext_ack[3]                    ),
    .ext_dst    ( ext_dst[3]                    ),
    .ext_dok    ( ext_dok[3]                    ),
    .ext_rdy    ( ext_rdy[3]                    )
);

jtframe_cache #(
    .AW     ( AW4      ),
    .BLOCKS ( BLOCKS4  ),
    .BLKSIZE( BLKSIZE4 ),
    .DW     ( DW4      ),
    .ENDIAN ( ENDIAN   ),
    .EW     ( SDRAM_AW )
) u_cache4 (
    .rst        ( rst                           ),
    .clk        ( clk                           ),
    .addr       ( addr4                         ),
    .dout       ( dout4                         ),
    .rd         ( rd4                           ),
    .ok         ( ok4                           ),
    .ext_addr   ( ext_addr4                     ),
    .ext_din    ( din                           ),
    .ext_rd     ( ext_rd4                       ),
    .ext_ack    ( ext_ack[4]                    ),
    .ext_dst    ( ext_dst[4]                    ),
    .ext_dok    ( ext_dok[4]                    ),
    .ext_rdy    ( ext_rdy[4]                    )
);

jtframe_cache #(
    .AW     ( AW5      ),
    .BLOCKS ( BLOCKS5  ),
    .BLKSIZE( BLKSIZE5 ),
    .DW     ( DW5      ),
    .ENDIAN ( ENDIAN   ),
    .EW     ( SDRAM_AW )
) u_cache5 (
    .rst        ( rst                           ),
    .clk        ( clk                           ),
    .addr       ( addr5                         ),
    .dout       ( dout5                         ),
    .rd         ( rd5                           ),
    .ok         ( ok5                           ),
    .ext_addr   ( ext_addr5                     ),
    .ext_din    ( din                           ),
    .ext_rd     ( ext_rd5                       ),
    .ext_ack    ( ext_ack[5]                    ),
    .ext_dst    ( ext_dst[5]                    ),
    .ext_dok    ( ext_dok[5]                    ),
    .ext_rdy    ( ext_rdy[5]                    )
);

jtframe_cache #(
    .AW     ( AW6      ),
    .BLOCKS ( BLOCKS6  ),
    .BLKSIZE( BLKSIZE6 ),
    .DW     ( DW6      ),
    .ENDIAN ( ENDIAN   ),
    .EW     ( SDRAM_AW )
) u_cache6 (
    .rst        ( rst                           ),
    .clk        ( clk                           ),
    .addr       ( addr6                         ),
    .dout       ( dout6                         ),
    .rd         ( rd6                           ),
    .ok         ( ok6                           ),
    .ext_addr   ( ext_addr6                     ),
    .ext_din    ( din                           ),
    .ext_rd     ( ext_rd6                       ),
    .ext_ack    ( ext_ack[6]                    ),
    .ext_dst    ( ext_dst[6]                    ),
    .ext_dok    ( ext_dok[6]                    ),
    .ext_rdy    ( ext_rdy[6]                    )
);

jtframe_cache #(
    .AW     ( AW7      ),
    .BLOCKS ( BLOCKS7  ),
    .BLKSIZE( BLKSIZE7 ),
    .DW     ( DW7      ),
    .ENDIAN ( ENDIAN   ),
    .EW     ( SDRAM_AW )
) u_cache7 (
    .rst        ( rst                           ),
    .clk        ( clk                           ),
    .addr       ( addr7                         ),
    .dout       ( dout7                         ),
    .rd         ( rd7                           ),
    .ok         ( ok7                           ),
    .ext_addr   ( ext_addr7                     ),
    .ext_din    ( din                           ),
    .ext_rd     ( ext_rd7                       ),
    .ext_ack    ( ext_ack[7]                    ),
    .ext_dst    ( ext_dst[7]                    ),
    .ext_dok    ( ext_dok[7]                    ),
    .ext_rdy    ( ext_rdy[7]                    )
);

endmodule
