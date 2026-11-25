set root [file normalize [file join [file dirname [info script]] ..]]
open_project [file join $root build lab4_radio.xpr]
launch_runs synth_1 -jobs 4
wait_on_run synth_1
set run [get_runs synth_1]
if {![string match "*Complete*" [get_property STATUS $run]]} {error "Radio synthesis failed: [get_property STATUS $run]"}
open_run synth_1
report_utilization -file [file join $root output radio_utilization_synth.rpt]
report_drc -file [file join $root output radio_drc_synth.rpt]
puts "RADIO_SYNTH_PASS"
close_project
