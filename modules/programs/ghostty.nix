{
  lib,
  pkgs,
  config,
  ...
}: let
  cfg = config.grimoire.programs.ghostty;

  format = pkgs.formats.keyValue {
    mkKeyValue = lib.generators.mkKeyValueDefault {} " = ";
    listsAsDuplicateKeys = true;
  };
in {
  options.grimoire.programs.ghostty = {
    enable = lib.mkEnableOption "ghostty";

    package = lib.mkPackageOption pkgs "ghostty" {
      nullable = true;
    };

    settings = lib.mkOption {
      type = format.type;
      default = {};
      example = lib.literalExpression ''
        {
          theme = "Mellow";
          font-family = "Berkeley Mono";
          font-size = 14;
          window-padding-x = 8;
          window-padding-y = 8;
          confirm-close-surface = false;
          # Repeatable keys can be specified as lists
          font-feature = [ "calt" "liga" ];
          keybind = [
            "ctrl+shift+t=new_tab"
            "ctrl+shift+n=new_window"
          ];
        }
      '';
      description = ''
        Configuration options for Ghostty. These are written to
        `$XDG_CONFIG_HOME/ghostty/config` in Ghostty's key = value format.

        See the Ghostty documentation for available options:
        https://ghostty.org/docs/config/reference

        Or run `ghostty +show-config --default --docs` for offline documentation.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    packages = lib.mkIf (cfg.package != null) [cfg.package];

    xdg.config.files."ghostty/config" = lib.mkIf (cfg.settings != {}) {
      source = format.generate "ghostty-config" cfg.settings;
    };
  };
}
