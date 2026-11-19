# Audit the fitted MiSTer capture clock crossings in an independent timing view.
# The fitter and its ordinary SDC are never modified.  The effective SDC is
# replayed with path exceptions suppressed, then checked against its clocks.
proc clocks {} {
    set result [dict create]
    foreach_in_collection c [get_clocks *] {
        dict set result [get_clock_info $c -name] [list \
            [get_clock_info $c -period] [get_clock_info $c -waveform] \
            [get_clock_info $c -latency -min -rise] [get_clock_info $c -latency -max -rise] [get_clock_info $c -latency -min -fall] [get_clock_info $c -latency -max -fall]]
    }
    return $result
}
proc required_nodes {pattern} {
    set result [get_keepers -nowarn $pattern]
    if {[get_collection_size $result] == 0} { error "missing CDC anchor: $pattern" }
    return $result
}
proc worst_path {kind args} {
    set paths [get_timing_paths -$kind {*}$args -npaths 1]
    if {[get_collection_size $paths] != 1} { error "missing $kind timing path: $args" }
    foreach_in_collection path $paths {
        set slack [get_path_info $path -slack]
        if {![string is double -strict $slack] || [catch {expr {abs($slack) < Inf}} finite] || !$finite} { error "invalid $kind slack: $slack" }
        return [list $slack [get_clock_info [get_path_info $path -from_clock] -name] [get_clock_info [get_path_info $path -to_clock] -name]]
    }
    error "empty $kind timing collection"
}
proc anchor_clocks {src dst} {
    set p [worst_path setup -from $src -to $dst]
    lassign $p ignored from to
    if {$from eq "" || $to eq ""} { error "unclocked CDC anchor" }
    return [list $from $to]
}
proc check_stage {label first second} {
    set allowed [dict create]
    foreach_in_collection node $second { dict set allowed [get_node_info $node -name] 1 }
    set fanouts [get_fanouts $first]
    if {[get_collection_size $fanouts] == 0} { error "missing $label synchronizer fanout" }
    foreach_in_collection node $fanouts {
        set name [get_node_info $node -name]
        if {![dict exists $allowed $name]} { error "unexpected $label F1 fanout: $name" }
    }
    check_pairs $label $first $second "" "" 1
}
# Quartus may clone a register to reduce fanout (seed dependent).  A clone
# keeps the logical register's name plus a ~DUPLICATE[n] suffix.
proc logical_name {name} {
    regsub {~DUPLICATE[0-9]*$} $name {} name
    return $name
}
proc logical_names {nodes} {
    set result [dict create]
    foreach_in_collection node $nodes { dict set result [logical_name [get_node_info $node -name]] 1 }
    return $result
}
# Inspect every surviving launch/latch pair, including duplicate registers.
# Full coverage requires every logical source register and every physical
# destination register: a source clone may serve only same-domain logic, while
# clock-wide extrema still bound the timing of every physical copy.
proc check_pairs {label from to expected_from expected_to require_all} {
    set paths [get_timing_paths -setup -from $from -to $to -npaths 0 -pairs_only]
    if {[get_collection_size $paths] == 0} { error "missing $label paths" }
    array set seen_from {}; array set seen_to {}
    foreach_in_collection path $paths {
        set source [logical_name [get_node_info [get_path_info $path -from] -name]]
        set target [get_node_info [get_path_info $path -to] -name]
        set fc [get_clock_info [get_path_info $path -from_clock] -name]
        set tc [get_clock_info [get_path_info $path -to_clock] -name]
        if {$fc eq "" || $tc eq ""} { error "unclocked $label path" }
        if {$expected_from ne "" && ($fc ne $expected_from || $tc ne $expected_to)} {
            error "unexpected $label clocks: $fc -> $tc"
        }
        set seen_from($source) 1; set seen_to($target) 1
    }
    if {$require_all && ([array size seen_from] != [dict size [logical_names $from]] ||
                        [array size seen_to] != [get_collection_size $to])} {
        error "uncovered $label endpoints"
    }
}
# write_sdc emits commands in canonical Tcl form.  Replay only documented
# clock directives and discard known path exceptions; reject anything else.
proc replay_clocks {path} {
    set input [open $path r]
    set contents [read $input]; close $input
    set command ""
    foreach line [split $contents "\n"] {
        if {$command eq "" && ([string trim $line] eq "" || [string match "#*" [string trimleft $line]])} continue
        append command $line "\n"
        if {![info complete $command]} continue
        if {[string first ";" $command] >= 0 || ![regexp {^[ \t]*([A-Za-z_][A-Za-z_0-9]*)} $command -> operation]} {
            error "unrecognized effective SDC command"
        }
        switch -- $operation {
            create_clock - create_generated_clock - derive_pll_clocks - derive_clock_uncertainty -
            set_time_format - set_clock_latency - set_clock_uncertainty - set_clock_transition {
                uplevel #0 $command
            }
            set_clock_groups - set_false_path - set_max_delay - set_min_delay - set_multicycle_path -
            set_input_delay - set_output_delay { }
            default { error "unsupported effective SDC command: $operation" }
        }
        set command ""
    }
    if {[string trim $command] ne ""} { error "incomplete effective SDC" }
}
# Quartus may clone a toggle register to reduce fanout.  Require a
# correctly clocked same-index source path to every F1 and both logical bits;
# timing extrema cover every physical copy, including copies used elsewhere.
proc check_half_routes {from to fc tc} {
    set targets [dict create]
    foreach_in_collection n $to {dict set targets [get_node_info $n -name] 0}
    set paths [get_timing_paths -setup -from $from -to $to -npaths 0 -pairs_only]
    array set bits {0 0 1 0}
    foreach_in_collection p $paths {
        set s [get_node_info [get_path_info $p -from] -name]
        set d [get_node_info [get_path_info $p -to] -name]
        if {![regexp {\|cap_half_req_toggle_i\[([01])\](~DUPLICATE[0-9]*)?$} $s -> sb] ||
            ![regexp {\|cap_half_req_sync1_o\[([01])\](~DUPLICATE[0-9]*)?$} $d -> db] ||
            $sb ne $db || [get_clock_info [get_path_info $p -from_clock] -name] ne $fc ||
            [get_clock_info [get_path_info $p -to_clock] -name] ne $tc} {
            error "invalid half control path: $s -> $d"
        }
        set bits($sb) 1
        dict set targets $d 1
    }
    if {!$bits(0) || !$bits(1)} {error "missing logical half control path"}
    dict for {name covered} $targets {if {!$covered} {error "uncovered half F1: $name"}}
}
proc check_half_bits {label nodes} {
    array set bits {0 0 1 0}
    foreach_in_collection node $nodes {
        set name [get_node_info $node -name]
        if {![regexp {\[([01])\]} $name -> bit]} { error "unexpected $label bit: $name" }
        set bits($bit) 1
    }
    if {!$bits(0) || !$bits(1)} { error "missing $label half bit" }
}
proc check_sync {name clock args} {
    foreach kind {setup hold} {
        set path [worst_path $kind -from_clock $clock -to_clock $clock {*}$args]
        set slack [lindex $path 0]
        puts "CDC synchronous $name $kind slack=$slack"
        if {$slack < 0} { error "CDC synchronous $name $kind violation: $slack" }
    }
}
set revision [lindex $quartus(args) 0]
if {$revision eq "" || [llength $quartus(args)] != 1} { error "expected Quartus revision" }
set qsf "${revision}.qsf"
if {![file isfile $qsf] || ![file readable $qsf]} { error "missing fitted QSF: $qsf" }
set tmp ".jtframe-cdc-[pid].sdc"
set status [catch {
    project_open $revision -revision $revision
    set macros [dict create]
    foreach_in_collection assignment [get_all_global_assignments -name VERILOG_MACRO] {
        set value [string trim [lindex $assignment 2]]
        if {[string index $value 0] eq "{" && [string index $value end] eq "}"} {
            set value [string range $value 1 end-1]
        }
        dict set macros [lindex [split $value =] 0] 1
    }
    set regression_active [expr {[dict exists $macros JTFRAME_REGRESSION] && ![dict exists $macros MISTER_DEBUG_NOHDMI]}]
    set capture_active [expr {$regression_active && ![dict exists $macros JTFRAME_CRT480I] && ![dict exists $macros JTFRAME_INTERLACED]}]
    create_timing_netlist -model slow
    set cab_present [expr {[get_collection_size [get_keepers -nowarn {*u_cab_stream*|snapshot*}]] > 0}]
    set capture_present [expr {[get_collection_size [get_keepers -nowarn {*cap_half_req_toggle_i*}]] > 0}]
    if {$cab_present != $regression_active || $capture_present != $capture_active} {
        error "effective macros and fitted regression/capture structures disagree"
    }
    if {!$regression_active} {
        delete_timing_netlist
        project_close
        puts "CDC audit skipped: regression logic is not built"
        puts "JTFRAME_CDC SKIP"
        exit 0
    }
    read_sdc
    update_timing_netlist
    set normal_clocks [clocks]
    write_sdc $tmp
    delete_timing_netlist
    create_timing_netlist -model slow
    # Reconstruct only clock definitions in this independent analysis.
    replay_clocks $tmp
    update_timing_netlist
    set audit_clocks [clocks]
    if {$normal_clocks ne $audit_clocks} { error "CDC audit clock replay differs from fitted project" }
    if {!$capture_active} {
        # CAB remains enabled in interlaced configurations; both interfaces
        # use the same clock and require ordinary one-cycle timing.
        set cab_src [required_nodes {*u_cab_stream*|snapshot*}]
        set cab_dst [required_nodes {*u_uio_transport*|response_word*}]
        lassign [anchor_clocks $cab_src $cab_dst] cab_launch cab_latch
        check_pairs cab_data $cab_src $cab_dst $cab_launch $cab_latch 0
        if {$cab_launch ne $cab_latch} { error "CAB clocks differ in capture-disabled build" }
        set cab_clock [get_clocks $cab_launch]
        set frame [required_nodes {*g_regression.u_uio_transport* *g_regression.u_cab_bridge*}]
        set conditions [get_available_operating_conditions]
        if {[llength $conditions] == 0} { error "no timing operating conditions" }
        foreach condition $conditions {
            set_operating_conditions $condition
            update_timing_netlist
            puts "CDC operating condition: $condition"
            check_sync cab $cab_clock -to $frame
        }
    } else {
    set half_src [required_nodes {*cap_half_req_toggle_i*}]
    set half_f1 [required_nodes {*cap_half_req_sync1_o*}]
    set half_f2 [required_nodes {*cap_half_req_sync2_o*}]
    set drain_src [required_nodes {*cap_drain_ack_avl*}]
    set drain_f1 [required_nodes {*cap_drain_ack_sync1_i*}]
    set drain_f2 [required_nodes {*cap_drain_ack_sync2_i*}]
    set req_src [required_nodes {*cap_drain_toggle_i*}]
    set req_f1 [required_nodes {*cap_drain_req_sync1_avl*}]
    set req_f2 [required_nodes {*cap_drain_req_sync2_avl*}]
    set fault_src [required_nodes {*cap_fault_mailbox_toggle_avl*}]
    set fault_f1 [required_nodes {ascal:ascal|cap_fault_mailbox_toggle_sync1_i}]
    set fault_f2 [required_nodes {ascal:ascal|cap_fault_mailbox_toggle_sync2_i}]
    set faultio_f1 [required_nodes {ascal:ascal|cap_fault_mailbox_toggle_sync1_io}]
    set faultio_f2 [required_nodes {ascal:ascal|cap_fault_mailbox_toggle_sync2_io}]
    check_stage half $half_f1 $half_f2
    check_stage drain_request $req_f1 $req_f2
    check_stage drain_ack $drain_f1 $drain_f2
    check_stage fault $fault_f1 $fault_f2
    check_stage fault_io $faultio_f1 $faultio_f2
    check_half_bits half_source $half_src
    check_half_bits half_f1 $half_f1
    check_half_bits half_f2 $half_f2
    lassign [anchor_clocks $half_src $half_f1] game_name avl_name
    lassign [anchor_clocks $drain_src $drain_f1] drain_name input_name
    if {$game_name ne $input_name || $avl_name ne $drain_name || $game_name eq $avl_name} {
        error "unexpected CDC clock pairing"
    }
    if {[anchor_clocks $req_src $req_f1] ne [list $game_name $avl_name] ||
        [anchor_clocks $fault_src $fault_f1] ne [list $avl_name $game_name] ||
        [anchor_clocks $fault_src $faultio_f1] ne [list $avl_name $game_name]} {
        error "unexpected mailbox clock pairing"
    }
    foreach triple [list [list half $half_src $half_f1 $game_name $avl_name] \
                         [list request $req_src $req_f1 $game_name $avl_name] \
                         [list drain $drain_src $drain_f1 $avl_name $game_name] \
                         [list fault $fault_src $fault_f1 $avl_name $game_name] \
                         [list fault_io $fault_src $faultio_f1 $avl_name $game_name]] {
        lassign $triple label from to fc tc
        # A single Avalon toggle may be duplicated separately for the two
        # consumers; each consumer is checked, while clock-wide extrema cover
        # all duplicate launch registers.
        if {$label eq "half"} {
            check_half_routes $from $to $fc $tc
        } else {
            set all [expr {$label ne "fault" && $label ne "fault_io"}]
            check_pairs $label $from $to $fc $tc $all
        }
    }
    set cab_src [required_nodes {*u_cab_stream*|snapshot*}]
    set cab_dst [required_nodes {*u_uio_transport*|response_word*}]
    check_pairs cab_data $cab_src $cab_dst $game_name $game_name 0
    set descriptor [required_nodes {*cap_target_expected_count_i* *cap_target_header_i* *cap_crc_state_i*}]
    set consumers [required_nodes {*u_uio_transport*|response_word* *u_capture_io*|first_fault* *u_capture_io*|result_valid*}]
    check_pairs descriptor $descriptor $consumers $game_name $game_name 0
    foreach stage [list [list half $half_f1 $half_f2 $avl_name] \
                        [list request $req_f1 $req_f2 $avl_name] \
                        [list drain $drain_f1 $drain_f2 $game_name] \
                        [list fault $fault_f1 $fault_f2 $game_name] \
                        [list fault_io $faultio_f1 $faultio_f2 $game_name]] {
        lassign $stage label from to clock
        check_pairs ${label}_stage $from $to $clock $clock 1
    }
    set game [get_clocks $game_name]
    set avl [get_clocks $avl_name]
    if {[get_collection_size $game] != 1 || [get_collection_size $avl] != 1} { error "ambiguous CDC clock" }
    set ascal [required_nodes {ascal:ascal|*}]
    set frame [required_nodes {*g_regression.u_uio_transport* *g_regression.u_cab_bridge* *g_capture.u_capture_io*}]
    set dirs [list [list input_to_avl $game $avl] [list avl_to_input $avl $game]]
    foreach d $dirs {
        lassign $d label from to
        # Whole-clock-pair extrema are conservative supersets: they cover
        # every physical launch/control path, including merged registers.
        set_max_delay -from $from -to $to 0
        set_min_delay -from $from -to $to 0
        set data_min($label) Inf
        set ctrl_min($label) Inf
        set period($label) [get_clock_info $to -period]
        if {![string is double -strict $period($label)] || [catch {expr {abs($period($label)) < Inf}} finite] || !$finite || $period($label) <= 0} { error "invalid clock period" }
    }
    set conditions [get_available_operating_conditions]
    if {[llength $conditions] == 0} { error "no timing operating conditions" }
    foreach condition $conditions {
        set_operating_conditions $condition
        update_timing_netlist
        puts "CDC operating condition: $condition"
        foreach d $dirs {
            lassign $d label from to
            set dp [worst_path setup -from_clock $from -to_clock $to]
            set cp [worst_path hold -from_clock $from -to_clock $to]
            set ds [lindex $dp 0]
            set cs [lindex $cp 0]
            if {$ds < $data_min($label)} {set data_min($label) $ds}
            if {$cs < $ctrl_min($label)} {set ctrl_min($label) $cs}
            puts "CDC $label setup0=$ds hold0=$cs period=$period($label)"
        }
        # The first two stages and their consumers must themselves meet
        # normal same-clock timing for the two-edge handshake bound.
        check_sync game_ascal $game -to $ascal
        check_sync game_frame $game -to $frame
        check_sync avl_ascal $avl -from $ascal -to $ascal
        check_sync half_sync $avl -from $half_f1 -to $half_f2
        check_sync drain_sync $game -from $drain_f1 -to $drain_f2
        check_sync request_sync $avl -from $req_f1 -to $req_f2
        check_sync fault_sync $game -from $fault_f1 -to $fault_f2
        check_sync faultio_sync $game -from $faultio_f1 -to $faultio_f2
    }
    foreach d $dirs {
        lassign $d label from to
        # F1 can sample immediately; a sequential consumer first observes F2
        # two destination periods later.  Independent extrema from all corners
        # conservatively include both clock trees, FF arcs and uncertainty.
        set margin [expr {2.0*$period($label) + $data_min($label) + $ctrl_min($label)}]
        puts "CDC $label conservative margin=$margin ns"
        if {$margin < 0} { error "CDC $label timing bound violated: $margin ns" }
    }
    }
    delete_timing_netlist
    project_close
} message options]
file delete -force $tmp
if {$status} { puts stderr "CDC audit failed: $message"; exit 1 }
puts "CDC audit passed"
puts "JTFRAME_CDC PASS"
