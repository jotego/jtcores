/* SPDX-License-Identifier: GPL-3.0-or-later */
// Synchronous four-register host boundary and held indirect word client.
// Physical asynchronous HCS/HREAD/HWRITE/HRDY pin timing belongs upstream.
// Semantics follow TI TMS34010 User's Guide sections 6 and 10 and the GPL
// tms34010_host_if.sv reference.
module jttms10_host(
    input clk, rst,
    input host_req, host_we,
    input [1:0] host_reg, host_be,
    input [15:0] host_wdata,
    output reg [15:0] host_rdata,
    output reg host_ack,
    output host_busy,
    input [15:0] ctl_rdata, hstctlh,
    output ctl_we,
    output [1:0] ctl_be,
    output [15:0] ctl_wdata,
    input cpu_we,
    input [1:0] cpu_reg,
    input [15:0] cpu_wdata,
    input indirect_we,
    input [1:0] indirect_reg,
    input [15:0] indirect_wdata,
    output reg [31:0] hstadr,
    output reg [15:0] hstdata,
    output local_req,
    output reg local_we,
    output reg [31:0] local_addr,
    output reg [15:0] local_wdata,
    input [15:0] local_rdata,
    input local_ack
);
    localparam [1:0] ADRL=0, ADRH=1, DATA=2, CTL=3;
    wire unused_hstctlh=&{1'b0,hstctlh[15:14],hstctlh[10:0]};
    reg busy, seen, incw_after;
    reg [31:0] merged_addr;
    reg [15:0] merged_data;
    // HSTCTL has no local-memory side effect, so it remains available while
    // a prior host-indirect HSTADR/HSTDATA cycle is awaiting local_ack.
    wire accept=host_req && !seen && (!busy || host_reg==CTL);
    wire last_byte=hstctlh[13] ? host_be[0] : host_be[1];
    wire addr_last=hstctlh[13] ?
        (host_reg==ADRL && host_be[0]) : (host_reg==ADRH && host_be[1]);
    wire start_addr=accept && host_we && addr_last;
    wire start_read=accept && !host_we && host_reg==DATA && last_byte;
    wire start_write=accept && host_we && host_reg==DATA && last_byte;
    wire [31:0] read_addr=hstctlh[12] ? hstadr+32'd16 : hstadr;
    assign ctl_we=accept && host_we && host_reg==CTL;
    assign ctl_be=host_be;
    assign ctl_wdata=host_wdata;
    assign host_busy=busy;
    assign local_req=busy;

    always @* begin
        merged_addr=hstadr;
        if (host_reg==ADRL) begin
            if (host_be[0]) merged_addr[7:0]=host_wdata[7:0];
            if (host_be[1]) merged_addr[15:8]=host_wdata[15:8];
        end else if (host_reg==ADRH) begin
            if (host_be[0]) merged_addr[23:16]=host_wdata[7:0];
            if (host_be[1]) merged_addr[31:24]=host_wdata[15:8];
        end
        merged_addr[3:0]=0;
        merged_data=hstdata;
        if (host_be[0]) merged_data[7:0]=host_wdata[7:0];
        if (host_be[1]) merged_data[15:8]=host_wdata[15:8];
    end

    always @(posedge clk) begin
        if (rst) begin
            hstadr<=0; hstdata<=0; host_rdata<=0; host_ack<=0;
            busy<=0; seen<=0; incw_after<=0;
            local_we<=0; local_addr<=0; local_wdata<=0;
        end else begin
            host_ack<=accept;
            if (!host_req) seen<=0;
            else if (accept) seen<=1;
            if (accept) begin
                case (host_reg)
                    ADRL: host_rdata<=hstadr[15:0];
                    ADRH: host_rdata<=hstadr[31:16];
                    DATA: host_rdata<=hstdata;
                    CTL: host_rdata<=ctl_rdata;
                endcase
            end
            if (busy && local_ack) busy<=0;
            if (start_addr || start_read || start_write) begin
                busy<=1;
                if (start_addr) begin
                    local_addr<=merged_addr; local_we<=0;
                    local_wdata<=0; incw_after<=0;
                end else if (start_read) begin
                    local_addr<=read_addr; local_we<=0;
                    local_wdata<=0; incw_after<=0;
                end else begin
                    local_addr<=hstadr; local_we<=1;
                    local_wdata<=merged_data; incw_after<=hstctlh[11];
                end
            end

            // Explicit writes override automatic prefetch and INCW updates.
            if (busy && local_ack && incw_after)
                hstadr<=local_addr+32'd16;
            if (cpu_we && cpu_reg==ADRL)
                hstadr[15:0]<={cpu_wdata[15:4],4'b0};
            else if (cpu_we && cpu_reg==ADRH)
                hstadr[31:16]<=cpu_wdata;
            if (indirect_we && indirect_reg==ADRL)
                hstadr[15:0]<={indirect_wdata[15:4],4'b0};
            else if (indirect_we && indirect_reg==ADRH)
                hstadr[31:16]<=indirect_wdata;
            if (accept && host_we && (host_reg==ADRL || host_reg==ADRH))
                hstadr<=merged_addr;
            else if (start_read && hstctlh[12])
                hstadr<=read_addr;

            if (busy && local_ack && !local_we) hstdata<=local_rdata;
            if (cpu_we && cpu_reg==DATA) hstdata<=cpu_wdata;
            if (indirect_we && indirect_reg==DATA) hstdata<=indirect_wdata;
            if (accept && host_we && host_reg==DATA)
                hstdata<=merged_data;
        end
    end
endmodule
