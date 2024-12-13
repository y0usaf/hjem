{
  inputs.nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";

  outputs = {self, ...}: {
    nixosModules = {
      hjem = ./modules/nixos.nix;
      default = self.nixosModules.hjem;
    };
  };
}
