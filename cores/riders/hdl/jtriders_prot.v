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

    input                cs,
    input         [13:1] addr,
    // input         [ 1:0] dsn,
    input         [15:0] din,
    output reg    [15:0] dout,
    input                cpu_we,
    input                ram_we,

    // DMA
    output        [13:1] oram_addr,
    output        [15:0] oram_din,
    output               oram_we,
    input         [15:0] oram_dout,

    output               irqn,
    output reg           BRn,
    input                BGn,
    output reg           BGACKn
);

localparam [13:1] DATA = 13'hd05, // 5a0a-4000>>1
                  CMD  = 13'hc7e, // 58fc-4000>>1
                  V0   = 13'hc0c, // 5818-4000>>1
                  V1   = 13'he58, // 5cb0-4000>>1
                  V2   = 13'h064; // 40c8-4000>>1

reg [15:0] cmd, odma, v0, v1, v2, vx;
reg [ 5:0] calc;

assign irqn = 1; // always high on the PCB
// DMA
reg [ 6:0] logic_prio;
reg [ 6:0] scan_addr;
reg [15:0] cpdata;
reg [ 1:0] st;
reg        owr;

assign oram_addr = !BGACKn ? {scan_addr,6'd0}+13'd6 : addr;
assign oram_din  = !BGACKn ? din : cpdata;
assign oram_we   = !BGACKn ? owr : cpu_we;

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        BRn        <= 1;
        BGACKn     <= 1;
        logic_prio <= 0;
        scan_addr  <= 0;
        st         <= 0;
        cpdata     <= 0;
    end else begin
        if( cs && cpu_we && addr==1 ) begin
            BRn <= 0;
            logic_prio <= 0;
            scan_addr  <= 0;
            st         <= 0;
        end
        if( !BGn && !BRn) begin
            $display("DMA in progress");
            {BRn, BGACKn} <= 2'b10;
        end
        if( !BGACKn && cen_16 ) begin
            st <= st+2'd1;
            case( st )
            0: begin
                owr <= 0;
            end
            2: begin // Write cpdata and advanced
                cpdata <= oram_dout;
                owr  <= 1;
            end
            3: begin
                owr <= 0;
                scan_addr <= scan_addr+7'd1;
                if( &scan_addr ) begin
                    logic_prio <= logic_prio<<1;
                    scan_addr  <= 0;
                    if( logic_prio[6] ) BGACKn <= 1;
                end
            end
            endcase
        end
    end
end

// Data read

always @* begin
    vx = (-v0-16'd32)>>3;
    vx = { 5'd0, vx[4:0], 6'd0 };
    vx = vx + v1 + v2 - 16'd6;
    vx = vx>>3;
    vx = vx+16'd12;
end

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        { cmd, odma, v0, v1, v2 } <= 0;
    end else if(ram_we) begin
        case(addr)
            DATA: odma <= din;
            CMD:  cmd  <= din;
            V0:   v0   <=-din;
            V1:   v1   <= din;
            V2:   v2   <= din;
            default:;
        endcase
    end
end

always @(posedge clk) begin
    calc <= vx[5:0];
    case(cmd)
        16'h100b: dout <= 16'h64;
        16'h6003: dout <= {12'd0,odma[3:0]};
        16'h6004: dout <= {11'd0,odma[4:0]};
        16'h6000: dout <= {15'd0,odma[  0]};
        16'h0000: dout <= { 8'd0,odma[7:0]};
        16'h6007: dout <= { 8'd0,odma[7:0]};
        16'h8abc: dout <= {10'd0,calc};
        default:  dout <= 0;
    endcase
end

endmodule