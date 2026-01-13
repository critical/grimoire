{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    hjem = {
      url = "github:feel-co/hjem";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    nixpkgs,
    ...
  }: let
    supportedSystems = [
      "x86_64-linux"
      "aarch64-linux"
    ];

    forEachSystem = function:
      nixpkgs.lib.genAttrs supportedSystems (system: function nixpkgs.legacyPackages.${system});
  in {
    hjemModules = {
      default = self.hjemModules.grimoire;
      grimoire = import ./modules;
    };

    devShells = forEachSystem (pkgs: {
      default = pkgs.mkShell {
        packages = [
          pkgs.nil
          pkgs.alejandra
        ];
      };
    });
  };
}
