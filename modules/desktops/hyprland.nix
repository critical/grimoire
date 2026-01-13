{
  lib,
  pkgs,
  config,
  ...
}: let
  cfg = config.grimoire.desktops.hyprland;

  # Port of toHyprconf from Home Manager / hjem-rum
  # Generates proper Hyprland config with brace syntax for categories
  toHyprconf = {
    attrs,
    indentLevel ? 0,
    importantPrefixes ? ["$"],
  }: let
    initialIndent = lib.concatStrings (lib.replicate indentLevel "  ");

    toHyprconf' = indent: attrs: let
      # Sections are nested attrs or lists of attrs
      sections =
        lib.filterAttrs
        (_: v: builtins.isAttrs v || (builtins.isList v && builtins.all builtins.isAttrs v))
        attrs;

      # Generate a section with braces
      mkSection = n: attrs:
        if builtins.isList attrs
        then lib.concatMapStringsSep "\n" (a: mkSection n a) attrs
        else ''
          ${indent}${n} {
          ${toHyprconf' "  ${indent}" attrs}${indent}}
        '';

      # Generate key = value fields
      mkFields = lib.generators.toKeyValue {
        mkKeyValue = lib.generators.mkKeyValueDefault {} " = ";
        listsAsDuplicateKeys = true;
        inherit indent;
      };

      # All non-section fields (scalars and lists of scalars)
      allFields =
        lib.filterAttrs
        (_: v: !(builtins.isAttrs v || (builtins.isList v && builtins.all builtins.isAttrs v)))
        attrs;

      # Check if field name starts with any important prefix
      isImportantField = n: _:
        lib.foldl'
        (acc: prefix:
          if lib.hasPrefix prefix n
          then true
          else acc)
        false
        importantPrefixes;

      importantFields = lib.filterAttrs isImportantField allFields;
      regularFields = removeAttrs allFields (lib.attrNames importantFields);
    in
      mkFields importantFields
      + lib.concatStringsSep "\n" (lib.mapAttrsToList mkSection sections)
      + mkFields regularFields;
  in
    toHyprconf' initialIndent attrs;

  # Compute effective importantPrefixes (add "source" if sourceFirst is enabled)
  effectivePrefixes =
    cfg.importantPrefixes
    ++ lib.optional cfg.sourceFirst "source";

  # Merge all environment variables (user-defined + defaults if enabled)
  allEnv =
    (lib.optionalAttrs cfg.env.xdgDefaults {
      XDG_CURRENT_DESKTOP = "Hyprland";
      XDG_SESSION_TYPE = "wayland";
      XDG_SESSION_DESKTOP = "Hyprland";
    })
    // cfg.env.variables;

  # Generate environment variable lines (env = VAR,value)
  envContent = lib.optionalString (allEnv != {}) (
    lib.concatStringsSep "\n" (
      lib.mapAttrsToList (name: value: "env = ${name},${value}") allEnv
    )
  );

  # Generate D-Bus exported environment variable lines (envd = VAR,value)
  envdContent = lib.optionalString (cfg.envd != {}) (
    lib.concatStringsSep "\n" (
      lib.mapAttrsToList (name: value: "envd = ${name},${value}") cfg.envd
    )
  );

  # Generate D-Bus activation environment command
  dbusActivationContent = lib.optionalString cfg.systemd.enable (
    let
      variables = builtins.concatStringsSep " " cfg.systemd.variables;
      extraCommands = builtins.concatStringsSep " " (map (cmd: "&& ${cmd}") cfg.systemd.extraCommands);
    in "exec-once = ${pkgs.dbus}/bin/dbus-update-activation-environment --systemd ${variables} ${extraCommands}"
  );

  # Generate plugin loading commands using toHyprconf
  pluginContent = lib.optionalString (cfg.plugins != []) (
    toHyprconf {
      attrs = {
        plugin =
          map (
            plugin:
              if lib.types.package.check plugin
              then "${plugin}/lib/lib${plugin.pname}.so"
              else toString plugin
          )
          cfg.plugins;
      };
      importantPrefixes = effectivePrefixes;
    }
  );

  # Generate settings using toHyprconf
  settingsContent = lib.optionalString (cfg.settings != {}) (
    toHyprconf {
      attrs = cfg.settings;
      importantPrefixes = effectivePrefixes;
    }
  );

  # Combine all config sections
  configContent = lib.concatStringsSep "\n\n" (
    lib.filter (s: s != "") [
      dbusActivationContent
      pluginContent
      envContent
      envdContent
      settingsContent
      cfg.extraConfig
    ]
  );

  hasConfig = configContent != "";

  # XDG portal configuration content
  portalConfigContent = lib.generators.toINI {} {
    preferred = {
      default = lib.concatStringsSep ";" cfg.xdgPortal.default;
    };
  };

  # Use JSON format type for settings - handles arbitrary nesting
  jsonFormat = pkgs.formats.json {};
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

    settings = lib.mkOption {
      type = jsonFormat.type;
      default = {};
      example = lib.literalExpression ''
        {
          "$mod" = "SUPER";
          monitor = ",preferred,auto,auto";
          general = {
            gaps_in = 5;
            gaps_out = 20;
            border_size = 2;
          };
          bind = [
            "$mod, Q, exec, kitty"
            "$mod, C, killactive"
          ];
        }
      '';
      description = ''
        Hyprland configuration settings written in Nix.
        Nested attribute sets become categories with braces.
        Lists are expanded as duplicate keys.
      '';
    };

    extraConfig = lib.mkOption {
      type = lib.types.lines;
      default = "";
      example = ''
        # Source additional config files
        source = ~/.config/hypr/colors.conf
      '';
      description = "Extra lines appended to the Hyprland configuration.";
    };

    sourceFirst =
      lib.mkEnableOption "putting source entries at the top of the configuration"
      // {
        default = true;
      };

    importantPrefixes = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = ["$" "bezier" "name"];
      example = ["$" "bezier"];
      description = ''
        List of prefix of attributes to source at the top of the config.
        If `sourceFirst` is enabled, "source" is automatically added.
      '';
    };

    env = {
      variables = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = {};
        example = {
          XCURSOR_SIZE = "24";
        };
        description = ''
          Environment variables to set via `env = VAR,value` directives.
          Do NOT quote the values - they are raw strings.
        '';
      };

      xdgDefaults =
        lib.mkEnableOption "default XDG environment variables"
        // {
          default = true;
          description = ''
            Whether to set default XDG environment variables:
            - `XDG_CURRENT_DESKTOP=Hyprland`
            - `XDG_SESSION_TYPE=wayland`
            - `XDG_SESSION_DESKTOP=Hyprland`
          '';
        };
    };

    envd = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {};
      description = ''
        Environment variables to set via `envd = VAR,value` directives.
        Like `env`, but also exports to D-Bus activation environment (systemd only).
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
            Whether to enable systemd integration including:
            - `hyprland-session.target` for user services
            - D-Bus activation environment setup
          '';
        };

      variables = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [
          "DISPLAY"
          "HYPRLAND_INSTANCE_SIGNATURE"
          "WAYLAND_DISPLAY"
          "XDG_CURRENT_DESKTOP"
        ];
        example = ["--all"];
        description = ''
          Environment variables to import into the systemd and D-Bus user environment.
        '';
      };

      extraCommands = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [
          "systemctl --user stop hyprland-session.target"
          "systemctl --user start hyprland-session.target"
        ];
        description = ''
          Extra commands to run after D-Bus activation environment setup.
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
      "hypr/hyprland.conf" = lib.mkIf hasConfig {
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
    };
  };
}
