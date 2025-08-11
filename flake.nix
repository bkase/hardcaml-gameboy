{
  description = "HardCaml development environment with OCaml 5";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            ocaml
            opam
            
            # SMT solver (available as system package)
            z3
            
            # Build tools
            gnumake
            pkg-config
            clang
            
            # GameBoy ROM development
            rgbds
            
            # Image processing for test diffs
            imagemagick
            
            # Additional tools for opam
            git
            m4
            gmp
            openssl
            libffi
          ];
          
          shellHook = ''
            ${pkgs.lib.optionalString pkgs.stdenv.isDarwin ''
              # Set macOS deployment target to avoid linker warnings on Darwin
              export MACOSX_DEPLOYMENT_TARGET=11.0
            ''}
            
            # Set up opam environment if it's initialized
            if [ -d "$HOME/.opam" ]; then
              eval $(opam env --shell=bash 2>/dev/null)
            fi
            
            echo "HardCaml development environment ready!"
            
            # Check if OCaml is available through opam
            if command -v ocaml &> /dev/null; then
              echo "OCaml version: $(ocaml -version 2>&1 | head -1)"
            else
              echo "OCaml: Not found (run setup commands below)"
            fi
            
            echo "Z3 version: $(z3 --version)"
            
            # Check if opam is initialized
            if [ ! -d "$HOME/.opam" ]; then
              echo ""
              echo "First time setup:"
              echo "  make setup"
            else
              echo ""
              echo "Opam environment loaded automatically"
              echo "Run 'make info' to see available commands"
            fi
          '';
        };
      });
}
