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

    Author: Andrea Bogazzi <andreabogazzi79@gmail.com>
    Version: 1.0
    Date: 17-8-2026 */

// Prefetching byte cache between the ADPCM-A SDRAM slot and the YM2610.
//
// jt10's ADPCM-A section time-multiplexes its six channels through a pipeline
// clocked at 666kHz: the ROM address bus belongs to each channel for ONE
// 1.5us slot and the byte must be on adpcma_data before that slot ends -
// next slot the bus is another channel's. This contract is not written down
// anywhere in jt12; it comes from jt10_adpcm_cnt (stage-1 outputs, cen6) and
// jt10_adpcm_drvA (data consumed at the slot boundary).
//
// A plain SDRAM slot can miss that deadline - measured worst 69 clk48 = 1.6us
// from address change to valid dout, contention with the same bank's gfx
// client included - and then the chip decodes ANOTHER channel's byte.
//
// Each channel walks its sample +1, so serving addr N is the moment to fetch
// N+1: every in-stream byte is then a hit, served well inside the
// slot, and only the first byte after a key-on can miss. The ROM is immutable
// so entries never go stale; valid bits clear at reset only.
//
// 16 entries: the live set is two bytes per channel - the current byte still
// owes its second nibble ~55us after the first, while the next is already
// prefetched - so six channels peak at 12. Sizing below that lets round robin
// evict a byte that is still owed a nibble; never wrong data, but a redundant
// refetch that can miss the slot.

module jtpspike_pcma_pf(
    input             rst,
    input             clk,
    // YM2610, async ROM contract
    input      [19:0] chip_addr,
    input             chip_rd,      // ~adpcma_roe_n
    output reg [ 7:0] chip_data,
    // SDRAM slot
    output reg [19:0] rom_addr,
    output reg        rom_cs,
    input      [ 7:0] rom_data,
    input             rom_ok
);

reg  [19:0] tag  [0:15];
reg  [ 7:0] data [0:15];
reg  [15:0] valid;
reg  [ 3:0] wrsel;      // round robin replacement
reg         busy, okwait, pend, demand;
reg  [19:0] pend_addr;
wire [19:0] nx_addr = chip_addr + 20'd1;

reg  [15:0] hit, hit_nx;
integer i;
always @* begin
    for( i=0; i<16; i=i+1 ) begin
        hit   [i] = valid[i] && tag[i]==chip_addr;
        hit_nx[i] = valid[i] && tag[i]==nx_addr;
    end
end

always @(posedge clk) begin
    if( rst ) begin
        valid     <= 0;
        rom_cs    <= 0;
        busy      <= 0;
        okwait    <= 0;
        pend      <= 0;
        demand    <= 0;
        pend_addr <= 0;
        wrsel     <= 0;
        rom_addr  <= 0;
        chip_data <= 0;
    end else begin
        // serve the chip from the cache; hold the last byte on a miss until
        // the demand fetch lands, as the old latch did
        for( i=0; i<16; i=i+1 ) if( hit[i] ) chip_data <= data[i];

        if( busy ) begin
            // a demand miss landing while a fetch is in flight must not be
            // lost: several channels keying on together - a chord - produce
            // back to back misses, and a dropped one leaves that channel on
            // a stale byte for a whole 55us nibble period
            if( chip_rd && hit==0 && chip_addr!=rom_addr && !pend ) begin
                pend      <= 1;
                pend_addr <= chip_addr;
            end
            // OKLATCH keeps rom_ok high for one clock after the address
            // changes; the first cycle's ok belongs to the previous request
            okwait <= 0;
            if( rom_ok && !okwait ) begin
                tag  [wrsel] <= rom_addr;
                data [wrsel] <= rom_data;
                valid[wrsel] <= 1;
                wrsel        <= wrsel + 4'd1;
                if( pend && pend_addr!=rom_addr ) begin
                    rom_addr <= pend_addr;      // queued demand first
                    okwait   <= 1;
                    demand   <= 1;
                end else if( demand ) begin
                    rom_addr <= rom_addr+20'd1; // chain one prefetch after a
                    okwait   <= 1;              // demand so key-ons self-heal
                    demand   <= 0;              // without waiting for the
                end else begin                  // channel's next visit
                    rom_cs <= 0;
                    busy   <= 0;
                end
                pend <= 0;
            end
        end else if( chip_rd && hit==0 ) begin      // demand miss
            rom_addr <= chip_addr;
            rom_cs   <= 1;
            busy     <= 1;
            okwait   <= 1;
            demand   <= 1;
        end else if( chip_rd && hit_nx==0 ) begin   // prefetch the next byte
            rom_addr <= nx_addr;
            rom_cs   <= 1;
            busy     <= 1;
            okwait   <= 1;
            demand   <= 0;
        end
    end
end

endmodule
