/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 9-4-2025 */

module jtthundr_objdma(
    input             rst, clk,
    input             copy, lvbl,

    output            busy,
    output     [ 1:0] ram_we,
    output     [12:1] ram_addr,
    input      [15:0] ram_dout,
    output reg [15:0] ram_din=0
);

localparam [1:0] RD=0,LATCH=1,WR=2,ADV=3;

reg        lvbl_l, we;
reg [10:4] objcnt;
reg [ 3:1] rd_addr,wr_addr;
reg [ 1:0] st;
wire       copy_en;

assign busy           = we;
assign ram_we         = {2{we && st==WR}};
assign ram_addr[12:4] = {2'b11,objcnt};
assign ram_addr[ 3:1] = st==WR ? wr_addr : rd_addr;

jtframe_edge u_irq(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .edgeof ( copy      ),
    .clr    ( we        ),
    .q      ( copy_en   )
);

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        we      <= 0;
        rd_addr <= 0;
        wr_addr <= 0;
        objcnt  <= 0;
        st      <= RD;
    end else begin
        lvbl_l <= lvbl;
        if(we) st <= st==WR ? RD : st+2'd1;
        if(st==LATCH) ram_din <= ram_dout;
        if( copy_en & ~lvbl & lvbl_l ) begin
            objcnt  <= 0;
            rd_addr <= 3'd2;
            wr_addr <= 3'd5;
            we      <= 1;
            st      <= RD;
        end
        if( we && st==WR ) begin
            if(~&wr_addr) begin
                rd_addr <= rd_addr+3'd1;
                wr_addr <= wr_addr+3'd1;
            end else begin
                rd_addr <= 3'd2;
                wr_addr <= 3'd5;
                objcnt  <= objcnt+1'd1;
                if(&objcnt) we <= 0;
            end
        end
    end
end

endmodule