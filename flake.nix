{
  inputs.nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";

  outputs = {
    self,
    nixpkgs,
    ...
  } @ inputs: {
    nixosModules = {
      hjem = ./modules/nixos.nix;
      default = self.nixosModules.hjem;
    };

    checks = import ./checks {inherit inputs;};

    formatter = nixpkgs.lib.genAttrs ["x86_64-linux" "aarch64-linux"] (system: nixpkgs.legacyPackages.${system}.alejandra);
  };
}
