/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 18-10-2026 */

module jtroundu_main(
    input rst,
    input clk,
    input cen,
    input vblank,
    input [15:0] dsw,
    output [15:0] control,
    output sub_irq_set,
    output [9:0] text_scroll_y,
    output road_enable,
    output [7:0] road_top,
    output [15:0] bg_back_x,
    output [15:0] bg_scroll_x,
    output [15:0] bg_scroll_y,
    output [15:0] audio_addr,
    output audio_sel,
    output audio_rd,
    output audio_wr,
    output [7:0] audio_din,
    input [7:0] audio_dout,
    input audio_ok,
    output [14:1] workram_addr,
    output [15:0] workram_din,
    input [15:0] workram_dout,
    output [1:0] workram_we,
    output [13:1] videoram_addr,
    output [15:0] videoram_din,
    input [15:0] videoram_dout,
    output [1:0] videoram_we,
    output [13:1] v30_shared_addr,
    output [15:0] v30_shared_din,
    input [15:0] v30_shared_dout,
    output [1:0] v30_shared_we,
    output [10:1] palette_addr,
    output [15:0] palette_din,
    input [15:0] palette_dout,
    output [1:0] palette_we,
    output [16:0] tx_gfxram_addr,
    output [7:0] tx_gfxram_din,
    input [7:0] tx_gfxram_dout,
    output tx_gfxram_we,
    output [16:0] bg_gfxram_addr,
    output [7:0] bg_gfxram_din,
    input [7:0] bg_gfxram_dout,
    output bg_gfxram_we,
    output [18:1] master_rom_addr,
    output master_rom_cs,
    input [15:0] master_rom_data,
    input master_rom_ok,
    output [18:1] v30_slave_rom_addr,
    output v30_slave_rom_cs,
    input [15:0] v30_slave_rom_data,
    input v30_slave_rom_ok
);

reg [2:0] half_delay=0;
wire cenb = half_delay[2];
wire [19:0] cpu_addr, addr;
wire [15:0] cpu_dout;
reg  [15:0] cpu_din;
wire [2:0] bs;
wire [1:0] lane;
wire ube_n, rd, wr, inta, commit, addr_valid;
wire [12:0] cs;
reg [15:0] control_reg;
reg [15:0] vregs [0:7];
reg [15:0] scroll_x, scroll_y;
reg [5:0] crtc_index;
reg [7:0] crtc [0:63];
wire [15:0] control_next = (control_reg & ~{{8{lane[1]}},{8{lane[0]}}})
                         | (cpu_dout & {{8{lane[1]}},{8{lane[0]}}});
wire sub_ram = control_reg[4:0] == 5'h18;
wire ready = addr_valid && (!master_rom_cs || master_rom_ok)
          && (!v30_slave_rom_cs || v30_slave_rom_ok)
          && (!cs[9] || audio_ok);
wire write_commit = wr && commit;

assign control = control_reg;
assign road_enable = vregs[1][0];
assign road_top = vregs[5][15:8];
assign bg_back_x = vregs[6];
assign bg_scroll_x = scroll_x;
assign bg_scroll_y = scroll_y;
assign sub_irq_set = write_commit && cs[7] && !control_reg[3] && !control_next[3];
assign text_scroll_y = {crtc[12][5:0],crtc[13][7:4]} | {2'b0,crtc[29]};
assign master_rom_addr = addr[18:1];
assign master_rom_cs = cs[12];
assign v30_slave_rom_addr = {control_reg[2:0],addr[15:1]};
assign v30_slave_rom_cs = cs[10] && rd && !sub_ram;
assign workram_addr = addr[14:1];
assign workram_din = cpu_dout;
assign workram_we = {2{write_commit && cs[0]}} & lane;
assign videoram_addr = addr[13:1];
assign videoram_din = cpu_dout;
assign videoram_we = {2{write_commit && cs[1]}} & lane;
assign v30_shared_addr = addr[13:1];
assign v30_shared_din = cpu_dout;
assign v30_shared_we = {2{write_commit && cs[10]}} & lane;
assign palette_addr = addr[11:2];
assign palette_din = {2{cpu_dout[7:0]}};
assign palette_we = {2{write_commit && cs[8] && lane[0]}} & (addr[1] ? 2'b01 : 2'b10);
assign tx_gfxram_addr = {control_reg[11:10],addr[15:1]};
assign bg_gfxram_addr = {control_reg[14:13],addr[15:1]};
assign tx_gfxram_din = cpu_dout[7:0];
assign bg_gfxram_din = cpu_dout[7:0];
assign tx_gfxram_we = write_commit && cs[11] && lane[0] && !control_reg[9];
assign bg_gfxram_we = write_commit && cs[11] && lane[0] && control_reg[9];
assign audio_addr = {control_reg[5],addr[15:1]};
assign audio_din = cpu_dout[7:0];
assign audio_sel = cs[9];
assign audio_rd = cs[9] && rd;
assign audio_wr = cs[9] && write_commit && lane[0];

always @* begin
    cpu_din = 16'hffff;
    if (inta) cpu_din = 16'h0032;
    else if (cs[0]) cpu_din = workram_dout;
    else if (cs[1]) cpu_din = videoram_dout;
    else if (cs[3]) cpu_din = dsw;
    else if (cs[4]) cpu_din = vregs[addr[3:1]];
    else if (cs[8]) cpu_din = {8'hff,addr[1] ? palette_dout[7:0] : palette_dout[15:8]};
    else if (cs[9]) cpu_din = {8'hff,audio_dout};
    else if (cs[10]) cpu_din = sub_ram ? v30_shared_dout
                                     : {v30_slave_rom_data[7:0],v30_slave_rom_data[15:8]};
    else if (cs[11]) cpu_din = {8'hff,control_reg[9] ? bg_gfxram_dout : tx_gfxram_dout};
    else if (cs[12]) cpu_din = master_rom_data;
end

always @(posedge clk) half_delay <= {half_delay[1:0],cen};

always @(posedge clk) begin
    if (rst) begin
        control_reg <= 0;
        crtc_index <= 0;
        scroll_x <= 0;
        scroll_y <= 0;
        for (integer i=0;i<64;i=i+1) crtc[i] <= 0;
        for (integer i=0;i<8;i=i+1) vregs[i] <= 0;
    end else begin
        if (write_commit) begin
            if (cs[2] && lane[0]) begin
                if (!addr[1]) crtc_index <= cpu_dout[5:0];
                else crtc[crtc_index] <= cpu_dout[7:0];
            end
            if (cs[7]) control_reg <= control_next;
            if (lane[0]) begin
                if (cs[4]) vregs[addr[3:1]][7:0] <= cpu_dout[7:0];
                if (cs[5]) scroll_x[7:0] <= cpu_dout[7:0];
                if (cs[6]) scroll_y[7:0] <= cpu_dout[7:0];
            end
            if (lane[1]) begin
                if (cs[4]) vregs[addr[3:1]][15:8] <= cpu_dout[15:8];
                if (cs[5]) scroll_x[15:8] <= cpu_dout[15:8];
                if (cs[6]) scroll_y[15:8] <= cpu_dout[15:8];
            end
        end
    end
end

jtframe_v30 u_cpu (
    .rst       ( rst      ),
    .clk       ( clk      ),
    .cen       ( cen      ),
    .cenb      ( cenb     ),
    .ready     ( ready    ),
    .int_n     ( ~vblank  ),
    .nmi_n     ( 1'b1     ),
    .poll_n    ( 1'b1     ),
    .A         ( cpu_addr ),
    .din       ( cpu_din  ),
    .dout      ( cpu_dout ),
    .bs        ( bs       ),
    .qs        (          ),
    .rd_n      (          ),
    .ube_n     ( ube_n    ),
    .buslock_n (          )
);

jtroundu_v30bus u_bus (
    .rst        ( rst        ),
    .clk        ( clk        ),
    .cen        ( cen        ),
    .cenb       ( cenb       ),
    .ready      ( ready      ),
    .cpu_addr   ( cpu_addr   ),
    .bs         ( bs         ),
    .ube_n      ( ube_n      ),
    .addr       ( addr       ),
    .lane       ( lane       ),
    .addr_valid ( addr_valid ),
    .mem_rd     ( rd         ),
    .mem_wr     ( wr         ),
    .inta       ( inta       ),
    .commit     ( commit     )
);

jtroundu_decode u_decode (
    .addr ( addr ),
    .rd   ( rd   ),
    .wr   ( wr   ),
    .cs   ( cs   )
);

`ifdef ROUNDU_TRACE
integer trace_writes=0, trace_reads=0, trace_resets=0;
always @(posedge clk) begin
    if (!rst && commit) begin
        if (trace_reads < 120) begin
            $display("BUS %0d addr=%h rd=%b wr=%b lane=%b in=%h out=%h pc=%04x",trace_reads,addr,rd,wr,lane,cpu_din,cpu_dout,u_cpu.u_cpu.u_eu.pc);
            trace_reads <= trace_reads+1;
        end
        if (addr == 20'hffff0 && u_bus.cycle_type == 4 && trace_resets < 3) begin
            $display("V30 reset fetch %h",cpu_din);
            trace_resets <= trace_resets+1;
        end
        if (wr && addr >= 20'h05152 && addr <= 20'h0515b)
            $display("CREDIT addr=%05x lane=%b data=%04x pc=%04x",addr,lane,cpu_dout,u_cpu.u_cpu.u_eu.pc);
        if (cs[7] && wr && trace_writes < 100) begin
            $display("V30 control %h",control_next);
            trace_writes <= trace_writes+1;
        end
    end
end
`endif

endmodule
