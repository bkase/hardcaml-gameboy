# Timing Constraints

This directory contains timing constraint files for FPGA synthesis.

## Directory Structure

- `generic/` - Generic timing constraints that apply to any FPGA target
- `xilinx/` - Xilinx-specific constraints (XDC files)
- `intel/` - Intel/Altera-specific constraints (SDC files)  
- `gowin/` - Gowin-specific constraints
- `lattice/` - Lattice-specific constraints

## File Types

- `.sdc` - Synopsys Design Constraints (industry standard)
- `.xdc` - Xilinx Design Constraints (Vivado)
- `.pcf` - Physical Constraint File (used by some open-source tools)

## Clock Domains

The GameBoy hardware operates with the following main clock domains:

- System Clock: 4.194304 MHz (GameBoy main clock)
- Pixel Clock: Derived from system clock for PPU timing
- External clocks: For interfacing with external components

## Notes

- Constraints are currently stubbed but will be populated as specific FPGA targets are added
- Timing requirements should be based on original GameBoy specifications
- Consider clock domain crossing constraints for multi-clock designs