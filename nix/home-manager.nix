{ self }:
{ config, lib, pkgs, ... }:

let
  cfg = config.programs.kaname;
  jsonFormat = pkgs.formats.json { };
  defaultSettings = builtins.fromJSON (builtins.readFile ../config/default.json);
  defaultMenus = builtins.fromJSON (builtins.readFile ../config/menus.json);
in
{
  options.programs.kaname = {
    enable = lib.mkEnableOption "the Kaname Quickshell launcher";

    package = lib.mkOption {
      type = lib.types.package;
      default = self.packages.${pkgs.stdenv.hostPlatform.system}.default;
      defaultText = lib.literalExpression
        "inputs.kaname.packages.${pkgs.stdenv.hostPlatform.system}.default";
      description = "Kaname package to install.";
    };

    settings = lib.mkOption {
      type = jsonFormat.type;
      default = defaultSettings;
      description = ''
        Contents of Kaname's config.json. Attribute definitions are merged with
        the bundled defaults, so only values that differ need to be specified.
      '';
    };

    menus = lib.mkOption {
      type = jsonFormat.type;
      default = defaultMenus;
      description = ''
        Contents of Kaname's menus.json. Attribute definitions are merged with
        the bundled defaults.
      '';
    };

    autostart = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Start kaname-shell with the graphical user session. Disable this when
        Niri starts kaname-shell or Kaname is embedded in another long-running
        Quickshell process.
      '';
    };

    matugen.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Install Kaname's matugen template below the matugen configuration
        directory. This does not overwrite or take ownership of config.toml.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ cfg.package ];

    xdg.configFile = {
      "kaname/config.json".source =
        jsonFormat.generate "kaname-config.json" cfg.settings;
      "kaname/menus.json".source =
        jsonFormat.generate "kaname-menus.json" cfg.menus;
    } // lib.optionalAttrs cfg.matugen.enable {
      "kaname/kaname-colors.json.template".source =
        "${cfg.package}/share/kaname/matugen/kaname-colors.json.template";
      "matugen/templates/kaname-colors.json".source =
        "${cfg.package}/share/kaname/matugen/kaname-colors.json.template";
    };

    systemd.user.services.kaname = lib.mkIf cfg.autostart {
      Unit = {
        Description = "Kaname Quickshell launcher";
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session.target" ];
      };
      Service = {
        ExecStart = "${cfg.package}/bin/kaname-shell";
        Restart = "on-failure";
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };
  };
}
