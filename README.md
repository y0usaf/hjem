# Hjem

A streamlined way to manage your `$HOME` for NixOS systems.

## What is this?

Hjem ("home" in Danish) is a NixOS module that implements a simple and
streamlined way to manage files in your `$HOME`, such as but not limited to
files in your `~/.config`.

It exposes a very basic interface with multi-tenant capabilities, which you may
use to manage individual users' homes by leveraging the module system.

```nix
{
  homes = {
    alice.files = {
      # Write a text file in `/homes/alice/.config/foo`
      # with the contents bar
      ".config/foo".text = "bar";
    };
  };
}
```

## Module Interface

The interface for the `homes` module is conceptually very similar to
Home-Manager, but it does not act as a collection of modules like Home-Manager.
We only implement basic features, and leave abstraction to the user to do as
they see fit.

Below is a live implementation of the module.

```nix
nix-repl> :p nixosConfigurations."nixos".config.homes
{
  alice = {
    directory = "/home/alice";
    enable = true;
    files = {
      ".config/foo" = {
        enable = true;
        executable = false;
        recursive = false;
        source = «derivation /nix/store/prc0c5yrfca63x987f2k9khpfhlfnq15-config-foo.drv»;
        target = ".config/foo";
        text = "bar";
      };
    };
    user = "alice";
  };
}

nix-repl> :p nixosConfigurations."nixos".config.systemd.user.tmpfiles.users
{
  alice = {
    rules = [ "L /home/alice/.config/foo - - - - /nix/store/jfpr2z1z1aykpw2j2gj02lwwvwv6hml4-config-foo" ];
  };
}
```

[systemd-tmpfiles]: https://man7.org/linux/man-pages/man8/systemd-tmpfiles.8.html

Instead of relying on a Bash script to link files in place, we utilize
[systemd-tmpfiles] to ensure the files are linked in place.

## Things to do

Hjem is mostly feature-complete, in the sense that it is a clean implementation
of `home.files` in Home-Manager: it was never a goal to dive into abstracting
files into modules. Although, some _basic_ features such as managing _Systemd
Services_ or user packages may make their ways into the project in future
iterations.

### Manifest & Cleaning up dangling files

The systemd-tmpfiles module lacks a good way of cleaning up dangling lists,
e.g., from files that are no longer linked. To tackle this problem, a _manifest_
of files can be used to diff said manifest during switch and remove files that
are no longer managed.

## License

This project is made available under the GPLv3 license. See [LICENSE](LICENSE)
for more details on the exact conditions.
