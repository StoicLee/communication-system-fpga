set scripts [file dirname [file normalize [info script]]]
source [file join $scripts create_project_final.tcl]
source [file join $scripts build_final.tcl]
