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
    Date: 13-7-2024 */

module jtriders_prot(
    input                rst,
    input                clk,
    input                cen_16,
    input                cen_8,

    input                cs,
    input         [13:1] addr,
    input         [ 1:0] dsn,
    input         [15:0] din,
    output reg    [15:0] dout,
    input                cpu_we,
    input                ram_we,

    // DMA

    input                objsys_cs,
    output               oram_cs,
    output        [13:1] oram_addr,
    output        [15:0] oram_din,
    input         [15:0] oram_dout,
    output        [ 1:0] oram_we,

    output               irqn,
    output reg           BRn,
    input                BGn,
    output reg           BGACKn,

    input         [ 7:0] debug_bus
);

localparam [13:1] DATA = 13'hd05, // 5a0a-4000>>1
                  CMD  = 13'hc7e, // 58fc-4000>>1
                  V0   = 13'hc0c, // 5818-4000>>1
                  V1   = 13'he58, // 5cb0-4000>>1
                  V2   = 13'h064; // 40c8-4000>>1

reg        [15:0] cmd, odma;
reg signed [15:0] v0,v1,v2,vx0,vx1,vx2,vsum,c,vcalc,calc;

assign irqn = 1; // always high on the PCB
// DMA
reg [13:1] dma_addr;
reg [ 7:0] hw_prio,logic_prio;
reg [ 6:0] scan_addr;
reg [ 1:0] st;
reg        owr;

// signal order expected at object chip pins
// function [13:1] conv( input [6:0] a);
// begin
//     reg [8:0] b;
//     b = {a,2'd0};
//     conv={b[8:2],2'd0,b[2:0],1'b0};
// end
// endfunction

function [13:1] conv13( input[13:1] a);
begin
    conv13 = { a[6:5], a[1], a[13:7], a[4:2] };
end
endfunction

assign oram_addr = !BGACKn ? dma_addr     : conv13(addr);
assign oram_din  = !BGACKn ? {2{hw_prio}} : din;
assign oram_we   = !BGACKn ? {1'b0,owr}   : ~dsn & {2{cpu_we}};
assign oram_cs   = !BGACKn ? 1'b1         : objsys_cs;

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        BRn        <= 1;
        BGACKn     <= 1;
        logic_prio <= 0;
        hw_prio    <= 0;
        scan_addr  <= 0;
        dma_addr   <= 0;
        st         <= 0;
    end else begin
        if( cs && cpu_we && addr[7:1]==1 ) begin
            BRn <= 0;
            logic_prio <= 1;
            hw_prio    <= 1;
            scan_addr  <= 0;
            st         <= 0;
        end
        if( !BGn && !BRn) begin
            $display("DMA in progress");
            {BRn, BGACKn} <= 2'b10;
        end
        if( !BGACKn && cen_8 ) begin
            st <= st+2'd1;
            case( st )
            0: begin
                dma_addr <= conv13({ scan_addr, 6'd3 });
                owr      <= 0;
            end
            2: begin
                if( oram_dout[15:8]==logic_prio) begin
                    dma_addr <= {3'd0,scan_addr,3'd0};
                    owr      <= 1;
                end
            end
            3: begin
                owr <= 0;
                scan_addr <= scan_addr+7'd1;
                if( owr ) hw_prio <= hw_prio+8'd1;
                if( &scan_addr ) begin
                    logic_prio <= logic_prio<<1;
                    scan_addr  <= 0;
                    if( logic_prio[7] ) BGACKn <= 1;
                end
            end
            endcase
        end
    end
end

// Data read
// MAME does a convoluted operation that seems to rely on the upper 16 bits
// being zero and getting set to 1 when v0 is negative. That changes the /8
// result by 1, which then creates a 0x40 difference in the final value
// This implementation does not rely on phantom bits. In any case, we need
// more information to accurately implement this chip
always @* begin
    c     = 0;
    vx0   = (v0+16'd32)>>3;
    vx1   = -vx0;
    vx2   = {5'd0,vx1[4:0],6'd0};
    vsum  = v1+v2-16'd6;
    c[0]  = vsum[15] & (|vsum[2:0]);
    vcalc = vx2+(((vsum>>3)+c+16'd12)&16'h3f);
end

`define WR16(a) begin if(!dsn[0]) a[7:0]<=din[7:0]; if(!dsn[1]) a[15:8]<=din[15:8]; end
always @(posedge clk, posedge rst) begin
    if( rst ) begin
        { cmd, odma, v0, v1, v2 } <= 0;
    end else if(ram_we) begin
        case(addr)
            DATA: `WR16( odma )
            CMD:  `WR16( cmd  )
            V0:   `WR16( v0   )
            V1:   `WR16( v1   )
            V2:   `WR16( v2   )
            default:;
        endcase
    end
end
`undef WR16

always @(posedge clk) begin
    calc <= vcalc;
    case(cmd)
        16'h100b: dout <= 16'h64;
        16'h6003: dout <= {12'd0,odma[3:0]};
        16'h6004: dout <= {11'd0,odma[4:0]};
        16'h6000: dout <= {15'd0,odma[  0]};
        16'h0000: dout <= { 8'd0,odma[7:0]};
        16'h6007: dout <= { 8'd0,odma[7:0]};
        16'h8abc: dout <= calc;
        default:  dout <= 16'hffff;
    endcase
end

endmodule