{
  description = "Nix flake for rve";

  # Flake inputs
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs"; # also valid: "nixpkgs";
  };

  # Flake outputs
  outputs = { self, nixpkgs }:
    let
      # Systems supported
      allSystems = [
        "x86_64-linux" # 64-bit Intel/AMD Linux
        "aarch64-linux" # 64-bit ARM Linux
        "x86_64-darwin" # 64-bit Intel macOS
        "aarch64-darwin" # 64-bit ARM macOS
      ];

      # Helper to provide system-specific attributes
      forAllSystems = f:
        nixpkgs.lib.genAttrs allSystems
        (system: f { pkgs = import nixpkgs { inherit system; }; });
    in {
      packages = forAllSystems ({ pkgs }: {
        lisp = (pkgs.callPackage ./doom.nix { });
        default = (pkgs.callPackage ./doom.nix { });
      });
      overlays.default = final: prev: {
        lisp = (prev.callPackage ./doom.nix { });
      };
    };
}
