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
    output [15:0] c_rdata,
    output c_ack,
    output c_hit,
    output [31:0] c_next_data,
    output c_next_valid,
    output c_next_first_valid,
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
            if (present[j]!=0 && tag[j]==c_addr[31:9]) begin
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
    wire hit_word=hit_segment && present[hit_slot][c_addr[8:6]];
    reg response_ack;
    reg [15:0] response_data;

    // Each subsegment is four words. Read the complete subsegment through
    // one synchronous port; fills update one 16-bit lane through the write
    // port. Tags/present flags reset, instruction data does not.
    wire [63:0] ram_q;
    // The synchronous RAM output is valid throughout HIT, beginning just
    // after the acceptance edge. Do not register an additional response
    // cycle after that RAM read. Mode changes may still revoke this hit.
    wire hit_ack=state==HIT && !cache_disable && !cache_flush;
    assign c_ack=hit_ack || response_ack;
    assign c_hit=hit_ack;
    assign c_rdata=hit_ack ? ram_q[16*word_q+:16] : response_data;
    reg [1:0] slot_q, word_q, fill_index;
    reg [2:0] sub_q;
    reg [31:0] addr_q;
    reg [25:0] fill_base;
    reg [15:0] data_q, target_q;
    reg we_q, iaq_q, pixel_q, lock_q, fill_store, fill_poison;
    wire ram_write=state==FILL && m_ack && fill_store &&
                   !fill_poison && !cache_flush && !cache_disable;
    wire [4:0] ram_write_addr={slot_q,sub_q};
    wire [25:0] next_block=addr_q[31:6]+26'd1;
    reg next_hit;
    reg [1:0] next_slot;
    integer look;
    always @* begin
        next_hit=0;
        next_slot=0;
        for(look=0;look<4;look=look+1)
            if(tag[look]==next_block[25:3] && present[look][next_block[2:0]]) begin
                next_hit=1;
                next_slot=look[1:0];
            end
    end
    wire look_next=state==HIT && iaq_q && word_q[1] && next_hit;
    wire [4:0] ram_read_addr=state==FILL ? {slot_q,sub_q} :
                           look_next ? {next_slot,next_block[2:0]} : {use_slot,c_addr[8:6]};
    reg [31:0] next_data_q;
    reg [15:0] next_tail;
    reg next_pending, next_valid_q, next_first_valid_q, next_upper;
    wire [31:0] pending_pair=next_upper ? ram_q[31:0] : {ram_q[15:0],next_tail};
    wire next_allowed=c_program && !c_we && c_addr==addr_q &&
                      !cache_flush && !cache_disable && !m_restart;
    assign c_next_valid=(next_pending || next_valid_q) && next_allowed;
    assign c_next_first_valid=(next_pending || next_first_valid_q) && next_allowed;
    assign c_next_data=next_pending ? pending_pair : next_data_q;
    always @(posedge clk) begin
        if(rst) begin
            next_pending<=0;
            next_valid_q<=0;
            next_first_valid_q<=0;
            next_data_q<=0;
            next_tail<=0;
            next_upper<=0;
        end else if(cache_flush || cache_disable || m_restart || accept) begin
            next_pending<=0;
            next_valid_q<=0;
            next_first_valid_q<=0;
        end else if(hit_ack && iaq_q) begin
            next_pending<=look_next;
            next_valid_q<=!word_q[1];
            next_first_valid_q<=word_q!=2'd3;
            next_upper<=word_q[0];
            next_tail<=ram_q[63:48];
            next_data_q<=word_q[1] ? {16'd0,ram_q[63:48]} :
                                    word_q[0] ? ram_q[63:32] : ram_q[47:16];
        end else if(state==FILL && m_ack && fill_index==2'd3 &&
                    fill_store && !fill_poison && word_q<2'd2) begin
            // A missing first address word refills the whole subsegment.
            // Its following word is ready with this response as well.
            next_pending<=0;
            next_valid_q<=1;
            next_first_valid_q<=1;
            next_data_q<=word_q[0] ? {m_rdata,ram_q[47:32]} : ram_q[47:16];
        end else if(next_pending) begin
            next_data_q<=pending_pair;
            next_pending<=0;
            next_valid_q<=1;
            next_first_valid_q<=1;
        end
    end
    genvar lane;
    generate for(lane=0;lane<4;lane=lane+1) begin : g_lane
        reg [15:0] ram [0:31];
        reg [15:0] read_q;
        assign ram_q[16*lane+:16]=read_q;
        always @(posedge clk) begin
            read_q<=ram[ram_read_addr];
            if(ram_write && fill_index==lane[1:0])
                ram[ram_write_addr]<=m_rdata;
        end
    end endgenerate

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
        response_ack<=0;
        if (rst) begin
            state<=IDLE; seen<=0; response_data<=0;
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
            if (!c_req) seen<=0;
            if (cache_flush) begin
                for (i=0;i<4;i=i+1) begin
                    present[i]<=0;
                    lru[i]<=i[1:0];
                end
            end
            if (state==FILL && (cache_flush || cache_disable))
                fill_poison<=1;
            case (state)
                IDLE: if (accept) begin
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
                        state<=DONE;
                    end
                end
                FILL: if (m_ack) begin
                    if (fill_index==word_q) target_q<=m_rdata;
                    if (fill_index==2'd3) begin
                        response_data<=word_q==2'd3 ? m_rdata : target_q;
                        response_ack<=1;
                        if (fill_store && !fill_poison &&
                            !cache_flush && !cache_disable)
                            present[slot_q][sub_q]<=1;
                        state<=DONE;
                    end else fill_index<=fill_index+2'd1;
                end
                BYPASS: if (m_ack) begin
                    response_data<=m_rdata;
                    response_ack<=1;
                    state<=DONE;
                end
                DONE: state<=IDLE;
                default: state<=IDLE;
            endcase
        end
    end
endmodule
