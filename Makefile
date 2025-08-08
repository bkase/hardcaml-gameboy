.PHONY: all build run clean dev-shell

# Default target
all: build

# Build the project
build:
	@echo "Building HardCaml hello world..."
	dune build

# Run the example
run: build
	@echo "Running HardCaml hello world with SMT checking..."
	dune exec ./src/main.exe

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	dune clean

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