{
  lib,
  pkgs,
  config,
  ...
}: let
  cfg = config.grimoire.programs.zsh;

  zdotdir = "\${XDG_CONFIG_HOME:-$HOME/.config}/zsh";

  setOptionsToString = opts:
    lib.concatMapStringsSep "\n" (opt: "setopt ${opt}") opts;

  unsetOptionsToString = opts:
    lib.concatMapStringsSep "\n" (opt: "unsetopt ${opt}") opts;

  aliasesToString = aliases:
    lib.concatStringsSep "\n" (
      lib.mapAttrsToList (name: value: "alias ${name}='${value}'") aliases
    );

  historySetOptions =
    lib.optional cfg.history.ignoreAllDups "hist_ignore_all_dups"
    ++ lib.optional cfg.history.ignoreSpace "hist_ignore_space"
    ++ lib.optional cfg.history.extended "extended_history"
    ++ lib.optional cfg.history.expireDupsFirst "hist_expire_dups_first"
    ++ lib.optional cfg.history.findNoDups "hist_find_no_dups"
    ++ lib.optional cfg.history.saveNoDups "hist_save_no_dups";

  historyUnsetOptions =
    lib.optional (!cfg.history.ignoreDups) "hist_ignore_dups"
    ++ lib.optional (!cfg.history.share) "share_history";

  pluginsConfig = lib.concatStringsSep "\n\n" (
    lib.filter (s: s != "") (
      lib.mapAttrsToList (
        name: plugin:
          lib.concatStringsSep "\n" (
            lib.filter (s: s != "") [
              "# ${name}"
              (lib.optionalString (plugin.completions != [])
                (lib.concatMapStringsSep "\n" (c: "fpath+=(${c})") plugin.completions))
              (lib.optionalString (plugin.source != null)
                ''source "${plugin.source}"'')
              (lib.optionalString (plugin.config != "")
                plugin.config)
            ]
          )
      )
      cfg.plugins
    )
  );

  hasEnvironmentVars = config.environment.sessionVariables != {};

  zshenvContent = lib.concatStringsSep "\n" (
    lib.filter (s: s != "") [
      ''export ZDOTDIR="${zdotdir}"''
      (lib.optionalString hasEnvironmentVars ''source "${config.environment.loadEnv}"'')
      cfg.envConfig
    ]
  );

  zshrcContent = lib.concatStringsSep "\n\n" (
    lib.filter (s: s != "") [
      pluginsConfig

      (lib.optionalString cfg.history.enable ''
        HISTFILE="${cfg.history.path}"
        HISTSIZE=${toString cfg.history.size}
        SAVEHIST=${toString cfg.history.save}'')

      (lib.optionalString (cfg.setOptions != [] || historySetOptions != [])
        (setOptionsToString (cfg.setOptions ++ historySetOptions)))

      (lib.optionalString (cfg.unsetOptions != [] || historyUnsetOptions != [])
        (unsetOptionsToString (cfg.unsetOptions ++ historyUnsetOptions)))

      (lib.optionalString cfg.completion.enable (
        lib.concatStringsSep "\n" (
          lib.filter (s: s != "") [
            "autoload -Uz compinit"
            "compinit -C"
            (lib.optionalString cfg.completion.caseInsensitive
              "zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'")
            (lib.optionalString cfg.completion.menuSelect
              "zstyle ':completion:*' menu select")
          ]
        )
      ))

      (lib.optionalString cfg.viMode.enable (
        lib.concatStringsSep "\n" [
          "bindkey -v"
          "export KEYTIMEOUT=${toString cfg.viMode.keyTimeout}"
          (lib.optionalString cfg.viMode.editCommandLine ''
            autoload -Uz edit-command-line
            zle -N edit-command-line
            bindkey -M vicmd 'v' edit-command-line'')
        ]
      ))

      (lib.optionalString (cfg.aliases != {}) (aliasesToString cfg.aliases))

      cfg.initConfig
    ]
  );

  zprofileContent = cfg.profileConfig;
  zloginContent = cfg.loginConfig;
  zlogoutContent = cfg.logoutConfig;

  pluginType = lib.types.submodule {
    options = {
      source = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        example = lib.literalExpression ''"''${pkgs.nix-zsh-completions}/share/zsh/plugins/nix/nix-zsh-completions.plugin.zsh"'';
        description = "Path to the plugin file to source.";
      };

      completions = lib.mkOption {
        type = lib.types.listOf lib.types.path;
        default = [];
        example = lib.literalExpression ''["''${pkgs.nix-zsh-completions}/share/zsh/site-functions"]'';
        description = "Paths to add to fpath for completions.";
      };

      config = lib.mkOption {
        type = lib.types.lines;
        default = "";
        description = "Plugin-specific configuration added after sourcing.";
      };
    };
  };
in {
  options.grimoire.programs.zsh = {
    enable = lib.mkEnableOption "zsh";

    package = lib.mkPackageOption pkgs "zsh" {
      nullable = true;
    };

    plugins = lib.mkOption {
      type = lib.types.attrsOf pluginType;
      default = {};
      example = lib.literalExpression ''
        {
          nix-zsh-completions = {
            source = "''${pkgs.nix-zsh-completions}/share/zsh/plugins/nix/nix-zsh-completions.plugin.zsh";
            completions = ["''${pkgs.nix-zsh-completions}/share/zsh/site-functions"];
          };
        }
      '';
      description = "Plugins to load with explicit source paths and completions.";
    };

    history = {
      enable = lib.mkEnableOption "zsh history" // {default = true;};

      path = lib.mkOption {
        type = lib.types.str;
        default = "${zdotdir}/.zhistory";
        description = "Path to the history file.";
      };

      size = lib.mkOption {
        type = lib.types.int;
        default = 10000;
        description = "Number of history entries to keep in memory.";
      };

      save = lib.mkOption {
        type = lib.types.int;
        default = 10000;
        description = "Number of history entries to save to file.";
      };

      ignoreDups = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Ignore duplicate entries in history.";
      };

      ignoreAllDups = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Remove older duplicate entries from history.";
      };

      ignoreSpace = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Ignore commands starting with a space.";
      };

      share = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Share history between all zsh sessions.";
      };

      extended = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Save timestamp and duration to history file.";
      };

      expireDupsFirst = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Expire duplicate entries first when trimming history.";
      };

      findNoDups = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Do not display duplicates when searching history.";
      };

      saveNoDups = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Do not write duplicate entries to history file.";
      };
    };

    setOptions = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      example = ["autocd" "extendedglob" "nomatch" "notify"];
      description = "Shell options to enable with setopt.";
    };

    unsetOptions = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      example = ["beep" "nomatch"];
      description = "Shell options to disable with unsetopt.";
    };

    completion = {
      enable = lib.mkEnableOption "zsh completion";

      caseInsensitive = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable case-insensitive completion.";
      };

      menuSelect = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable arrow-key driven completion menu.";
      };
    };

    viMode = {
      enable = lib.mkEnableOption "vi mode";

      keyTimeout = lib.mkOption {
        type = lib.types.int;
        default = 1;
        description = "Timeout in hundredths of a second for key sequences.";
      };

      editCommandLine = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Press 'v' in normal mode to edit command in $EDITOR.";
      };
    };

    aliases = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {};
      example = {
        ll = "ls -la";
        vim = "nvim";
      };
      description = "Shell aliases.";
    };

    envConfig = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = "Content for .zshenv (sourced for all shells).";
    };

    profileConfig = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = "Content for .zprofile (sourced for login shells).";
    };

    initConfig = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = "Content for .zshrc (sourced for interactive shells).";
    };

    loginConfig = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = "Content for .zlogin (sourced after .zshrc for login shells).";
    };

    logoutConfig = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = "Content for .zlogout (sourced when login shell exits).";
    };
  };

  config = lib.mkIf cfg.enable {
    packages = lib.mkIf (cfg.package != null) [cfg.package];

    files.".zshenv" = lib.mkIf (zshenvContent != "") {
      text = zshenvContent;
    };

    xdg.config.files = {
      "zsh/.zshrc" = lib.mkIf (zshrcContent != "") {
        text = zshrcContent;
      };

      "zsh/.zprofile" = lib.mkIf (zprofileContent != "") {
        text = zprofileContent;
      };

      "zsh/.zlogin" = lib.mkIf (zloginContent != "") {
        text = zloginContent;
      };

      "zsh/.zlogout" = lib.mkIf (zlogoutContent != "") {
        text = zlogoutContent;
      };
    };
  };
}
