# DE10-Lite timing constraints (50 MHz board clock)
create_clock -name CLOCK_50 -period 20.000 [get_ports {MAX10_CLK1_50}]
derive_clock_uncertainty
# Switches and buttons are asynchronous (synchronized inside the design);
# LEDs and 7-segment displays are slow human-visible outputs.
set_false_path -from [get_ports {KEY[*] SW[*]}]
set_false_path -to   [get_ports {LEDR[*] HEX0[*] HEX1[*] HEX2[*] HEX3[*] HEX4[*] HEX5[*]}]
