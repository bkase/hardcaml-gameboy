# Xilinx Design Constraints for HardCaml GameBoy
# Target: Generic Xilinx FPGA (to be customized for specific boards)

# Clock constraints
create_clock -period 238.42 -name sys_clk -waveform {0.000 119.21} [get_ports clock]

# Clock uncertainty
set_clock_uncertainty -setup 2.0 [get_clocks sys_clk]
set_clock_uncertainty -hold 1.0 [get_clocks sys_clk]

# I/O timing constraints
set_input_delay -clock [get_clocks sys_clk] -min 10.0 [all_inputs]
set_input_delay -clock [get_clocks sys_clk] -max 50.0 [all_inputs]
set_output_delay -clock [get_clocks sys_clk] -min 10.0 [all_outputs]
set_output_delay -clock [get_clocks sys_clk] -max 50.0 [all_outputs]

# Reset timing
set_false_path -from [get_ports reset]

# FPGA-specific settings
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO [current_design]

# Pin assignments (to be customized for specific development board)
# set_property PACKAGE_PIN E3 [get_ports clock]
# set_property IOSTANDARD LVCMOS33 [get_ports clock]
# set_property PACKAGE_PIN C12 [get_ports reset]  
# set_property IOSTANDARD LVCMOS33 [get_ports reset]

# Block RAM usage optimization
set_property RAM_STYLE block [get_cells -hierarchical *framebuf*mem*]