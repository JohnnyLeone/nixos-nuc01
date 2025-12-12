{
  description = "NixOS configurations (nuc01, nuc02)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
  };

  outputs = { self, nixpkgs }:
    let
      mkHost = host: nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./hosts/${host}/configuration.nix
        ];
      };
    in {
      nixosConfigurations = {
        nuc01 = mkHost "nuc01";
        nuc02 = mkHost "nuc02";
      };
    };
}

