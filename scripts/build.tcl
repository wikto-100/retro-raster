# Implement, check timing and DRC, write the bitstream.
if {[catch {
    source [file join [file dirname [info script]] project.tcl]
    set jobs [expr {[llength $argv] > 0 ? [lindex $argv 0] : 4}]
    set out [file join $repo_root build]
    reset_run synth_1
    launch_runs impl_1 -to_step route_design -jobs $jobs
    wait_on_run impl_1
    if {![string match {*route_design Complete*} [get_property STATUS [get_runs impl_1]]]} {
        error "Implementation failed: [get_property STATUS [get_runs impl_1]]"
    }
    open_run impl_1
    report_timing_summary -report_unconstrained -file [file join $out timing.rpt]
    report_drc -file [file join $out drc.rpt]
    if {[llength [get_drc_violations -quiet -filter {SEVERITY == Error || SEVERITY == "Critical Warning"}]]} {
        error "DRC failed; see build/drc.rpt"
    }
    foreach delay {max min} {
        set paths [get_timing_paths -quiet -delay_type $delay -max_paths 1]
        if {[llength $paths] == 0 || [get_property SLACK [lindex $paths 0]] < 0} {
            error "$delay timing failed; see build/timing.rpt"
        }
    }
    write_bitstream -force [file join $out retro_raster.bit]
    puts "Bitstream ready: build/retro_raster.bit"
} message options]} {
    puts stderr [dict get $options -errorinfo]
    exit 1
}
exit 0
