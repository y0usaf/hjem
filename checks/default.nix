{inputs, ...}: let
  inherit (inputs) self nixpkgs;
  systems = ["x86_64-linux" "aarch64-linux"];
  forEachSystem = inputs.nixpkgs.lib.genAttrs systems;
in
  forEachSystem (system: let
    pkgs = nixpkgs.legacyPackages.${system};
    baseSystem = nixpkgs.lib.nixosSystem {
      modules = [
        ({modulesPath, ...}: {
          imports = [
            # Minimal profile
            "${modulesPath}/profiles/minimal.nix"

            # Hjem NixOS module
            self.nixosModules.hjem
          ];

          boot.loader.grub.enable = false;
          fileSystems."/".device = "nodev";
          nixpkgs.hostPlatform = system;
          system.stateVersion = "24.11";

          # Hjem setup
          users.groups.alice = {};
          users.users.alice.isNormalUser = true;
          homes = {
            alice = {
              files.".config/foo".text = "Hello world!";
              packages = [pkgs.hello];
            };
          };
        })
      ];
    };
  in {
    default = baseSystem.config.system.build.toplevel;
  })
