set root [file normalize [file join [file dirname [info script]] ..]]
open_project [file join $root build lab4_radio.xpr]
open_run impl_1
report_timing -delay_type min -from [get_clocks RX_LAUNCH] -to [get_clocks AD9361_DATACLK] -max_paths 2 -file [file join $root output hold_before.rpt]
set_multicycle_path 0 -hold -end -rise_from [get_clocks RX_LAUNCH] -rise_to [get_clocks AD9361_DATACLK]
set_multicycle_path 0 -hold -end -fall_from [get_clocks RX_LAUNCH] -fall_to [get_clocks AD9361_DATACLK]
report_timing -delay_type min -from [get_clocks RX_LAUNCH] -to [get_clocks AD9361_DATACLK] -max_paths 2 -file [file join $root output hold_after.rpt]
report_methodology -file [file join $root output hold_methodology.rpt]
close_project
