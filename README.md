# HardCaml GameBoy

A hardware implementation of a GameBoy emulator using HardCaml, an OCaml library for hardware design and verification.

## Overview

This project aims to implement a cycle-accurate GameBoy emulator in hardware description using HardCaml. HardCaml allows us to write hardware designs in OCaml and generate synthesizable Verilog/VHDL.

## Features (Planned)

- [ ] CPU (Sharp LR35902) implementation
- [ ] Memory management unit (MMU)
- [ ] Picture Processing Unit (PPU)
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

## Setup

1. Enter the Nix development environment:
```bash
nix develop
```

2. Initialize opam and install dependencies:
```bash
opam init --disable-sandboxing
opam install hardcaml --yes
```

## Building

```bash
dune build
```

## Testing

```bash
dune test
```

## License

MIT

## References

- [Pan Docs](https://gbdev.io/pandocs/) - Comprehensive GameBoy technical reference
- [HardCaml Documentation](https://github.com/janestreet/hardcaml)
- [GameBoy CPU Manual](http://marc.rawer.de/Gameboy/Docs/GBCPUman.pdf)