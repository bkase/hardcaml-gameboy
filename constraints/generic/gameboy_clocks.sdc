# Generic timing constraints for HardCaml GameBoy
# GameBoy System Clock: 4.194304 MHz (238.42 ns period)

# Main system clock constraint
create_clock -name sys_clk -period 238.42 [get_ports clock]

# PPU pixel clock (derived from system clock)
# In original GameBoy, this runs at system clock frequency
create_generated_clock -name ppu_clk -source [get_ports clock] -divide_by 1 [get_pins ppu_clk_gen/Q]

# Clock uncertainty and jitter allowances
set_clock_uncertainty -setup 5.0 [get_clocks sys_clk]
set_clock_uncertainty -hold 2.0 [get_clocks sys_clk]

# Input/Output delay constraints (to be refined for specific FPGA boards)
set_input_delay -clock [get_clocks sys_clk] -min 10.0 [all_inputs]
set_input_delay -clock [get_clocks sys_clk] -max 50.0 [all_inputs]
set_output_delay -clock [get_clocks sys_clk] -min 10.0 [all_outputs]  
set_output_delay -clock [get_clocks sys_clk] -max 50.0 [all_outputs]

# Disable timing analysis on asynchronous reset signals
set_false_path -from [get_ports reset]

# Critical path constraints for PPU framebuffer access
# (to be refined based on actual implementation)
set_max_delay -from [get_pins *framebuf*/a_addr*] -to [get_pins *framebuf*/a_wdata*] 100.0