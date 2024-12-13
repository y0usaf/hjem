{
  config,
  pkgs,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf mkDefault;
  inherit (lib.options) mkOption mkEnableOption;
  inherit (lib.strings) hasPrefix concatStringsSep;
  inherit (lib.lists) filter map;
  inherit (lib.attrsets) filterAttrs mapAttrs' attrValues;
  inherit (lib.types) bool submodule str path attrsOf nullOr lines;

  usrCfg = config.users.users;

  fileType = relativeTo:
    submodule ({
      name,
      target,
      config,
      ...
    }: {
      options = {
        enable = mkOption {
          type = bool;
          default = true;
          description = ''
            Whether this file should be generated. This option allows specific
            files to be disabled.
          '';
        };

        target = mkOption {
          type = str;
          apply = p:
            if hasPrefix "/" p
            then throw "This option cannot handle absolute paths yet!"
            else "${config.relativeTo}/${p}";
          defaultText = "name";
          description = ''
            Path to target file relative to ${config.relativeTo}.
          '';
        };

        text = mkOption {
          default = null;
          type = nullOr lines;
          description = ''
            Text of the file.
          '';
        };

        source = mkOption {
          type = nullOr path;
          default = null;
          description = ''
            Path of the source file or directory.
          '';
        };

        executable = mkOption {
          type = nullOr bool;
          default = false;
          description = ''
            Whether to set the execute bit on the target file.
          '';
        };

        relativeTo = mkOption {
          internal = true;
          type = path;
          default = relativeTo;
          description = "Path to which symlinks will be relative to";
          apply = x:
            assert (hasPrefix "/" x || abort "Relative path ${x} cannot be used for files.<file>.relativeTo"); x;
        };
      };

      config = {
        target = mkDefault name;
        source = mkIf (config.text != null) (mkDefault (pkgs.writeTextFile {
          inherit name;
          inherit (config) text executable;
        }));
      };
    });

  homeOpts = {
    name,
    config,
    ...
  }: {
    options = {
      enable = mkEnableOption "Whether to enable home management for ${name}" // {default = true;};
      user = mkOption {
        type = str;
        default = name;
        description = "The owner of a given home directory.";
        apply = x: assert (builtins.hasAttr x usrCfg || abort "A home has  been configured for ${x}, but the user does not exist"); x;
      };

      directory = mkOption {
        type = path;
        default = usrCfg.${config.user}.home;
        description = "The directory in which configuration files will be created for the user.";
      };

      files = mkOption {
        default = {};
        type = attrsOf (fileType config.directory);
        description = "";
      };
    };
  };
in {
  options = {
    homes = mkOption {
      default = {};
      type = attrsOf (submodule homeOpts);
      description = "Home configurations to be managed";
    };
  };

  config = {
    systemd.user.tmpfiles.users = mapAttrs' (name: {files, ...}: {
      inherit name;
      value.rules = map (
        file: let
          # L+ will recrate, i.e., clobber existing files.
          rulesList = ["L+" file.target "- - - -" file.source];
        in
          concatStringsSep " " rulesList
      ) (filter (f: f.enable && f.source != null) (attrValues files));
    }) (filterAttrs (_: u: u.files != {}) config.homes);
  };
}
