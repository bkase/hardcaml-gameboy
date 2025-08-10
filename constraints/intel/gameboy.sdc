# Intel/Altera Design Constraints for HardCaml GameBoy
# Target: Generic Intel FPGA (Cyclone V, Arria, etc.)

# Clock definitions
create_clock -name "sys_clk" -period 238.42ns [get_ports {clock}]

# Clock uncertainty and skew
derive_clock_uncertainty

# Input constraints  
set_input_delay -clock "sys_clk" -min 10.0 [all_inputs]
set_input_delay -clock "sys_clk" -max 50.0 [all_inputs]

# Output constraints
set_output_delay -clock "sys_clk" -min 10.0 [all_outputs]
set_output_delay -clock "sys_clk" -max 50.0 [all_outputs]

# Asynchronous reset
set_false_path -from [get_ports {reset}]

# Memory optimization for framebuffer
# (Intel-specific RAM inference guidelines)
set_instance_assignment -name RAMSTYLE "M9K" -to *framebuf*mem*