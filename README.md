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

## Project Structure

```
src/
├── main.ml                    # Main entry point
└── ppu/                       # Picture Processing Unit
    ├── checker_fill.ml        # Checkerboard pattern generator
    ├── framebuf.ml           # Framebuffer interface
    └── top_checker_to_framebuf.ml  # Top-level PPU module

test/
└── oracle_lockstep.ml        # Oracle-based differential testing

tools/
├── sameboy_headless.c        # Headless SameBoy for oracle testing
└── bin2c.sh                  # Convert binaries to C headers

roms/
└── flat_bg.asm              # Test ROM generating checkerboard

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