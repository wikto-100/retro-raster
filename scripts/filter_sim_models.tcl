# Generate Verilog functional models of the two VHDL cores. This exercises
# the synthesized logic with full UNISIM primitives, without the large cost
# of the VHDL VITAL models for every bit in several complete 720p frames.
if {[catch {
    set repo_root [file normalize [file join [file dirname [info script]] ..]]
    source [file join $repo_root scripts filter_sources.tcl]
    set output [file join $repo_root build filter sim models]
    file mkdir $output
    create_project -in_memory -part xc7a50tfgg484-1
    foreach path $filter_vhdl_relative {
        read_vhdl -vhdl2008 [file join $repo_root $path]
    }
    foreach top {hdmi_rx hdmi_tx} {
        synth_design -top $top -part xc7a50tfgg484-1 -mode out_of_context -flatten_hierarchy full
        write_verilog -force -mode funcsim [file join $output $top.v]
        close_design
    }
    puts "Filter functional models ready: $output"
} message options]} {
    puts stderr [dict get $options -errorinfo]
    exit 1
}
exit 0
