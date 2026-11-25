# ============================================================================
# DE2-115 pin assignments used by the DSD tutorials
# Pins checked against the DE2-115 pin tables (UNLV DE2-115_Pin_Table.pdf and
# IFSC wiki "Interfaces de entrada e saida da DE2-115"). Always compare with
# the DE2-115 User Manual.  Like the Intel University Program pin file, no
# I/O standard is set: Quartus uses the Cyclone IV E default (2.5 V), which
# matches the switch / LED banks with the default jumper JP7 setting.
# ============================================================================
set_location_assignment PIN_Y2 -to CLOCK_50

set key_pins {M23 M21 N21 R24}
for {set i 0} {$i < 4} {incr i} { set_location_assignment PIN_[lindex $key_pins $i] -to KEY\[$i\] }

set sw_pins {AB28 AC28 AC27 AD27 AB27 AC26 AD26 AB26 AC25 AB25 AC24 AB24 AB23 AA24 AA23 AA22 Y24 Y23}
for {set i 0} {$i < 18} {incr i} { set_location_assignment PIN_[lindex $sw_pins $i] -to SW\[$i\] }

set ledr_pins {G19 F19 E19 F21 F18 E18 J19 H19 J17 G17 J15 H16 J16 H17 F15 G15 G16 H15}
for {set i 0} {$i < 18} {incr i} { set_location_assignment PIN_[lindex $ledr_pins $i] -to LEDR\[$i\] }

set ledg_pins {E21 E22 E25 E24 H21 G20 G22 G21 F17}
for {set i 0} {$i < 9} {incr i} { set_location_assignment PIN_[lindex $ledg_pins $i] -to LEDG\[$i\] }

# 7-segment displays: index 0..6 = segments a..g (active-low), no DP on this board
set hex_pins {
    {G18 F22 E17 L26 L25 J22 H22}
    {M24 Y22 W21 W22 W25 U23 U24}
    {AA25 AA26 Y25 W26 Y26 W27 W28}
    {V21 U21 AB20 AA21 AD24 AF23 Y19}
    {AB19 AA19 AG21 AH21 AE19 AF19 AE18}
    {AD18 AC18 AB18 AH19 AG19 AF18 AH18}
    {AA17 AB16 AA16 AB17 AB15 AA15 AC17}
    {AD17 AE17 AG17 AH17 AF17 AG18 AA14}
}
for {set h 0} {$h < 8} {incr h} {
    for {set i 0} {$i < 7} {incr i} {
        set_location_assignment PIN_[lindex [lindex $hex_pins $h] $i] -to HEX$h\[$i\]
    }
}
