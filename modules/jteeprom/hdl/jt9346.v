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

// Module compatible with Microchip 96C06/46

module jt9346 #(
    parameter
    AW=6,   // Memory address bits
    CW=AW,  // bits between the 2-bit op command and the data
    DW=16
) (
    input           rst,        // system reset
    input           clk,        // system clock
    // chip interface
    input           sclk,       // serial clock
    input           sdi,         // serial data in
    output      reg sdo,         // serial data out and ready/not busy signal
    input           scs,         // chip select, active high. Goes low in between instructions
    // Dump access
    input           dump_clk,
    input  [AW-1:0] dump_addr,
    input           dump_we,
    input  [DW-1:0] dump_din,
    output [DW-1:0] dump_dout,
    // NVRAM contents changed
    input           dump_clr,   // Clear the flag
    output reg      dump_flag   // There was a write
);


reg           erase_en, write_all;
reg           sdi_l;
reg           last_sclk, mem_we;
reg  [   1:0] dout_up;
wire          sclk_posedge = sclk && !last_sclk;
reg  [CW-1:0] addr;
reg  [DW-1:0] newdata, dout, mem_din;
wire [DW-1:0] qout;
reg  [  15:0] rx_cnt;
reg  [   1:0] op;
reg  [   6:0] st;
wire [DW-1:0] next_data = { newdata[DW-2:0], sdi };
wire [CW+1:0] full_op = { op, addr };

`ifdef SIMULATION
wire [AW-1:0] next_addr = {addr[AW-2:0], sdi};
`endif

localparam IDLE=7'd1, RX=7'd2, READ=7'd4, WRITE=7'd8, WRITE_ALL=7'h10,
           PRE_READ=7'h20, WAIT=7'h40;

always @(posedge clk) last_sclk <= sclk;

jt9346_dual_ram #(.DW(DW), .AW(AW)) u_ram(
    .clk0   ( clk       ),
    .clk1   ( dump_clk  ),
    // First port: internal use
    .addr0  ( addr[0+:AW] ),
    .data0  ( mem_din   ),
    .we0    ( mem_we    ),
    .q0     ( qout      ),
    // Second port: dump
    .addr1  ( dump_addr ),
    .data1  ( dump_din  ),
    .we1    ( dump_we   ),
    .q1     ( dump_dout )
);

`ifdef JT9346_SIMULATION
    `define REPORT_WRITE(a,v) $display("EEPROM: %X written to %X", v, a[0+:AW]);
    `define REPORT_READ(a,v) $display("EEPROM: %X read from  %X", v, a[AW-1:0]);
    `define REPORT_ERASE(a  ) $display("EEPROM: %X ERASED", a);
    `define REPORT_ERASEEN  $display("EEPROM: erase enabled");
    `define REPORT_ERASEDIS $display("EEPROM: erase disabled");
    `define REPORT_ERASEALL $display("EEPROM: erase all");
    `define REPORT_WRITEALL $display("EEPROM: write all");
`else
    `define REPORT_WRITE(a,v)
    `define REPORT_READ(a,v)
    `define REPORT_ERASE(a)
    `define REPORT_ERASEEN
    `define REPORT_ERASEDIS
    `define REPORT_ERASEALL
    `define REPORT_WRITEALL
`endif

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        erase_en <= 0;
        newdata  <= {DW{1'b1}};
        mem_we   <= 0;
        st       <= IDLE;
        sdo      <= 1'b0;
        dout_up  <= 0;
        dump_flag<= 0;
    end else begin
        if( dout_up[0] ) begin
            `REPORT_READ ( addr, qout )
            dout    <= qout;
            dout_up <= 0;
        end
        mem_we  <= 0;
        // It flags a write command, not necessarily a data change
        if( dump_clr )
            dump_flag <= 0;
        else if(mem_we) dump_flag <= 1;

        dout_up <= dout_up>>1;
        if( !scs ) begin
            st <= IDLE;
        end else begin
            if( sclk_posedge && scs ) sdi_l <= sdi;
            case( st )
                default: begin
                    sdo    <= 1; // ready
                    if( sclk_posedge && scs && sdi && !sdi_l ) begin
                        st <= RX;
                        rx_cnt <= 16'h1 << (CW+1);
                    end
                end
                RX: if( sclk_posedge && scs ) begin
                    rx_cnt <= rx_cnt>>1;
                    { op, addr } <= { full_op[CW:0], sdi };
                    if( rx_cnt[0] ) begin
                        case( full_op[CW:CW-1] ) // op is in bits 6:5
                            2'b10: begin
                                st      <= READ;
                                sdo     <= 0;
                                dout_up <= 2'b10;
                                // dout <= mem[ next_addr ];
                                rx_cnt  <= 16'hFFFF;
                            end
                            2'b01: begin
                                st        <= WRITE;
                                rx_cnt    <= DW==16 ? 16'h8000 : 16'h80;
                                write_all <= 1'b0;
                            end
                            2'b11: begin // ERASE
                                `REPORT_ERASE(next_addr)
                                mem_din <= {DW{1'b1}};
                                mem_we  <= 1;
                                // mem[ next_addr ] <= {DW{1'b1}};
                                st <= WAIT;
                            end
                            2'b00:
                                case( full_op[CW-2:CW-3] )
                                    2'b11: begin
                                        `REPORT_ERASEEN
                                        erase_en <= 1'b1;
                                        st <= WAIT;
                                    end
                                    2'b00: begin
                                        `REPORT_ERASEDIS
                                        erase_en <= 1'b0;
                                        st <= WAIT;
                                    end
                                    2'b10: begin
                                        if( erase_en ) begin
                                            `REPORT_ERASEALL
                                            sdo     <= 0; // busy
                                            newdata <= {DW{1'b1}};
                                            st      <= WRITE_ALL;
                                        end else begin
                                            st <= WAIT;
                                        end
                                    end
                                    2'b01: begin
                                        `REPORT_WRITEALL
                                        sdo       <= 0; // busy
                                        st        <= WRITE;
                                        newdata   <= {DW{1'b1}};
                                        rx_cnt    <= 16'h1 << (DW-1);
                                        write_all <= 1'b1;
                                    end
                                endcase
                        endcase
                    end
                end
                WRITE: if( sclk_posedge && scs ) begin
                    newdata <= next_data;
                    rx_cnt  <= rx_cnt>>1;
                    sdo     <= 0; // busy
                    if( rx_cnt[0] ) begin
                        mem_we  <= 1;
                        if( write_all ) begin
                            addr   <= 0;
                            mem_din<= next_data;
                            st   <= WRITE_ALL;
                        end else begin
                            `REPORT_WRITE( addr, next_data )
                            // mem[ addr ] <= next_data;
                            mem_din <= next_data;
                            st <= WAIT;
                        end
                    end
                end
                /*
                PRE_READ: if( sclk_posedge && scs ) begin
                    st <= READ;
                    sdo <= 0;
                end else if(!scs) st<=IDLE;*/
                READ: if( sclk_posedge && scs ) begin
                    { sdo, dout} <= { dout, 1'b1 };
                end else if(!scs) begin
                    st <= IDLE;
                end
                WRITE_ALL: begin
                    addr   <= addr+1'd1;
                    mem_we <= 1;
                    if( &addr ) st <= WAIT;
                end
                WAIT: begin
                    if (!scs) st<=IDLE;
                end
            endcase
        end
    end
end

endmodule


module jt9346_dual_ram #(parameter DW=8, AW=10) (
    input   clk0,
    input   clk1,
    // Port 0
    input   [DW-1:0] data0,
    input   [AW-1:0] addr0,
    input   we0,
    output reg [DW-1:0] q0,
    // Port 1
    input   [DW-1:0] data1,
    input   [AW-1:0] addr1,
    input   we1,
    output reg [DW-1:0] q1
    `ifdef JTFRAME_DUAL_RAM_DUMP
    ,input dump
    `endif
);

(* ramstyle = "no_rw_check" *) reg [DW-1:0] mem[0:(2**AW)-1];

`ifdef SIMULATION
integer rstcnt;
initial begin
    for( rstcnt=0; rstcnt<2**AW; rstcnt=rstcnt+1)
        mem[rstcnt] = {DW{1'b1}};
end
`endif

always @(posedge clk0) begin
    q0 <= mem[addr0];
    if(we0) mem[addr0] <= data0;
end

always @(posedge clk1) begin
    q1 <= mem[addr1];
    if(we1) mem[addr1] <= data1;
end

endmodule