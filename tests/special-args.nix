let
  userHome = "/home/alice";
in
  (import ./lib) {
    name = "hjem-basic";
    nodes = {
      node1 = {self, ...}: {
        imports = [self.nixosModules.hjem];

        users.groups.alice = {};
        users.users.alice = {
          isNormalUser = true;
          home = userHome;
          password = "";
        };

        hjem = {
          # Things like username, home directory or credentials should not really
          # be put into specialArgs, but users do it anyway. Lets test for a very
          # basic case of 'username' being passed to specialArgs as a string and
          # is consumed in a file later on.
          specialArgs = {username = "alice";};
          users.alice = {
            pkgs,
            username,
            ...
          }: {
            enable = true;
            packages = [pkgs.hello];
            files.".config/fooconfig" = {
              text = "My username is ${username}";
            };
          };
        };
      };
    };

    testScript = ''
      machine.succeed("loginctl enable-linger alice")
      machine.wait_until_succeeds("systemctl --user --machine=alice@ is-active systemd-tmpfiles-setup.service")

      # Test if the config file is properly generated, and contains the desired string1
      machine.succeed("grep alice ~alice/.config/fooconfig")
    '';
  }
