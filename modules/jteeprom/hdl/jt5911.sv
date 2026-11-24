/*  This file is part of JTEEPROM.
    JTEEPROM program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTEEPROM program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTEEPROM.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 21-3-2020 */

// Module compatible with Microchip ER5911

module jt5911 #( parameter
    PROG=0,     // 0 = 128x8bit, 1 = 64x16 bit. Pin in the original chip
                // 16 bit mode untested!
    SIMFILE="", // name of binary file to load during simulation
    SYNHEX="",  // name of hex file to load for synthesis
    // Do not assign manually
    AW= PROG ?  6 : 7,   // Memory address bits
    DW= PROG ? 16 : 8    // Data width
) (
    input           rst,        // system reset
    input           clk,        // system clock
    // chip interface
    input           sclk,       // serial clock
    input           sdi,         // serial data in
    output      reg sdo,         // serial data out
    output      reg rdy,
    input           scs,         // chip select, active high. Goes low in between instructions
    // RAM is external
    output reg [AW-1:0] mem_addr,
    output reg [DW-1:0] mem_din,
    output reg          mem_we,
    input      [DW-1:0] mem_dout,

    // NVRAM contents changed
    input           dump_clr,   // Clear the flag
    output reg      dump_flag   // There was a write
);

localparam  CW=AW+4;  // bits between the 4-bit op command and the data
localparam  [3:0] CMDIN = PROG ? 4'd11 : 4'd10;

reg           prog_en, write_all;
reg           sdi_l;
reg           last_sclk;
reg  [   1:0] dout_up;
wire          sclk_posedge = sclk && !last_sclk;
reg  [DW-1:0] newdata, dout;
reg  [   3:0] rx_cnt;
reg  [   3:0] op;
reg  [   3:0] csl;
wire [DW-1:0] next_data = { newdata[0+:DW-1], sdi };
wire [CW-1:0] full_op = { op, mem_addr };

`ifdef SIMULATION
wire [AW-1:0] next_addr = {mem_addr[AW-2:0], sdi};
`endif

enum logic [2:0] { IDLE      = 3'd0,
                   RX        = 3'd1,
                   READ      = 3'd2,
                   WRITE     = 3'd3,
                   WRITE_ALL = 3'd4,
                   WAIT      = 3'd5
                } st;

always @(posedge clk) begin
    last_sclk <= sclk;
    csl       <= csl << 1;
    csl[0]    <= scs;
end

`ifdef JT5911_SIMULATION
    `define JT5911_WRITE(a,v) $display("EEPROM: %X written to %X", v, a[0+:AW]);
    `define JT5911_READ(a,v)  $display("EEPROM: %X read from  %X", v, a[AW-1:0]);
    `define JT5911_ERASEEN    $display("EEPROM: erase enabled");
    `define JT5911_ERASEDIS   $display("EEPROM: erase disabled");
    `define JT5911_ERASEALL   $display("EEPROM: erase all");
`else
    `define JT5911_WRITE(a,v)
    `define JT5911_READ(a,v)
    `define JT5911_ERASEEN
    `define JT5911_ERASEDIS
    `define JT5911_ERASEALL
`endif

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        prog_en  <= 0;
        newdata  <= 0;
        mem_we   <= 0;
        st       <= IDLE;
        rx_cnt   <= 0;
        sdo      <= 0;
        rdy      <= 0;
        dout_up  <= 0;
        dump_flag<= 0;
    end else begin
        // data output
        dout_up <= dout_up>>1;
        if( dout_up[0] ) begin
            `JT5911_READ ( mem_addr, mem_dout )
            dout    <= mem_dout;
        end
        mem_we <= 0;

        // It flags a write command, not necessarily a data change
        if( dump_clr )
            dump_flag <= 0;
        else if(mem_we) dump_flag <= 1;

        if( ~&csl ) begin // instead of simply !scs. This prevents reacting
            // to sdi/sclk inputs right when cs goes high. Original chip had
            // a 400ns blind time after cs went high according to datasheet
            st  <= IDLE;
            rdy <= 1;
            sdo <= 1;
        end else  begin
            if( st==WRITE_ALL) begin
                mem_addr   <= mem_addr+1'd1;
                mem_we <= 1;
                if( &mem_addr ) begin
                    st  <= WAIT;
                    rdy <= 1;
                end
            end
            if( sclk_posedge ) begin
                sdi_l <= sdi;
                case( st )
                    RX: begin
                        rx_cnt <= rx_cnt+1'd1;
                        { op, mem_addr } <= { full_op[CW-2:0], sdi };
                        if( rx_cnt==CMDIN ) begin
                            casez( full_op[CW-2-:4] ) // op is top 4 bits
                                4'b1000: begin
                                    st      <= READ;
                                    sdo     <= 0;
                                    dout_up <= 2'b10;
                                end
                                4'b?100: if( prog_en ) begin
                                    st        <= WRITE;
                                    rx_cnt    <= 0;
                                    write_all <= 0;
                                end else begin
                                    st <= WAIT;
                                end
                                4'b0011: begin
                                    `JT5911_ERASEEN
                                    prog_en <= 1;
                                    st <= WAIT;
                                end
                                4'b0000: begin
                                    `JT5911_ERASEDIS
                                    prog_en <= 1'b0;
                                    st <= WAIT;
                                end
                                4'b0010: if( prog_en ) begin
                                    `JT5911_ERASEALL
                                    rdy     <= 0;
                                    newdata <= '1;
                                    st      <= WRITE_ALL;
                                end else begin
                                    st <= WAIT;
                                end
                                default: st <= WAIT;
                            endcase
                        end
                    end
                    WRITE: begin
                        newdata <= next_data;
                        rx_cnt  <= rx_cnt+1'd1;
                        sdo     <= 0; // busy
                        if( rx_cnt == (PROG?4'hf:4'h7) ) begin
                            mem_we <= 1;
                                `JT5911_WRITE( mem_addr, next_data )
                            mem_din <= next_data;
                            st <= WAIT;
                        end
                    end
                    READ: { sdo, dout} <= { dout, 1'b1 };
                    WAIT: rdy <= 1;
                    IDLE: begin
                        sdo <= 1;
                        rdy <= 1;
                        if( sdi && !sdi_l ) begin
                            st <= RX; // start-bit detected
                            rx_cnt <= 0;
                        end
                    end
                    default:;
                endcase
            end
        end
    end
end

endmodule
