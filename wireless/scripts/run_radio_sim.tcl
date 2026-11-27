set root [file normalize [file join [file dirname [info script]] ..]]
open_project [file join $root build lab4_radio.xpr]
if {[llength [get_filesets -quiet sim_width]] == 0} {create_fileset -simset sim_width}
set width_tb [file join $root tb tb_iq_width.sv]
if {[llength [get_files -quiet -of_objects [get_filesets sim_width] $width_tb]] == 0} {add_files -fileset sim_width $width_tb}
set_property top tb_iq_width [get_filesets sim_width]
update_compile_order -fileset sim_width
if {[llength [get_filesets -quiet sim_robust]] == 0} {create_fileset -simset sim_robust}
set tb [file join $root tb tb_rx_robust.sv]
if {[llength [get_files -quiet -of_objects [get_filesets sim_robust] $tb]] == 0} {add_files -fileset sim_robust $tb}
set_property top tb_rx_robust [get_filesets sim_robust]
update_compile_order -fileset sim_robust
foreach spec {{sim_1 wireless_pass.txt} {sim_interface radio_interface_pass.txt} {sim_robust rx_robust_pass.txt} {sim_width iq_width_pass.txt}} {
 lassign $spec setname marker
 set simdir [file join $root build lab4_radio.sim $setname behav xsim]
 file delete -force [file join $simdir $marker]
 set_property xsim.simulate.runtime {0 ns} [get_filesets $setname]
 launch_simulation -simset $setname
 run -all
 if {![file exists [file join $simdir $marker]]} {error "$setname self-check failed"}
 close_sim -force
 if {$setname eq "sim_1"} {
  foreach name {wireless_samples.csv radio_ila_sim.csv} {file copy -force [file join $simdir $name] [file join $root output $name]}
 }
 puts "RADIO_TEST_PASS: $setname"
}
close_project
