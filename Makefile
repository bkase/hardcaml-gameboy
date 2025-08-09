.PHONY: all build run clean dev-shell test tools roms vendor submodules

# ===== Configuration =====
# SameBoy paths
SAMEBOY_DIR = vendor/SameBoy
SAMEBOY_BUILD = $(SAMEBOY_DIR)/build
BOOT_ROM_SRC = $(SAMEBOY_DIR)/BootROMs/dmg_boot.asm

# Compiler settings
CC = clang
CFLAGS = -O2 -I$(SAMEBOY_BUILD)/include -Wall -Wextra -Werror -Wformat=2 -Wstrict-prototypes -Wno-unused-parameter
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

# ===== Vendor Targets =====

# Initialize git submodules
submodules:
	@echo "Initializing git submodules..."
	git submodule update --init --recursive

# Build SameBoy library with fake gcc wrapper
vendor: submodules
	@echo "Building SameBoy library..."
	@mkdir -p $(SAMEBOY_BUILD)
	PATH="$(CURDIR)/tools:$(CURDIR)/vendor/cppp:$$PATH" $(MAKE) -C $(SAMEBOY_DIR) lib

# ===== Tools Targets =====

tools: vendor out/sameboy_headless

# Build boot ROM from source
out/dmg_boot.bin: $(BOOT_ROM_SRC)
	@echo "Building boot ROM from source..."
	@mkdir -p out
	$(RGBASM) -I$(SAMEBOY_DIR)/BootROMs -o out/dmg_boot.o $(BOOT_ROM_SRC)
	$(RGBLINK) -x -o $@ out/dmg_boot.o
	@rm -f out/dmg_boot.o

out/boot_rom.h: out/dmg_boot.bin
	@echo "Generating boot ROM header..."
	@mkdir -p out
	cd out && ../tools/bin2c.sh dmg_boot.bin boot_rom.h

out/sameboy_headless: vendor tools/sameboy_headless.c out/boot_rom.h
	@echo "Building sameboy_headless..."
	@mkdir -p out
	$(CC) $(CFLAGS) -Iout -o $@ tools/sameboy_headless.c $(LDFLAGS)

# ===== ROMs Targets =====

roms: out/flat_bg.gb

out/flat_bg.gb: roms/flat_bg.asm
	@echo "Building test ROMs..."
	@mkdir -p out
	$(RGBASM) -o out/flat_bg.o roms/flat_bg.asm
	$(RGBLINK) -o out/flat_bg.gb out/flat_bg.o
	rgbfix -p 0xFF -v out/flat_bg.gb

# ===== Clean Target =====

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	dune clean
	rm -f out/sameboy_headless out/boot_rom.h out/dmg_boot.bin out/dmg_boot.o
	rm -f out/flat_bg.gb out/flat_bg.o

# Clean vendor builds too
clean-vendor:
	@echo "Cleaning vendor artifacts..."
	$(MAKE) -C $(SAMEBOY_DIR) clean

clean-all: clean clean-vendor

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