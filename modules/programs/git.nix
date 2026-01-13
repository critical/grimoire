{
  lib,
  pkgs,
  config,
  ...
}: let
  format = pkgs.formats.gitIni {};
  cfg = config.grimoire.programs.git;
in {
  options.grimoire.programs.git = {
    enable = lib.mkEnableOption "git";

    package = lib.mkPackageOption pkgs "git" {
      nullable = true;
    };

    settings = lib.mkOption {
      type = format.type;
      default = {};
      example = {
        user = {
          name = "Yuki Nagato";
          email = "yuki.nagato@sos-brigade.com";
          signingKey = "ssh-ed25519 ...";
        };
        init.defaultBranch = "main";
        push.autoSetupRemote = true;
      };
      description = "Git configuration written to `~/.config/git/config`.";
    };

    ignore = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      example = [
        ".DS_Store"
        ".direnv/"
      ];
      description = "Global ignore patterns written to `~/.config/git/ignore`.";
    };

    attributes = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      example = [
        "*.pdf diff=pdf"
        "*.json diff=json"
      ];
      description = "Global attributes written to `~/.config/git/attributes`.";
    };
  };

  config = lib.mkIf cfg.enable {
    packages = lib.mkIf (cfg.package != null) [cfg.package];

    xdg.config.files = {
      "git/config" = {
        generator = format.generate "config";
        value = cfg.settings;
      };

      "git/ignore" = lib.mkIf (cfg.ignore != []) {
        text = lib.concatStringsSep "\n" cfg.ignore;
      };

      "git/attributes" = lib.mkIf (cfg.attributes != []) {
        text = lib.concatStringsSep "\n" cfg.attributes;
      };
    };
  };
}
