package require qsys 25.1

# Build on Terasic's supported rev-B HPS system. Before this script runs, the
# caller provides a working copy in the project ip/terasic-ghrd directory.
set source_system terasic-ghrd/qsys_top.qsys
set output_system terasic-ghrd/mister_hps.qsys
file copy -force $source_system $output_system
load_system $output_system

if {![info exists legacy_no_vbuf]} {
    set legacy_no_vbuf 0
}
if {[info exists ::env(DE25_HPS_COMPAT_078)]} {
    set hps_compat_078 $::env(DE25_HPS_COMPAT_078)
    if {$hps_compat_078 eq "1"} {
        set legacy_no_vbuf 1
    }
}

# The imported GHRD stores its clock bridge as a generic component. Newer
# platforms recreate it as editable native IP. The 078A boot platform was
# compiled with Terasic's original bridge, so preserve that exact component
# for legacy PC110 builds even though both forms run at the same 100 MHz.
if {!$legacy_no_vbuf} {
    remove_interface clk_100
    remove_instance clk_100
    add_instance clk_100 altera_clock_bridge 19.2.0
    set_instance_parameter_value clk_100 EXPLICIT_CLOCK_RATE 100000000
    add_interface clk_100 clock sink
    set_interface_property clk_100 EXPORT_OF clk_100.in_clk

    foreach clock_sink {
        subsys_debug.clk
        subsys_periph.clk
        ace5lite_cache_coherency_translator_0.clk
        ext_hps_f2sdram_master.clock
        subsys_hps.f2sdram_adapter_clk
        subsys_hps.f2sdram_clk
        subsys_hps.fpga2hps_clk
        subsys_hps.hps2fpga_clk
        subsys_hps.lwhps2fpga_clk
    } {
        add_connection clk_100.out_clk $clock_sink
    }
}

# Agilex 5 requires the HPS-generated h2f_reset output to drive the reset
# inputs of every HPS/FPGA bridge.  The Terasic baseline connects these sinks
# to its generic fabric reset instead.  That lets the design compile and the
# HPS boot, but software transactions can stall after U-Boot releases only the
# hard bridge reset.  Keep h2f_reset exported for the board shell, export an
# active-high fanout input beside it, and have the shell loop the HPS reset
# output back into that input.  A reset bridge supplies the legal one-to-many
# Platform Designer connection to the four bridge-facing reset ports.
if {!$legacy_no_vbuf} {
    add_instance mister_h2f_reset_fanout altera_reset_bridge 19.2.0
    set_instance_parameter_value mister_h2f_reset_fanout ACTIVE_LOW_RESET 0
    set_instance_parameter_value mister_h2f_reset_fanout SYNCHRONOUS_EDGES none
    set_instance_parameter_value mister_h2f_reset_fanout NUM_RESET_OUTPUTS 1
    set_instance_parameter_value mister_h2f_reset_fanout USE_RESET_REQUEST 0
    set_instance_parameter_value mister_h2f_reset_fanout SYNC_RESET 0

    add_interface mister_h2f_bridge_reset reset sink
    set_interface_property mister_h2f_bridge_reset \
        EXPORT_OF mister_h2f_reset_fanout.in_reset

    foreach bridge_reset {
        f2sdram_rst
        fpga2hps_rst
        hps2fpga_rst
        lwhps2fpga_rst
    } {
        remove_connection rst_in.out_reset/subsys_hps.$bridge_reset
        add_connection mister_h2f_reset_fanout.out_reset \
            subsys_hps.$bridge_reset
    }
}

# The reference design's 256 KiB fabric OCM is debug scratch memory. Removing
# it returns about 104 M20Ks to MiSTer cores and leaves both HPS memory bridges
# available for the platform shell.
remove_connection rst_in.out_reset/ocm.reset1
remove_connection subsys_debug.fpga_m_master/ocm.axi_s1
remove_connection subsys_hps.hps2fpga/ocm.axi_s1
remove_instance ocm

# Export MiSTer's standard 64-bit DDRAM channel. The core presents 64-bit word
# addresses and bursts in its own clock domain; Platform Designer crosses into
# the 100 MHz HPS fabric and adapts transactions to the 256-bit FPGA-to-LPDDR4
# bridge. The board shell translates MiSTer's complete 512 MiB logical window
# into LPDDR physical addresses 0xa0000000 through 0xbfffffff.
add_instance mister_ddram_cdc altera_avalon_mm_clock_crossing_bridge 19.4.0
set_instance_parameter_value mister_ddram_cdc DATA_WIDTH 64
set_instance_parameter_value mister_ddram_cdc SYMBOL_WIDTH 8
set_instance_parameter_value mister_ddram_cdc ADDRESS_UNITS SYMBOLS
set_instance_parameter_value mister_ddram_cdc ADDRESS_WIDTH 32
set_instance_parameter_value mister_ddram_cdc HDL_ADDR_WIDTH 32
set_instance_parameter_value mister_ddram_cdc USE_AUTO_ADDRESS_WIDTH 0
set_instance_parameter_value mister_ddram_cdc MAX_BURST_SIZE 128
set_instance_parameter_value mister_ddram_cdc COMMAND_FIFO_DEPTH 32
set_instance_parameter_value mister_ddram_cdc RESPONSE_FIFO_DEPTH 256
set_instance_parameter_value mister_ddram_cdc MASTER_SYNC_DEPTH 3
set_instance_parameter_value mister_ddram_cdc SLAVE_SYNC_DEPTH 3
set_instance_parameter_value mister_ddram_cdc PIPELINE_ENABLE 1
set_instance_parameter_value mister_ddram_cdc SYNC_RESET 1

add_connection clk_100.out_clk mister_ddram_cdc.m0_clk
add_connection rst_in.out_reset mister_ddram_cdc.m0_reset
add_connection mister_ddram_cdc.m0 subsys_hps.f2sdram_adapter_axi4_sub
set_connection_parameter_value \
    mister_ddram_cdc.m0/subsys_hps.f2sdram_adapter_axi4_sub baseAddress 0x00000000

add_interface mister_ddram avalon slave
set_interface_property mister_ddram EXPORT_OF mister_ddram_cdc.s0

add_interface mister_ddram_clk clock sink
set_interface_property mister_ddram_clk EXPORT_OF mister_ddram_cdc.s0_clk

add_interface mister_ddram_reset reset sink
set_interface_property mister_ddram_reset EXPORT_OF mister_ddram_cdc.s0_reset

if {!$legacy_no_vbuf} {
    # Give the common HDMI scaler an independent, native 128-bit memory
    # channel. The scaler and HPS fabric already share clk_100, so a dual-clock
    # bridge only adds command and response FIFOs to a synchronous path. The
    # wide response FIFO was the sole read-path storage between a verified
    # clean LPDDR framebuffer and corrupted scanout. Use the same-clock Avalon
    # pipeline bridge and let Platform Designer retain width adaptation and
    # arbitration at the 256-bit FPGA-to-LPDDR4 interface.
    add_instance mister_vbuf_bridge altera_avalon_mm_bridge 20.1.0
    set_instance_parameter_value mister_vbuf_bridge DATA_WIDTH 128
    set_instance_parameter_value mister_vbuf_bridge SYMBOL_WIDTH 8
    set_instance_parameter_value mister_vbuf_bridge ADDRESS_UNITS SYMBOLS
    set_instance_parameter_value mister_vbuf_bridge ADDRESS_WIDTH 32
    set_instance_parameter_value mister_vbuf_bridge HDL_ADDR_WIDTH 32
    set_instance_parameter_value mister_vbuf_bridge USE_AUTO_ADDRESS_WIDTH 0
    set_instance_parameter_value mister_vbuf_bridge MAX_BURST_SIZE 16
    set_instance_parameter_value mister_vbuf_bridge MAX_PENDING_RESPONSES 2
    set_instance_parameter_value mister_vbuf_bridge MAX_PENDING_WRITES 0
    set_instance_parameter_value mister_vbuf_bridge PIPELINE_COMMAND 1
    set_instance_parameter_value mister_vbuf_bridge PIPELINE_RESPONSE 1
    set_instance_parameter_value mister_vbuf_bridge SYNC_RESET 1

    add_connection clk_100.out_clk mister_vbuf_bridge.clk
    add_connection rst_in.out_reset mister_vbuf_bridge.reset
    add_connection mister_vbuf_bridge.m0 subsys_hps.f2sdram_adapter_axi4_sub
    set_connection_parameter_value \
        mister_vbuf_bridge.m0/subsys_hps.f2sdram_adapter_axi4_sub baseAddress 0x00000000

    add_interface mister_vbuf avalon slave
    set_interface_property mister_vbuf EXPORT_OF mister_vbuf_bridge.s0
}

proc add_mister_pio {name direction base_address} {
    add_instance $name altera_avalon_pio 19.2.4
    set_instance_parameter_value $name width 32
    set_instance_parameter_value $name direction $direction
    set_instance_parameter_value $name resetValue 0
    set_instance_parameter_value $name bitModifyingOutReg false
    set_instance_parameter_value $name captureEdge 0
    set_instance_parameter_value $name generateIRQ false

    add_connection clk_100.out_clk $name.clk
    add_connection rst_in.out_reset $name.reset
    add_connection subsys_hps.lwhps2fpga $name.s1
    set_connection_parameter_value \
        subsys_hps.lwhps2fpga/$name.s1 baseAddress $base_address

    add_interface $name conduit end
    set_interface_property $name EXPORT_OF $name.external_connection
}

# Keep the existing 128 KiB GHRD peripheral window at 0x00000. These registers
# begin immediately after it in the Agilex lightweight bridge address space.
add_mister_pio mister_gp_out Output 0x00020000
add_mister_pio mister_gp_in  Input  0x00020010

# The FPGA debug master gives bring-up access before ARM64 Main works. The
# pristine GHRD's separate coherent hps_m master remains connected through its
# ACE5-Lite translator and provides full HPS access for recovery diagnostics.
add_connection subsys_debug.fpga_m_master mister_gp_out.s1
set_connection_parameter_value \
    subsys_debug.fpga_m_master/mister_gp_out.s1 baseAddress 0x00020000
add_connection subsys_debug.fpga_m_master mister_gp_in.s1
set_connection_parameter_value \
    subsys_debug.fpga_m_master/mister_gp_in.s1 baseAddress 0x00020010

save_system
