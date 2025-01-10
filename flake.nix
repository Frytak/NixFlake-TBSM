{
    description = "A pure bash session or application launcher. Inspired by cdm, tdm and krunner.";

    inputs = {
        nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";

        flake-utils = {
            url = "github:numtide/flake-utils";
        };
    };

    outputs = { self, nixpkgs, flake-utils, ... }:
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
        nixosModules = {
            tbsm = { config, pkgs, lib, ... }:
            {
                options.tbsm = {
                    enable = lib.mkOption {
                        type = lib.types.bool;
                        default = false;
                        description = "Enable TBSM session manager.";
                    };
                };

                config = 
                let
                    tbsm = self.packages.${pkgs.system}.tbsm;
                in
                lib.mkIf config.tbsm.enable {
                    environment.systemPackages = [ tbsm ];

                    environment.etc."xdg/tbsm/themes".source = "${tbsm}/etc/xdg/tbsm/themes";
                    environment.etc."xdg/tbsm/whitelist/hyprland.desktop".text = ''
                        [Desktop Entry]
                        Name=Hyprland
                        Comment=Start the Hyprland Wayland Compositor
                        Exec=${pkgs.hyprland}/bin/Hyprland
                        Type=Application
                        DesktopNames=Hyprland
                        Keywords=wayland;compositor;hyprland;
                    '';
                    environment.etc."xdg/tbsm/tbsm.conf".text = ''
                        XserverArg="-quiet -nolisten tcp"
                        verboseLevel=1

                        theme="gently"
                    '';

                    environment.shellInit = ''
                        # Launch TBSM on TTY1 after login
                        if [ -z "$DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then
                            exec ${tbsm}/bin/tbsm </dev/tty >/dev/tty 2>&1
                        fi
                    '';
                };
            };
        };
    };
}
