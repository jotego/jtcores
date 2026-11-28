# Optional HPS-only design-partition preservation. Unlike the earlier
# Reserved Core study, this partition contains no persona logic and imposes no
# core floorplan. It preserves only the generated HPS/LPDDR subsystem whose
# final implementation defines the HPS I/O compatibility hash.
#
#   DE25_HPS_PARTITION_MODE=source  export the HPS implementation
#   DE25_HPS_PARTITION_MODE=reuse   import that implementation for this core
#
# Source mode exports the final fitted snapshot by default. Set
# DE25_HPS_PARTITION_EXPORT_SNAPSHOT=synthesized to export the synthesized
# HPS netlist instead. Quartus Pro 25.3.1 can hit an internal PTI routing
# consistency error when a final Agilex 5 HPS snapshot is imported into a
# different root design. The synthesized snapshot preserves the common HPS
# netlist and I/O configuration while allowing the fitter to route the whole
# image coherently.
set de25_hps_partition_mode ""
if {[info exists ::env(DE25_HPS_PARTITION_MODE)]} {
    set de25_hps_partition_mode $::env(DE25_HPS_PARTITION_MODE)
}

if {$de25_hps_partition_mode ne ""} {
    set de25_hps_partition_qdb \
        ../artifacts/shell/de25_mister_hps_078a_final.qdb
    if {[info exists ::env(DE25_HPS_PARTITION_QDB)] &&
        $::env(DE25_HPS_PARTITION_QDB) ne ""} {
        set de25_hps_partition_qdb $::env(DE25_HPS_PARTITION_QDB)
    }

    set_instance_assignment -name PARTITION hps_partition -to hps

    # A design-partition boundary exposes the HPS LPDDR4 RZQ input as a pad
    # below `hps`. Quartus no longer propagates the generated EMIF entity's
    # RZQ_PIN_GROUP_NAME assignment to that boundary pad automatically. Read
    # the generated name instead of hard-coding the IP-generated suffix, then
    # apply the same group name to the boundary. This keeps the assignment
    # stable when Platform Designer regenerates the EMIF implementation.
    set de25_hps_emif_qip_glob \
        ip/terasic-ghrd/hps_subsys/ip/qsys_top/emif_io96b_hps/*/synth/ip/*/*lpddr4/*.qip
    set de25_hps_rzq_groups {}
    foreach de25_hps_emif_qip [glob -nocomplain $de25_hps_emif_qip_glob] {
        set de25_hps_qip_fd [open $de25_hps_emif_qip r]
        set de25_hps_qip_text [read $de25_hps_qip_fd]
        close $de25_hps_qip_fd
        if {[regexp -- {-name[ \t]+RZQ_PIN_GROUP_NAME[ \t]+([^ \t\r\n]+)[ \t]+-to[ \t]+"oct_rzqin_0"} \
            $de25_hps_qip_text -> de25_hps_rzq_group]} {
            lappend de25_hps_rzq_groups $de25_hps_rzq_group
        }
    }
    set de25_hps_rzq_groups [lsort -unique $de25_hps_rzq_groups]
    if {[llength $de25_hps_rzq_groups] > 1} {
        post_message -type error \
            "Expected at most one generated HPS EMIF RZQ group, found [llength $de25_hps_rzq_groups]"
        error "HPS EMIF RZQ group is ambiguous"
    }
    if {[llength $de25_hps_rzq_groups] == 1} {
        set_instance_assignment -name RZQ_PIN_GROUP_NAME \
            [lindex $de25_hps_rzq_groups 0] -to {hps|LPDDR4A_RZQ}
    } else {
        # Quartus evaluates this QSF while cleaning and before IP generation,
        # when the generated EMIF QIP intentionally does not exist. Synthesis
        # and fitting re-evaluate the file after quartus_ipgenerate has made
        # the QIP available, which is when the boundary assignment is needed.
        post_message -type info \
            "Generated HPS EMIF RZQ group is not available in this flow stage"
    }

    if {$de25_hps_partition_mode eq "source"} {
        set de25_hps_export_snapshot final
        if {[info exists ::env(DE25_HPS_PARTITION_EXPORT_SNAPSHOT)] &&
            $::env(DE25_HPS_PARTITION_EXPORT_SNAPSHOT) ne ""} {
            set de25_hps_export_snapshot \
                $::env(DE25_HPS_PARTITION_EXPORT_SNAPSHOT)
        }
        if {$de25_hps_export_snapshot eq "final"} {
            set_instance_assignment -name EXPORT_PARTITION_SNAPSHOT_FINAL \
                $de25_hps_partition_qdb -to hps
        } elseif {$de25_hps_export_snapshot eq "synthesized"} {
            set_instance_assignment \
                -name EXPORT_PARTITION_SNAPSHOT_SYNTHESIZED \
                $de25_hps_partition_qdb -to hps
        } else {
            post_message -type error \
                "Invalid DE25_HPS_PARTITION_EXPORT_SNAPSHOT: $de25_hps_export_snapshot"
            error "DE25_HPS_PARTITION_EXPORT_SNAPSHOT must be final or synthesized"
        }
    } elseif {$de25_hps_partition_mode eq "reuse"} {
        if {![file isfile $de25_hps_partition_qdb]} {
            post_message -type error \
                "DE25 HPS partition is missing: $de25_hps_partition_qdb"
            error "DE25 HPS partition is missing"
        }
        set_instance_assignment -name QDB_FILE_PARTITION \
            $de25_hps_partition_qdb -to hps
        # The exported and importing partitions both instantiate the same
        # `mister_hps` entity. ENTITY_REBINDING is only legal when Quartus has
        # imported a Reuse Core or Partial Reconfiguration partition that is
        # intended to bind a different entity, so it must not be applied to
        # this ordinary design-partition import.
    } else {
        post_message -type error \
            "Invalid DE25_HPS_PARTITION_MODE: $de25_hps_partition_mode"
        error "DE25_HPS_PARTITION_MODE must be source or reuse"
    }
}
