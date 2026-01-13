{
  lib,
  pkgs,
  config,
  ...
}: let
  cfg = config.grimoire.programs.starship;
  format = pkgs.formats.toml {};
in {
  options.grimoire.programs.starship = {
    enable = lib.mkEnableOption "starship";

    package = lib.mkPackageOption pkgs "starship" {
      nullable = true;
    };

    settings = lib.mkOption {
      type = format.type;
      default = {};
      example = {
        add_newline = false;
        character = {
          success_symbol = "[➜](bold green)";
          error_symbol = "[➜](bold red)";
        };
      };
      description = "Configuration written to {file}`~/.config/starship.toml`.";
    };

    integrations = {
      zsh = {
        enable = lib.mkEnableOption "zsh integration" // {default = true;};
      };
    };
  };

  config = lib.mkIf cfg.enable {
    packages = lib.mkIf (cfg.package != null) [cfg.package];

    xdg.config.files."starship.toml" = lib.mkIf (cfg.settings != {}) {
      source = format.generate "starship.toml" cfg.settings;
    };

    grimoire.programs.zsh.initConfig = lib.mkIf cfg.integrations.zsh.enable (
      lib.mkAfter ''
        eval "$(${
          if cfg.package != null
          then lib.getExe cfg.package
          else "starship"
        } init zsh)"
      ''
    );
  };
}
