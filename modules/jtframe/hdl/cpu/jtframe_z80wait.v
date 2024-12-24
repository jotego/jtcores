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
    Date: 1-1-2020 */

module jtframe_rom_wait(
    input       rst_n,
    input       clk,
    input       cen_in,
    input       rec_en,
    output      cen_out,
    output      gate,
    // manage access to ROM data from SDRAM
    input       rom_cs,
    input       rom_ok
);
    jtframe_z80wait #(1) u_wait(
        .rst_n      ( rst_n     ),
        .clk        ( clk       ),
        .cen_in     ( cen_in    ),
        .cen_out    ( cen_out   ),
        .gate       ( gate      ),
        .iorq_n     ( rec_en    ),
        .mreq_n     ( 1'b1      ),
        .busak_n    ( 1'b1      ),
        // manage access to shared memory
        .dev_busy   ( 1'b0      ),
        // manage access to ROM data from SDRAM
        .rom_cs     ( rom_cs    ),
        .rom_ok     ( rom_ok    )
    );
endmodule

/////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////

module jtframe_dual_wait #(parameter devcnt=2)(
    input       rst_n,
    input       clk,
    input  [1:0]     cen_in,
    output reg [1:0] cen_out,
    output           gate,
    // manage access to shared memory
    input  [devcnt-1:0] dev_busy,
    // manage access to ROM data from SDRAM
    input       rom_cs,
    input       rom_ok
);

/////////////////////////////////////////////////////////////////
// wait_n generation
reg last_rom_cs;
wire rom_cs_posedge = !last_rom_cs && rom_cs;
wire rom_bad = rom_cs && !rom_ok || rom_cs_posedge;

reg [1:0] mark, gated_at;
reg       locked, latched;
assign gate = !( rom_bad || dev_busy || locked || latched);
wire bus_ok = (rom_ok||!rom_cs) && !dev_busy;

always @(posedge clk, negedge rst_n) begin
    if( !rst_n ) begin
        gated_at <= 1'b0;
        latched  <= 1'b0;
    end else begin
        if(cen_in[0]) mark <= 2'b01;
        if(cen_in[1]) mark <= 2'b10;
        if(locked) begin
            gated_at <= mark;
            latched  <= 1'b1;
        end
        latched <= locked;
        if(bus_ok && !locked && latched) begin
            if( gated_at[0] & cen_in[1] ) latched <= 1'b0;
            if( gated_at[1] & cen_in[0] ) latched <= 1'b0;
        end
    end
end

always @(posedge clk)
    cen_out <= cen_in & {2{gate}};


always @(posedge clk or negedge rst_n) begin
    if( !rst_n ) begin
        last_rom_cs <= 1'b1;
        locked      <= 1'b0;
    end else begin
        last_rom_cs <= rom_cs;
        if( rom_bad || dev_busy) begin
            locked  <= 1'b1;
        end
        else begin
            locked <= 1'b0;
        end
    end
end

endmodule

module jtframe_z80wait #(parameter DEVCNT=2, RECOVERY=1)(
    input       rst_n,
    input       clk,
    input       cen_in,
    output reg  cen_out,
    output      gate,
    // Recover cycles
    input       mreq_n,
    input       iorq_n,
    input       busak_n,
    // manage access to shared memory
    input  [DEVCNT-1:0] dev_busy, // Delays here are not recovered
    // manage access to ROM data from SDRAM
    input       rom_cs,
    input       rom_ok // Delays because of rom_ok are recovered
);

`ifdef JTFRAME_CLK24
initial begin
    if(RECOVERY==1) begin
       $display("WARNING: %m");
       $display("         Do not use cycle recovery with a 24MHz clock and 6MHz pixel");
       $display("         that combination fails in jtkiwi.");
       $display("         See issue https://github.com/jotego/jtbubl/issues/27");
       $display("         This could affect 48MHz/8MHz combination too");
    end
end
`endif

/////////////////////////////////////////////////////////////////
// wait_n generation
reg last_rom_cs;
wire rom_cs_posedge = !last_rom_cs && rom_cs;

reg        locked, rec, start, cen_l;
wire       rom_bad, rec_en;
reg  [3:0] miss_cnt;

// wire bus_ok = (rom_ok||!rom_cs) && !dev_busy;

assign gate    = !(rom_bad || dev_busy!=0 || locked );
assign rom_bad = (rom_cs && !rom_ok) || rom_cs_posedge;
assign rec_en  = &{mreq_n, iorq_n, busak_n, RECOVERY[0] };

always @(*) begin
    rec = 0;
    // two cen pulses in a row will break most systems
    // probably because of memory delays. That's why cen_l
    // is used too
    if( miss_cnt!=0 && !cen_in && rec_en && !cen_l )
        rec = 1;
end

always @(posedge clk) cen_l <= cen_out;

always @(posedge clk, negedge rst_n) begin
    if( !rst_n ) begin
        miss_cnt <= 4'd0;
    end else begin
        if( !start ) begin
            miss_cnt <= 4'd0;
        end else begin
            if( cen_in && !gate && dev_busy==0 ) begin
                if( ~&miss_cnt ) miss_cnt <= miss_cnt+4'd1;
            end else if( rec ) begin
                if( miss_cnt!=0 ) miss_cnt <= miss_cnt - 4'd1;
            end
        end
    end
end

always @(*)
    cen_out = (cen_in & gate) | rec;

always @(posedge clk or negedge rst_n) begin
    if( !rst_n ) begin
        last_rom_cs <= 1'b1;
        locked      <= 1'b0;
        start       <= 0;
    end else begin
        last_rom_cs <= rom_cs;
        if(rom_bad) begin
            locked  <= 1'b1;
        end
        else begin
            locked <= 1'b0;
            start  <= 1;
        end
    end
end

`ifdef SIMULATION
// Count how often there are delays because of ROM waits
integer misses=0;
always @(posedge cen_in) if(!gate) misses<=misses+1;
`endif

endmodule // jtframe_z80wait