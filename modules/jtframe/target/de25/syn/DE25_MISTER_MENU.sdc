# Generated PLL constraints can create the board reference before this shared
# file is read.  Reuse a clock already attached to each port, otherwise create
# the platform clock here.  This avoids both duplicate-clock warnings and
# name-dependent clock groups in every core build.
set de25_board_ref_clock \
    [get_clocks -nowarn -of_objects [get_ports CLOCK0_50]]
if {[get_collection_size $de25_board_ref_clock] == 0} {
    create_clock -name CLOCK0_50 -period 20.000 [get_ports CLOCK0_50]
    set de25_board_ref_clock \
        [get_clocks -nowarn -of_objects [get_ports CLOCK0_50]]
}
# Use the same build-time clock declaration as the startup programmer.
set de25_clock1_period 20.000
foreach_in_collection assignment [get_all_global_assignments -name VERILOG_MACRO] {
    if {[regexp {^DE25_GAME_REF_HZ=([0-9]+)$} [lindex $assignment 2] -> hz]} {
        set de25_clock1_period [expr {1.0e9 / $hz}]
    }
}
set de25_board_aux_clocks {}
foreach de25_aux_port_name {CLOCK1_50 CLOCK2_50} {
    set de25_aux_port [get_ports -nowarn $de25_aux_port_name]
    if {[get_collection_size $de25_aux_port] == 1} {
        set de25_aux_clock [get_clocks -nowarn -of_objects $de25_aux_port]
        if {[get_collection_size $de25_aux_clock] == 0} {
            set period [expr {$de25_aux_port_name eq "CLOCK1_50" ? $de25_clock1_period : 20.000}]
            create_clock -name $de25_aux_port_name -period $period $de25_aux_port
            set de25_aux_clock \
                [get_clocks -nowarn -of_objects $de25_aux_port]
        }
        lappend de25_board_aux_clocks $de25_aux_clock
    }
}
set de25_hps_ref_clock \
    [get_clocks -nowarn -of_objects [get_ports HPS_CLK_25]]
if {[get_collection_size $de25_hps_ref_clock] == 0} {
    create_clock -name HPS_CLK_25 -period 40.000 [get_ports HPS_CLK_25]
}

# Platform Designer inserts JTAG Avalon masters into the HPS subsystem. TCK is
# unrelated to every functional clock and the generated bridges contain their
# own clock-crossing synchronizers. Create the debug clock before assembling
# the asynchronous groups so recovery/removal analysis does not invent a
# phase relationship between TCK and the platform or core PLLs.
set de25_jtag_tck [get_ports -nowarn altera_reserved_tck]
if {[get_collection_size $de25_jtag_tck] == 1 &&
    [get_collection_size \
        [get_clocks -nowarn -of_objects $de25_jtag_tck]] == 0} {
    create_clock -name altera_reserved_tck -period 30.000 $de25_jtag_tck
}
set de25_jtag_clock \
    [get_clocks -nowarn -of_objects $de25_jtag_tck]

# ao486 derives its two legacy serial clocks from a 24.576 MHz accumulator.
# Their edge spacing is intentionally non-uniform, so they cannot be modeled
# as phase-related integer generated clocks. Model each with its shortest
# possible full period, then isolate it from the source and other domains. The
# conservative periods cover the bounded jitter while still timing all logic
# clocked by the legacy UART and MPU clocks.
# Keep optional clocks as genuine TimeQuest collections even when this persona
# does not instantiate them. A plain empty Tcl string is not a collection and
# makes get_collection_size abort unrelated core fits such as NES.
set de25_ao486_uart_clock [get_clocks -nowarn DE25_AO486_UART]
set de25_ao486_mpu_clock [get_clocks -nowarn DE25_AO486_MPU]
set de25_ao486_uart_target \
    [get_keepers -nowarn {core|pll|clk_uart_slow}]
set de25_ao486_mpu_target \
    [get_keepers -nowarn {core|pll|mpu_phase[9]}]
if {[get_collection_size $de25_ao486_uart_target] == 1} {
    create_clock -name DE25_AO486_UART -period 488.281 \
        $de25_ao486_uart_target
    set de25_ao486_uart_clock [get_clocks DE25_AO486_UART]
}
if {[get_collection_size $de25_ao486_mpu_target] == 1} {
    create_clock -name DE25_AO486_MPU -period 325.521 \
        $de25_ao486_mpu_target
    set de25_ao486_mpu_clock [get_clocks DE25_AO486_MPU]
}

# Quartus reads project SDC before automatically discovered IP constraints.
# Source the two generated IOPLL constraints so their clock objects exist when
# the asynchronous groups below are evaluated.
foreach pll_root {mister_pll de25_game_pll menu_core_pll inputtest_core_pll memtest_core_pll memtest_core_pll_cal memtest_video_pll nes_core_pll_cal snes_core_pll_cal minimig_core_pll_cal tgfx16_core_pll sms_core_pll_cal pcxt_core_pll ao486_core_pll_cal ay38500_core_pll chip8_core_pll atari7800_core_pll jaguar_core_pll psx_core_pll psx_video_pll n64_core_pll n64_video_pll saturn_core_pll} {
    set pll_sdc_root [file normalize [file join ip ip $pll_root]]
    foreach pll_sdc [glob -nocomplain [file join $pll_sdc_root * altera_iopll_2100 synth *.sdc]] {
        source $pll_sdc
    }
}

# The common complete-image Menu clock service has its own generated IOPLL
# hierarchy. Keep the controller, SDRAM launch, and SDRAM capture clocks in
# one synchronous group, and keep video independent from that group.
set de25_shell_memory_clocks [get_clocks -nowarn {
    *|bank0_iopll|bank0_iopll_outclk0
    *|bank0_iopll|bank0_iopll_outclk2
    *|bank0_iopll|bank0_iopll_outclk3
}]
set de25_shell_video_clock [get_clocks -nowarn {
    *|bank0_iopll|bank0_iopll_outclk1
}]

# Keep the controller and its phase-shifted SDRAM pin clock in the same
# synchronous group.  Grouping every outclk index separately used to cut the
# very C0-to-C1 relationship that makes the source-synchronous interface work.
# Menu's C0 controller and C2 SDRAM clock are likewise related, while its C1
# video clock is intentionally treated as an independent domain.
set de25_async_clock_groups {}
if {[get_collection_size $de25_board_ref_clock] > 0} {
    lappend de25_async_clock_groups $de25_board_ref_clock
}
foreach de25_board_aux_clock $de25_board_aux_clocks {
    if {[get_collection_size $de25_board_aux_clock] > 0} {
        lappend de25_async_clock_groups $de25_board_aux_clock
    }
}
if {[get_collection_size $de25_jtag_clock] > 0} {
    lappend de25_async_clock_groups $de25_jtag_clock
}
if {[get_collection_size $de25_ao486_uart_clock] > 0} {
    lappend de25_async_clock_groups $de25_ao486_uart_clock
}
if {[get_collection_size $de25_ao486_mpu_clock] > 0} {
    lappend de25_async_clock_groups $de25_ao486_mpu_clock
}
if {[get_collection_size $de25_shell_memory_clocks] > 0} {
    lappend de25_async_clock_groups $de25_shell_memory_clocks
}
if {[get_collection_size $de25_shell_video_clock] > 0} {
    lappend de25_async_clock_groups $de25_shell_video_clock
}

# PSX and other large personas use a second PLL instance for their native
# video pipeline. The upstream cores contain explicit asynchronous transfer
# logic between this domain and the main core PLL. Treating both PLLs as
# phase-related creates a zero-nanosecond relationship and thousands of false
# setup violations.
set de25_persona_video_clocks [get_clocks -nowarn {
    *|pll2|impl|iopll_0|iopll_0_outclk*
    *|pll2|pll|iopll_0|iopll_0_outclk*
    *|video_pll|impl|iopll_0|iopll_0_outclk*
    *|vpll|impl|iopll_0|iopll_0_outclk*
}]
if {[get_collection_size $de25_persona_video_clocks] > 0} {
    lappend de25_async_clock_groups $de25_persona_video_clocks
}

# NES and SNES expose more than two outputs and intentionally isolate their
# video clock from the SDRAM clocks. Minimig exposes exactly two outputs with
# a strict 4:1 relationship, so keep both in one synchronous timing group.
set de25_core_pll_clocks [get_clocks -nowarn {
    *|pll|pll|iopll_0|iopll_0_outclk*
    *|pll|impl|iopll_0|iopll_0_outclk*
    *|pll_all|impl|iopll_0|iopll_0_outclk*
}]

# PCXT derives two legacy CGA clocks in fabric from its 28.571 MHz PLL output.
# clk_14_318 is a divide-by-two toggle. ce_pixel_cga is the same clock delayed
# by one 28.571 MHz cycle, so its rising edge is 35 ns later. The CRTC HSYNC
# clock is programmable, but both standard 40- and 80-column modes produce one
# edge every 1824 input cycles (63.84 us). Treat its phase as asynchronous
# because software may rewrite the horizontal timing registers at run time.
set de25_pcxt_clk_14_318 [get_clocks -nowarn DE25_PCXT_CLK_14_318]
set de25_pcxt_ce_pixel_cga [get_clocks -nowarn DE25_PCXT_CE_PIXEL_CGA]
set de25_pcxt_cga_hsync [get_clocks -nowarn DE25_PCXT_CGA_HSYNC]
set de25_pcxt_clk_28_636 [get_clocks -nowarn {
    core|pll_all|impl|iopll_0|iopll_0_outclk2
}]
set de25_pcxt_clk_14_318_target [get_keepers -nowarn {core|clk_14_318}]
set de25_pcxt_ce_pixel_cga_target [get_keepers -nowarn {core|ce_pixel_cga}]
set de25_pcxt_cga_hsync_target [get_keepers -nowarn {
    core|u_CHIPSET|u_PERIPHERALS|cga1|crtc|HSYNC
}]
if {[get_collection_size $de25_pcxt_clk_28_636] == 1 &&
    [get_collection_size $de25_pcxt_clk_14_318_target] == 1} {
    create_generated_clock -name DE25_PCXT_CLK_14_318 \
        -master_clock $de25_pcxt_clk_28_636 \
        -source [get_clock_info -targets $de25_pcxt_clk_28_636] \
        -edges {1 3 5} $de25_pcxt_clk_14_318_target
    set de25_pcxt_clk_14_318 [get_clocks DE25_PCXT_CLK_14_318]
}
if {[get_collection_size $de25_pcxt_clk_28_636] == 1 &&
    [get_collection_size $de25_pcxt_ce_pixel_cga_target] == 1} {
    create_generated_clock -name DE25_PCXT_CE_PIXEL_CGA \
        -master_clock $de25_pcxt_clk_28_636 \
        -source [get_clock_info -targets $de25_pcxt_clk_28_636] \
        -edges {3 5 7} $de25_pcxt_ce_pixel_cga_target
    set de25_pcxt_ce_pixel_cga [get_clocks DE25_PCXT_CE_PIXEL_CGA]
}
if {[get_collection_size $de25_pcxt_cga_hsync_target] == 1} {
    create_clock -name DE25_PCXT_CGA_HSYNC -period 63840.000 \
        $de25_pcxt_cga_hsync_target
    set de25_pcxt_cga_hsync [get_clocks DE25_PCXT_CGA_HSYNC]
    lappend de25_async_clock_groups $de25_pcxt_cga_hsync
}

# Main updates status in clk_chipset while the splash sequencer samples its
# enable bit at 14.318 MHz. The bit remains stable between HPS commands, so the
# receiving register is the intended CDC boundary.
set de25_pcxt_splash_enable [get_keepers -nowarn {core|splash_off}]
if {[get_collection_size $de25_pcxt_splash_enable] == 1} {
    set_false_path -to $de25_pcxt_splash_enable
}

set de25_core_pll_clock_count [get_collection_size $de25_core_pll_clocks]
if {[lsearch -exact {2 3 5 6} $de25_core_pll_clock_count] >= 0} {
    # Minimig's two clocks have a fixed 4:1 relationship. SMS's three clocks
    # are the controller plus phase-related SDRAM launch and capture clocks.
    # PCXT has five surviving PLL outputs after optimization; all five retain
    # fixed phase relationships and belong in the same core timing group.
    set de25_core_related_clocks $de25_core_pll_clocks
    foreach de25_pcxt_generated_clock [list \
        $de25_pcxt_clk_14_318 $de25_pcxt_ce_pixel_cga] {
        # A non-PCXT persona leaves these variables as empty Tcl strings,
        # which are not valid TimeQuest collection handles.
        if {$de25_pcxt_generated_clock ne "" &&
            [get_collection_size $de25_pcxt_generated_clock] > 0} {
            set de25_core_related_clocks [add_to_collection \
                $de25_core_related_clocks $de25_pcxt_generated_clock]
        }
    }
    lappend de25_async_clock_groups $de25_core_related_clocks
} else {
    set de25_core_pll_memory_clocks [get_clocks -nowarn {
        *|pll|pll|iopll_0|iopll_0_outclk0
        *|pll|pll|iopll_0|iopll_0_outclk2
        *|pll|pll|iopll_0|iopll_0_outclk3
        *|pll|pll|iopll_0|iopll_0_outclk4
        *|pll|impl|iopll_0|iopll_0_outclk0
        *|pll|impl|iopll_0|iopll_0_outclk2
        *|pll|impl|iopll_0|iopll_0_outclk3
        *|pll|impl|iopll_0|iopll_0_outclk4
    }]
    set de25_core_pll_video_clock [get_clocks -nowarn {
        *|pll|pll|iopll_0|iopll_0_outclk1
        *|pll|impl|iopll_0|iopll_0_outclk1
    }]
    if {[get_collection_size $de25_core_pll_memory_clocks] > 0} {
        lappend de25_async_clock_groups $de25_core_pll_memory_clocks
    }
    if {[get_collection_size $de25_core_pll_video_clock] > 0} {
        lappend de25_async_clock_groups $de25_core_pll_video_clock
    }
}

foreach de25_clock_pattern {
    {*|de25_pll|*|iopll_0_outclk*}
    {*|de25_vpll|*|iopll_0_outclk*}
    {*|system_pll|*outclk0}
    {*|system_pll|*outclk1}
    {*|system_pll|*outclk2}
    {*|system_pll|*outclk3}
    {*|cpu_pll|*outclk*}
    {*|peripheral_pll|*outclk*}
} {
    set de25_clock_group [get_clocks -nowarn $de25_clock_pattern]
    if {[get_collection_size $de25_clock_group] > 0} {
        lappend de25_async_clock_groups $de25_clock_group
    }
}
if {[llength $de25_async_clock_groups] > 1} {
    set de25_clock_group_command [list set_clock_groups -asynchronous]
    foreach de25_clock_group $de25_async_clock_groups {
        lappend de25_clock_group_command -group $de25_clock_group
    }
    eval $de25_clock_group_command
}

# DE25-Nano Rev. B carries two IS42/45VM16320G devices on the PCB.  These
# constraints model a conservative -6 speed grade. MemTest starts at 80 MHz;
# Menu uses the upstream controller's nominal 100 MHz operating point. The
# ISSI limits are tAC(max)=5.5 ns, tOH(min)=2.5 ns,
# input setup=1.5 ns, and input hold=1.0 ns.  Board flight time follows the
# Altera source-synchronous SDRAM example: 0.5 ns for DRAM_CLK and 0.4 to
# 0.6 ns for data/control.  Because -reference_pin evaluates the clock at the
# FPGA pin, the delays below include only the resulting +/-0.1 ns mismatch.
#
# The controller clock is C0. C1 on MemTest drives DRAM_CLK 5.75 ns later at
# 80 MHz. C2 on Menu drives it 5.5 ns later at 100 MHz, and C3 captures read
# data at +6.5 ns. The independent capture phase preserves read margin while
# the forwarded phase favors output setup.
# Dynamic MemTest rates
# above the 80 MHz startup profile are hardware stress modes, not timing
# signoff points for normal operation.
set de25_sdram_clock [get_clocks -nowarn {
    *|de25_pll|*|iopll_0_outclk1
    *|pll|impl|iopll_0|iopll_0_outclk2
    *|pll|pll|iopll_0|iopll_0_outclk3
    *|pll_all|impl|iopll_0|iopll_0_outclk1
    *|bank0_iopll|bank0_iopll_outclk2
    *|pll|pll|cpu_pll|cpu_pll_outclk1
}]
# SMS forwards C1 to SDRAM. PSX C3 is a dedicated phase-related replacement
# for the Cyclone V DDR clock primitive, and C4 captures its returning data.
# Detect these hierarchies directly rather than inferring them from the PLL
# output count.
set de25_sms_sdram_clock [get_clocks -nowarn {
    *|pll|pll|iopll_0|iopll_0_outclk1
}]
if {[get_collection_size $de25_sms_sdram_clock] == 1} {
    set de25_sdram_clock $de25_sms_sdram_clock
}
set de25_psx_sdram_capture_clock [get_clocks -nowarn {
    *|pll|impl|iopll_0|iopll_0_outclk4
}]
if {[get_collection_size $de25_psx_sdram_capture_clock] == 1} {
    set de25_psx_sdram_clock [get_clocks -nowarn {
        *|pll|impl|iopll_0|iopll_0_outclk3
    }]
    if {[get_collection_size $de25_psx_sdram_clock] == 1} {
        set de25_sdram_clock $de25_psx_sdram_clock
    }
}
if {[get_collection_size $de25_sdram_clock] == 1} {
    set de25_sdram_clock_port [get_ports DRAM_CLK]
    set de25_sdram_dq [get_ports {DRAM_DQ[*]}]
    set de25_sdram_outputs [get_ports {
        DRAM_ADDR[*] DRAM_BA[*] DRAM_DQ[*] DRAM_LDQM DRAM_UDQM
        DRAM_WE_n DRAM_CAS_n DRAM_RAS_n DRAM_CKE DRAM_CS_n[*]
    }]

    set_input_delay -clock $de25_sdram_clock \
        -reference_pin $de25_sdram_clock_port -max 5.600 $de25_sdram_dq
    set_input_delay -clock $de25_sdram_clock \
        -reference_pin $de25_sdram_clock_port -min 2.400 $de25_sdram_dq
    set_output_delay -clock $de25_sdram_clock \
        -reference_pin $de25_sdram_clock_port -max 1.600 $de25_sdram_outputs
    set_output_delay -clock $de25_sdram_clock \
        -reference_pin $de25_sdram_clock_port -min -1.100 $de25_sdram_outputs

    # Menu intentionally captures each read on the following C3 edge. The C3
    # edge immediately after the SDRAM launch contains the preceding bus value
    # and is skipped by the read-triggered capture sequencer.
    set de25_sdram_capture_registers [get_keepers -nowarn {
        *|sdr|data_capture[*]
        *|sdram|data_capture[*]
        *|gus|sdram|data[*]
    }]
    if {[get_collection_size $de25_sdram_capture_registers] > 0} {
        set_multicycle_path -setup 2 -from $de25_sdram_dq \
            -to $de25_sdram_capture_registers
        set_multicycle_path -hold 1 -from $de25_sdram_dq \
            -to $de25_sdram_capture_registers
    }

    # The captured word changes only for a read and remains held while the
    # controller's CAS pipeline deliberately skips the immediately following
    # C0 edge. Model that functional two-cycle C3-to-C0 transfer explicitly.
    set de25_sdram_read_registers [get_keepers -nowarn {
        *|sdr|data*
        *|sdram|ch?_dout[*]
        *|sdram|last_data[*][*]
        *|sdram|rbuf[*]
    }]
    if {[get_collection_size $de25_sdram_capture_registers] > 0 &&
        [get_collection_size $de25_sdram_read_registers] > 0} {
        set_multicycle_path -setup 2 -from $de25_sdram_capture_registers \
            -to $de25_sdram_read_registers
        set_multicycle_path -hold 1 -from $de25_sdram_capture_registers \
            -to $de25_sdram_read_registers
    }

    # DRAM_CLK is the forwarded reference clock, not a data output.  It has no
    # external setup/hold requirement of its own.
    set_false_path -to $de25_sdram_clock_port
}

# Core audio is sampled continuously by the independent fixed-rate I2S
# serializer. It is payload data crossing into clk_audio, not a synchronous
# transfer between the core and platform PLLs.
set de25_audio_sample_registers [get_keepers -nowarn {*audio|samples*}]
if {[get_collection_size $de25_audio_sample_registers] > 0} {
    set_false_path -to $de25_audio_sample_registers
}
# Platform V2 samples each asynchronous core channel through an explicit
# meta/sync pair. Only the first stage accepts an unrelated core clock.
set de25_audio_sample_meta [get_keepers -nowarn {
    *audio|left_meta[*]
    *audio|right_meta[*]
}]
if {[get_collection_size $de25_audio_sample_meta] > 0} {
    set_false_path -to $de25_audio_sample_meta
}
# reset_request is generated in the core system domain. audio_reset_pipe is
# its assertion/release synchronizer in the unrelated fixed I2S domain, so
# only the first stage is an asynchronous timing endpoint.
set de25_audio_reset_meta [get_keepers -nowarn {audio_reset_pipe[0]}]
if {[get_collection_size $de25_audio_reset_meta] > 0} {
    set_false_path -to $de25_audio_reset_meta
}

# MiSTer's OSD calculates its horizontal placement from slowly changing
# configuration registers written in clk_sys. The video domain samples the
# result only at an active-video edge, so this is a functional CDC rather than
# a same-cycle transfer. Preserve the upstream MiSTer exception on both sides
# of the sampled placement register.
set de25_osd_slow_pipeline [get_keepers -nowarn {
    *shell_osd|v_cnt*
    *shell_osd|v_osd_start*
    *shell_osd|v_info_start*
    *shell_osd|h_osd_start*
    *shell_osd|half*
}]
if {[get_collection_size $de25_osd_slow_pipeline] > 0} {
    set_false_path -to $de25_osd_slow_pipeline
}
set de25_osd_slow_sources [get_keepers -nowarn {
    *shell_osd|v_osd_start*
    *shell_osd|v_info_start*
    *shell_osd|h_osd_start*
    *shell_osd|rot*
    *shell_osd|dsp_width*
}]
if {[get_collection_size $de25_osd_slow_sources] > 0} {
    set_false_path -from $de25_osd_slow_sources
}
set de25_osd_vcount [get_keepers -nowarn {*shell_osd|osd_vcnt*}]
if {[get_collection_size $de25_osd_vcount] > 0} {
    set_multicycle_path -setup 2 -to $de25_osd_vcount
    set_multicycle_path -hold 1 -to $de25_osd_vcount
}

# The ADV7513 samples 24-bit video, DE, and sync on HDMI_TX_CLK. The shell
# forwards the opposite video-clock phase, giving the parallel bus half a
# pixel period after its source registers change. The receiver requires at
# least 1.8 ns setup and 1.3 ns hold across its supported temperature range.
set de25_hdmi_video_clock_port [get_ports -nowarn HDMI_TX_CLK]
set de25_hdmi_video_master \
    [get_clocks -nowarn -of_objects $de25_hdmi_video_clock_port]
set de25_hdmi_video_outputs [get_ports -nowarn {
    HDMI_TX_D[*] HDMI_TX_DE HDMI_TX_HS HDMI_TX_VS
}]
if {[get_collection_size $de25_hdmi_video_master] == 1 &&
    [get_collection_size $de25_hdmi_video_outputs] > 0} {
    create_generated_clock -name DE25_HDMI_TX_CLK \
        -master_clock $de25_hdmi_video_master \
        -source [get_clock_info -targets $de25_hdmi_video_master] \
        -invert $de25_hdmi_video_clock_port
    set_output_delay -clock [get_clocks DE25_HDMI_TX_CLK] \
        -reference_pin $de25_hdmi_video_clock_port \
        -max 1.800 $de25_hdmi_video_outputs
    set_output_delay -clock [get_clocks DE25_HDMI_TX_CLK] \
        -reference_pin $de25_hdmi_video_clock_port \
        -min -1.300 $de25_hdmi_video_outputs
    set_false_path -to $de25_hdmi_video_clock_port
}

# I2S BCLK is the 24.576 MHz audio master divided by eight. Serial data and
# LRCLK change on BCLK falling edges and the ADV7513 samples them on rising
# edges. Model the forwarded clock and the receiver's 2 ns setup/hold limits.
set de25_hdmi_audio_master \
    [get_clocks -nowarn -of_objects [get_ports -nowarn HDMI_MCLK]]
set de25_hdmi_audio_clock_port [get_ports -nowarn HDMI_SCLK]
set de25_hdmi_audio_clock_register \
    [get_keepers -nowarn {*audio|bit_clock}]
if {[get_collection_size $de25_hdmi_audio_master] == 1 &&
    [get_collection_size $de25_hdmi_audio_clock_port] == 1 &&
    [get_collection_size $de25_hdmi_audio_clock_register] == 1} {
    create_generated_clock -name DE25_HDMI_SCLK \
        -master_clock $de25_hdmi_audio_master \
        -source [get_clock_info -targets $de25_hdmi_audio_master] \
        -divide_by 8 $de25_hdmi_audio_clock_register
    set de25_hdmi_audio_outputs [get_ports -nowarn {
        HDMI_I2S HDMI_LRCLK
    }]
    set_output_delay -clock [get_clocks DE25_HDMI_SCLK] \
        -reference_pin $de25_hdmi_audio_clock_port \
        -max 2.000 $de25_hdmi_audio_outputs
    set_output_delay -clock [get_clocks DE25_HDMI_SCLK] \
        -reference_pin $de25_hdmi_audio_clock_port \
        -min -2.000 $de25_hdmi_audio_outputs

    # word_clock and serial_data use a synchronous MCLK clock enable which is
    # active only on BCLK falling edges. TimeQuest otherwise assumes these
    # registers may launch on the MCLK edge immediately before BCLK rises.
    # The four-cycle start multicycle models the enforced half-BCLK interval.
    set de25_hdmi_audio_data_registers [get_keepers -nowarn {
        *audio|word_clock *audio|serial_data
    }]
    # Silent personas can optimize serial_data to a constant while LRCLK
    # remains live. Apply the edge relationship to every surviving register.
    if {[get_collection_size $de25_hdmi_audio_data_registers] > 0} {
        set_multicycle_path -setup -start 4 \
            -from $de25_hdmi_audio_data_registers \
            -to $de25_hdmi_audio_outputs
        set_multicycle_path -hold -start 4 \
            -from $de25_hdmi_audio_data_registers \
            -to $de25_hdmi_audio_outputs
    }
}
# MCLK and BCLK are forwarded clocks, not receiver-sampled data outputs.
set_false_path -to [get_ports -nowarn {HDMI_MCLK HDMI_SCLK}]

# ADV7513 I2C is an asynchronous open-drain management bus. Its protocol
# frequency and edge spacing are generated by the 50 MHz initializer FSM.
set_false_path -from [get_ports -nowarn {HDMI_I2C_SCL HDMI_I2C_SDA}]
set_false_path -to [get_ports -nowarn {HDMI_I2C_SCL HDMI_I2C_SDA}]

# JTAG serial control/data pins are asynchronous protocol signals.
set_false_path -from [get_ports -nowarn {
    altera_reserved_tdi altera_reserved_tms
}]
set_false_path -to [get_ports -nowarn altera_reserved_tdo]

# HPS reset-manager outputs are asynchronous reset sources. Platform Designer
# reset controllers and the shell's reset pipes synchronize their release.
set_false_path -from [get_keepers {*sundancemesa_hps_inst~intosc_clk.reg}]

# PLL lock-loss and platform-reset logic asynchronously disables CKE, both
# chip selects, and DQ drive as an emergency safety action. These paths are
# intentionally not timed as normal source-synchronous SDRAM transactions.
set de25_pll_control_registers [get_keepers -nowarn {
    *|tennm_ph2_iopll~pll_ctrl_reg
    *|pll|reconfigure|busy*
    *|pll|reconfigure|error*
}]
if {[get_collection_size $de25_pll_control_registers] > 0} {
    set_false_path -from $de25_pll_control_registers -to [get_ports {
        DRAM_CKE DRAM_CS_n[*] DRAM_DQ[*]
    }]
    # GUS samples lock loss only to restart and quiesce its controller. The
    # variable clock is not valid while that hard-IP status changes, so this
    # is an asynchronous safety/reset path rather than a functional transfer.
    set de25_gus_sdram_registers [get_keepers -nowarn {
        *|gus|sdram|*
    }]
    if {[get_collection_size $de25_gus_sdram_registers] > 0} {
        set_false_path -from $de25_pll_control_registers \
            -to $de25_gus_sdram_registers
    }
}

# The reset pipes assert through their asynchronous clear inputs, then release
# only through three clocked stages. Recovery/removal analysis on the clear pins
# does not describe the synchronized release seen by downstream logic.
set_false_path -to [get_pins -nowarn -hierarchical {
    *reset_pipe*clrn
    *init_sync*clrn
}]
set de25_reset_request_clr [get_pins -nowarn {reset_request|clrn}]
if {[get_collection_size $de25_reset_request_clr] > 0} {
    set_false_path -to $de25_reset_request_clr
}

# MemTest deliberately synchronizes its reconfiguration/PLL-lock reset request
# into the variable SDRAM clock.  Only the first metastability stage accepts an
# asynchronous input; the second stage and all consumers remain fully timed.
set ram_reset_meta [get_keepers -nowarn {*ram_*_sync[0]}]
if {[get_collection_size $ram_reset_meta] > 0} {
    set_false_path -to $ram_reset_meta
}

# MemTest's camera-readable hardware status is sampled in the unrelated video
# domain through a two-register synchronizer. Only the first register is an
# asynchronous endpoint; the second stage and display logic remain timed.
set de25_memtest_display_meta [get_keepers -nowarn {
    *|displayed_passcount_meta[*]
}]
if {[get_collection_size $de25_memtest_display_meta] > 0} {
    set_false_path -to $de25_memtest_display_meta
}

# ao486 bring-up status combines sticky observations from the input-video,
# output-video, and scaler-memory domains. The shell samples those flags
# through an explicit two-register synchronizer before publishing them to the
# HPS GP input. Only its first metastability stage is asynchronous.
set de25_ao486_scaler_meta [get_keepers -nowarn {
    *ao486_scaler_diag_meta*
    *ao486_user_meta*
}]
if {[get_collection_size $de25_ao486_scaler_meta] > 0} {
    set_false_path -to $de25_ao486_scaler_meta
}

# NES and SNES synchronize reconfiguration and controller initialization
# requests into their phase-related SDRAM domains. Only the first synchronizer
# stages accept asynchronous control signals.
set de25_nes_sdram_meta [get_keepers -nowarn {
    *|sdram|quiesce_sync[0]
    *|sdram|init_sync[0]
    *|sdram|capture_init_sync[0]
    *|ram|quiesce_sync[0]
    *|ram|capture_init_sync[0]
    *|de25_ram_quiesce|ram_request_sync[0]
    *|de25_want_pal_sync[0]
    *|de25_loader_bridge|request_sync[0]
    *|de25_loader_bridge|done_sync[0]
    *|de25_loader_bridge|accepted_sync[0]
    *|de25_loader_bridge|verify_error_sync[0]
}]
if {[get_collection_size $de25_nes_sdram_meta] > 0} {
    set_false_path -to $de25_nes_sdram_meta
}

# IOPLL lock loss asynchronously disables SDRAM drive and advances the
# controller toward reset. This safety path is intentionally not a normal
# synchronous transfer from the PLL hard-IP reference-clock domain.
set de25_pll_lock_loss [get_keepers -nowarn {
    *|tennm_ph2_iopll~pll_ctrl_reg
}]
if {[get_collection_size $de25_pll_lock_loss] > 0} {
    set de25_sdram_lock_loss_registers [get_keepers -nowarn {
        *|sdram|SDRAM_DQ_OE
        *|sdram|mode*
        *|ram|SDRAM_DQ_OE
        *|ram|mode*
    }]
    if {[get_collection_size $de25_sdram_lock_loss_registers] > 0} {
        set_false_path -from $de25_pll_lock_loss \
            -to $de25_sdram_lock_loss_registers
    }
}

set_false_path -from [get_ports {KEY[*]}]
set_false_path -from [get_ports {SW[*]}]
set_false_path -from [get_ports -nowarn FPGA_UART_RX]
set_false_path -from [get_ports HPS_ENET_RX_CTL]
set_false_path -from [get_ports HPS_USB_DIR]
set_false_path -from [get_ports HPS_USB_NXT]
set_false_path -from [get_ports HDMI_TX_INT]
set_false_path -to [get_ports {LED[*]}]
set_false_path -to [get_ports FPGA_UART_TX]

derive_clock_uncertainty
