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
              ENDIAN0   = ENDIAN,
              FULL0     = 0,
              AW0       = 23,
              BLOCKS0   = 8,
              BLKSIZE0  = 1024,
              DW0       = 8,
              AW0_0     = DW0==128 ? 4 : DW0==64 ? 3 : DW0==32 ? 2 : DW0==16 ? 1 : 0,
              BA0       = 0,
              OFFSET0   = 0,
              ENDIAN1   = ENDIAN,
              FULL1     = 0,
              AW1       = 23,
              BLOCKS1   = 8,
              BLKSIZE1  = 1024,
              DW1       = 8,
              AW0_1     = DW1==128 ? 4 : DW1==64 ? 3 : DW1==32 ? 2 : DW1==16 ? 1 : 0,
              BA1       = 0,
              OFFSET1   = 0,
              ENDIAN2   = ENDIAN,
              FULL2     = 0,
              AW2       = 23,
              BLOCKS2   = 8,
              BLKSIZE2  = 1024,
              DW2       = 8,
              AW0_2     = DW2==128 ? 4 : DW2==64 ? 3 : DW2==32 ? 2 : DW2==16 ? 1 : 0,
              BA2       = 0,
              OFFSET2   = 0,
              ENDIAN3   = ENDIAN,
              FULL3     = 0,
              AW3       = 23,
              BLOCKS3   = 8,
              BLKSIZE3  = 1024,
              DW3       = 8,
              AW0_3     = DW3==128 ? 4 : DW3==64 ? 3 : DW3==32 ? 2 : DW3==16 ? 1 : 0,
              BA3       = 0,
              OFFSET3   = 0,
              ENDIAN4   = ENDIAN,
              FULL4     = 0,
              AW4       = 23,
              BLOCKS4   = 8,
              BLKSIZE4  = 1024,
              DW4       = 8,
              AW0_4     = DW4==128 ? 4 : DW4==64 ? 3 : DW4==32 ? 2 : DW4==16 ? 1 : 0,
              BA4       = 0,
              OFFSET4   = 0,
              ENDIAN5   = ENDIAN,
              FULL5     = 0,
              AW5       = 23,
              BLOCKS5   = 8,
              BLKSIZE5  = 1024,
              DW5       = 8,
              AW0_5     = DW5==128 ? 4 : DW5==64 ? 3 : DW5==32 ? 2 : DW5==16 ? 1 : 0,
              BA5       = 0,
              OFFSET5   = 0,
              ENDIAN6   = ENDIAN,
              FULL6     = 0,
              AW6       = 23,
              BLOCKS6   = 8,
              BLKSIZE6  = 1024,
              DW6       = 8,
              AW0_6     = DW6==128 ? 4 : DW6==64 ? 3 : DW6==32 ? 2 : DW6==16 ? 1 : 0,
              BA6       = 0,
              OFFSET6   = 0,
              ENDIAN7   = ENDIAN,
              FULL7     = 0,
              AW7       = 23,
              BLOCKS7   = 8,
              BLKSIZE7  = 1024,
              DW7       = 8,
              AW0_7     = DW7==128 ? 4 : DW7==64 ? 3 : DW7==32 ? 2 : DW7==16 ? 1 : 0,
              BA7       = 0,
              OFFSET7   = 0
)(
    input                       rst,
    input                       clk,

    input      [AW0-1:AW0_0]    addr0,
    output     [DW0-1:0]        dout0,
    input                       rd0,
    input                       wr0,
    input      [DW0-1:0]        din0,
    input      [DW0/8-1:0]      wdsn0,
    output                      ok0,

    input      [AW1-1:AW0_1]    addr1,
    output     [DW1-1:0]        dout1,
    input                       rd1,
    input                       wr1,
    input      [DW1-1:0]        din1,
    input      [DW1/8-1:0]      wdsn1,
    output                      ok1,

    input      [AW2-1:AW0_2]    addr2,
    output     [DW2-1:0]        dout2,
    input                       rd2,
    input                       wr2,
    input      [DW2-1:0]        din2,
    input      [DW2/8-1:0]      wdsn2,
    output                      ok2,

    input      [AW3-1:AW0_3]    addr3,
    output     [DW3-1:0]        dout3,
    input                       rd3,
    input                       wr3,
    input      [DW3-1:0]        din3,
    input      [DW3/8-1:0]      wdsn3,
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
    output                      wr,
    input      [15:0]           din,
    output reg [15:0]           dout,
    input                       ack,
    input                       dst,
    input                       dok,
    input                       rdy
);

localparam EW0 = FULL0 ? SDRAM_AW+2 : SDRAM_AW;
localparam EW1 = FULL1 ? SDRAM_AW+2 : SDRAM_AW;
localparam EW2 = FULL2 ? SDRAM_AW+2 : SDRAM_AW;
localparam EW3 = FULL3 ? SDRAM_AW+2 : SDRAM_AW;
localparam EW4 = FULL4 ? SDRAM_AW+2 : SDRAM_AW;
localparam EW5 = FULL5 ? SDRAM_AW+2 : SDRAM_AW;
localparam EW6 = FULL6 ? SDRAM_AW+2 : SDRAM_AW;
localparam EW7 = FULL7 ? SDRAM_AW+2 : SDRAM_AW;

wire [EW0-1:1] ext_addr0;
wire [EW1-1:1] ext_addr1;
wire [EW2-1:1] ext_addr2;
wire [EW3-1:1] ext_addr3;
wire [EW4-1:1] ext_addr4;
wire [EW5-1:1] ext_addr5;
wire [EW6-1:1] ext_addr6;
wire [EW7-1:1] ext_addr7;
wire [15:0] ext_dout0, ext_dout1, ext_dout2, ext_dout3;
wire [15:0] ext_dout4, ext_dout5, ext_dout6, ext_dout7;
wire ext_rd0, ext_rd1, ext_rd2, ext_rd3, ext_rd4, ext_rd5, ext_rd6, ext_rd7;
wire ext_wr0, ext_wr1, ext_wr2, ext_wr3, ext_wr4, ext_wr5, ext_wr6, ext_wr7;
wire [SDRAM_AW-1:0] bank_addr0, bank_addr1, bank_addr2, bank_addr3;
wire [SDRAM_AW-1:0] bank_addr4, bank_addr5, bank_addr6, bank_addr7;
wire cache_ok0, cache_ok1, cache_ok2, cache_ok3;
wire cache_ok4, cache_ok5, cache_ok6, cache_ok7;
wire [DW0-1:0] cache_dout0;
wire [DW1-1:0] cache_dout1;
wire [DW2-1:0] cache_dout2;
wire [DW3-1:0] cache_dout3;
wire [DW4-1:0] cache_dout4;
wire [DW5-1:0] cache_dout5;
wire [DW6-1:0] cache_dout6;
wire [DW7-1:0] cache_dout7;

wire req0 = rd0 | wr0;
wire req1 = rd1 | wr1;
wire req2 = rd2 | wr2;
wire req3 = rd3 | wr3;
wire req4 = rd4;
wire req5 = rd5;
wire req6 = rd6;
wire req7 = rd7;

wire [7:0] ext_req = {
    ext_rd7 | ext_wr7,
    ext_rd6 | ext_wr6,
    ext_rd5 | ext_wr5,
    ext_rd4 | ext_wr4,
    ext_rd3 | ext_wr3,
    ext_rd2 | ext_wr2,
    ext_rd1 | ext_wr1,
    ext_rd0 | ext_wr0
};

wire [7:0] ext_ack = {
    active && active_sel==3'd7 && ack,
    active && active_sel==3'd6 && ack,
    active && active_sel==3'd5 && ack,
    active && active_sel==3'd4 && ack,
    active && active_sel==3'd3 && ack,
    active && active_sel==3'd2 && ack,
    active && active_sel==3'd1 && ack,
    active && active_sel==3'd0 && ack
};

wire [7:0] ext_dst = {
    active && active_sel==3'd7 && dst,
    active && active_sel==3'd6 && dst,
    active && active_sel==3'd5 && dst,
    active && active_sel==3'd4 && dst,
    active && active_sel==3'd3 && dst,
    active && active_sel==3'd2 && dst,
    active && active_sel==3'd1 && dst,
    active && active_sel==3'd0 && dst
};

wire [7:0] ext_dok = {
    active && active_sel==3'd7 && dok,
    active && active_sel==3'd6 && dok,
    active && active_sel==3'd5 && dok,
    active && active_sel==3'd4 && dok,
    active && active_sel==3'd3 && dok,
    active && active_sel==3'd2 && dok,
    active && active_sel==3'd1 && dok,
    active && active_sel==3'd0 && dok
};

wire [7:0] ext_rdy = {
    active && active_sel==3'd7 && rdy,
    active && active_sel==3'd6 && rdy,
    active && active_sel==3'd5 && rdy,
    active && active_sel==3'd4 && rdy,
    active && active_sel==3'd3 && rdy,
    active && active_sel==3'd2 && rdy,
    active && active_sel==3'd1 && rdy,
    active && active_sel==3'd0 && rdy
};

assign bank_addr0 = {1'b0, ext_addr0[SDRAM_AW-1:1]} + {1'b0, OFFSET0[0+:SDRAM_AW-1]};
assign bank_addr1 = {1'b0, ext_addr1[SDRAM_AW-1:1]} + {1'b0, OFFSET1[0+:SDRAM_AW-1]};
assign bank_addr2 = {1'b0, ext_addr2[SDRAM_AW-1:1]} + {1'b0, OFFSET2[0+:SDRAM_AW-1]};
assign bank_addr3 = {1'b0, ext_addr3[SDRAM_AW-1:1]} + {1'b0, OFFSET3[0+:SDRAM_AW-1]};
assign bank_addr4 = {1'b0, ext_addr4[SDRAM_AW-1:1]} + {1'b0, OFFSET4[0+:SDRAM_AW-1]};
assign bank_addr5 = {1'b0, ext_addr5[SDRAM_AW-1:1]} + {1'b0, OFFSET5[0+:SDRAM_AW-1]};
assign bank_addr6 = {1'b0, ext_addr6[SDRAM_AW-1:1]} + {1'b0, OFFSET6[0+:SDRAM_AW-1]};
assign bank_addr7 = {1'b0, ext_addr7[SDRAM_AW-1:1]} + {1'b0, OFFSET7[0+:SDRAM_AW-1]};

reg        active;
reg [2:0]  active_sel;
reg [2:0]  next_sel;
reg        next_valid;
reg [7:0]  ok_hold;
reg [DW0-1:0] dout_hold0;
reg [DW1-1:0] dout_hold1;
reg [DW2-1:0] dout_hold2;
reg [DW3-1:0] dout_hold3;
reg [DW4-1:0] dout_hold4;
reg [DW5-1:0] dout_hold5;
reg [DW6-1:0] dout_hold6;
reg [DW7-1:0] dout_hold7;

assign dout0 = dout_hold0;
assign dout1 = dout_hold1;
assign dout2 = dout_hold2;
assign dout3 = dout_hold3;
assign dout4 = dout_hold4;
assign dout5 = dout_hold5;
assign dout6 = dout_hold6;
assign dout7 = dout_hold7;
assign ok0   = ok_hold[0];
assign ok1   = ok_hold[1];
assign ok2   = ok_hold[2];
assign ok3   = ok_hold[3];
assign ok4   = ok_hold[4];
assign ok5   = ok_hold[5];
assign ok6   = ok_hold[6];
assign ok7   = ok_hold[7];

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

assign wr = active && (
    (active_sel == 3'd0 && ext_wr0) ||
    (active_sel == 3'd1 && ext_wr1) ||
    (active_sel == 3'd2 && ext_wr2) ||
    (active_sel == 3'd3 && ext_wr3) ||
    (active_sel == 3'd4 && ext_wr4) ||
    (active_sel == 3'd5 && ext_wr5) ||
    (active_sel == 3'd6 && ext_wr6) ||
    (active_sel == 3'd7 && ext_wr7)
);

always @(*) begin
    next_valid = 1'b0;
    next_sel   = 3'd0;
    if( ext_req[0] ) begin
        next_valid = 1'b1;
        next_sel   = 3'd0;
    end else if( ext_req[1] ) begin
        next_valid = 1'b1;
        next_sel   = 3'd1;
    end else if( ext_req[2] ) begin
        next_valid = 1'b1;
        next_sel   = 3'd2;
    end else if( ext_req[3] ) begin
        next_valid = 1'b1;
        next_sel   = 3'd3;
    end else if( ext_req[4] ) begin
        next_valid = 1'b1;
        next_sel   = 3'd4;
    end else if( ext_req[5] ) begin
        next_valid = 1'b1;
        next_sel   = 3'd5;
    end else if( ext_req[6] ) begin
        next_valid = 1'b1;
        next_sel   = 3'd6;
    end else if( ext_req[7] ) begin
        next_valid = 1'b1;
        next_sel   = 3'd7;
    end
end

always @(*) begin
    addr = {SDRAM_AW-1{1'b0}};
    ba   = 2'd0;
    dout = 16'd0;
    case( active_sel )
        3'd0: begin
            if( FULL0 ) begin
                addr = ext_addr0[SDRAM_AW-1:1];
                ba   = ext_addr0[EW0-1 -: 2];
            end else begin
                addr = bank_addr0[SDRAM_AW-2:0];
                ba   = BA0[1:0];
            end
            dout = ext_dout0;
        end
        3'd1: begin
            if( FULL1 ) begin
                addr = ext_addr1[SDRAM_AW-1:1];
                ba   = ext_addr1[EW1-1 -: 2];
            end else begin
                addr = bank_addr1[SDRAM_AW-2:0];
                ba   = BA1[1:0];
            end
            dout = ext_dout1;
        end
        3'd2: begin
            if( FULL2 ) begin
                addr = ext_addr2[SDRAM_AW-1:1];
                ba   = ext_addr2[EW2-1 -: 2];
            end else begin
                addr = bank_addr2[SDRAM_AW-2:0];
                ba   = BA2[1:0];
            end
            dout = ext_dout2;
        end
        3'd3: begin
            if( FULL3 ) begin
                addr = ext_addr3[SDRAM_AW-1:1];
                ba   = ext_addr3[EW3-1 -: 2];
            end else begin
                addr = bank_addr3[SDRAM_AW-2:0];
                ba   = BA3[1:0];
            end
            dout = ext_dout3;
        end
        3'd4: begin
            if( FULL4 ) begin
                addr = ext_addr4[SDRAM_AW-1:1];
                ba   = ext_addr4[EW4-1 -: 2];
            end else begin
                addr = bank_addr4[SDRAM_AW-2:0];
                ba   = BA4[1:0];
            end
            dout = ext_dout4;
        end
        3'd5: begin
            if( FULL5 ) begin
                addr = ext_addr5[SDRAM_AW-1:1];
                ba   = ext_addr5[EW5-1 -: 2];
            end else begin
                addr = bank_addr5[SDRAM_AW-2:0];
                ba   = BA5[1:0];
            end
            dout = ext_dout5;
        end
        3'd6: begin
            if( FULL6 ) begin
                addr = ext_addr6[SDRAM_AW-1:1];
                ba   = ext_addr6[EW6-1 -: 2];
            end else begin
                addr = bank_addr6[SDRAM_AW-2:0];
                ba   = BA6[1:0];
            end
            dout = ext_dout6;
        end
        default: begin
            if( FULL7 ) begin
                addr = ext_addr7[SDRAM_AW-1:1];
                ba   = ext_addr7[EW7-1 -: 2];
            end else begin
                addr = bank_addr7[SDRAM_AW-2:0];
                ba   = BA7[1:0];
            end
            dout = ext_dout7;
        end
    endcase
end

always @(posedge clk) begin
    if( rst ) begin
        active     <= 1'b0;
        active_sel <= 3'd0;
        ok_hold    <= 8'd0;
        dout_hold0 <= {DW0{1'b0}};
        dout_hold1 <= {DW1{1'b0}};
        dout_hold2 <= {DW2{1'b0}};
        dout_hold3 <= {DW3{1'b0}};
        dout_hold4 <= {DW4{1'b0}};
        dout_hold5 <= {DW5{1'b0}};
        dout_hold6 <= {DW6{1'b0}};
        dout_hold7 <= {DW7{1'b0}};
    end else begin
        if( !req0 ) ok_hold[0] <= 1'b0;
        if( !req1 ) ok_hold[1] <= 1'b0;
        if( !req2 ) ok_hold[2] <= 1'b0;
        if( !req3 ) ok_hold[3] <= 1'b0;
        if( !req4 ) ok_hold[4] <= 1'b0;
        if( !req5 ) ok_hold[5] <= 1'b0;
        if( !req6 ) ok_hold[6] <= 1'b0;
        if( !req7 ) ok_hold[7] <= 1'b0;

        if( cache_ok0 ) begin
            dout_hold0 <= cache_dout0;
            ok_hold[0] <= 1'b1;
        end
        if( cache_ok1 ) begin
            dout_hold1 <= cache_dout1;
            ok_hold[1] <= 1'b1;
        end
        if( cache_ok2 ) begin
            dout_hold2 <= cache_dout2;
            ok_hold[2] <= 1'b1;
        end
        if( cache_ok3 ) begin
            dout_hold3 <= cache_dout3;
            ok_hold[3] <= 1'b1;
        end
        if( cache_ok4 ) begin
            dout_hold4 <= cache_dout4;
            ok_hold[4] <= 1'b1;
        end
        if( cache_ok5 ) begin
            dout_hold5 <= cache_dout5;
            ok_hold[5] <= 1'b1;
        end
        if( cache_ok6 ) begin
            dout_hold6 <= cache_dout6;
            ok_hold[6] <= 1'b1;
        end
        if( cache_ok7 ) begin
            dout_hold7 <= cache_dout7;
            ok_hold[7] <= 1'b1;
        end

        if( active ) begin
            if( rdy ) begin
                active <= 1'b0;
            end
        end else if( next_valid ) begin
            active     <= 1'b1;
            active_sel <= next_sel;
        end
    end
end

jtframe_cache #(
    .AW     ( AW0      ),
    .BLOCKS ( BLOCKS0  ),
    .BLKSIZE( BLKSIZE0 ),
    .DW     ( DW0      ),
    .ENDIAN ( ENDIAN0  ),
    .EW     ( EW0      )
) u_cache0 (
    .rst        ( rst                           ),
    .clk        ( clk                           ),
    .addr       ( addr0                         ),
    .dout       ( cache_dout0                   ),
    .din        ( din0                          ),
    .rd         ( rd0                           ),
    .wr         ( wr0                           ),
    .wdsn       ( wdsn0                         ),
    .ok         ( cache_ok0                     ),
    .ext_addr   ( ext_addr0                     ),
    .ext_din    ( din                           ),
    .ext_dout   ( ext_dout0                     ),
    .ext_rd     ( ext_rd0                       ),
    .ext_wr     ( ext_wr0                       ),
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
    .ENDIAN ( ENDIAN1  ),
    .EW     ( EW1      )
) u_cache1 (
    .rst        ( rst                           ),
    .clk        ( clk                           ),
    .addr       ( addr1                         ),
    .dout       ( cache_dout1                   ),
    .din        ( din1                          ),
    .rd         ( rd1                           ),
    .wr         ( wr1                           ),
    .wdsn       ( wdsn1                         ),
    .ok         ( cache_ok1                     ),
    .ext_addr   ( ext_addr1                     ),
    .ext_din    ( din                           ),
    .ext_dout   ( ext_dout1                     ),
    .ext_rd     ( ext_rd1                       ),
    .ext_wr     ( ext_wr1                       ),
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
    .ENDIAN ( ENDIAN2  ),
    .EW     ( EW2      )
) u_cache2 (
    .rst        ( rst                           ),
    .clk        ( clk                           ),
    .addr       ( addr2                         ),
    .dout       ( cache_dout2                   ),
    .din        ( din2                          ),
    .rd         ( rd2                           ),
    .wr         ( wr2                           ),
    .wdsn       ( wdsn2                         ),
    .ok         ( cache_ok2                     ),
    .ext_addr   ( ext_addr2                     ),
    .ext_din    ( din                           ),
    .ext_dout   ( ext_dout2                     ),
    .ext_rd     ( ext_rd2                       ),
    .ext_wr     ( ext_wr2                       ),
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
    .ENDIAN ( ENDIAN3  ),
    .EW     ( EW3      )
) u_cache3 (
    .rst        ( rst                           ),
    .clk        ( clk                           ),
    .addr       ( addr3                         ),
    .dout       ( cache_dout3                   ),
    .din        ( din3                          ),
    .rd         ( rd3                           ),
    .wr         ( wr3                           ),
    .wdsn       ( wdsn3                         ),
    .ok         ( cache_ok3                     ),
    .ext_addr   ( ext_addr3                     ),
    .ext_din    ( din                           ),
    .ext_dout   ( ext_dout3                     ),
    .ext_rd     ( ext_rd3                       ),
    .ext_wr     ( ext_wr3                       ),
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
    .ENDIAN ( ENDIAN4  ),
    .EW     ( EW4      )
) u_cache4 (
    .rst        ( rst                           ),
    .clk        ( clk                           ),
    .addr       ( addr4                         ),
    .dout       ( cache_dout4                   ),
    .din        ( {DW4{1'b0}}                   ),
    .rd         ( rd4                           ),
    .wr         ( 1'b0                          ),
    .wdsn       ( {(DW4/8){1'b1}}               ),
    .ok         ( cache_ok4                     ),
    .ext_addr   ( ext_addr4                     ),
    .ext_din    ( din                           ),
    .ext_dout   ( ext_dout4                     ),
    .ext_rd     ( ext_rd4                       ),
    .ext_wr     ( ext_wr4                       ),
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
    .ENDIAN ( ENDIAN5  ),
    .EW     ( EW5      )
) u_cache5 (
    .rst        ( rst                           ),
    .clk        ( clk                           ),
    .addr       ( addr5                         ),
    .dout       ( cache_dout5                   ),
    .din        ( {DW5{1'b0}}                   ),
    .rd         ( rd5                           ),
    .wr         ( 1'b0                          ),
    .wdsn       ( {(DW5/8){1'b1}}               ),
    .ok         ( cache_ok5                     ),
    .ext_addr   ( ext_addr5                     ),
    .ext_din    ( din                           ),
    .ext_dout   ( ext_dout5                     ),
    .ext_rd     ( ext_rd5                       ),
    .ext_wr     ( ext_wr5                       ),
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
    .ENDIAN ( ENDIAN6  ),
    .EW     ( EW6      )
) u_cache6 (
    .rst        ( rst                           ),
    .clk        ( clk                           ),
    .addr       ( addr6                         ),
    .dout       ( cache_dout6                   ),
    .din        ( {DW6{1'b0}}                   ),
    .rd         ( rd6                           ),
    .wr         ( 1'b0                          ),
    .wdsn       ( {(DW6/8){1'b1}}               ),
    .ok         ( cache_ok6                     ),
    .ext_addr   ( ext_addr6                     ),
    .ext_din    ( din                           ),
    .ext_dout   ( ext_dout6                     ),
    .ext_rd     ( ext_rd6                       ),
    .ext_wr     ( ext_wr6                       ),
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
    .ENDIAN ( ENDIAN7  ),
    .EW     ( EW7      )
) u_cache7 (
    .rst        ( rst                           ),
    .clk        ( clk                           ),
    .addr       ( addr7                         ),
    .dout       ( cache_dout7                   ),
    .din        ( {DW7{1'b0}}                   ),
    .rd         ( rd7                           ),
    .wr         ( 1'b0                          ),
    .wdsn       ( {(DW7/8){1'b1}}               ),
    .ok         ( cache_ok7                     ),
    .ext_addr   ( ext_addr7                     ),
    .ext_din    ( din                           ),
    .ext_dout   ( ext_dout7                     ),
    .ext_rd     ( ext_rd7                       ),
    .ext_wr     ( ext_wr7                       ),
    .ext_ack    ( ext_ack[7]                    ),
    .ext_dst    ( ext_dst[7]                    ),
    .ext_dok    ( ext_dok[7]                    ),
    .ext_rdy    ( ext_rdy[7]                    )
);

endmodule
