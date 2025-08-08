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
            echo "HardCaml development environment ready!"
            echo "OCaml version: $(ocaml -version)"
            echo "Z3 version: $(z3 --version)"
            echo ""
            echo "First time setup:"
            echo "  opam init --disable-sandboxing"
            echo "  opam install . --deps-only --yes"
            echo ""
            echo "Then run 'make info' to see available commands"
          '';
        };
      });
}
