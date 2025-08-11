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
            dune_3
            
            # OCaml packages available in nixpkgs
            ocamlPackages.ocamlformat
            
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
            
            # Additional tools
            git
            m4
            gmp
            openssl
            libffi
          ];
          
          shellHook = ''
            ${pkgs.lib.optionalString pkgs.stdenv.isDarwin ''
              # Set macOS deployment target to avoid linker warnings on Darwin
              export MACOSX_DEPLOYMENT_TARGET=12.0
            ''}
            
            echo "HardCaml development environment ready!"
            echo "OCaml version: $(ocaml -version 2>&1 | head -1)"
            echo "Dune version: $(dune --version)"
            echo "Z3 version: $(z3 --version)"
            echo ""
            echo "Run 'make info' to see available commands"
          '';
        };
      });
}
