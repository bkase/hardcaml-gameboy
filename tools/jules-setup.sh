#!/usr/bin/env bash
# This script sets up the nix-portable environment for Jules.
set -euo pipefail

echo "--- Setting up nix-portable for Jules ---"

# 1) Download nix-portable if it's not already present
if [ ! -f "./nix-portable" ]; then
  echo "Downloading nix-portable..."
  curl -L https://github.com/DavHau/nix-portable/releases/latest/download/nix-portable-$(uname -m) > nix-portable
  chmod +x ./nix-portable
else
  echo "nix-portable already exists."
fi

# 2) Create a 'nix' symlink for convenience
ln -sf ./nix-portable ./nix

echo "nix-portable setup is complete."
echo "You can now use './nix' to run commands."
echo "Remember to set NIX_CONFIG and NP_LOCATION environment variables."
echo "Example: ./nix develop .#default --command 'make build'"
