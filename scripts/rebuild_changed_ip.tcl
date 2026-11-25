set root [file normalize [file join [file dirname [info script]] ..]]
open_project [file join $root vivado lab4_2ASK.xpr]

set changed_ips [get_ips {ila_ask fir_lpf_ask}]
reset_target all $changed_ips
generate_target all $changed_ips

set changed_runs [get_runs {ila_ask_synth_1 fir_lpf_ask_synth_1}]
reset_run $changed_runs
launch_runs $changed_runs -jobs 4
foreach run $changed_runs {
    wait_on_run $run
    if {[get_property PROGRESS $run] ne "100%"} {
        error "IP synthesis failed: $run -- [get_property STATUS $run]"
    }
}

puts "CHANGED_IP_REBUILD_PASS: ila_ask=7 probes, fir_lpf_ask=112 taps"
close_project
