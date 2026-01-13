{
  lib,
  config,
  ...
}: let
  cfg = config.grimoire.programs.ssh;

  hostBlockType = lib.types.submodule {
    options = {
      host = lib.mkOption {
        type = lib.types.str;
        description = "Host pattern(s) for this block.";
        example = "*.example.com";
      };

      options = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = {};
        description = "SSH options for this block.";
        example = {
          User = "git";
          IdentityFile = "~/.ssh/id_ed25519";
        };
      };
    };
  };

  blockToString = block: let
    options = lib.concatStringsSep "\n" (
      lib.mapAttrsToList (key: value: "\t${key} ${value}") block.options
    );
  in ''
    Host ${block.host}
    ${options}'';

  includesToString = includes:
    lib.concatMapStringsSep "\n" (path: "Include ${path}") includes;

  toSSHConfig = let
    includesSection =
      if cfg.includes != []
      then includesToString cfg.includes + "\n\n"
      else "";
    blocksSection = lib.concatStringsSep "\n\n" (map blockToString cfg.blocks);
    extraSection =
      if cfg.extraConfig != ""
      then "\n\n${cfg.extraConfig}"
      else "";
  in
    includesSection + blocksSection + extraSection;
in {
  options.grimoire.programs.ssh = {
    enable = lib.mkEnableOption "ssh";

    blocks = lib.mkOption {
      type = lib.types.listOf hostBlockType;
      default = [];
      description = ''
        Ordered list of Host blocks. Each block has a `host` pattern
        and an `options` attrset with SSH configuration options.

        Blocks are written in order - put specific hosts before wildcards.
      '';
      example = [
        {
          host = "github.com";
          options = {
            User = "git";
            IdentityFile = "~/.ssh/id_ed25519";
          };
        }
        {
          host = "*";
          options = {
            IdentityAgent = "~/.1password/agent.sock";
          };
        }
      ];
    };

    includes = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "List of paths to include. Added at the top of the config.";
      example = ["~/.ssh/config.d/*"];
    };

    extraConfig = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = "Extra configuration appended to the end of the SSH config.";
    };
  };

  config = lib.mkIf cfg.enable {
    files.".ssh/config" = lib.mkIf (cfg.blocks != [] || cfg.includes != [] || cfg.extraConfig != "") {
      text = toSSHConfig;
    };
  };
}
