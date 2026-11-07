# Require less than a quarter of the 1.347 ns 720p TMDS bit time. Check both
# edges and both differential output polarities at each min/max process corner.
proc check_passthrough {report_file} {
    set limit_ns 0.330
    set report [open $report_file w]
    set failed 0
    foreach corner {Slow Fast} {
        config_timing_corners -corner $corner -delay_type min_max
        set other [expr {$corner eq "Slow" ? "Fast" : "Slow"}]
        config_timing_corners -corner $other -delay_type none
        foreach delay {max min} {
            set delays {}
            foreach {rx tx} {
                hdmi_rx_clk hdmi_tx_clk
                hdmi_rx_0 hdmi_tx_0
                hdmi_rx_1 hdmi_tx_1
                hdmi_rx_2 hdmi_tx_2
            } {
                if {$rx eq "hdmi_rx_clk"} {
                    set input hdmi_rx_clk_p
                    set positive hdmi_tx_clk_p
                    set negative hdmi_tx_clk_n
                } else {
                    set lane [string index $rx end]
                    set input [format {hdmi_rx_p[%s]} $lane]
                    set positive [format {hdmi_tx_p[%s]} $lane]
                    set negative [format {hdmi_tx_n[%s]} $lane]
                }
                foreach edge {rise fall} {
                    foreach polarity {positive negative} {
                        set output [set $polarity]
                        set output_edge $edge
                        if {$polarity eq "negative"} {
                            set output_edge [expr {$edge eq "rise" ? "fall" : "rise"}]
                        }
                        set path [get_timing_paths -quiet -delay_type $delay \
                            -${edge}_from [get_ports $input] \
                            -${output_edge}_to [get_ports $output] -max_paths 1]
                        if {[llength $path] != 1} {
                            close $report
                            error "Missing TMDS path: $corner $delay $edge $input -> $output"
                        }
                        set ns [get_property DATAPATH_DELAY [lindex $path 0]]
                        lappend delays $ns
                        puts $report "$corner $delay $edge $input -> $output: $ns ns"
                    }
                }
            }
            set ordered [lsort -real $delays]
            set skew [expr {[lindex $ordered end] - [lindex $ordered 0]}]
            puts $report [format "%s %s lane/edge delay spread: %.3f ns (limit %.3f ns)" \
                $corner $delay $skew $limit_ns]
            if {$skew > $limit_ns} { set failed 1 }
        }
    }
    config_timing_corners -corner Slow -delay_type min_max
    config_timing_corners -corner Fast -delay_type min_max
    close $report
    if {$failed} { error "720p TMDS delay matching failed; see $report_file" }
}
