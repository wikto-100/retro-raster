if {[catch {
    source [file join [file dirname [info script]] filter_project.tcl]
    set jobs 4
    if {[llength $argv] > 0} { set jobs [lindex $argv 0] }
    if {![string is integer -strict $jobs] || $jobs < 1} { error "JOBS must be positive" }
    set reports [file join $repo_root build filter reports]
    set artifacts [file join $repo_root build filter artifacts]
    file mkdir $reports $artifacts
    reset_run synth_1
    launch_runs impl_1 -to_step route_design -jobs $jobs
    wait_on_run impl_1
    if {![string match {*route_design Complete*} [get_property STATUS [get_runs impl_1]]]} {
        error "Filter implementation failed: [get_property STATUS [get_runs impl_1]]"
    }
    open_run impl_1
    report_utilization -file [file join $reports utilization.rpt]
    report_clocks -file [file join $reports clocks.rpt]
    report_clock_interaction -file [file join $reports clock_interaction.rpt]
    report_cdc -details -file [file join $reports cdc.rpt]
    puts [exec python3 [file join $repo_root scripts check_filter_cdc.py] [file join $reports cdc.rpt]]
    report_timing_summary -delay_type min_max -check_timing_verbose \
        -report_unconstrained -file [file join $reports timing.rpt]
    report_drc -upgrade_cw -file [file join $reports drc.rpt]
    if {[llength [get_drc_violations -quiet -filter {SEVERITY == Error || SEVERITY == "Critical Warning"}]]} {
        error "Filter DRC failed; see $reports/drc.rpt"
    }
    foreach delay {max min} {
        set paths [get_timing_paths -quiet -delay_type $delay -max_paths 1]
        if {[llength $paths] == 0 || [get_property SLACK [lindex $paths 0]] < 0} {
            error "Filter $delay timing failed; see $reports/timing.rpt"
        }
    }
    # No register may be silently excluded by a missing clock constraint.
    set checks [check_timing -override_defaults {no_clock unconstrained_internal_endpoints} -return_string]
    puts $checks
    if {[regexp {There (are|is) [1-9][0-9]* } $checks]} {
        error "Filter has unconstrained internal timing; see $reports/timing.rpt"
    }
    write_checkpoint -force [file join $artifacts mimas_filter_top_routed.dcp]
    write_bitstream -force [file join $artifacts mimas_filter_top.bit]
    puts "Filter bitstream ready: $artifacts/mimas_filter_top.bit"
} message options]} {
    puts stderr [dict get $options -errorinfo]
    exit 1
}
exit 0
