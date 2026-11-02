if {[catch {
    source [file join [file dirname [info script]] project.tcl]
} message options]} {
    puts stderr [dict get $options -errorinfo]
    if {[info exists ::tcl_interactive] && $::tcl_interactive} {
        error $message
    }
    exit 1
}
