# ============================================================================
# DE10-Lite pin assignments used by the DSD tutorials (source in Quartus:
#   Tools > Tcl Scripts..., or  "source de10_lite_pins.tcl"  in the Tcl console)
# Pins checked against the DE10-Lite tables (UF EEL3701 DE10-Lite_Pins.pdf and
# ULPGC DE10-Lite-info).  Always compare with your board's user manual.
# ============================================================================
set_location_assignment PIN_P11 -to MAX10_CLK1_50
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to MAX10_CLK1_50

set key_pins {B8 A7}
for {set i 0} {$i < 2} {incr i} {
    set_location_assignment PIN_[lindex $key_pins $i] -to KEY\[$i\]
    set_instance_assignment -name IO_STANDARD "3.3 V SCHMITT TRIGGER" -to KEY\[$i\]
}
set sw_pins {C10 C11 D12 C12 A12 B12 A13 A14 B14 F15}
for {set i 0} {$i < 10} {incr i} {
    set_location_assignment PIN_[lindex $sw_pins $i] -to SW\[$i\]
    set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to SW\[$i\]
}
set led_pins {A8 A9 A10 B10 D13 C13 E14 D14 A11 B11}
for {set i 0} {$i < 10} {incr i} {
    set_location_assignment PIN_[lindex $led_pins $i] -to LEDR\[$i\]
    set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to LEDR\[$i\]
}
# 7-segment displays: index 0..6 = segments a..g, index 7 = DP (all active-low)
set hex_pins {
    {C14 E15 C15 C16 E16 D17 C17 D15}
    {C18 D18 E18 B16 A17 A18 B17 A16}
    {B20 A20 B19 A21 B21 C22 B22 A19}
    {F21 E22 E21 C19 C20 D19 E17 D22}
    {F18 E20 E19 J18 H19 F19 F20 F17}
    {J20 K20 L18 N18 M20 N19 N20 L19}
}
for {set h 0} {$h < 6} {incr h} {
    for {set i 0} {$i < 8} {incr i} {
        set_location_assignment PIN_[lindex [lindex $hex_pins $h] $i] -to HEX$h\[$i\]
        set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to HEX$h\[$i\]
    }
}
