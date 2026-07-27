{
  lib,
  pkgs,
  config,
  ...
}: let
  cfg = config.grimoire.desktops.hyprland;

  luaString = s: builtins.toJSON s;

  envContent = lib.optionalString (cfg.env.variables != {} || cfg.env.dbusVariables != {}) (
    lib.concatStringsSep "\n" (
      lib.mapAttrsToList (name: value: "hl.env(${luaString name}, ${luaString value})") cfg.env.variables
      ++ lib.mapAttrsToList (name: value: "hl.env(${luaString name}, ${luaString value}, true)") cfg.env.dbusVariables
    )
  );

  pluginContent = lib.optionalString (cfg.plugins != []) (
    lib.concatStringsSep "\n" (
      map (
        plugin: "hl.plugin.load(${luaString (
          if lib.types.package.check plugin
          then "${plugin}/lib/lib${plugin.pname}.so"
          else toString plugin
        )})"
      )
      cfg.plugins
    )
  );

  sessionTargetContent = lib.optionalString cfg.systemd.enable ''
    hl.on("hyprland.start", function()
      hl.exec_cmd("systemctl --user start hyprland-session.target")
    end)

    hl.on("hyprland.shutdown", function()
      os.execute("systemctl --user stop hyprland-session.target && sleep 0.1")
    end)
  '';

  requireContent = lib.concatStringsSep "\n" (
    map (
      path:
        if lib.pathIsDirectory path
        then "require(\"${path}/*.lua\")"
        else "require(\"${path}\")"
    )
    cfg.configs
  );

  configContent = lib.concatStringsSep "\n\n" (
    lib.filter (s: s != "") [
      envContent
      pluginContent
      sessionTargetContent
      requireContent
    ]
  );

  hasConfig = configContent != "";

  portalConfigContent = lib.generators.toINI {} {
    preferred = {
      default = lib.concatStringsSep ";" cfg.xdgPortal.default;
    };
  };
in {
  options.grimoire.desktops.hyprland = {
    enable = lib.mkEnableOption "hyprland";

    package = lib.mkPackageOption pkgs "hyprland" {
      nullable = true;
      extraDescription = "Set to null if Hyprland is installed via NixOS module.";
    };

    portalPackage = lib.mkPackageOption pkgs "xdg-desktop-portal-hyprland" {
      nullable = true;
      extraDescription = "Set to null if the portal is installed via NixOS module.";
    };

    plugins = lib.mkOption {
      type = lib.types.listOf (lib.types.either lib.types.package lib.types.path);
      default = [];
      example = lib.literalExpression ''
        [
          pkgs.hyprlandPlugins.hyprbars
        ]
      '';
      description = ''
        List of Hyprland plugins to load. Can be packages or paths to plugin .so files.
      '';
    };

    configs = lib.mkOption {
      type = lib.types.listOf lib.types.path;
      default = [];
      example = lib.literalExpression ''
        [
          ./hyprland
          ./hosts/desktop/hyprland.lua
        ]
      '';
      description = ''
        Lua configuration files or directories. Each entry is loaded from the
        generated `hypr/hyprland.lua` entry point via `require`, giving every
        file an isolated error scope. Directories load all contained `*.lua`
        files in sorted order.
      '';
    };

    env.variables = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {};
      example = {
        XCURSOR_SIZE = "24";
      };
      description = ''
        Environment variables to set via `hl.env(name, value)` calls.
      '';
    };

    env.dbusVariables = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {};
      example = {
        XCURSOR_SIZE = "24";
      };
      description = ''
        Like {option}`env.variables`, but also exported to the systemd and D-Bus
        activation environment via the third `dbus` argument of `hl.env`, so
        D-Bus-activated services (xdg-desktop-portal and friends) see them.

        Hyprland already exports a fixed set (WAYLAND_DISPLAY, XDG_CURRENT_DESKTOP,
        QT_QPA_PLATFORMTHEME, PATH, ...) on its own; use this only for variables
        outside that set, such as cursor theme variables.
      '';
    };

    xdgPortal = {
      enable = lib.mkEnableOption "XDG portal configuration" // {default = true;};

      default = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = ["hyprland" "gtk"];
        description = ''
          List of portals to use, in order of preference.
        '';
      };
    };

    systemd = {
      enable =
        lib.mkEnableOption "systemd integration"
        // {
          default = true;
          description = ''
            Whether to manage `hyprland-session.target`, binding the user
            session to `graphical-session.target`. Hyprland imports its
            environment into systemd and D-Bus on its own.
          '';
        };

      enableXdgAutostart = lib.mkEnableOption ''
        autostart of applications using systemd-xdg-autostart-generator
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    packages = lib.filter (p: p != null) [
      cfg.package
      cfg.portalPackage
    ];

    xdg.config.files = {
      "hypr/hyprland.lua" = lib.mkIf hasConfig {
        text = configContent;
      };

      "xdg-desktop-portal/hyprland-portals.conf" = lib.mkIf cfg.xdgPortal.enable {
        text = portalConfigContent;
      };
    };

    systemd.targets.hyprland-session = lib.mkIf cfg.systemd.enable {
      description = "Hyprland compositor session";
      documentation = ["man:systemd.special(7)"];
      bindsTo = ["graphical-session.target"];
      wants =
        ["graphical-session-pre.target"]
        ++ lib.optional cfg.systemd.enableXdgAutostart "xdg-desktop-autostart.target";
      after = ["graphical-session-pre.target"];
      before = lib.mkIf cfg.systemd.enableXdgAutostart ["xdg-desktop-autostart.target"];
      unitConfig.PropagatesStopTo = ["graphical-session.target"];
    };
  };
}
