set root [file normalize [file join [file dirname [info script]] ..]]
open_project [file join $root vivado_final lab4_2ASK_final.xpr]

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

set_property -dict [list \
    CONFIG.Sample_Frequency {8.192} \
    CONFIG.Clock_Frequency {32.768} \
    CONFIG.CoefficientSource {COE_File} \
    CONFIG.Coefficient_File [file normalize [file join $root coeff lpf_ask_17tap.coe]] \
    CONFIG.Coefficient_Width {16} \
    CONFIG.Quantization {Integer_Coefficients} \
    CONFIG.Data_Width {12} \
    CONFIG.Output_Rounding_Mode {Full_Precision} \
    CONFIG.Has_ARESETn {true} \
    CONFIG.M_DATA_Has_TREADY {false}] [get_ips fir_lpf_ask]

generate_target all [get_ips ila_ask]
generate_target all [get_ips fir_lpf_ask]
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1
puts "UPDATED: 7-probe ILA and 17-tap 8.192-MHz FIR"
close_project

