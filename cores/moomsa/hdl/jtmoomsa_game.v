/* SPDX-License-Identifier: GPL-3.0-or-later */

`timescale 1ns/1ps

/* verilator lint_off UNUSEDSIGNAL */
module jtmoomsa_game(
    `include "jtframe_game_ports.inc"
);

wire [7:0] video_st;
wire [7:0] video_tilesys_dout;
wire [15:0] video_objsys_dout, video_pal_dout, main_cpu_din, cabinet_din;
wire [7:0] sound_pair_dout;
wire [7:0] cr_dout;
wire [23:1] main_cpu_addr;
wire [15:0] main_cpu_dout;
wire [1:0] main_cpu_dsn;
wire main_cpu_we, main_bus_active, main_cpu_as_n;
wire [2:0] main_cpu_ipl_n;
wire video_vdtac;
wire cr_dout_valid, cr_int1, cr_int2, cr_fcnt, cr_cres_n;
wire cr_n_hsy, cr_n_hbk, cr_n_vsy, cr_n_vbk, cr_n_hld, cr_n_vld;
wire [9:0] cr_h_count;
wire [8:0] cr_v_count, cr_vrender, cr_vrender1, cr_vreload;
wire [8:0] cr_hdump = cr_h_count[8:0] - 9'd40;

function [8:0] active_vcoord(input [8:0] raw, input [8:0] vmax);
    reg [10:0] tmp;
    begin
        tmp = {2'b0,raw};
        if (tmp < 11'd16)
            tmp = tmp + {2'b0,vmax} + 11'd1;
        tmp = tmp - 11'd16;
        active_vcoord = tmp[8:0];
    end
endfunction

// The K053246 scanner restarts on every HS inside 0x10E..0x1F7 of the JTFRAME
// line numbering, where the first active line is 0x110.  Moo's CRTC counts
// active lines from zero, so that window is unreachable without this rebase.
function [8:0] obj_vcoord(input [8:0] rel, input [8:0] vmax);
    reg [10:0] tmp;
    begin
        tmp = {2'b0,rel} + 11'h110;
        if (tmp > 11'h1ff)
            tmp = tmp - ({2'b0,vmax} + 11'd1);
        obj_vcoord = tmp[8:0];
    end
endfunction

wire [8:0] cr_vdump = active_vcoord(cr_v_count, cr_vreload);
wire [8:0] cr_vrender_rel = active_vcoord(cr_vrender, cr_vreload);
wire [8:0] cr_vrender1_rel = active_vcoord(cr_vrender1, cr_vreload);
wire [8:0] cr_vdump_obj = obj_vcoord(cr_vdump, cr_vreload);
wire irq_n, irq_dma_n;
wire [15:0] control2_dout;
wire control2_irq5_en, control2_irq4_en, control2_objcha_n;
wire control2_cs = main_bus_active && (main_cpu_addr == 23'h06f000);
wire video_objdma_n;
wire [13:1] video_oram_addr;
wire [1:0] video_oram_we, video_oram_we_raw;
wire video_objsys_cs, video_objreg_cs, video_objcha_n;
wire video_tilesys_cs, video_pal_cs, video_pcu_cs, video_rmrd;
wire [31:0] lyrf_data_lanes, lyra_data_lanes, lyrb_data_lanes;
wire [19:0] lyrf_t8_addr, lyrf_t10_addr;
wire [19:0] lyra_t8_addr, lyra_t10_addr;
wire [19:0] lyrb_t8_addr, lyrb_t10_addr;
wire [7:0] video_red, video_green, video_blue;
wire m6_rom, m6_reg, m6_cr, m6_regcs, m6_pcu, m6_objcs, m6_objreg;
wire g7_cc0, g7_col, g7_sdon, g7_pair, g7_bnk_scr;
wire g7_io, g7_iocsb, g7_reg_write;
wire main_rom_cs, palette_cs_raw, palette_cs, work_cs, objram_cs;
wire [15:0] k338_dout, palette_cpu_dout, k053990_dout, k053246_reg_dout;
wire [23:0] palette_rgb;
wire [10:0] palette_addr;
wire [15:0] k056_cpu_dout, k056_rom_dout;
wire k056_cpu_dout_valid, k056_rom_ok, k056_rom_busy;
wire k056_reg_cs, k056_b_cs, k056_vram_cs, k056_rom_cs, k056_any_cs;
wire k056_mem_read_cs = k056_any_cs && !main_cpu_we;
wire k056_cpu_wait_cs = k056_rom_cs || k056_mem_read_cs;
wire k056_cpu_wait_busy = k056_rom_busy ||
                          (k056_mem_read_cs && !k056_cpu_dout_valid);
wire [4:0] k056_reg_addr;
wire [1:0] k056_b_addr;
wire [13:1] k056_vram_addr;
wire [12:1] k056_rom_addr;
wire [15:0] objram_cpu_dout;
wire        objram_cpu_dout_valid;
wire [15:1] work_cpu_addr;
wire [15:0] work_cpu_din, work_cpu_dout;
wire [1:0]  work_cpu_we;
wire [15:0] work_prot_din;
wire [15:1] prot_work_addr;
wire [15:0] prot_work_dout;
wire [1:0]  prot_work_we;
wire        prot_work_req, prot_busy, prot_error;
wire        prot_obj_req;
wire [15:1] prot_obj_addr;
wire [12:0] prot_obj_phys_addr;
wire [15:0] prot_obj_din;
wire        prot_pal_req;
wire [12:1] prot_pal_addr;
wire [15:0] prot_pal_din;
// The CRTC runs at 32 MHz from the 48 MHz root clock.  jtframe_gated_cen
// emits divided single-cycle pulses and cannot represent this >1/2 ratio.
reg  [1:0] crtc_cen_phase;
reg        crtc_cen_32;
always @(posedge clk) begin
    if (rst) begin
        crtc_cen_phase <= 2'd0;
        crtc_cen_32   <= 1'b0;
    end else if (crtc_cen_phase >= 2'd1) begin
        crtc_cen_phase <= crtc_cen_phase - 2'd1;
        crtc_cen_32   <= 1'b1;
    end else begin
        crtc_cen_phase <= crtc_cen_phase + 2'd2;
        crtc_cen_32   <= 1'b0;
    end
end
wire        p6_pale_n, p6_oram_we_n, p6_pre_dtack_n, p6_lyr_prio_n;
wire        p6_vpa_n, p6_palette_cs;
wire [1:0]  p6_objram_we;
reg         work_read_done;
wire        work_read_busy = work_cs && main_bus_active && !main_cpu_we &&
                              !work_read_done;
wire        object_rom_cpu_cs = video_objsys_cs && !main_cpu_we && !control2_objcha_n;
wire        object_rom_cpu_busy = object_rom_cpu_cs && !lyro_ok;
wire [12:0] objram_phys_addr;
wire [12:0] objram_dma_phys_addr;
wire [13:1] object_dma_addr;
wire [15:0] object_dma_data, object_objsys_dout;
wire        object_dma_bsy;
wire [4:0]  objram_ea_cpu, objram_ea_prot;
wire        objram_g5p11_cpu, objram_g5p11_prot;
wire        objram_g5p13_cpu, objram_g5p13_prot;
wire [7:0]  objram_en_cpu, objram_en_prot;
wire [7:0]  object_cfg;
wire [9:0]  object_xoffset, object_yoffset;
wire [22:1] object_rmrd_addr;
wire [8:0]  object_pxl;
wire [4:0]  object_prio;
wire [1:0]  object_shd;
wire        objram_cpu_cs = objram_cs && main_bus_active &&
                            (!main_cpu_dsn[1] || !main_cpu_dsn[0]);
wire        objram_read_busy = objram_cpu_cs && !main_cpu_we &&
                               !objram_cpu_dout_valid;
wire [10:0] color_cout, color_palette_addr;
wire        color_brit, color_n, color_blank;
wire [1:0]  color_shadow, color_mix_code, color_shadow_code, color_bright_code;
wire [23:0] k338_rgb;
wire [7:0]  k338_brightness;
wire        k338_pixel_valid;
wire        k338_dout_valid;
wire crkb, k051550_clk;
wire srst_n = ~rst;
wire pair_read = g7_pair && !main_cpu_dsn[0] && !main_cpu_we;
wire [15:0] pair_din;
wire eeprom_do, eeprom_rdy, k51550_si, irq_set;
wire [7:0] p1 = {cab_1p[0],joystick1[6:4],joystick1[3:0]};
wire [7:0] p2 = {cab_1p[1],joystick2[6:4],joystick2[3:0]};
wire [7:0] p3 = {cab_1p[2],joystick3[6:4],joystick3[3:0]};
wire [7:0] p4 = {cab_1p[3],joystick4[6:4],joystick4[3:0]};

wire irq5_active = control2_irq5_en && !cr_n_vbk;
assign irq_n = (!control2_irq4_en || irq_dma_n) && !irq5_active;

assign video_objsys_dout = object_objsys_dout;
assign video_objdma_n = ~object_dma_bsy;

assign dip_flip = 1'b0;
`ifdef MOO_INPUT_BUS_TRACE
reg        moo_input_bus_active;
reg [10:0] moo_input_bus_count;
reg [31:0] moo_input_bus_frame;
reg        moo_input_bus_prev_lvbl;
always @(posedge clk) begin
    if (rst) begin
        moo_input_bus_active   <= 1'b0;
        moo_input_bus_count    <= 11'd0;
        moo_input_bus_frame    <= 32'd0;
        moo_input_bus_prev_lvbl <= LVBL;
    end else begin
        if (moo_input_bus_prev_lvbl && !LVBL) begin
            $display("MOO-FRAME frame=%0d", moo_input_bus_frame);
            moo_input_bus_frame <= moo_input_bus_frame + 1'b1;
        end
        moo_input_bus_prev_lvbl <= LVBL;
        if (main_bus_active) begin
            if (!moo_input_bus_active && moo_input_bus_count != 11'h7ff &&
                ({main_cpu_addr,1'b0} == 24'h0da000 ||
                 {main_cpu_addr,1'b0} == 24'h0dc000 ||
                 {main_cpu_addr,1'b0} == 24'h0d4000)) begin
                if (main_cpu_we)
                    $display("MOO-WRITE frame=%0d addr=%06x dsn=%b dout=%04x g7=%02x m6=%02x",
                             moo_input_bus_frame, {main_cpu_addr,1'b0}, main_cpu_dsn, main_cpu_dout,
                             {g7_iocsb,g7_io,g7_pair,g7_sdon,g7_col,g7_cc0},
                             {m6_objreg,m6_pcu,m6_regcs,m6_cr,m6_reg,m6_rom});
                else
                    $display("MOO-READ frame=%0d addr=%06x dsn=%b din=%04x g7=%02x m6=%02x p1=%02x p2=%02x",
                             moo_input_bus_frame, {main_cpu_addr,1'b0}, main_cpu_dsn, main_cpu_din,
                             {g7_iocsb,g7_io,g7_pair,g7_sdon,g7_col,g7_cc0},
                             {m6_objreg,m6_pcu,m6_regcs,m6_cr,m6_reg,m6_rom}, p1, p2);
                moo_input_bus_count <= moo_input_bus_count + 1'b1;
            end
            moo_input_bus_active <= 1'b1;
        end else begin
            moo_input_bus_active <= 1'b0;
        end
    end
end
`endif
`ifdef MOO_PALETTE_TRACE
reg [10:0] moo_palette_trace_count;
reg [7:0]  moo_palette_watch_count;
reg [31:0] moo_palette_trace_frame;
reg        moo_palette_trace_prev_lvbl;
wire [31:0] moo_palette_trace_pc = u_main.u_cpu.u_cpu.PC;
wire [23:0] moo_palette_trace_cpu_byte_addr = {main_cpu_addr,1'b0};
wire        moo_palette_trace_reg_access = main_bus_active &&
                                           (moo_palette_trace_cpu_byte_addr >= 24'h1c0000) &&
                                           (moo_palette_trace_cpu_byte_addr <= 24'h1c1fff);
wire        moo_palette_trace_accept = moo_palette_trace_reg_access &&
                                       u_main.cpu_cenb && !u_main.DTACKn;
always @(posedge clk) begin
    if (rst) begin
        moo_palette_trace_count     <= 11'd0;
        moo_palette_watch_count     <= 8'd0;
        moo_palette_trace_frame     <= 32'd0;
        moo_palette_trace_prev_lvbl <= LVBL;
    end else begin
        if (moo_palette_trace_prev_lvbl && !LVBL)
            moo_palette_trace_frame <= moo_palette_trace_frame + 1'b1;
        moo_palette_trace_prev_lvbl <= LVBL;

        if (moo_palette_trace_reg_access && moo_palette_watch_count != 8'hff) begin
            $display("MOO-PAL-WATCH frame=%0d pc=%08x addr=%06x we=%b dsn=%b bus_cs=%b bus_busy=%b wait2=%b dtack_n=%b cen=%b cenb=%b as_n=%b ds_n=%b",
                     moo_palette_trace_frame, moo_palette_trace_pc,
                     moo_palette_trace_cpu_byte_addr, main_cpu_we, main_cpu_dsn,
                     u_main.bus_cs, u_main.bus_busy, u_main.wait2_cs,
                     u_main.DTACKn, u_main.cpu_cen, u_main.cpu_cenb,
                     u_main.ASn, {u_main.UDSn,u_main.LDSn});
            moo_palette_watch_count <= moo_palette_watch_count + 1'b1;
        end

        if (moo_palette_trace_accept && moo_palette_trace_count != 11'h7ff) begin
            $display("MOO-PAL-COMPLETE frame=%0d pc=%08x addr=%06x we=%b dsn=%b dout=%04x raw=%b ramcs=%b cs=%b dtack_n=%b cenb=%b",
                     moo_palette_trace_frame, moo_palette_trace_pc,
                     moo_palette_trace_cpu_byte_addr, main_cpu_we, main_cpu_dsn,
                     main_cpu_dout, palette_cs_raw, p6_palette_cs, palette_cs,
                     u_main.DTACKn, u_main.cpu_cenb);
            moo_palette_trace_count <= moo_palette_trace_count + 1'b1;
        end
    end
end
`endif
`ifdef MOO_PROTECTION_TRACE
reg        moo_prot_trace_active;
reg [10:0] moo_prot_trace_count;
reg [31:0] moo_prot_trace_frame;
reg        moo_prot_trace_prev_lvbl;
reg        moo_prot_trace_prev_busy;
reg        moo_prot_trace_prev_req;
wire [23:0] moo_prot_trace_cpu_byte_addr = {main_cpu_addr,1'b0};
wire [31:0] moo_prot_trace_pc = u_main.u_cpu.u_cpu.PC;
wire        moo_prot_trace_reg_access = main_bus_active &&
                                         (moo_prot_trace_cpu_byte_addr >= 24'h0ce000) &&
                                         (moo_prot_trace_cpu_byte_addr <= 24'h0ce01f);
always @(posedge clk) begin
    if (rst) begin
        moo_prot_trace_active    <= 1'b0;
        moo_prot_trace_count     <= 11'd0;
        moo_prot_trace_frame     <= 32'd0;
        moo_prot_trace_prev_lvbl <= LVBL;
        moo_prot_trace_prev_busy <= 1'b0;
        moo_prot_trace_prev_req  <= 1'b0;
    end else begin
        if (moo_prot_trace_prev_lvbl && !LVBL)
            moo_prot_trace_frame <= moo_prot_trace_frame + 1'b1;
        moo_prot_trace_prev_lvbl <= LVBL;

        if ((prot_busy != moo_prot_trace_prev_busy) ||
            (prot_work_req != moo_prot_trace_prev_req)) begin
            $display("MOO-PROT-STATE frame=%0d pc=%08x busy=%0d req=%0d work_addr=%06x work_we=%b work_dout=%04x work_din=%04x obj_req=%0d obj_addr=%06x",
                     moo_prot_trace_frame, moo_prot_trace_pc, prot_busy, prot_work_req,
                     {8'h18,prot_work_addr,1'b0}, prot_work_we, prot_work_dout,
                     work_prot_din, prot_obj_req, {8'h1c,prot_obj_addr,1'b0});
        end
        moo_prot_trace_prev_busy <= prot_busy;
        moo_prot_trace_prev_req  <= prot_work_req;

        if (main_bus_active) begin
            if (!moo_prot_trace_active && moo_prot_trace_count != 11'h7ff &&
                moo_prot_trace_reg_access) begin
                if (main_cpu_we)
                    $display("MOO-PROT-WR frame=%0d pc=%08x addr=%06x dsn=%b dout=%04x",
                             moo_prot_trace_frame, moo_prot_trace_pc, moo_prot_trace_cpu_byte_addr,
                             main_cpu_dsn, main_cpu_dout);
                else
                    $display("MOO-PROT-RD frame=%0d pc=%08x addr=%06x dsn=%b din=%04x busy=%0d",
                             moo_prot_trace_frame, moo_prot_trace_pc, moo_prot_trace_cpu_byte_addr,
                             main_cpu_dsn, main_cpu_din, prot_busy);
                moo_prot_trace_count <= moo_prot_trace_count + 1'b1;
            end
            moo_prot_trace_active <= 1'b1;
        end else begin
            moo_prot_trace_active <= 1'b0;
        end
    end
end
`endif
`ifdef MOO_RAM_TRACE
reg        moo_ram_test_active;
reg        moo_ram_read_seen;
reg [31:0] moo_ram_read_count;
reg [31:0] moo_ram_write_count;
reg [31:0] moo_ram_mismatch_count;
reg [15:0] moo_ram_expected [0:32767];
always @(posedge clk) begin
    if (rst) begin
        moo_ram_test_active    <= 1'b0;
        moo_ram_read_seen      <= 1'b0;
        moo_ram_read_count     <= 32'd0;
        moo_ram_write_count    <= 32'd0;
        moo_ram_mismatch_count <= 32'd0;
    end else begin
        if (!main_bus_active || !work_cs)
            moo_ram_read_seen <= 1'b0;

        if (!moo_ram_test_active && main_bus_active && work_cs && main_cpu_we &&
            work_cpu_we == 2'b11 && work_cpu_addr == 15'h0000 &&
            main_cpu_dout == 16'h0000) begin
            moo_ram_test_active <= 1'b1;
            moo_ram_expected[15'h0000] <= 16'h0000;
            $display("MOO-RAM-ARM addr=%06x", {main_cpu_addr,1'b0});
        end

        if (moo_ram_test_active && main_bus_active && work_cs && main_cpu_we &&
            work_cpu_we != 2'b00) begin
            if (work_cpu_we[0])
                moo_ram_expected[work_cpu_addr][7:0] <= main_cpu_dout[7:0];
            if (work_cpu_we[1])
                moo_ram_expected[work_cpu_addr][15:8] <= main_cpu_dout[15:8];
            moo_ram_write_count <= moo_ram_write_count + 1'b1;
        end

        if (moo_ram_test_active && main_bus_active && work_cs && !main_cpu_we &&
            work_read_done && !moo_ram_read_seen) begin
            moo_ram_read_count <= moo_ram_read_count + 1'b1;
            if (work_cpu_dout !== moo_ram_expected[work_cpu_addr]) begin
                moo_ram_mismatch_count <= moo_ram_mismatch_count + 1'b1;
                $display("MOO-RAM-MISMATCH addr=%06x work_addr=%04x dsn=%b actual=%04x expected=%04x din=%04x rdone=%b",
                         {main_cpu_addr,1'b0}, work_cpu_addr, main_cpu_dsn,
                         work_cpu_dout, moo_ram_expected[work_cpu_addr],
                         main_cpu_din, work_read_done);
            end
            moo_ram_read_seen <= 1'b1;
        end
    end
end
`endif
`ifdef MOO_BUS_TRACE
reg [9:0] moo_bus_trace_count;
reg       moo_bus_trace_valid;
reg [22:0] moo_bus_trace_addr;
reg [15:0] moo_bus_trace_data;
reg [1:0]  moo_bus_trace_dsn;
always @(posedge clk) begin
    if (rst) begin
        moo_bus_trace_count <= 10'd0;
        moo_bus_trace_valid <= 1'b0;
    end else if (main_bus_active && main_cpu_we && (main_cpu_dsn != 2'b11) &&
                 (main_cpu_addr < 23'h070000) && moo_bus_trace_count != 10'h3ff) begin
        if (!moo_bus_trace_valid || moo_bus_trace_addr != main_cpu_addr ||
            moo_bus_trace_data != main_cpu_dout || moo_bus_trace_dsn != main_cpu_dsn) begin
            $display("MOO-BUS addr=%06x data=%04x dsn=%b", main_cpu_addr,
                     main_cpu_dout, main_cpu_dsn);
            moo_bus_trace_count <= moo_bus_trace_count + 1'b1;
        end
        moo_bus_trace_valid <= 1'b1;
        moo_bus_trace_addr <= main_cpu_addr;
        moo_bus_trace_data <= main_cpu_dout;
        moo_bus_trace_dsn <= main_cpu_dsn;
    end else begin
        moo_bus_trace_valid <= 1'b0;
    end
end
`endif
`ifdef MOO_VRAM_TRACE
reg        moo_vram_trace_active;
reg [10:0] moo_vram_trace_count;
reg [23:1] moo_vram_trace_addr;
reg [1:0]  moo_vram_trace_dsn;
wire [31:0] moo_vram_trace_pc = u_main.u_cpu.u_cpu.PC;
wire [23:0] moo_vram_trace_byte_addr = {main_cpu_addr,1'b0};
always @(posedge clk) begin
    if (rst) begin
        moo_vram_trace_active <= 1'b0;
        moo_vram_trace_count  <= 11'd0;
        moo_vram_trace_addr   <= 23'd0;
        moo_vram_trace_dsn    <= 2'b11;
    end else if (main_bus_active && k056_vram_cs && !main_cpu_we) begin
        if (moo_vram_trace_count != 11'd256) begin
            $display("MOO-VRAM-RD frame=%0d v=%0d pc=%08x addr=%06x kaddr=%04x a1=%b dsn=%b din=%04x kdin=%04x valid=%b dtack_n=%b cenb=%b",
                     cr_fcnt, cr_v_count, moo_vram_trace_pc,
                     moo_vram_trace_byte_addr, k056_vram_addr,
                     k056_vram_addr[1], main_cpu_dsn, main_cpu_din,
                     k056_cpu_dout, k056_cpu_dout_valid,
                     u_main.DTACKn, u_main.cpu_cenb);
            moo_vram_trace_count <= moo_vram_trace_count + 1'b1;
        end
        moo_vram_trace_active <= 1'b1;
        moo_vram_trace_addr   <= main_cpu_addr;
        moo_vram_trace_dsn    <= main_cpu_dsn;
    end else begin
        moo_vram_trace_active <= 1'b0;
    end
end
`endif
`ifdef MOO_STATUS_TRACE
reg        moo_status_trace_active;
reg [23:1] moo_status_trace_addr;
reg        moo_status_trace_we;
reg [1:0]  moo_status_trace_dsn;
wire [31:0] moo_status_trace_pc = u_main.u_cpu.u_cpu.PC;
wire [23:0] moo_status_trace_byte_addr = {main_cpu_addr,1'b0};
wire        moo_status_trace_window = main_bus_active &&
                                      (moo_status_trace_byte_addr >= 24'h0d6000) &&
                                      (moo_status_trace_byte_addr <= 24'h0d601f);
always @(posedge clk) begin
    if (rst) begin
        moo_status_trace_active <= 1'b0;
        moo_status_trace_addr   <= 23'd0;
        moo_status_trace_we     <= 1'b0;
        moo_status_trace_dsn    <= 2'b11;
    end else if (moo_status_trace_window) begin
        if (!moo_status_trace_active ||
            moo_status_trace_addr != main_cpu_addr ||
            moo_status_trace_we != main_cpu_we ||
            moo_status_trace_dsn != main_cpu_dsn) begin
            $display("MOO-STATUS pc=%08x addr=%06x we=%b dsn=%b din=%04x pair=%b pair_din=%04x pair_byte=%02x m6_regcs=%b k338=%04x g7_sdon=%b g7_pair=%b latch2=%02x",
                     moo_status_trace_pc, moo_status_trace_byte_addr,
                     main_cpu_we, main_cpu_dsn, main_cpu_din,
                     pair_read, pair_din, sound_pair_dout, m6_regcs, k338_dout,
                     g7_sdon, g7_pair, u_sound.u_054321.snd_latch[2]);
            moo_status_trace_addr <= main_cpu_addr;
            moo_status_trace_we   <= main_cpu_we;
            moo_status_trace_dsn  <= main_cpu_dsn;
        end
        moo_status_trace_active <= 1'b1;
    end else begin
        moo_status_trace_active <= 1'b0;
    end
end
`endif
`ifdef MOO_CTRL2_TRACE
assign debug_view = {
    control2_cs && main_cpu_we && (main_cpu_dsn != 2'b11),
    main_cpu_dout[6:0]
};
`elsif MOO_PALETTE_TRACE
assign debug_view = {
    palette_cs && main_cpu_we &&  main_cpu_addr[1] && !main_cpu_dsn[0],
    palette_cs && main_cpu_we &&  main_cpu_addr[1] && !main_cpu_dsn[1],
    palette_cs && main_cpu_we && !main_cpu_addr[1] && !main_cpu_dsn[0],
    palette_cs && main_cpu_we && (main_cpu_dout[7:0]  != 8'h00),
    palette_cs && main_cpu_we && (main_cpu_dout[15:8] != 8'h00),
    palette_cs && main_cpu_we,
    palette_cs,
    palette_cs_raw
};
`else
assign debug_view = 8'h00;
`endif

assign main_cpu_din = k056_rom_cs ? k056_rom_dout :
                      k056_any_cs ? k056_cpu_dout :
                      m6_regcs ? k338_dout :
                      m6_reg ? k053246_reg_dout :
                      m6_objreg ? k053990_dout :
                      control2_cs ? control2_dout :
                      objram_cs ? objram_cpu_dout :
                      palette_cs ? palette_cpu_dout :
                      work_cs ? work_cpu_dout :
                      main_cs ? main_data :
                      g7_cc0 ? {8'hff,cr_dout} :
                      video_objsys_cs ? video_objsys_dout :
                      video_tilesys_cs ? {2{video_tilesys_dout}} :
                      video_pal_cs ? video_pal_dout :
                      pair_read ? pair_din :
                      (g7_io || g7_iocsb) ? cabinet_din : 16'hffff;

jtmoomsa_main u_main(
    .clk(clk), .rst(rst),
    .main_rom_cs(main_rom_cs),
    .rom_addr(main_addr), .rom_cs(main_cs), .rom_ok(main_ok),
    .cpu_din(main_cpu_din),
    .dev_cs(palette_cs || work_cs || objram_cs || g7_cc0 || g7_io || g7_iocsb ||
            g7_pair || g7_sdon || m6_cr || m6_objcs || m6_reg || m6_regcs ||
            m6_pcu || m6_objreg || k056_any_cs),
    .dev_bus_cs(k056_cpu_wait_cs || objram_cpu_cs || object_rom_cpu_cs || work_cs || palette_cs),
    .dev_busy(k056_cpu_wait_busy || objram_read_busy || object_rom_cpu_busy ||
              work_read_busy || (prot_busy && (work_cs || objram_cpu_cs || palette_cs))),
    .ipl_n(main_cpu_ipl_n),
    .vpa_n(p6_vpa_n),
    .cpu_addr(main_cpu_addr), .cpu_dout(main_cpu_dout), .cpu_dsn(main_cpu_dsn),
    .cpu_we(main_cpu_we), .bus_active(main_bus_active), .cpu_as_n(main_cpu_as_n)
);

jtmoomsa_control2 u_control2(
    .clk(clk), .rst(rst), .cpu_cs(control2_cs), .cpu_wr(main_cpu_we),
    .cpu_dsn(main_cpu_dsn), .cpu_din(main_cpu_dout), .cpu_dout(control2_dout),
    .irq5_en(control2_irq5_en), .irq4_en(control2_irq4_en),
    .objcha_n(control2_objcha_n)
);

jtmoomsa_irq u_irq(
    .enable_n(1'b0),
    .ipl0_n(1'b1),
    // Q3 I4 is the active-low K053252 INT1 input; cr_int1 is active high.
    .int1_n(~cr_int1),
    .irq_n(irq_n),
    .ipl_n(main_cpu_ipl_n)
);

jtmoomsa_irq_latch u_irq_latch(
    .clk(clk), .rst(rst), .objdma_n(video_objdma_n), .irq_set(irq_set), .irq_n(irq_dma_n)
);

jtmoomsa_053252 u_crtc(
    .clk(clk), .cen(crtc_cen_32), .rst(rst),
    .cpu_cs(g7_cc0 && !main_cpu_dsn[0]),
    .cpu_wr(main_cpu_we && !main_cpu_dsn[0]),
    .cpu_rd(!main_cpu_we && !main_cpu_dsn[0]),
    .cpu_addr(main_cpu_addr[4:1]), .cpu_din(main_cpu_dout[7:0]),
    .cpu_dout(cr_dout), .cpu_dout_valid(cr_dout_valid), .sel(2'b00),
    .h_count(cr_h_count), .v_count(cr_v_count),
    .v_render(cr_vrender), .v_render1(cr_vrender1), .v_reload_out(cr_vreload),
    .n_hsy(cr_n_hsy), .n_hbk(cr_n_hbk),
    .n_vsy(cr_n_vsy), .n_vbk(cr_n_vbk), .n_hld(cr_n_hld), .n_vld(cr_n_vld),
    .int1(cr_int1), .int2(cr_int2), .fcnt(cr_fcnt), .cres_n(cr_cres_n)
);

jtmoomsa_colmix_n6 u_n6(
    .clk(clk), .uds_n(main_cpu_dsn[1]), .reg_write(g7_reg_write),
    .srst_n(srst_n), .main_d(main_cpu_dout[11:8]),
    .crkb(crkb), .k051550_clk(k051550_clk)
);

jtmoomsa_p6_decode u_p6(
    .addr(main_cpu_addr), .as_n(main_cpu_as_n), .rw(!main_cpu_we),
    .uds_n(main_cpu_dsn[1]), .lds_n(main_cpu_dsn[0]),
    .pale_n(p6_pale_n), .oram_we_n(p6_oram_we_n),
    .pre_dtack_n(p6_pre_dtack_n), .lyr_prio_n(p6_lyr_prio_n),
    .vpa_n(p6_vpa_n), .main_rom_cs(main_rom_cs),
    .palette_cs(p6_palette_cs), .work_cs(work_cs), .objram_cs(objram_cs),
    .objram_we(p6_objram_we)
);

assign palette_cs_raw = p6_palette_cs;
assign palette_cs = p6_palette_cs;

jtmoomsa_main_decode u_decode(
    .addr(main_cpu_addr), .as_n(main_cpu_as_n), .pale_n(p6_pale_n),
    .uds_n(main_cpu_dsn[1]), .lds_n(main_cpu_dsn[0]),
    .rw(!main_cpu_we),
    .m6_rom(m6_rom), .m6_reg(m6_reg), .m6_cr(m6_cr), .m6_regcs(m6_regcs),
    .m6_pcu(m6_pcu), .m6_objcs(m6_objcs), .m6_objreg(m6_objreg),
    .g7_cc0(g7_cc0), .g7_col(g7_col), .g7_sdon(g7_sdon), .g7_pair(g7_pair),
    .g7_bnk_scr(g7_bnk_scr),
    .g7_io(g7_io), .g7_iocsb(g7_iocsb), .g7_reg_write(g7_reg_write)
);

jtmoomsa_k056832_windows u_k056_windows(
    .bus_active(main_bus_active), .cpu_rnw(!main_cpu_we),
    .uds_n(main_cpu_dsn[1]), .lds_n(main_cpu_dsn[0]), .addr(main_cpu_addr),
    .pale_n(p6_pale_n), .lyr_prio_n(p6_lyr_prio_n),
    .pre_dtack_n(p6_pre_dtack_n),
    .reg_cs(k056_reg_cs), .b_cs(k056_b_cs), .vram_cs(k056_vram_cs),
    .rom_cs(k056_rom_cs), .any_cs(k056_any_cs), .reg_addr(k056_reg_addr),
    .b_addr(k056_b_addr), .vram_addr(k056_vram_addr), .rom_addr(k056_rom_addr)
);

jtmoomsa_tile_rom_sel u_tile_rom_sel(
    .romcs(m6_rom), .colcs(g7_col), .k056_rom_cs(k056_rom_cs),
    .cpu_we(main_cpu_we),
    .tile_cs(video_tilesys_cs), .rmrd(video_rmrd)
);

jtmoomsa_cabinet u_cabinet(
    .p1(p1), .p2(p2), .p3(p3), .p4(p4), .coin(coin), .dip(dipsw[3:0]),
    .eeprom_do(eeprom_do), .eeprom_rdy(eeprom_rdy),
    .service(service), .dip_test(dip_test), .psaca1(main_cpu_addr[1]),
    .iocs(g7_io), .iocsb(g7_iocsb), .data(cabinet_din)
);

jtmoomsa_eeprom_io u_eeprom(
    .clk(clk), .rst(rst), .lds_n(main_cpu_dsn[0]), .reg_write(g7_reg_write),
    .cpu_dout(main_cpu_dout[3:0]), .cpu_dout5(main_cpu_dout[5]),
    .eeprom_do(eeprom_do), .eeprom_rdy(eeprom_rdy),
    .k51550_si(k51550_si), .irq_set(irq_set)
`ifdef JTFRAME_SAVEGAME
    ,.sav_change(sav_change), .sav_wait(sav_wait), .sav_done(sav_done),
    .sav_wr(sav_wr), .sav_ack(sav_ack), .sav_din(sav_din),
    .sav_dout(sav_dout), .sav_addr(sav_addr)
`endif
`ifdef JTFRAME_IOCTL_RD
    ,.ioctl_addr(ioctl_addr[15:0]), .ioctl_ram(ioctl_ram),
    .ioctl_wr(ioctl_wr), .ioctl_dout(ioctl_dout), .ioctl_din(ioctl_din)
`endif
);

jtmoomsa_color_bridge u_color_bridge(
    .clk(clk), .rst(rst), .cen(cen_16),
    .col(color_cout), .brit(color_brit), .col_n(color_n), .sdo(color_shadow),
    .palette_addr(color_palette_addr), .mix_code(color_mix_code),
    .shadow_code(color_shadow_code), .bright_code(color_bright_code),
    .color_blank(color_blank)
);

jtmoomsa_palette_rgb u_palette(
    .clk(clk), .cpu_cs(palette_cs && !prot_busy), .cpu_we(main_cpu_we),
    .cpu_dsn(main_cpu_dsn), .cpu_addr(main_cpu_addr[12:1]),
    .cpu_din(main_cpu_dout), .cpu_dout(palette_cpu_dout),
    .prot_req(prot_pal_req), .prot_addr(prot_pal_addr), .prot_dout(prot_pal_din),
    .video_addr(color_palette_addr), .video_rgb(palette_rgb)
);

jtmoomsa_053990_regs u_k053990_regs(
    .clk(clk), .rst(rst), .cen(cen_16),
    .cpu_cs(m6_objreg && main_bus_active && (!main_cpu_dsn[1] || !main_cpu_dsn[0])),
    .cpu_wr(main_cpu_we),
    .cpu_addr(main_cpu_addr[4:1]), .cpu_din(main_cpu_dout), .cpu_dsn(main_cpu_dsn),
    .cpu_dout(k053990_dout),
    .work_req(prot_work_req), .work_addr(prot_work_addr), .work_we(prot_work_we),
    .work_dout(prot_work_dout), .work_din(work_prot_din),
    .obj_req(prot_obj_req), .obj_addr(prot_obj_addr), .obj_din(prot_obj_din),
    .pal_req(prot_pal_req), .pal_addr(prot_pal_addr), .pal_din(prot_pal_din),
    .busy(prot_busy), .error(prot_error)
);

jtmoomsa_053246_regs u_k053246_regs(
    .clk(clk), .rst(rst),
    .cpu_cs(m6_reg && main_bus_active && (!main_cpu_dsn[1] || !main_cpu_dsn[0])),
    .cpu_wr(main_cpu_we), .cpu_rd(!main_cpu_we),
    .cpu_addr(main_cpu_addr[4:1]), .cpu_din(main_cpu_dout), .cpu_dsn(main_cpu_dsn),
    .cpu_dout(k053246_reg_dout),
    .cfg(object_cfg), .xoffset(object_xoffset), .yoffset(object_yoffset),
    .rmrd_addr(object_rmrd_addr)
);

jtmoomsa_obj u_object(
    .rst(rst), .clk(clk), .pxl_cen(pxl_cen), .pxl2_cen(pxl2_cen),
    .hdump(cr_h_count[8:0]), .vdump(cr_vdump_obj), .voffset(10'd23),
    .hs(~cr_n_hsy), .lvbl(cr_n_vbk),
    .cfg(object_cfg), .xoffset(object_xoffset), .yoffset(object_yoffset),
    .rmrd_addr(object_rmrd_addr), .dma_data(object_dma_data),
    .dma_addr(object_dma_addr), .dma_bsy(object_dma_bsy),
    .rom_addr(lyro_addr), .rom_cs(lyro_cs), .rom_data(lyro_data), .rom_ok(lyro_ok),
    .objcha_n(video_objcha_n), .objsys_cs(video_objsys_cs),
    .objsys_dout(object_objsys_dout),
    .prio(object_prio), .shd(object_shd),
    .pxl(object_pxl), .gfx_en(gfx_en)
);

jtmoomsa_054338 #(.BOARD_MODE(1)) u_054338(
    .clk(clk), .cen(pxl_cen), .rst(rst),
    .cpu_cs(m6_regcs && main_bus_active && (!main_cpu_dsn[1] || !main_cpu_dsn[0])),
    .cpu_wr(main_cpu_we),
    .cpu_rd(m6_regcs && main_bus_active && !main_cpu_we &&
        (!main_cpu_dsn[1] || !main_cpu_dsn[0])),
    .cpu_addr(main_cpu_addr[4:1]), .cpu_din(main_cpu_dout), .cpu_dsn(main_cpu_dsn),
    .cpu_dout(k338_dout), .cpu_dout_valid(k338_dout_valid),
    .palette_rgb(palette_rgb), .board_mix_code(color_mix_code),
    .board_shadow_code(color_shadow_code), .board_bright_code(color_bright_code),
    .board_blank(color_blank),
    .layer_a_r(8'd0), .layer_a_g(8'd0), .layer_a_b(8'd0),
    .layer_b_r(8'd0), .layer_b_g(8'd0), .layer_b_b(8'd0),
    .layer_a_trans(1'b1), .layer_b_trans(1'b1),
    .mix_code(2'd0), .shadow_code(2'd0), .bright_code(2'd0),
    .red(k338_rgb[23:16]), .green(k338_rgb[15:8]), .blue(k338_rgb[7:0]),
    .brightness(k338_brightness), .pixel_valid(k338_pixel_valid)
);

jtmoomsa_video u_video(
    .rst(rst), .clk(clk), .pxl_cen(pxl_cen), .pxl2_cen(pxl2_cen),
    .raster_lhbl(cr_n_hbk), .raster_lvbl(cr_n_vbk),
    .raster_hs(~cr_n_hsy), .raster_vs(~cr_n_vsy),
    .raster_hdump(cr_hdump), .raster_vdump(cr_vdump),
    .raster_vrender(cr_vrender_rel), .raster_vrender1(cr_vrender1_rel),
    .raster_vmax(cr_vreload),
    .lhbl(LHBL), .lvbl(LVBL), .hs(HS), .vs(VS),
    .cpu_addr(main_cpu_addr[16:1]), .cpu_dout(main_cpu_dout),
    .cpu_dsn(main_cpu_dsn), .cpu_we(main_cpu_we), .cpu_active(main_bus_active),
    .oram_addr(video_oram_addr), .oram_we(video_oram_we),
    .objsys_cs(video_objsys_cs), .objreg_cs(video_objreg_cs), .objcha_n(video_objcha_n),
    .pcu_cs(video_pcu_cs),
    .palette_cpu_din(palette_cpu_dout), .palette_addr(palette_addr),
    .color_rgb(k338_rgb), .color_cout(color_cout), .color_brit(color_brit),
    .color_n(color_n), .color_shadow(color_shadow),
    .vdtac(video_vdtac), .tilesys_dout(video_tilesys_dout),
    .pal_dout(video_pal_dout), .object_pxl(object_pxl),
    .object_prio(object_prio), .object_shd(object_shd),
    .k056_reg_cs(k056_reg_cs), .k056_b_cs(k056_b_cs), .k056_vram_cs(k056_vram_cs),
    .k056_rom_cs(k056_rom_cs), .k056_reg_addr(k056_reg_addr), .k056_b_addr(k056_b_addr),
    .k056_vram_addr(k056_vram_addr), .k056_rom_addr(k056_rom_addr),
    .k056_cpu_dout(k056_cpu_dout), .k056_cpu_dout_valid(k056_cpu_dout_valid),
    .k056_rom_dout(k056_rom_dout), .k056_rom_ok(k056_rom_ok), .k056_rom_busy(k056_rom_busy),
    .lyrf_addr(lyrf_addr), .lyra_addr(lyra_addr), .lyrb_addr(lyrb_addr),
    .lyrf_cs(lyrf_cs), .lyra_cs(lyra_cs), .lyrb_cs(lyrb_cs),
    .lyrf_data(lyrf_data_lanes),
    .lyrf_ok(lyrf_ok),
    .red(red), .green(green), .blue(blue),
    .ioctl_addr(ioctl_addr[3:0]), .ioctl_ram(ioctl_ram),
    .gfx_en(gfx_en[2:0]), .debug_bus(debug_bus[3:0]), .st_dout(video_st)
);

jtmoomsa_gfxrom_lanes u_lyrf_lanes(
    .gfxrom_addr({lyrf_addr,1'b0}),
    .t8_data(lyrf_data[15:0]), .t10_data(lyrf_data[31:16]),
    .t8_addr(lyrf_t8_addr), .t10_addr(lyrf_t10_addr), .gfxrom_data(lyrf_data_lanes)
);

jtmoomsa_gfxrom_lanes u_lyra_lanes(
    .gfxrom_addr({lyra_addr,1'b0}),
    .t8_data(lyra_data[15:0]), .t10_data(lyra_data[31:16]),
    .t8_addr(lyra_t8_addr), .t10_addr(lyra_t10_addr), .gfxrom_data(lyra_data_lanes)
);

jtmoomsa_gfxrom_lanes u_lyrb_lanes(
    .gfxrom_addr({lyrb_addr,1'b0}),
    .t8_data(lyrb_data[15:0]), .t10_data(lyrb_data[31:16]),
    .t8_addr(lyrb_t8_addr), .t10_addr(lyrb_t10_addr), .gfxrom_data(lyrb_data_lanes)
);

jtmoomsa_oram_cpu u_oram_cpu(
    .main_addr(main_cpu_addr[13:1]), .dsn_n(main_cpu_dsn),
    .cpu_we(main_cpu_we), .bus_active(main_bus_active), .objram_cs(objram_cs),
    .oram_addr(video_oram_addr), .oram_we(video_oram_we_raw)
);

assign video_oram_we = video_oram_we_raw & p6_objram_we & {2{!p6_oram_we_n}};

jtmoomsa_objram_addr_map u_objram_addr(
    .main_a(main_cpu_addr[15:1]), .ea(objram_ea_cpu),
    .g5p11(objram_g5p11_cpu), .g5p13(objram_g5p13_cpu), .en(objram_en_cpu),
    .ram_addr(objram_phys_addr)
);

jtmoomsa_objram_cpu u_objram_cpu(
    .clk(clk), .rst(rst), .cs(objram_cpu_cs), .cpu_read(!main_cpu_we),
    .ram_we(video_oram_we),
    .cpu_addr(objram_phys_addr), .cpu_din(main_cpu_dout),
    .dma_addr(objram_dma_phys_addr), .dma_dout(object_dma_data),
    .prot_req(prot_obj_req), .prot_addr(prot_obj_phys_addr), .prot_dout(prot_obj_din),
    .cpu_dout(objram_cpu_dout),
    .cpu_dout_valid(objram_cpu_dout_valid)
);

jtmoomsa_objram_addr_map u_objram_prot_addr(
    .main_a(prot_obj_addr), .ea(objram_ea_prot),
    .g5p11(objram_g5p11_prot), .g5p13(objram_g5p13_prot), .en(objram_en_prot),
    .ram_addr(prot_obj_phys_addr)
);

// F10 owns EA/EN during OBJDMA; adapt its packed records to Moo's SRAM pins.
assign objram_dma_phys_addr =
    {object_dma_addr[11:4],1'b0,object_dma_addr[3:1],1'b0};

jtmoomsa_sound u_sound(
    .clk(clk), .rst(rst), .cen_8(cen_8), .cen_pcm(cen_pcm), .cen_4(cen_4), .cen_2(cen_2),
    .rom_addr(snd_addr), .rom_cs(snd_cs), .rom_data(snd_data), .rom_ok(snd_ok),
    .pcm_addr(pcm_addr), .pcm_cs(pcm_cs), .pcm_data(pcm_data), .pcm_ok(pcm_ok),
    .main_addr(main_cpu_addr[4:1]), .main_dout(main_cpu_dout[7:0]),
    .pair_we(g7_pair && main_cpu_we && !main_cpu_dsn[0]), .sdon(g7_sdon),
    .snd_en(snd_en),
    .pair_dout(sound_pair_dout),
    .audio_l(snd_left), .audio_r(snd_right), .sample(sample)
);

jtmoomsa_pair_mux u_pair_mux(
    .pair_cs(g7_pair), .lower_lane(!main_cpu_dsn[0] && !main_cpu_we),
    .pair_dout(sound_pair_dout), .dout(pair_din)
);

jtmoomsa_workram_bus u_workram_bus(
    .main_addr(main_cpu_addr[15:1]), .main_dout(main_cpu_dout),
    .work_cs(work_cs), .main_dsn(main_cpu_dsn), .main_we(main_cpu_we),
    .work_addr(work_cpu_addr), .work_din(work_cpu_din), .work_we(work_cpu_we)
);

assign work_addr = work_cpu_addr;
assign work_din  = work_cpu_din;
assign work_we   = work_cpu_we;

// Work RAM is a single logical store with independent CPU and protection
// owners.  The generated wrapper-facing port remains a compatibility mirror;
// functional reads and writes use this dual-port owner.
jtframe_dual_ram16 #(.AW(15)) u_workram_local(
    .clk0  (clk), .data0(work_cpu_din), .addr0(work_cpu_addr),
    .we0   (work_cpu_we), .q0(work_cpu_dout),
    .clk1  (clk), .data1(prot_work_dout), .addr1(prot_work_addr),
    .we1   (prot_work_req ? prot_work_we : 2'b00), .q1(work_prot_din)
);

always @(posedge clk) begin
    if (rst)
        work_read_done <= 1'b0;
    else if (!work_cs || !main_bus_active || main_cpu_we)
        work_read_done <= 1'b0;
    else
        work_read_done <= 1'b1;
end
// M6B O2 is the direct CR~CS path to the K053246/K053247 object read port.
// m6_objcs remains inactive because the direct source marks M6B O3/O4 NC.
assign video_objsys_cs = m6_cr;
assign video_objreg_cs = m6_reg;
assign video_objcha_n = control2_objcha_n;
assign video_pal_cs = palette_cs;
assign video_pcu_cs = m6_pcu;

endmodule
/* verilator lint_on UNUSEDSIGNAL */
