.PHONY: all build run clean dev-shell test tools roms

# ===== Configuration =====
# SameBoy paths
SAMEBOY_DIR = vendor/SameBoy
SAMEBOY_BUILD = $(SAMEBOY_DIR)/build
BOOT_ROM_SRC = $(SAMEBOY_DIR)/BootROMs/dmg_boot.asm

# Compiler settings
CC = clang
CFLAGS = -O2 -I$(SAMEBOY_BUILD)/include -Wall
LDFLAGS = -L$(SAMEBOY_BUILD)/lib -lsameboy -lm

# Assembly tools
RGBASM = rgbasm
RGBLINK = rgblink

# ===== Main Targets =====

# Default target
all: build tools roms

# Build the OCaml project
build:
	@echo "Building HardCaml project..."
	dune build

# Run the example
run: build
	@echo "Running HardCaml hello world with SMT checking..."
	dune exec ./src/main.exe

# Run tests
test: tools roms
	@echo "Running oracle lockstep tests..."
	dune test

# ===== Tools Targets =====

tools: tools/sameboy_headless

# Build boot ROM from source
tools/dmg_boot.bin: $(BOOT_ROM_SRC)
	@echo "Building boot ROM from source..."
	$(RGBASM) -I$(SAMEBOY_DIR)/BootROMs -o tools/dmg_boot.o $(BOOT_ROM_SRC)
	$(RGBLINK) -x -o $@ tools/dmg_boot.o
	@rm -f tools/dmg_boot.o

tools/boot_rom.h: tools/dmg_boot.bin
	@echo "Generating boot ROM header..."
	cd tools && ./bin2c.sh dmg_boot.bin boot_rom.h

tools/sameboy_headless: tools/sameboy_headless.c tools/boot_rom.h
	@echo "Building sameboy_headless..."
	$(CC) $(CFLAGS) -o $@ tools/sameboy_headless.c $(LDFLAGS)

# ===== ROMs Targets =====

roms: roms/flat_bg.gb

roms/flat_bg.gb: roms/flat_bg.asm
	@echo "Building test ROMs..."
	$(MAKE) -C roms

# ===== Clean Target =====

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	dune clean
	rm -f tools/sameboy_headless tools/boot_rom.h tools/dmg_boot.bin tools/dmg_boot.o
	rm -f roms/*.gb roms/*.o

# Enter development shell (requires nix)
dev-shell:
	@echo "Entering Nix development shell..."
	nix develop

# Build and run in one step
demo: build run

# Show project structure
info:
	@echo "HardCaml Project Structure:"
	@echo "=========================="
	@echo "flake.nix          - Nix flake with OCaml 5 + HardCaml + Z3"
	@echo "dune-project       - Dune project configuration"
	@echo "src/main.ml        - HardCaml counter example with SMT verification"
	@echo "src/dune           - Dune build file"
	@echo "Makefile           - This makefile"
	@echo ""
	@echo "Commands:"
	@echo "  make dev-shell   - Enter Nix development environment"
	@echo "  make build       - Build the project"
	@echo "  make run         - Run the example"
	@echo "  make demo        - Build and run"
	@echo "  make clean       - Clean build artifacts"
	@echo "  make info        - Show this information"