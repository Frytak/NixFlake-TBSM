{
    description = "A pure bash session or application launcher. Inspired by cdm, tdm and krunner.";

    inputs = {
        nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";

        home-manager = {
            url = "github:nix-community/home-manager/release-24.11";
            inputs.nixpkgs.follows = "nixpkgs";
        };

        flake-utils = {
            url = "github:numtide/flake-utils";
        };
    };

    outputs = { self, nixpkgs, flake-utils, home-manager, ... }:
    flake-utils.lib.eachDefaultSystem (system:
        let
            pkgs = nixpkgs.legacyPackages.${system};
        in
        {
            packages.tbsm = pkgs.stdenv.mkDerivation {
                pname = "tbsm";
                version = "v0.7";

                src = pkgs.fetchFromGitHub {
                    owner = "loh-tar";
                    repo = "tbsm";
                    rev = "v0.7";
                    hash = "sha256-wGw/+mZhtB9Z8xYgiH9593aIS8Xg49+yGPinKv3SEnQ=";
                };

                installPhase = ''
                    # Install tbsm
                    mkdir -p $out/bin
                    install -pDm775 src/tbsm $out/bin/

                    # Install documentation
                    mkdir -p $out/usr/share/doc/tbsm
                    install -pDm644 doc/* $out/usr/share/doc/tbsm

                    # Install themes
                    mkdir -p $out/etc/xdg/tbsm/themes
                    install -pDm644 themes/* $out/etc/xdg/tbsm/themes
                '';
            };
        }
    ) //
    {
        homeManagerModules.tbsm = { config, pkgs, lib, ... }:
        {
            options.tbsm = {
                enable = lib.mkOption {
                    type = lib.types.bool;
                    description = "Enable TBSM.";
                    default = false;
                };

                config = lib.mkOption {
                    type = lib.types.nullOr lib.types.str;
                    description = "Configuration for TBSM.";
                    default = null;
                    example = ''
                        XserverArg="-quiet -nolisten tcp"
                        verboseLevel=1
                        theme=""
                    '';
                };

                sessions = lib.mkOption {
                    type = lib.types.listOf lib.types.attrs;
                    description = "`.desktop` session entries.";
                    default = [];
                    example = [
                        {
                            Name = "Hyprland";
                            Comment = "Start the Hyprland Wayland Compositor";
                            Exec = "\${pkgs.hyprland}/bin/Hyprland";
                            Type = "Application";
                            DesktopNames = "Hyprland";
                            Keywords = "wayland;compositor;hyprland;";
                        }
                    ];
                };

                defaultSession = lib.mkOption {
                    type = lib.types.nullOr lib.types.str;
                    description = "Default session";
                    default = null;
                    example = "Hyprland";
                };
            };

            config = 
            let
                tbsm = self.packages.${pkgs.system}.tbsm;

                nixToDesktopEntry = entry: (
                    lib.attrsets.foldlAttrs (acc: name: value:
                        acc + "${name}=${value}\n"
                    ) "[Desktop Entry]\n" entry
                );

                # Check if each entry in `sessions` has `Name`
                sessions =
                    assert (builtins.all (session: builtins.hasAttr "Name" session) config.tbsm.sessions) || throw "some `tbsm.sessions` entry doesn't have a `Name` attribute which is required";
                    config.tbsm.sessions;

                # Check if `defaultSession` is defined in `sessions`
                defaultSession = 
                    assert (builtins.elem config.tbsm.defaultSession (map (session: session.Name) sessions)) || throw "`tbsm.defaultSession = \"${config.tbsm.defaultSession}\"` is not defined in `tbsm.sessions`";
                    config.tbsm.defaultSession;
            in
            lib.mkIf config.tbsm.enable {
                home.packages = [ tbsm ];

                # Set config file if not null
                home.file = lib.attrsets.optionalAttrs (config.tbsm.config != null) {
                    ".config/tbsm/tbsm.conf".text = config.tbsm.config;
                # Generate `.desktop` files from `config.tbsm.sessions`
                } // builtins.foldl' (acc: entry:
                    acc // {
                        ".config/tbsm/whitelist/${entry.Name}.desktop".text = nixToDesktopEntry entry;
                    }
                ) {} sessions //
                # Set the default session if defined
                lib.attrsets.optionalAttrs (defaultSession != null) {
                    ".config/tbsm/000-default-session.desktop".text = nixToDesktopEntry (builtins.elemAt (builtins.filter (entry: entry.Name == defaultSession) sessions) 0);
                };
            };
        };

        nixosModules.tbsm = { config, pkgs, lib, ... }:
        {
            options.tbsm = {
                enable = lib.mkOption {
                    type = lib.types.bool;
                    description = "Enable TBSM.";
                    default = false;
                };

                defaultThemes = lib.mkOption {
                    type = lib.types.bool;
                    description = "Enable TBSM default themes (places default themes at `/etc/xdg/tbsm/themes`).";
                    default = false;
                };

                autoStart = {
                    enable = lib.mkOption {
                        type = lib.types.bool;
                        description = "Makes TBSM auto start upon loging into a TTY.";
                        default = false;
                    };

                    allowedTtys = lib.mkOption {
                        type = lib.types.listOf lib.types.str;
                        description = "List of TTYs where TBSM should launch, or 'all' to launch on all TTYs.";
                        default = [ "/dev/tty1" ];
                        example = [ "all" ];
                    };
                };

                config = lib.mkOption {
                    type = lib.types.nullOr lib.types.str;
                    description = "Configuration for TBSM.";
                    default = null;
                    example = ''
                        XserverArg="-quiet -nolisten tcp"
                        verboseLevel=1
                        theme=""
                    '';
                };
            };

            config = 
            let
                tbsm = self.packages.${pkgs.system}.tbsm;
                allowedTtys = lib.strings.concatMapStrings (x: " " + x) config.tbsm.autoStart.allowedTtys;
            in
            lib.mkIf config.tbsm.enable {
                environment.systemPackages = [ tbsm ];

                environment.etc = lib.attrsets.optionalAttrs (config.tbsm.defaultThemes) {
                    "xdg/tbsm/themes".source = "${tbsm}/etc/xdg/tbsm/themes";
                } // lib.attrsets.optionalAttrs (config.tbsm.config != null) {
                    "xdg/tbsm/tbsm.conf".text = config.tbsm.config;
                };

                # Launch TBSM on specific TTYs after login
                environment.shellInit = lib.mkIf config.tbsm.autoStart.enable ''
                    # Launch TBSM on specific TTYs after login
                    if [ -z "$DISPLAY" ]; then
                        allowed_ttys="${allowedTtys}"
                        current_tty=$(tty)

                        # If "all" is in the allowed_ttys list, launch on any TTY
                        if echo "$allowed_ttys" | grep -q "all"; then
                            exec ${pkgs.bashInteractive}/bin/bash ${tbsm}/bin/tbsm </dev/tty >/dev/tty 2>&1
                        # If the current TTY is in the allowed list
                        elif echo "$allowed_ttys" | grep -q "$current_tty"; then
                            exec ${pkgs.bashInteractive}/bin/bash ${tbsm}/bin/tbsm </dev/tty >/dev/tty 2>&1
                        fi
                    fi
                '';
            };
        };
    };
}
