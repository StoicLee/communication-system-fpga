set root [file normalize [file join [file dirname [info script]] ..]]
set out [file join $root output]
file mkdir $out

open_project [file join $root vivado_final lab4_2ASK_final.xpr]
update_compile_order -fileset sources_1
# Rebuild the out-of-context FIR checkpoint whenever coefficients change.
reset_run fir_lpf_ask_synth_1
launch_runs fir_lpf_ask_synth_1 -jobs 4
wait_on_run fir_lpf_ask_synth_1
if {![string match "*Complete*" [get_property STATUS [get_runs fir_lpf_ask_synth_1]]]} {
    error "FIR IP synthesis failed: [get_property STATUS [get_runs fir_lpf_ask_synth_1]]"
}
reset_run synth_1
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1

set impl [get_runs impl_1]
if {[get_property PROGRESS $impl] ne "100%" ||
    ![string match "write_bitstream Complete*" [get_property STATUS $impl]]} {
    error "Lab 4 bitstream build failed: [get_property STATUS $impl]"
}

open_run impl_1
report_timing_summary -file [file join $out lab4_timing.rpt]
report_drc -file [file join $out lab4_drc.rpt]
foreach check {setup hold} {
    set failed_paths [get_timing_paths -quiet -$check -slack_lesser_than 0 -max_paths 1]
    if {[llength $failed_paths]} {
        error "Lab 4 failed $check timing; see output/lab4_timing.rpt"
    }
}

set ltx [file join $out lab4_2ASK.ltx]
set bit [file join $out lab4_2ASK.bit]
write_debug_probes -force $ltx
file copy -force [file join [get_property DIRECTORY $impl] lab4_top.bit] $bit
puts "LAB4_BUILD_PASS: $bit and $ltx"
close_project
