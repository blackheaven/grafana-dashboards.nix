{
  description = "Pure Nix flake utility functions";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }: {
    lib = import ./lib.nix {
      pkgs = import nixpkgs { system = builtins.currentSystem; };
    };
  };
}
