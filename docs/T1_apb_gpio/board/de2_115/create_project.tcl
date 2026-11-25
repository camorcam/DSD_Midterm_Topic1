# ============================================================================
# Creates and compiles the Quartus project:   quartus_sh -t create_project.tcl
# (or open Quartus > Tools > Tcl Scripts and run this file)
# ============================================================================
load_package flow
set name t1_apb_gpio_de2_115
project_new $name -overwrite
set_global_assignment -name FAMILY "Cyclone IV E"
set_global_assignment -name DEVICE EP4CE115F29C7
set_global_assignment -name TOP_LEVEL_ENTITY de2_115_top
foreach f {sync_2ff edge_detect rst_sync byte_reg gpio_irq apb_gpio apb_master
           gpio_demo_seq pulse_stretch hex7seg gpio_system} {
    set_global_assignment -name VERILOG_FILE ../../rtl/$f.v
}
set_global_assignment -name VERILOG_FILE de2_115_top.v
set_global_assignment -name SDC_FILE de2_115.sdc
set_global_assignment -name RESERVE_ALL_UNUSED_PINS_WEAK_PULLUP "AS INPUT TRI-STATED"
source de2_115_pins.tcl
execute_flow -compile
project_close
