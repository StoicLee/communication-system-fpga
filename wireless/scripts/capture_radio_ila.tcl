# Explicitly programs the wireless candidate bitstream, then captures its ILA.
# Run only after board power, JTAG and AD9361 configuration are ready.
set root [file normalize [file join [file dirname [info script]] ..]]
set out [file join $root output]
set bit [file join $out lab4_radio.bit]
set ltx [file join $out lab4_radio.ltx]
if {![file exists $bit] || ![file exists $ltx]} {error "Missing matching wireless bit/ltx in $out"}
open_hw_manager
connect_hw_server -allow_non_jtag
set targets [get_hw_targets -quiet *]
if {[llength $targets] != 1} {error "Expected one JTAG target, found [llength $targets]"}
open_hw_target [lindex $targets 0]
set devices [get_hw_devices -quiet xc7z020*]
if {[llength $devices] != 1} {error "Expected one xc7z020 FPGA, found [llength $devices]"}
set device [lindex $devices 0]
current_hw_device $device
set_property PROGRAM.FILE $bit $device
set_property PROBES.FILE $ltx $device
program_hw_devices $device
refresh_hw_device $device
set ilas [get_hw_ilas -quiet -of_objects $device]
if {[llength $ilas] != 1} {error "Expected one ILA, found [llength $ilas]"}
set ila [lindex $ilas 0]
puts "ILA probes: [join [get_property NAME [get_hw_probes -of_objects $ila]] {, }]"
set_property CONTROL.TRIGGER_POSITION 1024 $ila
run_hw_ila -trigger_now $ila
if {[catch {wait_on_hw_ila -timeout 0.5 $ila} reason]} {
    error "ILA capture timed out or failed: $reason. Check AD9361 configuration and sample clock."
}
set data [upload_hw_ila_data $ila]
write_hw_ila_data -force [file join $out radio_ila_capture.ila] $data
write_hw_ila_data -force -csv_file [file join $out radio_ila_capture.csv] $data
write_hw_ila_data -force -vcd_file [file join $out radio_ila_capture.vcd] $data
puts "Capture saved to $out/radio_ila_capture.{ila,csv,vcd}"
puts "Open the .ila in Vivado, or run: python wireless/scripts/plot_radio_ila.py --source hardware"
close_hw_manager
