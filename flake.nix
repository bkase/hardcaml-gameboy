{
  description = "HardCaml GameBoy - Stable nixpkgs version";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        
        # Simple hardcaml derivation using basic dependencies
        customOcamlPackages = pkgs.ocamlPackages.overrideScope (oself: osuper: {
          # Add jane_rope dependency (needed by hardcaml)
          jane_rope = osuper.jane_rope or (oself.buildDunePackage rec {
            pname = "jane_rope";
            version = "v0.17.0";
            src = pkgs.fetchFromGitHub {
              owner = "janestreet";
              repo = "jane_rope";
              rev = version;
              sha256 = "sha256-o8Y21/sUIoq5TeOpgEOyvBQhmiMnIJtq+85mwVvJtco=";
            };
            buildInputs = with oself; [ base ppx_jane ];
            propagatedBuildInputs = with oself; [ base ppx_jane ];
          });
          
          # Add notty_async dependency (needed by hardcaml_waveterm)
          notty_async = osuper.notty_async or (oself.buildDunePackage rec {
            pname = "notty_async";
            version = "v0.17.0";
            src = pkgs.fetchFromGitHub {
              owner = "janestreet";
              repo = "notty_async";
              rev = version;
              sha256 = "sha256-zD9V2vtgCJfjj4DAQLReGIno2SLeryukCPgScyoQFP0=";
            };
            buildInputs = with oself; [ async notty ];
            propagatedBuildInputs = with oself; [ async notty ];
          });
          
          # Stable hardcaml v0.17.0
          hardcaml = oself.buildDunePackage rec {
            pname = "hardcaml";
            version = "0.17.0";
            src = pkgs.fetchFromGitHub {
              owner = "janestreet";
              repo = "hardcaml";
              rev = "v0.17.0";
              sha256 = "sha256-lRzqXuUYrk3VjQhFDTN0Q/aPolf0gKr4gK0i1ZOKKww=";
            };
            buildInputs = with oself; [ ppx_jane bin_prot zarith topological_sort core_kernel jane_rope ];
            propagatedBuildInputs = with oself; [ base stdio ppx_jane bin_prot zarith topological_sort core_kernel jane_rope ];
          };
          
          # hardcaml_waveterm v0.17.0 
          hardcaml_waveterm = oself.buildDunePackage rec {
            pname = "hardcaml_waveterm";
            version = "0.17.0";
            src = pkgs.fetchFromGitHub {
              owner = "janestreet";
              repo = "hardcaml_waveterm";
              rev = "v0.17.0";
              sha256 = "sha256-R7NTEJel52KjdzRrTtJaX0dx1kuzxVqNHGwi4ORaR9k=";
            };
            buildInputs = with oself; [ hardcaml base stdio core_kernel core_unix cryptokit notty_async ];
            propagatedBuildInputs = with oself; [ hardcaml base stdio core_kernel core_unix cryptokit notty_async ];
          };
          
          # ppx_hardcaml v0.17.0
          ppx_hardcaml = oself.buildDunePackage rec {
            pname = "ppx_hardcaml";
            version = "0.17.0";
            src = pkgs.fetchFromGitHub {
              owner = "janestreet";
              repo = "ppx_hardcaml";
              rev = "v0.17.0";
              sha256 = "sha256-sBVuzpElyZzgBEmDFeBMxQvGOum2ow6++ugBBT0dWtw=";
            };
            buildInputs = with oself; [ ppx_jane ppx_deriving hardcaml ];
            propagatedBuildInputs = with oself; [ base ppx_jane ppx_deriving hardcaml ];
          };
        });
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            # OCaml toolchain
            ocaml
            dune_3
            ocamlPackages.findlib
            
            # Custom hardcaml packages (v0.17.0)
            customOcamlPackages.hardcaml
            customOcamlPackages.hardcaml_waveterm
            customOcamlPackages.ppx_hardcaml
            
            # Core OCaml packages from nixpkgs
            ocamlPackages.base
            ocamlPackages.stdio
            ocamlPackages.core
            ocamlPackages.core_kernel
            ocamlPackages.core_unix
            ocamlPackages.alcotest
            ocamlPackages.bin_prot
            ocamlPackages.zarith
            ocamlPackages.topological_sort
            ocamlPackages.digestif
            ocamlPackages.cryptokit
            ocamlPackages.notty
            ocamlPackages.async
            customOcamlPackages.notty_async
            
            # PPX and Jane Street packages
            ocamlPackages.ppx_deriving
            ocamlPackages.ppx_jane
            customOcamlPackages.jane_rope
            
            # Additional utilities
            ocamlPackages.ocamlformat
            
            # Build tools for tests
            gnumake
            pkg-config
            
            # GameBoy ROM development
            rgbds
            
            # SMT solver
            z3
          ];
          
          shellHook = ''
            ${pkgs.lib.optionalString pkgs.stdenv.isDarwin ''
              # Set macOS deployment target to avoid linker warnings on Darwin
              export MACOSX_DEPLOYMENT_TARGET=12.0
            ''}
            
            echo "HardCaml GameBoy development environment (Nix-only, v0.17.0)"
            echo "OCaml version: $(ocaml -version 2>&1 | head -1)"
            echo "Dune version: $(dune --version)"
            echo ""
            echo "Run 'dune build' to build the project"
            echo "Run 'dune test' to run tests"
          '';
        };
      });
}