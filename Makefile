.PHONY: all build run clean dev-shell test tools roms vendor submodules format check-format synth

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

# Synthesis settings
SYNTH_DIR = synth
CONSTRAINTS_DIR = constraints

# ===== Main Targets =====

# Default target
all: build tools roms

# Build the OCaml project
build:
	@echo "Building HardCaml project..."
	dune build


# Run tests
test: tools roms
	@echo "Running oracle lockstep tests..."
	dune test

# ===== Synthesis Targets =====

# Generate Verilog from HardCaml modules
synth: build
	@echo "Generating Verilog from HardCaml modules..."
	@mkdir -p $(SYNTH_DIR)
	dune exec ./synth_tool/synthesize.exe
	@echo "Verilog files generated in $(SYNTH_DIR)/"

# ===== Formatting Targets =====

# Format all OCaml source files
format:
	@echo "Formatting OCaml source files..."
	ocamlformat --inplace $$(find src test -name "*.ml" -o -name "*.mli" | grep -v "_build")

# Check if files are properly formatted (non-zero exit if not formatted)
check-format:
	@echo "Checking OCaml code formatting..."
	@if ! ocamlformat --check $$(find src test -name "*.ml" -o -name "*.mli" | grep -v "_build"); then \
		echo "Code is not properly formatted. Run 'make format' to fix."; \
		exit 1; \
	else \
		echo "All OCaml files are properly formatted."; \
	fi

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
	rm -rf $(SYNTH_DIR)

# Clean vendor builds too
clean-vendor:
	@echo "Cleaning vendor artifacts..."
	$(MAKE) -C $(SAMEBOY_DIR) clean

clean-all: clean clean-vendor

# Enter development shell (requires nix)
dev-shell:
	@echo "Entering Nix development shell..."
	nix develop


# Show project structure
info:
	@echo "HardCaml GameBoy Project Structure:"
	@echo "==================================="
	@echo "flake.nix          - Nix flake with OCaml 5 + HardCaml + Z3"
	@echo "dune-project       - Dune project configuration"
	@echo "src/ppu/           - PPU implementation modules"
	@echo "synth_tool/        - Verilog synthesis tool"
	@echo "constraints/       - FPGA timing constraints"
	@echo "test/              - Oracle lockstep testing"
	@echo "tools/             - SameBoy integration tools"
	@echo "roms/              - Test ROM sources"
	@echo ""
	@echo "Main Commands:"
	@echo "  make dev-shell     - Enter Nix development environment"
	@echo "  make build         - Build the OCaml project"
	@echo "  make synth         - Generate synthesizable Verilog"
	@echo "  make test          - Run oracle lockstep tests against SameBoy"
	@echo "  make format        - Format all OCaml source files"
	@echo "  make check-format  - Check if files are properly formatted"
	@echo "  make clean         - Clean build artifacts"
	@echo "  make info          - Show this information"
	@echo ""
	@echo "Synthesis Output:"
	@echo "  synth/checker_fill.v           - Checkerboard pattern generator"
	@echo "  synth/framebuf.v              - Dual-port framebuffer memory"
	@echo "  synth/top_checker_to_framebuf.v - Top-level PPU module"