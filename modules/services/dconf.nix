{
  lib,
  pkgs,
  config,
  ...
}: let
  cfg = config.grimoire.services.dconf;

  inherit (builtins) isString isBool isInt isFloat isList typeOf;

  toDconfValue = value:
    if isString value
    then "'${value}'"
    else if isBool value
    then lib.boolToString value
    else if isInt value || isFloat value
    then toString value
    else if isList value
    then "[${lib.concatMapStringsSep ", " toDconfValue value}]"
    else throw "Unsupported dconf value type: ${typeOf value}";

  keyfileContent =
    lib.generators.toINI {
      mkKeyValue = key: value: "${key}=${toDconfValue value}";
    }
    cfg.settings;

  keyfile = pkgs.writeText "dconf-settings.ini" keyfileContent;
in {
  options.grimoire.services.dconf = {
    enable = lib.mkEnableOption "dconf settings management";

    package = lib.mkPackageOption pkgs "dconf" {};

    settings = lib.mkOption {
      type = lib.types.attrsOf (lib.types.attrsOf (lib.types.oneOf [
        lib.types.str
        lib.types.bool
        lib.types.int
        lib.types.float
        (lib.types.listOf lib.types.str)
        (lib.types.listOf lib.types.int)
      ]));
      default = {};
      example = lib.literalExpression ''
        {
          "org/gnome/desktop/interface" = {
            color-scheme = "prefer-dark";
            gtk-theme = "Adwaita-dark";
            cursor-theme = "Adwaita";
          };
          "org/gnome/desktop/wm/preferences" = {
            button-layout = "close,minimize,maximize:";
          };
        }
      '';
      description = ''
        dconf settings to apply. Keys are dconf paths (without leading slash),
        values are attribute sets of key-value pairs.

        Settings are applied via `dconf load` on system activation.
        Running applications will be notified of changes via D-Bus.
      '';
    };
  };

  config = lib.mkIf (cfg.enable && cfg.settings != {}) {
    packages = [cfg.package];

    systemd.services.dconf-load = {
      description = "Load dconf settings";
      wantedBy = ["default.target"];
      after = ["dbus.socket"];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };

      script = ''
        ${lib.getExe cfg.package} load / < ${keyfile}
      '';
    };
  };
}
