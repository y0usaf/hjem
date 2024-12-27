{
  config,
  pkgs,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf mkDefault mkDerivedConfig;
  inherit (lib.options) mkOption mkEnableOption literalExpression;
  inherit (lib.strings) hasPrefix;
  inherit (lib.lists) filter map;
  inherit (lib.attrsets) filterAttrs mapAttrs' attrValues;
  inherit (lib.types) bool submodule str path attrsOf nullOr lines;

  usrCfg = config.users.users;
  cfg = config.hjem;

  fileType = relativeTo:
    submodule ({
      name,
      target,
      config,
      options,
      ...
    }: {
      options = {
        enable = mkOption {
          type = bool;
          default = true;
          example = false;
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
          type = bool;
          default = false;
          description = ''
            Whether to set the execute bit on the target file.
          '';
        };

        clobber = mkOption {
          type = bool;
          default = cfg.clobberByDefault;
          defaultText = literalExpression "config.hjem.clobberByDefault";
          description = ''
            Whether to "clobber", i.e., override existing target paths.

            While `true`, tmpfile rules will be constructed with `L+`
            (*re*create) instead of `L` (create) type.
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
        source = mkIf (config.text != null) (mkDerivedConfig options.text (text:
          pkgs.writeTextFile {
            inherit name text;
            inherit (config) executable;
          }));
      };
    });

  userOpts = {
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
        defaultText = "Home directory inherited from {option}`users.users.${name}.home`";
        description = ''
          The home directory for the user, to which files configured in
          {option}`homes.<name>.files` will be relative to by default.
        '';
      };

      files = mkOption {
        default = {};
        type = attrsOf (fileType config.directory);
        description = "Files to be managed, inserted to relevant systemd-tmpfiles rules";
      };

      packages = mkOption {
        type = with lib.types; listOf package;
        default = [];
        description = "Packages for ${config.user}";
      };
    };
  };
in {
  imports = [
    # This should be removed in the future, since 'homes' is a very vague
    # namespace to occupy. Added 2024-12-27, remove 2025-01-27 to allow
    # sufficient time to migrate.
    (lib.mkRenamedOptionModule ["homes"] ["hjem" "users"])
  ];

  options.hjem = {
    clobberByDefault = mkOption {
      type = bool;
      default = false;
      description = ''
        The default override behaviour for files managed by Hjem.

        While `true`, existing files will be overriden with new
        files on rebuild.
      '';
    };

    users = mkOption {
      default = {};
      type = attrsOf (submodule userOpts);
      description = "Home configurations to be managed";
    };
  };

  config = {
    users.users = mapAttrs' (name: {packages, ...}: {
      inherit name;
      value.packages = packages;
    }) (filterAttrs (_: u: u.packages != []) cfg.users);

    systemd.user.tmpfiles.users = mapAttrs' (name: {files, ...}: {
      inherit name;
      value.rules = map (
        file: let
          # L+ will recreate, i.e., clobber existing files.
          mode =
            if file.clobber
            then "L+"
            else "L";
        in
          # Constructed rule string that consists of the type, target, and source
          # of a tmpfile. Files with 'null' sources are filtered before the rule
          # is constructed.
          "${mode} '${file.target}' - - - - ${file.source}"
      ) (filter (f: f.enable && f.source != null) (attrValues files));
    }) (filterAttrs (_: u: u.files != {}) cfg.users);
  };
}
