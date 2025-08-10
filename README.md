# HardCaml GameBoy

A hardware implementation of a GameBoy emulator using HardCaml, an OCaml library for hardware design and verification.

## Overview

This project implements a cycle-accurate GameBoy emulator in hardware description using HardCaml. HardCaml allows us to write hardware designs in OCaml and generate synthesizable Verilog/VHDL.

**Current Status:** PPU (Picture Processing Unit) implementation with oracle-based differential testing.

## Features

- [x] PPU checkerboard pattern generation
- [x] Framebuffer interface (160x144 pixels, RGB555)
- [x] Oracle lockstep testing against SameBoy
- [ ] CPU (Sharp LR35902) implementation  
- [ ] Memory management unit (MMU)
- [ ] Audio Processing Unit (APU)
- [ ] Timer and interrupt handling
- [ ] Cartridge support (MBC1, MBC3, etc.)
- [ ] LCD controller
- [ ] Input handling

## Requirements

- OCaml 5.x
- opam package manager
- HardCaml library
- Z3 SMT solver
- Nix (recommended for development environment)
- RGBDS (Game Boy development tools)
- clang compiler

## Quick Start

### Option 1: Using Nix (Recommended)

```bash
# Enter development environment with all tools
nix develop

# Build everything and run tests in one command
make test
```

### Option 2: Manual Setup

```bash
# Install dependencies
opam init --disable-sandboxing
opam install hardcaml alcotest --yes

# Build tools and test ROMs, then run tests
make test
```

## Development Workflow

### Essential Commands

```bash
# Build everything (OCaml + tools + ROMs) and run oracle tests
make test

# Build only the OCaml project
make build

# Generate synthesizable Verilog from HardCaml modules
make synth

# Format OCaml code
make format

# Check code formatting
make check-format

# Clean all build artifacts
make clean

# Show detailed project information
make info
```

### Development Loop

The typical development cycle:

1. **Make changes** to OCaml source files in `src/`
2. **Format code** with `make format`  
3. **Run tests** with `make test` to validate against SameBoy oracle
4. **Debug issues** using generated artifacts in `_artifacts/`

### Oracle Lockstep Testing

The project uses differential testing against SameBoy (a reference GameBoy emulator):

- **Oracle**: SameBoy generates reference framebuffer outputs
- **DUT** (Device Under Test): HardCaml implementation generates test outputs  
- **Comparison**: Pixel-by-pixel comparison with detailed diff reporting

Test artifacts are saved in `_artifacts/`:
- `expected.ppm` - SameBoy reference output
- `actual.ppm` - HardCaml DUT output  
- `diff.ppm` - Visual difference highlighting
- `mismatches.txt` - Detailed pixel difference report

### Test ROMs

The project includes test ROMs in `roms/`:
- `flat_bg.asm` - Generates a checkerboard pattern for PPU testing

### Building Components

The Makefile orchestrates building multiple components:

```bash
make submodules    # Initialize git submodules (SameBoy)
make vendor        # Build SameBoy library
make tools         # Build sameboy_headless and boot ROM
make roms          # Build test ROMs
make build         # Build OCaml project
```

## Hardware Synthesis

The project can generate synthesizable Verilog from the HardCaml modules for FPGA implementation:

```bash
# Generate Verilog files from all HardCaml modules
make synth
```

This creates Verilog files in the `synth/` directory:
- `checker_fill.v` - Checkerboard pattern generator FSM
- `framebuf.v` - Dual-port framebuffer memory
- `top_checker_to_framebuf.v` - Top-level PPU module

### Synthesis Features

- **Clean Verilog Output**: HardCaml generates readable, synthesizable Verilog
- **Memory Inference**: Framebuffer uses inferred block RAM primitives  
- **Clock Domain**: Single clock design with asynchronous reset
- **Timing Constraints**: Constraint files provided for various FPGA vendors

### FPGA Constraints

Timing constraint files are provided in `constraints/` for different FPGA vendors:

```
constraints/
├── generic/          # Generic SDC constraints
├── xilinx/          # Xilinx XDC constraints  
├── intel/           # Intel/Altera SDC constraints
├── gowin/           # Gowin-specific constraints
└── lattice/         # Lattice-specific constraints
```

**Clock Specifications:**
- System Clock: 4.194304 MHz (238.42 ns period) - Original GameBoy frequency
- Reset: Asynchronous active-high reset
- Memory: Block RAM inference for framebuffer storage

### Synthesis Workflow

1. **Generate Verilog**: `make synth` creates synthesizable RTL
2. **Choose Constraints**: Select appropriate constraint file for your FPGA
3. **Run Synthesis**: Use vendor tools (Vivado, Quartus, etc.) to synthesize
4. **Place & Route**: Apply timing constraints during implementation
5. **Generate Bitstream**: Create FPGA configuration file

The generated Verilog is vendor-neutral and should work with most FPGA synthesis tools.

## Project Structure

```
src/
└── ppu/                       # Picture Processing Unit
    ├── checker_fill.ml        # Checkerboard pattern generator
    ├── framebuf.ml           # Framebuffer interface
    └── top_checker_to_framebuf.ml  # Top-level PPU module

synth_tool/
├── synthesize.ml             # Verilog generation tool
└── dune                      # Build configuration for synthesis tool

test/
└── oracle_lockstep.ml        # Oracle-based differential testing

tools/
├── sameboy_headless.c        # Headless SameBoy for oracle testing
└── bin2c.sh                  # Convert binaries to C headers

roms/
└── flat_bg.asm              # Test ROM generating checkerboard

constraints/                   # FPGA timing constraints
├── generic/                  # Generic SDC constraints
├── xilinx/                   # Xilinx XDC constraints
├── intel/                    # Intel/Altera constraints
├── gowin/                    # Gowin constraints
└── lattice/                  # Lattice constraints

synth/                        # Generated Verilog files (created by make synth)
├── checker_fill.v           # Synthesizable checkerboard generator
├── framebuf.v              # Synthesizable framebuffer
└── top_checker_to_framebuf.v # Top-level synthesizable module

vendor/
└── SameBoy/                 # Reference GameBoy emulator
```

## Debugging

### Waveform Generation

HardCaml supports waveform generation for debugging:

```ocaml
(* Add to your simulation code *)
let waveform = Hardcaml_waveterm.Waveform.create () in
let sim = Cyclesim.create ~config:(Cyclesim.Config.trace_all waveform) module in
(* After simulation *)
Hardcaml_waveterm.Waveform.print waveform
```

### Test Artifacts

When tests fail, examine the generated artifacts:

```bash
# View reference vs actual output
open _artifacts/expected.ppm _artifacts/actual.ppm

# Check detailed differences  
cat _artifacts/flat_bg/mismatches.txt

# Compare execution traces
diff _artifacts/flat_bg/trace.expected.csv _artifacts/flat_bg/trace.actual.csv
```

## License

MIT

## References

- [Pan Docs](https://gbdev.io/pandocs/) - Comprehensive GameBoy technical reference
- [HardCaml Documentation](https://github.com/janestreet/hardcaml)
- [GameBoy CPU Manual](http://marc.rawer.de/Gameboy/Docs/GBCPUman.pdf)