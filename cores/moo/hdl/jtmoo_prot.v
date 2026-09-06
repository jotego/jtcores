/* SPDX-FileCopyrightText: 2026 meathax
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Author: meathax
 * Date: 4-9-2026 */

// K053990 as Moo Mesa uses it: bus-mastering block operation dst[i]=src1[i]+2*src2[i]
// over len words, registers at 0x0CE000-1F, write to 0x0CE018 starts it (MAME moo.cpp)
// Riders/TMNT2 use the chip's sprite-DMA mode instead, see jtriders_tmnt2.v

module jtmoo_prot(
    input                rst,
    input                clk,
    input                cen,   // 16 MHz

    input                cs,
    input         [ 4:1] addr,
    input         [ 1:0] dsn,
    input         [15:0] din,
    input                cpu_we,
    input                dtack_n,
    output        [15:0] dout,   // register read-back for the CPU

    // Bus mastership
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
// Legacy switch retained for protection-disabled builds.
`ifndef NOTMNT2
reg  [15:0] mmr[0:15];
reg  [23:1] a, p1, p2, pd;
reg  [15:0] va, res, cnt;
reg  [ 3:0] st;
reg         trig, wr_l;
integer     i;

wire        wr_trig = cs & cpu_we & (addr==4'hc) & ~wr_l;

assign bus_addr = a;
assign bus_dsn  = 2'b00; // whole words only
assign dout     = mmr[addr];

always @(posedge clk) begin
    if( rst ) begin
        for( i=0; i<16; i=i+1 ) mmr[i] <= 16'd0;
        trig <= 0;
        wr_l <= 0;
    end else begin
        wr_l <= cs & cpu_we & (addr==4'hc);
        if( cs && cpu_we ) begin
            if( !dsn[1] ) mmr[addr][15:8] <= din[15:8];
            if( !dsn[0] ) mmr[addr][ 7:0] <= din[ 7:0];
        end
        if( wr_trig )
            trig <= 1;
        else if( cen && st==0 )
            trig <= 0;
    end
end

always @(posedge clk) begin
    if( rst ) begin
        st      <= 0;
        BRn     <= 1;
        BGACKn  <= 1;
        bus_asn <= 1;
        bus_wrn <= 1;
        bus_din <= 0;
        a       <= 0;
    end else if( cen ) begin
        case( st )
            0: if( trig && |mmr[15] ) begin // MAME while(length){} is a no-op at 0
                // 24-bit byte pointers, high byte in the odd register
                p1  <= { mmr[1][7:0], mmr[0][15:1] };
                p2  <= { mmr[3][7:0], mmr[2][15:1] };
                pd  <= { mmr[5][7:0], mmr[4][15:1] };
                cnt <= mmr[15];
                st  <= 1;
            end
            1: begin
                BRn <= 0;
                bus_asn <= 1;
                bus_wrn <= 1;
                if( !BGn ) st <= 2;
            end
            2: begin
                BGACKn <= 0;
                st <= cnt==16'd0 ? 4'd9 : 4'd3;
            end
            // src1
            3: begin
                a <= p1;
                bus_wrn <= 1;
                bus_asn <= 0;
                if( !dtack_n ) st <= 4;
            end
            4: begin
                va <= bus_dout;
                bus_asn <= 1;
                st <= 5;
            end
            // src2
            5: begin
                a <= p2;
                bus_asn <= 0;
                if( !dtack_n ) st <= 6;
            end
            6: begin
                res <= va + { bus_dout[14:0], 1'b0 };
                bus_asn <= 1;
                st <= 7;
            end
            // dst
            7: begin
                a <= pd;
                bus_din <= res;
                bus_wrn <= 0;
                bus_asn <= 0;
                if( !dtack_n ) st <= 8;
            end
            8: begin
                bus_asn <= 1;
                bus_wrn <= 1;
                p1  <= p1+23'd1;
                p2  <= p2+23'd1;
                pd  <= pd+23'd1;
                cnt <= cnt-16'd1;
                st  <= cnt==16'd1 ? 4'd9 : 4'd3;
            end
            9: begin
                BRn <= 1;
                bus_asn <= 1;
                bus_wrn <= 1;
                if( BGn ) st <= 10;
            end
           10: begin
               BGACKn <= 1;
               st <= 0;
           end
           default: st <= 0;
        endcase
    end
end
`else
assign bus_addr = 0;
assign bus_dsn  = 3;
assign dout     = 16'd0;
initial begin
    bus_asn = 1;
    bus_din = 0;
    bus_wrn = 1;
    BRn     = 1;
    BGACKn  = 1;
end
`endif
endmodule
