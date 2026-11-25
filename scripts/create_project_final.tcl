set script_dir [file dirname [file normalize [info script]]]
set root_dir   [file normalize [file join $script_dir ..]]
set proj_dir   [file join $root_dir vivado_final]

file mkdir $proj_dir
create_project lab4_2ASK_final $proj_dir -part xc7z020clg484-1 -force
set_property target_language Verilog [current_project]
set_property simulator_language Mixed [current_project]

add_files -fileset sources_1 [file join $root_dir rtl ask_mod_demod.v]
add_files -fileset sources_1 [file join $root_dir rtl lab4_top.v]
add_files -fileset constrs_1 [file join $root_dir constraints lab4.xdc]
add_files -fileset sim_1 [file join $root_dir rtl ask_mod_demod.v]
add_files -fileset sim_1 [file join $root_dir tb tb_ask_link.sv]

create_ip -name clk_wiz -vendor xilinx.com -library ip -version 6.0 -module_name clk_128M
set_property -dict [list \
    CONFIG.PRIM_IN_FREQ {100.000} \
    CONFIG.PRIM_SOURCE {Single_ended_clock_capable_pin} \
    CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {128.000} \
    CONFIG.NUM_OUT_CLKS {1} \
    CONFIG.USE_LOCKED {true} \
    CONFIG.USE_RESET {false}] [get_ips clk_128M]

create_ip -name clk_wiz -vendor xilinx.com -library ip -version 6.0 -module_name clk_32d768M
set_property -dict [list \
    CONFIG.PRIM_IN_FREQ {128.000} \
    CONFIG.PRIM_SOURCE {No_buffer} \
    CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {32.768} \
    CONFIG.NUM_OUT_CLKS {1} \
    CONFIG.USE_LOCKED {true} \
    CONFIG.USE_RESET {false}] [get_ips clk_32d768M]

create_ip -name ila -vendor xilinx.com -library ip -version 6.2 -module_name ila_ask
set_property -dict [list \
    CONFIG.C_NUM_OF_PROBES {7} \
    CONFIG.C_DATA_DEPTH {4096} \
    CONFIG.C_PROBE0_WIDTH {1} \
    CONFIG.C_PROBE1_WIDTH {1} \
    CONFIG.C_PROBE2_WIDTH {12} \
    CONFIG.C_PROBE3_WIDTH {12} \
    CONFIG.C_PROBE4_WIDTH {12} \
    CONFIG.C_PROBE5_WIDTH {14} \
    CONFIG.C_PROBE6_WIDTH {1}] [get_ips ila_ask]

create_ip -name fir_compiler -vendor xilinx.com -library ip -version 7.2 -module_name fir_lpf_ask
set_property -dict [list \
    CONFIG.Filter_Type {Single_Rate} \
    CONFIG.Sample_Frequency {8.192} \
    CONFIG.Clock_Frequency {32.768} \
    CONFIG.CoefficientSource {COE_File} \
    CONFIG.Coefficient_File [file normalize [file join $root_dir coeff lpf_ask_17tap.coe]] \
    CONFIG.Coefficient_Width {16} \
    CONFIG.Quantization {Integer_Coefficients} \
    CONFIG.Data_Width {12} \
    CONFIG.Output_Rounding_Mode {Full_Precision} \
    CONFIG.Has_ARESETn {true} \
    CONFIG.M_DATA_Has_TREADY {false}] [get_ips fir_lpf_ask]

generate_target all [get_ips]
set_property top lab4_top [get_filesets sources_1]
set_property top tb_ask_link [get_filesets sim_1]
set_property xsim.simulate.runtime {90 us} [get_filesets sim_1]
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1
puts "PROJECT_READY: [file join $proj_dir lab4_2ASK_final.xpr]"
close_project
