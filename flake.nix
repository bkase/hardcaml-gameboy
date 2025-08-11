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
        
        # Custom OCaml packages
        customOcamlPackages = pkgs.ocamlPackages.overrideScope (oself: osuper: {
          
          # ppx_hardcaml
          ppx_hardcaml = oself.buildDunePackage rec {
            pname = "ppx_hardcaml";
            version = "unstable-2024-08-11";
            src = pkgs.fetchFromGitHub {
              owner = "janestreet";
              repo = "ppx_hardcaml";
              rev = "main";
              sha256 = pkgs.lib.fakeHash;
            };
            buildInputs = with oself; [ ppx_jane ppx_deriving hardcaml ];
            propagatedBuildInputs = with oself; [ base ppx_jane ppx_deriving hardcaml ];
          };
          
          # hardcaml
          hardcaml = oself.buildDunePackage rec {
            pname = "hardcaml";
            version = "unstable-2024-08-11";
            src = pkgs.fetchFromGitHub {
              owner = "janestreet";
              repo = "hardcaml";
              rev = "main";
              sha256 = pkgs.lib.fakeHash;
            };
            buildInputs = with oself; [ ppx_jane bin_prot zarith topological_sort ];
            propagatedBuildInputs = with oself; [ base stdio ppx_jane bin_prot zarith topological_sort ];
          };
          
          # hardcaml_waveterm
          hardcaml_waveterm = oself.buildDunePackage rec {
            pname = "hardcaml_waveterm";
            version = "unstable-2024-08-11";
            src = pkgs.fetchFromGitHub {
              owner = "janestreet";
              repo = "hardcaml_waveterm";
              rev = "main";
              sha256 = pkgs.lib.fakeHash;
            };
            buildInputs = with oself; [ hardcaml ];
            propagatedBuildInputs = with oself; [ hardcaml base stdio ];
          };
          
        });
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            ocaml
            dune_3
            
            # Custom OCaml packages
            customOcamlPackages.hardcaml
            customOcamlPackages.hardcaml_waveterm
            customOcamlPackages.ppx_hardcaml
            
            # OCaml packages from nixpkgs
            ocamlPackages.base
            ocamlPackages.stdio
            ocamlPackages.core
            ocamlPackages.alcotest
            ocamlPackages.ppx_deriving
            ocamlPackages.ppx_jane
            ocamlPackages.ocamlformat
            
            # SMT solver
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
