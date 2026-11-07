set repo_root [file normalize [file join [file dirname [info script]] ..]]
set project_dir [file join $repo_root build filter project]
set project_file [file join $project_dir mimas_filter.xpr]
set fpga_part xc7a50tfgg484-1
if {[llength [get_parts -quiet $fpga_part]] != 1} { error "Missing device $fpga_part" }
if {[llength [get_projects -quiet]] == 0} {
    if {[file exists $project_file]} { open_project $project_file } else {
        create_project mimas_filter $project_dir -part $fpga_part
    }
}
if {[get_property PART [current_project]] ne $fpga_part ||
    [file normalize [get_property DIRECTORY [current_project]]] ne $project_dir} {
    error "Close the unrelated project before opening the filter project"
}
source [file join $repo_root scripts filter_sources.tcl]
set sources {}
foreach path [concat $filter_vhdl_relative $filter_sv_relative] {
    lappend sources [file join $repo_root $path]
}
foreach path $sources {
    if {[llength [get_files -quiet $path]] == 0} { add_files -norecurse $path }
    if {[file extension $path] eq ".vhd"} {
        set_property file_type {VHDL 2008} [get_files $path]
    }
}
set_property target_language Verilog [current_project]
set_property simulator_language Mixed [current_project]
set_property top mimas_filter_top [get_filesets sources_1]
set xdc [file join $repo_root constraints mimas_a7_v3_filter.xdc]
if {[llength [get_files -quiet $xdc]] == 0} {
    add_files -fileset constrs_1 -norecurse $xdc
}
update_compile_order -fileset sources_1
puts "Filter project ready: $project_file"
