/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 28-2-2019 */

////////////////////////////////////////////////////////////
/////// read/write type
/////// simple pass through
/////// It requires addr_ok signal to toggle for each request
/////// addr_ok is meant to be the CS signal coming from a CPU memory decoder
/////// so it should go up and stay up until the data is served. It should go down
/////// after that.
/* verilator coverage_off */
module jtframe_ram_rq #(parameter
    SDRAMW = 22,
    AW     = 18,
    DW     = 8,
    ERASE  = 1, // erase memory contents after a reset
    AUTOTOGGLE= // automatically toggles cs after a data delivery.
        `ifdef JTFRAME_SDRAM_TOGGLE
        1 `else 0 `endif ,
    FASTWR = 0  // gives an ok as soon as the slot mux accepts the write
                // operation. But a new operation won't be accepted until
                // the current one finishes
                // This is useful to have a CPU continue working while a
                // write occurs in the background
)(
    input               rst,
    input               clk,
    input [AW-1:0]      addr,
    input [SDRAMW-1:0]  offset,     // It is not supposed to change during game play
    input               addr_ok,    // signals that value in addr is valid
    input [15:0]        din,        // data read from SDRAM
    input               din_ok,
    input               wrin,
    input               we,
    input               dst,
    output              req,
    output              req_rnw,
    output reg          data_ok,    // strobe that signals that data is ready
    output     [SDRAMW-1:0]   sdram_addr,
    input      [DW-1:0] wrdata,
    output reg [DW-1:0] dout,       // sends SDRAM data back to requester
    output              erase_bsy
);

    wire  [SDRAMW-1:0] size_ext   = { {SDRAMW-AW{1'b0}}, addr };

    reg          last_cs, pending, erased;
    reg          req_l, req_rnw_l;
    reg [SDRAMW-1:0] sdram_addr_l;
    reg [AW-1:0] erase_cnt;
    wire         cs_posedge = addr_ok && !last_cs;
    wire         req_fast = !erase_bsy && !we && (cs_posedge || pending);
    // wire   cs_negedge = !addr_ok && last_cs;
    assign erase_bsy = ERASE[0] && !erased;
    assign req        = req_l | req_fast;
    assign req_rnw    = req_fast ? ~wrin : req_rnw_l;
    assign sdram_addr = req_fast ? size_ext + offset : sdram_addr_l;

    always @(posedge clk) begin
        if( rst ) begin
            last_cs   <= 0;
            req_l     <= 0;
            data_ok   <= 0;
            pending   <= 0;
            dout      <= 0;
            req_rnw_l <= 1;
            if( ERASE==1 ) begin
                erased    <= 0;
                erase_cnt <= 0;
            end
        end else begin
            if( ERASE==1 && !erased ) begin
                if( we ) begin
                    req_l <= 0;
                    if( req_l ) {erased,erase_cnt}<= erase_cnt+1'd1;
                end else begin
                    req_l     <= 1;
                    req_rnw_l <= 0;
                    if(!req_l) begin
                        sdram_addr_l <= { {SDRAMW-AW{1'b0}}, erase_cnt } + offset;
                    end
                end
            end else begin
                last_cs <= addr_ok;
                if( !addr_ok ) data_ok <= 0;
                if( we ) begin
                    if( cs_posedge && FASTWR ) begin
                        data_ok <= 0;
                        pending <= 1;
                    end
                    req_l <= 0;
                    if( FASTWR && !req_rnw_l ) begin
                        data_ok <= 1;
                    end
                    if( dst ) begin // note byte selection for DW==8
                        dout <= DW==8 && addr[0] ? din[15-:DW] : din[0+:DW];
                        if( AUTOTOGGLE==1 ) last_cs <= 0; // forces a toggle
                    end
                    if( din_ok && (!FASTWR || req_rnw) ) data_ok <= 1;
                end else if( cs_posedge || pending ) begin
                    req_l      <= 1;
                    req_rnw_l  <= ~wrin;
                    data_ok    <= 0;
                    pending    <= 0;
                    sdram_addr_l <= size_ext + offset;
                end
            end
        end
    end

endmodule
