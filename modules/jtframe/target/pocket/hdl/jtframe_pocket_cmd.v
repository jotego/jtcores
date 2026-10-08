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
    along with JTFRAME. If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 27-8-2022 */

// The Pocket has a convoluted protocol full of useless steps
// Each command has to come with parameters that set the address (pointer)
// of where other parameters or results will be.
//
// They even made two command classes, the "host" and the "target" command
// which differ in how parameters are set and read. Their original example
// even wastes 8kB of RAM in here. Crazy.
//
// On top of that, the handshake is based in 16-bit words that
// encode a 2-character English word: like "CM" for command
// It doesn't even make sense for readability, as the original Pocket
// files use hex codes for ASCII. The whole thing is just a bad design.
//
// I have simplified things as much as possible in this implementation.

module jtframe_pocket_cmd(
    input             clk,
    output reg        rst_req_n,

    input      [31:2] sys_addr,
    input             sys_rd,
    output reg [31:0] sys_din,
    input      [31:0] ioctl_din32,
    input             sys_wr,
    input      [31:0] sys_dout, // the Pocket writes to the core
    input      [31:0] dipsw,    // the Pocket writes to the core
    input      [63:0] status,   // the Pocket writes to the core

    output reg [ 7:0] down_index,

    output reg        ds_done,
    output reg        inmenu
);

parameter IDX_NVRAM = 2;

// Pointer for the parameters, because life cannot be easy
localparam [31:0] PARAM_PTR    = 32'h20,
                  RESPONSE_PTR = 32'h40;

wire [31:0] sys_addr32;

// host command execution
reg  [31:0] host_0;
reg  [31:0] host_20; // parameter data

reg         hcmd_go;
reg  [15:0] hcmd, hcmd_return;

initial begin
    rst_req_n  <= 0;
    down_index <= 0;
    ds_done    <= 0;
    inmenu     <= 0;
end

assign sys_addr32 = { sys_addr, 2'd0 };

localparam NVRAM_SIZE = `ifdef JTFRAME_IOCTL_RD `JTFRAME_IOCTL_RD `else 0 `endif ;

// Parses read and write requests
always @(posedge clk) begin
    hcmd_go <= 0;
    if( sys_wr && sys_addr32[31-:8]==8'hf8 && sys_addr32[15:8]==0 ) case( sys_addr32[7:0] )
        // Host Command
         8'h00: begin
                if(sys_dout[31:16] == "CM") begin // Command Word
                    // host wants us to do a command
                    hcmd <= sys_dout[15:0];
                    hcmd_go <= 1;
                end
            end
        8'h20: host_20 <= sys_dout; // parameter data regs
        default:;
    endcase

    if(sys_rd) begin
        casez(sys_addr32)
            // Host Command
            32'hf8??0000: sys_din <= { "OK", hcmd_return}; // command/status
            32'hf8??0004: sys_din <= PARAM_PTR;
            32'hf8??0008: sys_din <= RESPONSE_PTR;
            // Target command
            32'hf8??1000: sys_din <= { "cm",16'h0140 };
            32'hf8??1004: sys_din <= PARAM_PTR;
            32'hf8??1008: sys_din <= RESPONSE_PTR;
            32'hf8??20??: sys_din <= sys_addr32[2] ? NVRAM_SIZE : IDX_NVRAM; // reply with NVRAM size (slot ID 2)
            32'hfa??????: sys_din <= dipsw;
            32'hfb?????0: sys_din <= status[31:0];
            32'hfb?????4: sys_din <= status[63:32];
`ifdef JTFRAME_COMMIT_DEC
            32'hff??????: sys_din <= `JTFRAME_COMMIT_DEC;
`else
            32'hff??????: sys_din <= 0;
`endif
            default: sys_din <= sys_addr32[31:24]!=8'hf8 ? ioctl_din32 : 0;
        endcase
    end
end

// Executes host commands
always @(posedge clk) begin
    if( hcmd_go ) begin
        hcmd_return <= 0;
        case(hcmd)
            16'h0000: hcmd_return <= ds_done ? 16'd4 : 16'd2; // Report we are running
            16'h0010: rst_req_n <= 0;   // enter reset
            16'h0011: rst_req_n <= 1;   // exit reset
            16'h0080: begin // Data slot reading starts
                down_index  <= host_20[7:0];
                hcmd_return <= 0;
            end
            16'h0082: begin // Data slot writting starts
                down_index  <= host_20[7:0];
                hcmd_return <= 0;
            end
            16'h008F: begin
                ds_done    <= 1;
                down_index <= 8'hff; // Disables the download index
            end
            16'h00B0: inmenu  <= host_20[0];
            default: hcmd_return <= 16'hffff; // unknown command
        endcase
    end
end

endmodule
