/*  This file is part of JT_FRAME.
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
    Date: 20-11-2022 */

// Pseudo SRAM
// simple simulation model based on AS1C8M16PL-70BIN data sheet

module psram128(
    input   [21:16] a,
    input   [  1:0] cen,
    input           clk,
    input           advn,
    input           wen,
    input           oen,
    input           cre,
    input           lbn,
    input           ubn,
    output          wt,
    inout   [15 :0] adq
);

    psram64 u_psram0(
        .a    ( a     ),
        .cen  ( cen[0]),
        .clk  ( clk   ),
        .advn ( advn  ),
        .wen  ( wen   ),
        .oen  ( oen   ),
        .cre  ( cre   ),
        .lbn  ( lbn   ),
        .ubn  ( ubn   ),
        .wt   ( wt    ),
        .adq  ( adq   )
    );

    psram64 u_psram1(
        .a    ( a     ),
        .cen  ( cen[1]),
        .clk  ( clk   ),
        .advn ( advn  ),
        .wen  ( wen   ),
        .oen  ( oen   ),
        .cre  ( cre   ),
        .lbn  ( lbn   ),
        .ubn  ( ubn   ),
        .wt   ( wt    ),
        .adq  ( adq   )
    );

endmodule

module psram64(
    input   [21:16] a,
    input           cen,
    input           clk,
    input           advn,
    input           wen,
    input           oen,
    input           cre,
    input           lbn,
    input           ubn,
    inout           wt,
    inout    [15:0] adq
);

reg  [15:0] mem[0:2**22-1];
reg  [21:0] addr;
reg  [ 2:0] wtk;
reg  [ 3:0] st;
reg         wt_reg, do_rd, do_cfg;
wire [15:0] cur_mem, wrq;

// bus configuration
reg       bus_mode,
          wt_cfg, // not implemented
          wt_sign,
          acc_lat,    // access latency, not implemented
          wrap;       // not implemented
reg [2:0] latency,
          burst_len;  // not implemented
reg [1:0] drv_str;    // not implemented


localparam [3:0] IDLE  = 0,
                 WAIT  = 1,
                 READ  = 2,
                 WRITE = 3;

assign cur_mem = mem[addr];
assign adq = (!oen && !cen && st==READ) ? cur_mem : 16'hzzzz;
assign wt  = cen ? 1'bz : wt_reg ^ ~wt_sign;
assign wrq = { ubn ? cur_mem[15:8] : adq[15:8], lbn ? cur_mem[7:0] : adq[7:0] };

integer k;
initial begin
    wt_reg = 0;
    st = IDLE;
    // default configuration
    acc_lat   = 0;
    burst_len = 7;
    bus_mode  = 1;
    drv_str   = 2'd1;
    latency   = 3;
    wrap      = 1;
    wt_cfg    = 1;
    wt_sign   = 1;
    // clear the memory
    for(k=0;k<2**22-1;k++) mem[k] = 0;
end

always @(posedge clk) begin
    case( st )
        IDLE: begin
            do_rd  <= 0;
            do_cfg <= 0;
            wt_reg <= 0;      // just a work around so it won't halt the sim
            if( !cen && !advn && !cre ) begin
                do_rd <= wen;
                addr  <= { a, adq };
                wtk   <= 3;
                st    <= WAIT;
            end
            if( !cen && !advn && cre ) begin
                if( !wen ) begin
                    if( a[19:18]==2'd2 ) begin
                        bus_mode   = adq[15];
                        acc_lat    = adq[14];
                        latency    = adq[13:11];
                        wt_sign  = adq[10];
                        wt_cfg = adq[8];
                        drv_str    = adq[5:4];
                        wrap       = adq[3];
                        burst_len  = adq[2:0];
                    end
                end
                do_cfg <= 1;   // the cre function isn't implemented
                wtk    <= 3;
                st     <= WAIT;
            end
        end
        WAIT: begin
            if( wtk==0 ) st <= do_cfg ? IDLE : do_rd ? READ : WRITE;
            wt_reg <= wtk==0;
            wtk <= wtk-1;
        end
        READ: begin
            wt_reg <= 0;
            addr   <= addr + 1'd1;
            if( cen ) st <= IDLE;
        end
        WRITE: begin
            wt_reg <= 0;
            addr   <= addr + 1'd1;
            if( cen ) 
                st <= IDLE;
            else begin
                mem[addr] <= wrq;
            end
        end
        default:;
    endcase
end

endmodule