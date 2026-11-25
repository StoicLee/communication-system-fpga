set root [file normalize [file join [file dirname [info script]] ..]]
set dir [file join $root build]
file mkdir $dir
create_project lab4_radio $dir -part xc7z020clg484-1 -force
set_property target_language Verilog [current_project]
set_property simulator_language Mixed [current_project]
foreach f {AD9361_1RT_FDD.v ask_iq_tx.v ask_iq_rx.v lab4_radio_top.v} {add_files [file join $root rtl $f]}
add_files -fileset constrs_1 [file join $root constraints radio.xdc]
add_files -fileset sim_1 [file join $root tb tb_iq_link.sv]
create_fileset -simset sim_width
add_files -fileset sim_width [file join $root tb tb_iq_width.sv]
set_property top tb_iq_width [get_filesets sim_width]
create_fileset -simset sim_robust
add_files -fileset sim_robust [file join $root tb tb_rx_robust.sv]
set_property top tb_rx_robust [get_filesets sim_robust]
create_fileset -simset sim_interface
add_files -fileset sim_interface [file join $root tb tb_radio_interface.sv]
set_property top tb_iq_link [get_filesets sim_1]
set_property top tb_radio_interface [get_filesets sim_interface]
set_property top lab4_radio_top [get_filesets sources_1]
create_ip -name clk_wiz -vendor xilinx.com -library ip -version 6.0 -module_name clk_radio
set_property -dict [list CONFIG.PRIM_IN_FREQ {100.000} CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {200.000} CONFIG.USE_LOCKED {true} CONFIG.USE_RESET {false}] [get_ips clk_radio]
create_ip -name ila -vendor xilinx.com -library ip -version 6.2 -module_name ila_radio
set_property -dict [list CONFIG.C_NUM_OF_PROBES {9} CONFIG.C_DATA_DEPTH {4096} CONFIG.C_PROBE0_WIDTH {1} CONFIG.C_PROBE1_WIDTH {12} CONFIG.C_PROBE2_WIDTH {12} CONFIG.C_PROBE3_WIDTH {12} CONFIG.C_PROBE4_WIDTH {12} CONFIG.C_PROBE5_WIDTH {13} CONFIG.C_PROBE6_WIDTH {1} CONFIG.C_PROBE7_WIDTH {1} CONFIG.C_PROBE8_WIDTH {1}] [get_ips ila_radio]
generate_target all [get_ips]
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1
update_compile_order -fileset sim_interface
update_compile_order -fileset sim_robust
update_compile_order -fileset sim_width
puts "RADIO_PROJECT_READY: [file join $dir lab4_radio.xpr]"
close_project
