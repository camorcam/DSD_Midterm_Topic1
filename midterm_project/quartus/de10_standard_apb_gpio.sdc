create_clock -name CLOCK_50 -period 20.000 [get_ports {CLOCK_50}]
derive_clock_uncertainty

# Reset, keys, and slide switches are asynchronous to CLOCK_50 and are
# synchronized inside the design. Exclude their external arrival paths.
set_false_path -from [get_ports {KEY[*]}]
set_false_path -from [get_ports {SW[*]}]
