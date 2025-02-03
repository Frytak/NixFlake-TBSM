# TBSM nix flake
Nix flake for a pure bash session or application launcher inspired by cdm, tdm and krunner. This is **NOT** an official flake. `doc` and `search` commands won't work on NixOS due to their implementation, while `whitelist` should not be used. You can find the TBSM repository [here](https://github.com/loh-tar/tbsm).

## Standalone NixOS configuration
You will need to create `.desktop` entries at `~/.config/tbsm/whitelist`

```nix
{ config, lib, pkgs, inputs, ... }:

{
    imports = [ inputs.tbsm.nixosModules.tbsm ];

    tbsm = {
        enable = true;
        autoStart = {
            enable = true; # Auto start TBSM using `environment.shellInit`
            allowedTtys = [ "all" ]; # TTYs TBSM should launch on, for example [ "/dev/tty1" "/dev/tty2" ] (for TTY1 and TTY2) or [ "all" ] (for all TTYs)
        };

        # System wide configuration
        config = ''
            XserverArg="-quiet -nolisten tcp"
            verboseLevel=1
            theme=""
        '';
    };
}
```

## Standalone HomeManager configuration
```nix
{ config, lib, pkgs, inputs, ... }:

{
    imports = [ inputs.tbsm.homeManagerModules.tbsm ];

    tbsm = {
        enable = true;
        config = ''
            XserverArg="-quiet -nolisten tcp"
            verboseLevel=1
            theme=""
        '';

        sessions = [
            {
                Name = "Hyprland";
                Comment = "Start the Hyprland Wayland Compositor";
                Exec = "${pkgs.hyprland}/bin/Hyprland";
                Type = "Application";
                DesktopNames = "Hyprland";
                Keywords = "wayland;compositor;hyprland;";
            }
        ];
    };

    # Auto start TBSM in bash
    programs.bash.initExtra = ''
        # Launch TBSM on specific TTYs after login
        if [ -z "$DISPLAY" ]; then
            allowed_ttys="/dev/tty1" # Replace with TTYs TBSM should launch on, for example "/dev/tty1 /dev/tty2" (for TTY1 and TTY2) or "all" (for all TTYs)
            current_tty=$(tty)

            # If "all" is in the allowed_ttys list, launch on any TTY
            if echo "$allowed_ttys" | ${pkgs.gnugrep}/bin/grep -q "all"; then
                exec ${inputs.tbsm.packages.${pkgs.system}.tbsm}/bin/tbsm </dev/tty >/dev/tty 2>&1
            # If the current TTY is in the allowed list
            elif echo "$allowed_ttys" | ${pkgs.gnugrep}/bin/grep -q "$current_tty"; then
                exec ${inputs.tbsm.packages.${pkgs.system}.tbsm}/bin/tbsm </dev/tty >/dev/tty 2>&1
            fi
        fi
    '';
}
```

## NixOS + HomeManager configuration
```nix
{ config, lib, pkgs, inputs, ... }:

{
    imports = [ inputs.tbsm.nixosModules.tbsm ];

    tbsm = {
        enable = true;
        autoStart = {
            enable = true; # Auto start TBSM using `environment.shellInit`
            allowedTtys = [ "all" ]; # TTYs TBSM should launch on, for example [ "/dev/tty1" "/dev/tty2" ] (for TTY1 and TTY2) or [ "all" ] (for all TTYs)
        };
    };
}
```

```nix
{ config, lib, pkgs, inputs, ... }:

{
    imports = [ inputs.tbsm.homeManagerModules.tbsm ];

    tbsm = {
        enable = true;
        config = ''
            XserverArg="-quiet -nolisten tcp"
            verboseLevel=1
            theme=""
        '';

        sessions = [
            {
                Name = "Hyprland";
                Comment = "Start the Hyprland Wayland Compositor";
                Exec = "${pkgs.hyprland}/bin/Hyprland";
                Type = "Application";
                DesktopNames = "Hyprland";
                Keywords = "wayland;compositor;hyprland;";
            }
        ];
    };
}
