{
  lib,
  pkgs,
  config,
  ...
}: let
  cfg = config.grimoire.programs.direnv;
  format = pkgs.formats.toml {};
in {
  options.grimoire.programs.direnv = {
    enable = lib.mkEnableOption "direnv";

    package = lib.mkPackageOption pkgs "direnv" {
      nullable = true;
    };

    settings = lib.mkOption {
      type = format.type;
      default = {};
      example = {
        global = {
          hide_env_diff = true;
          strict_env = true;
          warn_timeout = "10s";
        };
        whitelist = {
          prefix = ["/home/user/projects"];
        };
      };
      description = "Configuration written to {file}`~/.config/direnv/direnv.toml`.";
    };

    integrations = {
      nix-direnv = {
        enable = lib.mkEnableOption "nix-direnv integration";

        package = lib.mkPackageOption pkgs "nix-direnv" {
          nullable = true;
        };
      };

      zsh = {
        enable = lib.mkEnableOption "zsh integration" // {default = true;};
      };
    };
  };

  config = lib.mkIf cfg.enable {
    packages = lib.mkIf (cfg.package != null) [cfg.package];

    xdg.config.files = {
      "direnv/direnv.toml" = lib.mkIf (cfg.settings != {}) {
        source = format.generate "direnv.toml" cfg.settings;
      };

      "direnv/lib/nix-direnv.sh" = lib.mkIf cfg.integrations.nix-direnv.enable {
        source =
          if cfg.integrations.nix-direnv.package != null
          then "${cfg.integrations.nix-direnv.package}/share/nix-direnv/direnvrc"
          else "${pkgs.nix-direnv}/share/nix-direnv/direnvrc";
      };
    };

    grimoire.programs.zsh.initConfig = lib.mkIf cfg.integrations.zsh.enable (
      lib.mkAfter ''
        eval "$(${
          if cfg.package != null
          then lib.getExe cfg.package
          else "direnv"
        } hook zsh)"
      ''
    );
  };
}
