# ============================================================================
# Creates and compiles the Quartus project:   quartus_sh -t create_project.tcl
# (or open Quartus > Tools > Tcl Scripts and run this file)
# ============================================================================
load_package flow
set name t14_axil_slave_de10_lite
project_new $name -overwrite
set_global_assignment -name FAMILY "MAX 10"
set_global_assignment -name DEVICE 10M50DAF484C7G
set_global_assignment -name TOP_LEVEL_ENTITY de10_lite_top
foreach f {sync_2ff rst_sync hex7seg wstrb_merge free_counter periph_regs axil_slave
           axil_master axil_demo_seq axil_system} {
    set_global_assignment -name VERILOG_FILE ../../rtl/$f.v
}
set_global_assignment -name VERILOG_FILE de10_lite_top.v
set_global_assignment -name SDC_FILE de10_lite.sdc
set_global_assignment -name RESERVE_ALL_UNUSED_PINS_WEAK_PULLUP "AS INPUT TRI-STATED"
source de10_lite_pins.tcl
execute_flow -compile
project_close
