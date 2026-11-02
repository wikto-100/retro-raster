if {[catch {
    source [file join [file dirname [info script]] project.tcl]
    set jobs 4
    if {[llength $argv] > 0} { set jobs [lindex $argv 0] }
    if {![string is integer -strict $jobs] || $jobs < 1} {
        error "JOBS must be a positive integer"
    }
    set reports [file join $repo_root build reports]
    set artifacts [file join $repo_root build artifacts]
    file mkdir $reports $artifacts
    reset_run synth_1
    launch_runs impl_1 -to_step route_design -jobs $jobs
    wait_on_run impl_1
    if {![string match {*route_design Complete*} [get_property STATUS [get_runs impl_1]]]} {
        error "Implementation failed: [get_property STATUS [get_runs impl_1]]"
    }
    open_run impl_1
    report_utilization -file [file join $reports utilization.rpt]
    report_clocks -file [file join $reports clocks.rpt]
    report_timing_summary -delay_type min_max -check_timing_verbose \
        -report_unconstrained -file [file join $reports timing.rpt]
    report_drc -upgrade_cw -file [file join $reports drc.rpt]
    if {[llength [get_drc_violations -quiet -filter {SEVERITY == Error || SEVERITY == "Critical Warning"}]] != 0} {
        error "DRC errors found; see build/reports/drc.rpt"
    }
    foreach delay {max min} {
        set paths [get_timing_paths -quiet -delay_type $delay -max_paths 1]
        if {[llength $paths] == 0} { error "No $delay timing paths found" }
        if {[get_property SLACK [lindex $paths 0]] < 0} {
            error "$delay timing failed; see build/reports/timing.rpt"
        }
    }
    write_checkpoint -force [file join $artifacts mimas_hdmi_top_routed.dcp]
    write_bitstream -force [file join $artifacts mimas_hdmi_top.bit]
    puts "Bitstream ready: [file join $artifacts mimas_hdmi_top.bit]"
} message options]} {
    puts stderr [dict get $options -errorinfo]
    exit 1
}
exit 0
