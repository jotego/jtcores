/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 29-10-2026 */

module jtapach3_main(
    input             rst,
    input             clk,
    input             cen,
    input             vblank,
    input      [15:0] dsw,
    output reg [15:0] control,
    output     [14:0] host_addr,
    output            host_sel,
    output            host_rd,
    output            host_wr,
    output     [ 7:0] host_din,
    input      [ 7:0] host_dout,
    input             host_ok,
    output     [13:1] workram_addr,
    output     [15:0] workram_din,
    input      [15:0] workram_dout,
    output     [ 1:0] workram_we,
    output     [13:1] backup_addr,
    output     [15:0] backup_din,
    input      [15:0] backup_dout,
    output     [ 1:0] backup_we,
    output     [12:1] videoram_addr,
    output     [15:0] videoram_din,
    input      [15:0] videoram_dout,
    output     [ 1:0] videoram_we,
    output     [11:1] palette_addr,
    output     [15:0] palette_din,
    input      [15:0] palette_dout,
    output     [ 1:0] palette_we,
    output     [13:1] v30_shared_addr,
    output     [15:0] v30_shared_din,
    input      [15:0] v30_shared_dout,
    output     [ 1:0] v30_shared_we,
    output     [18:1] master_rom_addr,
    output            master_rom_cs,
    input      [15:0] master_rom_data,
    input             master_rom_ok,
    output     [18:1] v30_slave_rom_addr,
    output            v30_slave_rom_cs,
    input      [15:0] v30_slave_rom_data,
    input             v30_slave_rom_ok
);

reg [2:0] half_delay;
wire cenb = half_delay[2];
wire [19:0] cpu_addr, addr;
wire [15:0] raw_dout, cpu_dout;
reg  [15:0] cpu_din;
wire [2:0] bs;
wire [1:0] lane;
wire ube_n, rd, wr, inta, commit, addr_valid;
wire sub_ram = control[4:0] == 5'h18;
wire work_cs    = addr_valid && addr[19:14] == 6'h00;
wire nvram_cs   = addr_valid && addr[19:14] == 6'h01;
wire palette_cs = addr_valid && addr[19:12] == 8'h08;
wire text_cs    = addr_valid && addr[19:13] == 7'h06;
wire crtc_cs    = addr_valid && addr[19:2] == 18'h03a00;
wire dsw_cs     = addr_valid && addr[19:1] == 19'h07800;
wire control_cs = addr_valid && addr[19:1] == 19'h07c00;
wire sound_cs   = addr_valid && addr[19:16] == 4'h1;
wire sub_cs     = addr_valid && addr[19:16] == 4'h2;
wire main_cs    = addr_valid && addr[19];
wire ready = addr_valid && (!master_rom_cs || master_rom_ok)
          && (!v30_slave_rom_cs || v30_slave_rom_ok)
          && (!host_sel || host_ok);
wire write_commit = !rst && wr && commit;
reg [5:0] crtc_index;
reg [7:0] crtc [0:63];
integer i;

assign master_rom_addr    = addr[18:1];
assign master_rom_cs      = main_cs && rd;
assign v30_slave_rom_addr = {control[2:0],addr[15:1]};
assign v30_slave_rom_cs   = sub_cs && rd && !sub_ram;
assign workram_addr       = addr[13:1];
assign workram_din        = cpu_dout;
assign workram_we         = {2{write_commit && work_cs}} & lane;
assign backup_addr         = addr[13:1];
assign backup_din          = cpu_dout;
assign backup_we           = {2{write_commit && nvram_cs}} & lane;
assign videoram_addr      = addr[12:1];
assign videoram_din       = cpu_dout;
assign videoram_we        = {2{write_commit && text_cs}} & lane;
assign palette_addr       = addr[11:1];
assign palette_din        = cpu_dout;
assign palette_we         = {2{write_commit && palette_cs}} & lane;
assign v30_shared_addr    = addr[13:1];
assign v30_shared_din     = cpu_dout;
assign v30_shared_we      = {2{write_commit && sub_cs}} & lane;
assign host_addr          = addr[15:1];
assign host_din           = cpu_dout[7:0];
assign host_sel           = !rst && sound_cs;
assign host_rd            = !rst && sound_cs && rd;
assign host_wr            = !rst && sound_cs && wr && lane[0];

always @* begin
    cpu_din = 16'hffff;
    if (inta)            cpu_din = 16'h0032;
    else if (work_cs)    cpu_din = workram_dout;
    else if (nvram_cs)   cpu_din = backup_dout;
    else if (palette_cs) cpu_din = palette_dout;
    else if (text_cs)    cpu_din = videoram_dout;
    else if (dsw_cs)     cpu_din = dsw;
    else if (control_cs) cpu_din = control;
    else if (sound_cs)   cpu_din = {8'hff,host_dout};
    else if (sub_cs)     cpu_din = sub_ram ? v30_shared_dout
                                           : {v30_slave_rom_data[7:0],v30_slave_rom_data[15:8]};
    else if (main_cs)    cpu_din = master_rom_data;
end

always @(posedge clk) begin
    half_delay <= {half_delay[1:0],cen};
    if (rst) begin
        control <= 0;
        crtc_index <= 0;
        for (i=0;i<64;i=i+1) crtc[i] <= 0;
    end else if (write_commit) begin
        if (control_cs) begin
            if (lane[0]) control[7:0] <= cpu_dout[7:0];
            if (lane[1]) control[15:8] <= cpu_dout[15:8];
        end
        if (crtc_cs && lane[0]) begin
            if (!addr[1]) crtc_index <= cpu_dout[5:0];
            else crtc[crtc_index] <= cpu_dout[7:0];
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
    .dout      ( raw_dout ),
    .bs        ( bs       ),
    .qs        (          ),
    .rd_n      (          ),
    .wr_n      (          ),
    .ube_n     ( ube_n    ),
    .buslock_n (          )
);

jtapach3_v30bus u_bus (
    .rst        ( rst        ),
    .clk        ( clk        ),
    .cen        ( cen        ),
    .cenb       ( cenb       ),
    .ready      ( ready      ),
    .cpu_addr   ( cpu_addr   ),
    .cpu_dout   ( raw_dout   ),
    .bs         ( bs         ),
    .ube_n      ( ube_n      ),
    .addr       ( addr       ),
    .dout       ( cpu_dout   ),
    .lane       ( lane       ),
    .addr_valid ( addr_valid ),
    .mem_rd     ( rd         ),
    .mem_wr     ( wr         ),
    .inta       ( inta       ),
    .commit     ( commit     )
);

`ifdef SIMULATION
`ifdef APACH3_BOOT_TRACE
integer boot_events=0;
wire boot_instruction = cen && u_cpu.u_cpu.u_eu.q_pop && u_cpu.u_cpu.u_eu.q_ripe && u_cpu.u_cpu.u_eu.q_first;
always @(posedge clk) if (!rst && boot_instruction && boot_events<256) begin
    case (u_cpu.u_cpu.u_eu.pc)
        16'h007c,16'h0099,16'h00aa,16'h00bc,16'h00cc,16'hd370,
        16'hd59b,16'hd5cc,16'hd63d,16'hd66e,16'he340,16'he378,16'h81a2: begin
            $display("BOOT_MAIN t=%0t pc=%04x:%04x aw=%04x cw=%04x dw=%04x bw=%04x bp=%04x ix=%04x iy=%04x es=%04x",
                $time,u_cpu.u_cpu.u_eu.sreg[1],u_cpu.u_cpu.u_eu.pc,u_cpu.u_cpu.u_eu.gpr[0],
                u_cpu.u_cpu.u_eu.gpr[1],u_cpu.u_cpu.u_eu.gpr[2],u_cpu.u_cpu.u_eu.gpr[3],
                u_cpu.u_cpu.u_eu.gpr[5],u_cpu.u_cpu.u_eu.gpr[6],u_cpu.u_cpu.u_eu.gpr[7],u_cpu.u_cpu.u_eu.sreg[0]);
            boot_events <= boot_events+1;
            $fflush();
        end
        default:;
    endcase
end
`endif
`endif
endmodule
