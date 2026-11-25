set root [file normalize [file join [file dirname [info script]] ..]]
set out [file join $root output]
file mkdir $out
open_project [file join $root build lab4_radio.xpr]
reset_run synth_1
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1
set run [get_runs impl_1]
if {[get_property PROGRESS $run] ne "100%" || ![string match "write_bitstream Complete*" [get_property STATUS $run]]} {
 error "Radio implementation failed: [get_property STATUS $run]"
}
open_run impl_1
report_timing_summary -report_unconstrained -file [file join $out radio_timing.rpt]
report_drc -file [file join $out radio_drc.rpt]
report_methodology -file [file join $out radio_methodology.rpt]
report_clock_interaction -file [file join $out radio_clock_interaction.rpt]
report_route_status -file [file join $out radio_route_status.rpt]
check_timing -verbose -file [file join $out radio_check_timing.rpt]
report_utilization -file [file join $out radio_utilization.rpt]
set bit [file join $out lab4_radio.bit]
set ltx [file join $out lab4_radio.ltx]
write_debug_probes -force $ltx
file copy -force [file join [get_property DIRECTORY $run] lab4_radio_top.bit] $bit
foreach check {setup hold} {
 if {[llength [get_timing_paths -quiet -$check -slack_lesser_than 0 -max_paths 1]]} {
  error "Radio $check timing failed; bit and ltx are experimental only; see radio_timing.rpt"
 }
}
puts "RADIO_IMPL_PASS: $bit ; $ltx"
close_project
