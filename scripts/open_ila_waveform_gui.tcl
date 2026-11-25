set root [file normalize [file join [file dirname [info script]] ..]]
set wcfg [file join $root output lab4_ILA_6signals.wcfg]

if {![file exists $wcfg]} {
    error "Missing ILA waveform configuration: $wcfg"
}

open_wave_config $wcfg
puts "ILA_GUI_READY: $wcfg"
