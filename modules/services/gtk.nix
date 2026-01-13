{
  lib,
  config,
  ...
}: let
  cfg = config.grimoire.services.gtk;

  formatSettingsKey = key:
    if lib.hasPrefix "gtk-" key
    then key
    else "gtk-" + key;

  # GTK 3/4 INI format generator
  toGtkINI = lib.generators.toINI {
    mkKeyValue = name: value: let
      name' = formatSettingsKey name;
      value' =
        if builtins.isBool value
        then lib.boolToString value
        else toString value;
    in "${name'}=${value'}";
  };

  # GTK 2 RC format generator
  toGtk2Text = settings: let
    formatGtk2 = name: value: let
      name' = formatSettingsKey name;
      value' =
        if builtins.isBool value
        then lib.boolToString value
        else if builtins.isString value
        then
          if lib.hasPrefix "GTK_" value
          then value
          else ''"${value}"''
        else toString value;
    in "${name'}=${value'}";
  in
    lib.concatStringsSep "\n" (lib.mapAttrsToList formatGtk2 settings);

  gtk2ConfigPath = "${config.xdg.config.directory}/gtk-2.0/gtkrc";

  themeName =
    cfg.settings.gtk-theme-name
    or cfg.settings.theme-name
    or null;
in {
  options.grimoire.services.gtk = {
    enable = lib.mkEnableOption "gtk";

    packages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [];
      example = lib.literalExpression "[pkgs.gnome-themes-extra pkgs.adwaita-icon-theme]";
      description = "Packages to install that affect GTK theming (themes, icons, cursors).";
    };

    settings = lib.mkOption {
      type = lib.types.attrsOf (lib.types.oneOf [lib.types.str lib.types.bool lib.types.int]);
      default = {};
      example = {
        theme-name = "Adwaita";
        icon-theme-name = "Adwaita";
        font-name = "Sans 11";
        cursor-theme-name = "Breeze";
        application-prefer-dark-theme = true;
      };
      description = ''
        GTK settings applied to both GTK 3 and GTK 4.
        Keys are automatically prefixed with `gtk-` if not already present.
        Written to {file}`~/.config/gtk-3.0/settings.ini` and {file}`~/.config/gtk-4.0/settings.ini`.
      '';
    };

    gtk2 = {
      settings = lib.mkOption {
        type = lib.types.attrsOf (lib.types.oneOf [lib.types.str lib.types.bool lib.types.int]);
        default = {};
        example = {
          theme-name = "Adwaita";
          icon-theme-name = "Adwaita";
          font-name = "Sans 11";
        };
        description = ''
          GTK 2 specific settings.
          Keys are automatically prefixed with `gtk-` if not already present.
          Written to {file}`~/.config/gtk-2.0/gtkrc`.
        '';
      };

      extraConfig = lib.mkOption {
        type = lib.types.lines;
        default = "";
        description = "Extra configuration to append to the GTK 2 config file.";
      };
    };

    css = lib.mkOption {
      type = lib.types.lines;
      default = "";
      example = ''
        /* Custom CSS */
        window {
          border-radius: 0;
        }
      '';
      description = ''
        Custom CSS applied to both GTK 3 and GTK 4.
        Written to {file}`~/.config/gtk-3.0/gtk.css` and {file}`~/.config/gtk-4.0/gtk.css`.
      '';
    };

    bookmarks = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      example = [
        "file:///home/user/Documents"
        "file:///home/user/Downloads"
      ];
      description = ''
        GTK bookmarks for file chooser dialogs.
        Written to {file}`~/.config/gtk-3.0/bookmarks`.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    packages = cfg.packages;

    environment.sessionVariables = {
      GTK2_RC_FILES = gtk2ConfigPath;
      GTK_THEME = lib.mkIf (themeName != null) themeName;
    };

    xdg.config.files = {
      "gtk-3.0/settings.ini" = lib.mkIf (cfg.settings != {}) {
        text = toGtkINI {Settings = cfg.settings;};
      };

      "gtk-4.0/settings.ini" = lib.mkIf (cfg.settings != {}) {
        text = toGtkINI {Settings = cfg.settings;};
      };

      "gtk-2.0/gtkrc" = lib.mkIf (cfg.gtk2.settings != {} || cfg.gtk2.extraConfig != "") {
        text = lib.concatStringsSep "\n" (
          lib.filter (s: s != "") [
            (lib.optionalString (cfg.gtk2.settings != {}) (toGtk2Text cfg.gtk2.settings))
            cfg.gtk2.extraConfig
          ]
        );
      };

      "gtk-3.0/gtk.css" = lib.mkIf (cfg.css != "") {
        text = cfg.css;
      };

      "gtk-4.0/gtk.css" = lib.mkIf (cfg.css != "") {
        text = cfg.css;
      };

      "gtk-3.0/bookmarks" = lib.mkIf (cfg.bookmarks != []) {
        text = lib.concatStringsSep "\n" cfg.bookmarks;
      };
    };
  };
}
