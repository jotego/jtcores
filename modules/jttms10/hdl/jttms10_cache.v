/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * TI TMS34010 256-byte instruction cache, User's Guide section 5.4.
 * Physical 16-bit words; all addresses are bit addresses. No data-array reset.
 */
module jttms10_cache(
    input clk, rst,
    input cache_disable, cache_flush,
    input c_req, c_we, c_iaq, c_program, c_pixel, c_lock,
    input [31:0] c_addr,
    input [15:0] c_wdata,
    output reg [15:0] c_rdata,
    output reg c_ack,
    input p_req,
    input [31:0] p_addr,
    input p_busy,
    input p_consume,
    output reg p_ack,
    output reg p_hit,
    output [15:0] p_rdata,
    output c_restart,
    output m_req, m_we, m_iaq, m_pixel, m_lock,
    output [31:0] m_addr,
    output [15:0] m_wdata,
    input [15:0] m_rdata,
    input m_ack, m_restart
);
    localparam [2:0] IDLE=0, HIT=1, FILL=2, BYPASS=3, DONE=4;
    reg [2:0] state;
    reg seen, last_we, last_iaq, last_program, last_pixel, last_lock;
    reg [31:0] last_addr;
    reg [15:0] last_wdata;
    wire same_request=c_we==last_we && c_iaq==last_iaq &&
        c_program==last_program && c_pixel==last_pixel &&
        c_lock==last_lock && c_addr==last_addr && c_wdata==last_wdata;
    wire accept=state==IDLE && c_req && (!seen || !same_request);
    wire cacheable=c_program && !c_we && !c_pixel;
    wire p_req_valid=p_req===1'b1;
    wire p_consume_valid=p_consume===1'b1;
    wire [31:9] lookup_tag=(p_req_valid || p_consume_valid) ?
                            p_addr[31:9] : c_addr[31:9];
    wire [8:6] lookup_sub=(p_req_valid || p_consume_valid) ?
                           p_addr[8:6] : c_addr[8:6];
    reg [22:0] tag [0:3];
    reg [7:0] present [0:3];
    reg [1:0] lru [0:3]; // [0] most recently used, [3] victim
    reg hit_segment;
    reg [1:0] hit_slot, use_slot;
    reg [1:0] lru_next [0:3];
    integer i, j, k, n, pos;
    always @* begin
        hit_segment=0; hit_slot=0;
        for (j=0;j<4;j=j+1)
            if (present[j]!=0 && tag[j]==lookup_tag) begin
                hit_segment=1;
                hit_slot=j[1:0];
            end
        use_slot=hit_segment ? hit_slot : lru[3];
        pos=3;
        for (k=0;k<4;k=k+1)
            if (lru[k]==use_slot) pos=k;
        lru_next[0]=use_slot;
        for (n=1;n<4;n=n+1)
            lru_next[n]=(n<=pos) ? lru[n-1] : lru[n];
    end
    wire hit_word=hit_segment && present[hit_slot][lookup_sub];
    wire peek_accept=p_req_valid && state==IDLE && !c_req && !p_busy &&
                     !cache_disable && !cache_flush &&
                     p_addr[3:0]==0 && hit_word;
    wire consume_hit=p_consume_valid && state==IDLE && !c_req && !p_busy &&
                     !cache_disable && !cache_flush &&
                     p_addr[3:0]==0 && hit_word;

    // Exactly 128 x 16 bits. A registered read and separate write port infer
    // one small synchronous block RAM; P flags and tags have reset, data does not.
    reg [15:0] ram [0:127];
    reg [15:0] ram_q;
    wire [6:0] ram_read_addr=peek_accept ?
                             {hit_slot,p_addr[8:4]} :
                             {use_slot,c_addr[8:4]};
    reg [1:0] slot_q, word_q, fill_index;
    reg [2:0] sub_q;
    reg [31:0] addr_q;
    reg [25:0] fill_base;
    reg [15:0] data_q, target_q;
    reg we_q, iaq_q, pixel_q, lock_q, fill_store, fill_poison;
    wire ram_write=state==FILL && m_ack && fill_store &&
                   !fill_poison && !cache_flush && !cache_disable;
    wire [6:0] ram_write_addr={slot_q,sub_q,fill_index};
    always @(posedge clk) begin
        ram_q<=ram[ram_read_addr];
        if (ram_write) ram[ram_write_addr]<=m_rdata;
    end
    assign p_rdata=ram_q;

    // HOLD can revoke an unaccepted partial RMW write even after this helper
    // captured it. Drop m_req combinationally on the restart edge so the bus
    // cannot grant the stale write when HOLD releases.
    assign m_req=(state==FILL || state==BYPASS) && !m_restart;
    assign m_we=state==BYPASS && we_q;
    assign m_addr=state==FILL ? {fill_base,fill_index,4'b0} : addr_q;
    assign m_wdata=state==BYPASS ? data_q : 16'd0;
    assign m_iaq=state==FILL ? 1'b1 : iaq_q;
    assign m_pixel=state==BYPASS && pixel_q;
    assign m_lock=state==BYPASS && lock_q;
    // A HOLD restart can arrive between a bypassed partial read and write,
    // including while the cache is issuing the prior CPU acknowledgment.
    assign c_restart=m_restart;

    always @(posedge clk) begin
        c_ack<=0;
        p_ack<=0;
        p_hit<=0;
        if (rst) begin
            state<=IDLE; seen<=0; c_rdata<=0;
            slot_q<=0; word_q<=0; fill_index<=0; sub_q<=0;
            addr_q<=0; fill_base<=0; data_q<=0; target_q<=0;
            we_q<=0; iaq_q<=0; pixel_q<=0; lock_q<=0;
            fill_store<=0; fill_poison<=0;
            last_we<=0; last_iaq<=0; last_program<=0;
            last_pixel<=0; last_lock<=0; last_addr<=0; last_wdata<=0;
            for (i=0;i<4;i=i+1) begin
                present[i]<=0; lru[i]<=i[1:0]; tag[i]<=0;
            end
        end else if (m_restart) begin
            state<=IDLE;
            seen<=0;
            fill_poison<=1;
        end else begin
            p_ack<=p_req_valid;
            p_hit<=peek_accept;
            if (!c_req) seen<=0;
            if(consume_hit)
                for(i=0;i<4;i=i+1) lru[i]<=lru_next[i];
            if (cache_flush) begin
                for (i=0;i<4;i=i+1) begin
                    present[i]<=0;
                    lru[i]<=i[1:0];
                end
            end
            if (state==FILL && (cache_flush || cache_disable))
                fill_poison<=1;
            case (state)
                IDLE: if (accept && !p_req_valid && !p_consume_valid) begin
                    seen<=1;
                    last_we<=c_we; last_iaq<=c_iaq;
                    last_program<=c_program; last_pixel<=c_pixel;
                    last_lock<=c_lock; last_addr<=c_addr; last_wdata<=c_wdata;
                    addr_q<=c_addr; data_q<=c_wdata;
                    we_q<=c_we; iaq_q<=c_iaq;
                    pixel_q<=c_pixel; lock_q<=c_lock;
                    word_q<=c_addr[5:4]; sub_q<=c_addr[8:6];
                    fill_base<=c_addr[31:6];
                    fill_index<=0; fill_poison<=0;
                    if (!cacheable || cache_disable) begin
                        state<=BYPASS;
                    end else if (!cache_flush && hit_word) begin
                        slot_q<=hit_slot;
                        if (!cache_flush)
                            for (i=0;i<4;i=i+1) lru[i]<=lru_next[i];
                        state<=HIT;
                    end else begin
                        slot_q<=use_slot;
                        fill_store<=!cache_flush;
                        if (!cache_flush) begin
                            if (!hit_segment) begin
                                tag[use_slot]<=c_addr[31:9];
                                present[use_slot]<=0;
                            end
                            for (i=0;i<4;i=i+1) lru[i]<=lru_next[i];
                        end
                        state<=FILL;
                    end
                end
                HIT: begin
                    if (cache_disable) state<=BYPASS;
                    else if (cache_flush) begin
                        fill_index<=0; fill_store<=0; fill_poison<=1;
                        state<=FILL;
                    end else begin
                        c_rdata<=ram_q;
                        c_ack<=1;
                        state<=DONE;
                    end
                end
                FILL: if (m_ack) begin
                    if (fill_index==word_q) target_q<=m_rdata;
                    if (fill_index==2'd3) begin
                        c_rdata<=word_q==2'd3 ? m_rdata : target_q;
                        c_ack<=1;
                        if (fill_store && !fill_poison &&
                            !cache_flush && !cache_disable)
                            present[slot_q][sub_q]<=1;
                        state<=DONE;
                    end else fill_index<=fill_index+2'd1;
                end
                BYPASS: if (m_ack) begin
                    c_rdata<=m_rdata;
                    c_ack<=1;
                    state<=DONE;
                end
                DONE: state<=IDLE;
                default: state<=IDLE;
            endcase
        end
    end
endmodule
