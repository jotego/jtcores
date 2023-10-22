/*  This file is part of JTFRAME.
      JTFRAME program is free software: you can redistribute it and/or modify
      it under the terms of the GNU General Public License as published by
      the Free Software Foundation, either version 3 of the License, or
      (at your option) any later version.

      JTFRAME program is distributed in the hope that it will be useful,
      but WITHOUT ANY WARRANTY; without even the implied warranty of
      MERCHANTABILITY or FITNESS FOR addr PARTICULAR PURPOSE.  See the
      GNU General Public License for more details.

      You should have received a copy of the GNU General Public License
      along with JTFRAME.  If not, see <http://www.gnu.org/licenses/>.

      Author: Jose Tejada Gomez. Twitter: @topapate
      Version: 1.0
      Date: 2-6-2020

*/

// Gates the clock enable signals for two clock cycles if rom_cs
// has risen or if the rom address has changed while rom_cs was high

// Depending on how the CPU and the rom_cs decoder logic, rom_cs might
// not toggle in between ROM address changes, so the address must be
// tracked

// if rom_cs is constantly high, rom_ok will take one clock cycle to come
// down after an address change. If the cen frequency allows for at least
// two clock cycles between two cen pulses, then checking the ROM address
// is not necessary

// Missed cycles because of slow ROM access are tracked and recovered
// when rom_cs is low and rec_en is high. rec_en should be set low if
// a bus transaction sensitive to two consequitive cen is happening.

// If unsure about when to set rec_en high, just set it to the OR of
// of all bus select signals

module jtframe_gatecen #(parameter ROMW=12 )(
    input             clk,
    input             rst,
    input             cen,
    input             rec_en,   // recovery enable
                                // indicates when it is safe to recover a
                                // lost cycle
    input  [ROMW-1:0] rom_addr,
    input             rom_cs,
    input             rom_ok,
    output            wait_cen  // warning: this module may generate two cen pulses in a row (!)
);

reg  [     1:0] last_cs;
reg  [ROMW-1:0] last_addr;
reg             waitn, rec, start;
reg  [     2:0] miss_cnt;
wire            new_addr = last_addr != rom_addr;

assign          wait_cen = cen & waitn | rec;

always @(*) begin
    rec = 0;
    if( miss_cnt!=0 && !cen && rec_en && !rom_cs )
        rec = 1;
end

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        miss_cnt <= 3'd0;
    end else begin
        if( !start ) begin
            miss_cnt <= 3'd0;
        end else begin
            if( cen && !waitn ) begin
                if( ~&miss_cnt ) miss_cnt <= miss_cnt+1'd1;
            end else if( rec ) begin
                if( miss_cnt!=0 ) miss_cnt <= miss_cnt - 1'd1;
            end
        end
    end
end


always @(posedge clk) begin
    if( rst ) begin
        waitn     <= 1;
        last_cs   <= 0;
        last_addr <= {ROMW{1'b0}};
    end else begin
        last_cs   <= { last_cs[0] & ~new_addr, rom_cs };
        last_addr <= rom_addr;
        if( rom_cs && (!last_cs[0] || new_addr) ) waitn <= 0;
        else if( rom_ok && last_cs[1] ) begin
          waitn <= 1;
          start <= 1;
        end
    end
end

endmodule