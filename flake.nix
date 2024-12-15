{
  inputs.nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";

  outputs = {self, ...} @ inputs: {
    nixosModules = {
      hjem = ./modules/nixos.nix;
      default = self.nixosModules.hjem;
    };

    checks = import ./checks {inherit inputs;};
  };
}
