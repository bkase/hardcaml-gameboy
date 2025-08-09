# CLAUDE.md - Project-Specific Instructions for HardCaml GameBoy

This file provides guidance to Claude Code when working on the HardCaml GameBoy project.

## Project Overview

This is a hardware implementation of a GameBoy emulator using HardCaml, an OCaml library for hardware design. The goal is to create a cycle-accurate, synthesizable GameBoy implementation.

## Current Implementation Plan

**Starting with PPU (Picture Processing Unit) implementation first**
- The PPU is the graphics processor of the GameBoy
- This will establish the display pipeline and timing
- Other components (CPU, APU, MMU) are TBD

## Development Environment

- The project uses Nix flakes for environment management
- OCaml dependencies are managed via opam
- HardCaml is the primary library for hardware description
- Z3 is available for formal verification tasks

## Code Structure Guidelines

### Module Organization
- CPU logic should be in `src/cpu/`
- PPU (graphics) logic should be in `src/ppu/`
- APU (audio) logic should be in `src/apu/`
- Memory management in `src/mmu/`
- Common utilities in `src/utils/`

### HardCaml Conventions
- Use `Signal` module for hardware signals
- Prefer combinational logic where possible
- Use `Reg_spec` for sequential logic
- Always include simulation test benches for modules
- **NEVER use magic numbers** - all constants should be defined in appropriate Constants modules

### Testing Strategy
- Unit tests for individual modules using `dune test`
- Integration tests for complete subsystems
- Waveform generation for debugging using `Hardcaml_waveterm`
- Property-based testing where appropriate

## GameBoy Architecture Notes

### CPU (Sharp LR35902)
- 8-bit processor similar to Z80
- 8 general purpose registers (A, B, C, D, E, H, L, F)
- 16-bit program counter (PC) and stack pointer (SP)
- Clock speed: 4.194304 MHz

### Memory Map
- 0x0000-0x7FFF: Cartridge ROM
- 0x8000-0x9FFF: Video RAM
- 0xA000-0xBFFF: External RAM
- 0xC000-0xDFFF: Work RAM
- 0xE000-0xFDFF: Echo RAM
- 0xFE00-0xFE9F: OAM (Object Attribute Memory)
- 0xFF00-0xFF7F: I/O Registers
- 0xFF80-0xFFFE: High RAM
- 0xFFFF: Interrupt Enable Register

### Display
- 160x144 pixels
- 4 shades of gray
- 60 FPS refresh rate

## Common Tasks

### Adding a new CPU instruction
1. Define the instruction in the opcode table
2. Implement the instruction logic
3. Add unit tests for the instruction
4. Update the decoder

### Debugging hardware modules
1. Generate waveforms using `Hardcaml_waveterm`
2. Check timing constraints
3. Verify combinational logic paths
4. Use formal verification for critical properties

## Testing Commands

```bash
# Run all tests
dune test

# Build the project
dune build

# Generate documentation
dune build @doc

# Clean build artifacts
dune clean
```

## References to Consult

- Pan Docs (https://gbdev.io/pandocs/) for GameBoy specifications
- HardCaml documentation for library usage
- GameBoy CPU manual for instruction set details

## Important Reminders

- Always verify timing constraints for sequential logic
- Ensure all modules are synthesizable
- Keep register widths consistent with GameBoy specifications
- Test edge cases, especially for memory boundaries
- Consider power-of-2 optimizations for hardware efficiency
- **NO MAGIC NUMBERS**: Use constants from appropriate Constants modules (e.g., `src/ppu/constants.ml` for display-related values)

## Constants Organization

### PPU Constants (`src/ppu/constants.ml`)
- `screen_width` (160): GameBoy LCD width in pixels
- `screen_height` (144): GameBoy LCD height in pixels  
- `total_pixels` (23,040): Total pixels in GameBoy screen
- `pixel_addr_width` (15): Address width for pixel addressing
- `pixel_data_width` (16): RGB555 pixel data width
- `coord_width` (8): Coordinate width for x,y values
- `rgb555_white` (0x7FFF), `rgb555_black` (0x0000): Color constants
- Other RGB555 and checkerboard pattern constants

**Always import and use these constants instead of hardcoding numeric values!**