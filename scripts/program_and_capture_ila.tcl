set root [file normalize [file join [file dirname [info script]] ..]]
set out  [file join $root output]
set bit  [file join $out lab4_2ASK.bit]
set ltx  [file join $out lab4_2ASK.ltx]

if {![file exists $bit] || ![file exists $ltx]} {
    error "Missing bit/ltx in $out"
}

open_hw_manager
connect_hw_server -allow_non_jtag

# A newly launched hw_server may need a few seconds to enumerate the USB/JTAG
# cable.  Poll explicitly so a harmless startup race does not abort the run.
set targets {}
for {set retry 0} {$retry < 8} {incr retry} {
    set targets [get_hw_targets -quiet *]
    if {[llength $targets] > 0} {
        break
    }
    puts "Waiting for JTAG target ([expr {$retry + 1}]/8)..."
    after 3000
}
if {[llength $targets] == 0} {
    error "NO_JTAG_TARGET: power the board and reconnect the SOC-JTAG USB cable"
}
open_hw_target [lindex $targets 0]

set devices [get_hw_devices -quiet]
if {[llength $devices] == 0} {
    error "NO_JTAG_DEVICE: power the board and connect the SOC-JTAG USB cable"
}

set fpga_devices [get_hw_devices -quiet xc7z020*]
if {[llength $fpga_devices] != 1} {
    error "Expected one xc7z020 FPGA node, found: [join $devices {, }]"
}
set device [lindex $fpga_devices 0]
current_hw_device $device
set_property PROGRAM.FILE $bit $device
set_property PROBES.FILE  $ltx $device
program_hw_devices $device
refresh_hw_device $device

set ilas [get_hw_ilas -quiet -of_objects $device]
if {[llength $ilas] != 1} {
    error "Expected exactly one ILA, found [llength $ilas]"
}

set ila [lindex $ilas 0]
set_property CONTROL.TRIGGER_POSITION 1024 $ila
run_hw_ila -trigger_now $ila
wait_on_hw_ila $ila
set data [upload_hw_ila_data $ila]

write_hw_ila_data -force [file join $out lab4_ila_capture.ila] $data
write_hw_ila_data -force -csv_file [file join $out lab4_ila_capture.csv] $data
write_hw_ila_data -force -vcd_file [file join $out lab4_ila_capture.vcd] $data

if {[catch {exec python [file join $root scripts plot_ila_period.py] [file join $out lab4_ila_capture.csv]} plot_result]} {
    error "ILA capture saved, but period alignment failed: $plot_result"
}
puts $plot_result

puts "JTAG_DEVICE: [get_property NAME $device]"
puts "ILA_CORE: [get_property CELL_NAME $ila]"
puts "ILA_PROBES: [join [get_property NAME [get_hw_probes -of_objects $ila]] {, }]"
puts "ILA_CAPTURE_PASS: [file join $out lab4_ila_capture.ila]"
close_hw_manager
