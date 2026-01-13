{
  lib,
  pkgs,
  config,
  ...
}: let
  cfg = config.grimoire.programs.opencode;
  format = pkgs.formats.json {};

  filterNulls = attrs:
    lib.filterAttrsRecursive (_: v: v != null) attrs;

  finalSettings = filterNulls (
    {
      "$schema" = cfg.schema;
      inherit (cfg) theme;
      model = cfg.model;
      small_model = cfg.smallModel;
      default_agent = cfg.defaultAgent;
      disabled_providers = cfg.disabledProviders;
      enabled_providers = cfg.enabledProviders;
      inherit (cfg) keybinds mcp provider agent command permission;
    }
    // cfg.settings
  );
in {
  options.grimoire.programs.opencode = {
    enable = lib.mkEnableOption "opencode";

    package = lib.mkPackageOption pkgs "opencode" {
      nullable = true;
    };

    schema = lib.mkOption {
      type = lib.types.str;
      default = "https://opencode.ai/config.json";
      description = "JSON schema URL for configuration validation.";
    };

    theme = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "catppuccin";
      description = ''
        Theme name. Built-in themes include: opencode, tokyonight, catppuccin,
        catppuccin-macchiato, gruvbox, kanagawa, nord, everforest, ayu, one-dark, matrix.
      '';
    };

    model = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "anthropic/claude-sonnet-4-20250514";
      description = "Default model in `provider/model` format.";
    };

    smallModel = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "anthropic/claude-haiku-3-5-20241022";
      description = "Model for lightweight tasks like title generation.";
    };

    defaultAgent = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "plan";
      description = "Default agent to use. Must be a primary agent.";
    };

    disabledProviders = lib.mkOption {
      type = lib.types.nullOr (lib.types.listOf lib.types.str);
      default = null;
      example = ["ollama" "lmstudio"];
      description = "List of provider IDs to disable.";
    };

    enabledProviders = lib.mkOption {
      type = lib.types.nullOr (lib.types.listOf lib.types.str);
      default = null;
      example = ["anthropic" "openai"];
      description = "Allowlist of provider IDs. If set, only these providers are enabled.";
    };

    keybinds = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {};
      example = {
        leader = "ctrl+a";
        session_new = "<leader>n";
        model_list = "<leader>m";
      };
      description = ''
        Keybind configuration. Keys are action names, values are key combinations.
        Use `<leader>` to reference the leader key, `none` to disable.
        Multiple bindings can be comma-separated.
      '';
    };

    mcp = lib.mkOption {
      type = lib.types.attrsOf format.type;
      default = {};
      example = lib.literalExpression ''
        {
          fetch = {
            type = "local";
            command = ["uvx" "mcp-server-fetch"];
          };
          github = {
            type = "local";
            command = ["npx" "-y" "@modelcontextprotocol/server-github"];
            environment.GITHUB_PERSONAL_ACCESS_TOKEN = "{env:GITHUB_TOKEN}";
          };
        }
      '';
      description = ''
        MCP (Model Context Protocol) server configuration.
        Each server can be local (with command) or remote (with url).
      '';
    };

    provider = lib.mkOption {
      type = lib.types.attrsOf format.type;
      default = {};
      example = lib.literalExpression ''
        {
          anthropic.options.apiKey = "{env:ANTHROPIC_API_KEY}";
          custom-openai = {
            npm = "@ai-sdk/openai-compatible";
            options = {
              baseURL = "https://api.example.com/v1";
              apiKey = "{env:CUSTOM_API_KEY}";
            };
          };
        }
      '';
      description = ''
        Provider configuration for API keys, custom endpoints, and model options.
        Supports variable substitution with `{env:VAR_NAME}` syntax.
      '';
    };

    agent = lib.mkOption {
      type = lib.types.attrsOf format.type;
      default = {};
      example = lib.literalExpression ''
        {
          build = {
            model = "anthropic/claude-sonnet-4-20250514";
            temperature = 0.7;
          };
          custom-agent = {
            description = "A custom specialized agent";
            prompt = "You are a specialized assistant for...";
            mode = "subagent";
          };
        }
      '';
      description = ''
        Agent configuration. Customize built-in agents (build, plan, explore, etc.)
        or define custom agents with their own prompts, models, and permissions.
      '';
    };

    command = lib.mkOption {
      type = lib.types.attrsOf format.type;
      default = {};
      example = lib.literalExpression ''
        {
          review = {
            description = "Review code changes";
            template = "Review the following code for issues: $ARGUMENTS";
          };
          test = {
            description = "Run tests";
            template = "Run the test suite and fix any failures";
            agent = "build";
          };
        }
      '';
      description = ''
        Custom slash command definitions.
        Templates support `$ARGUMENTS`, `$1`, `$2` for arguments,
        `` !`command` `` for shell output, and `@path` for file references.
      '';
    };

    permission = lib.mkOption {
      type = format.type;
      default = {};
      example = lib.literalExpression ''
        {
          "*" = "allow";
          bash."rm *" = "deny";
          external_directory = "ask";
        }
      '';
      description = ''
        Permission configuration for tools.
        Values can be "allow", "ask", or "deny".
        Supports glob patterns for granular control.
      '';
    };

    settings = lib.mkOption {
      type = format.type;
      default = {};
      example = lib.literalExpression ''
        {
          autoupdate = false;
          share = "disabled";
          compaction = {
            auto = true;
            prune = true;
          };
          tui.scroll_speed = 1.5;
          lsp.typescript.disabled = true;
        }
      '';
      description = ''
        Additional OpenCode configuration options.
        These are merged with other options and written to
        {file}`~/.config/opencode/opencode.json`.

        See https://opencode.ai/docs/config for all available options.
      '';
    };

    agents = {
      file = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        example = lib.literalExpression "./AGENTS.md";
        description = ''
          Path to an AGENTS.md file to use as global instructions.
          This file will be copied to {file}`~/.config/opencode/AGENTS.md`.

          Mutually exclusive with {option}`agents.text`.
        '';
      };

      text = lib.mkOption {
        type = lib.types.nullOr lib.types.lines;
        default = null;
        example = lib.literalExpression ''
          '''
          # Global Instructions

          - Always ask clarifying questions when necessary
          '''
        '';
        description = ''
          Inline text content for the global AGENTS.md file.
          This will be written to {file}`~/.config/opencode/AGENTS.md`.

          Mutually exclusive with {option}`agents.file`.
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = !(cfg.agents.file != null && cfg.agents.text != null);
        message = "grimoire.programs.opencode.agents.file and agents.text are mutually exclusive";
      }
    ];

    packages = lib.mkIf (cfg.package != null) [cfg.package];

    xdg.config.files = {
      "opencode/opencode.json" = lib.mkIf (finalSettings != {}) {
        source = format.generate "opencode.json" finalSettings;
      };

      "opencode/AGENTS.md" = lib.mkIf (cfg.agents.file != null || cfg.agents.text != null) {
        source = lib.mkIf (cfg.agents.file != null) cfg.agents.file;
        text = lib.mkIf (cfg.agents.text != null) cfg.agents.text;
      };
    };
  };
}
