set script_dir [file dirname [file normalize [info script]]]
set root_dir   [file normalize [file join $script_dir ..]]
open_project [file join $root_dir vivado_final lab4_2ASK_final.xpr]
set_property top tb_ask_link [get_filesets sim_1]
set_property xsim.simulate.runtime {0 ns} [get_filesets sim_1]
set simdir [file join $root_dir vivado_final lab4_2ASK_final.sim sim_1 behav xsim]
file delete -force [file join $simdir ask_pass.txt]
launch_simulation

add_wave [get_objects /tb_ask_link/clk_sample]
add_wave [get_objects /tb_ask_link/pn_tx]
add_wave [get_objects /tb_ask_link/carrier]
add_wave [get_objects /tb_ask_link/ask]
add_wave [get_objects /tb_ask_link/rectified]
add_wave [get_objects /tb_ask_link/envelope]
add_wave [get_objects /tb_ask_link/demod]
run -all
if {![file exists [file join $simdir ask_pass.txt]]} { error "XSim self-check did not pass" }
set wcfg_path [file join $root_dir output lab4_core_7signals.wcfg]
file copy -force [file join $root_dir tb lab4_core_7signals.wcfg] $wcfg_path
puts "XSIM_WCFG: $wcfg_path"
set samples [file join $root_dir vivado_final lab4_2ASK_final.sim sim_1 behav xsim ask_samples.csv]
file copy -force $samples [file join $root_dir output xsim_samples.csv]
close_sim -force
close_project
